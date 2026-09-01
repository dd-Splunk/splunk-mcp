"""REST endpoint to read/set Buttercup workshop Eventgen mode (infrastructure vs NK threat)."""

from __future__ import annotations

import json
import os
import sys
from typing import Any, Dict, Optional, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import splunk.rest as rest
from splunk.persistconn.application import PersistentServerConnectionApplication

STANZA = "[attack.nk.purchase.sample]"
APP_DIR = os.path.join("etc", "apps", "SA-S4R")
MODES = frozenset({"infrastructure", "threat"})
EVENTGEN_DISABLE_URL = (
    "/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/disable"
)
EVENTGEN_ENABLE_URL = (
    "/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/enable"
)


def _splunk_home() -> str:
    return os.environ.get("SPLUNK_HOME", "/opt/splunk")


def eventgen_conf_path() -> str:
    """Same file as scripts/toggle-s4r-attack-nk.sh (bind-mounted default/)."""
    return os.path.join(_splunk_home(), APP_DIR, "default", "eventgen.conf")


def read_disabled_flag(path: str) -> Optional[bool]:
    """Return True when the stanza is disabled (infrastructure / NK off)."""
    in_stanza = False
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            stripped = line.rstrip("\n")
            if stripped == STANZA:
                in_stanza = True
                continue
            if in_stanza and stripped.startswith("disabled = "):
                value = stripped.split("=", 1)[1].strip()
                return value not in ("false", "0")
            if in_stanza and stripped.startswith("[") and stripped != STANZA:
                break
    return None


def write_disabled_flag(path: str, disabled: bool) -> None:
    value = "true" if disabled else "false"
    lines = open(path, encoding="utf-8").read().splitlines(keepends=True)
    out: list[str] = []
    in_stanza = False
    updated = False
    for line in lines:
        stripped = line.rstrip("\n")
        if stripped == STANZA:
            in_stanza = True
            out.append(line)
            continue
        if in_stanza and stripped.startswith("disabled = "):
            out.append(f"disabled = {value}\n")
            updated = True
            continue
        if in_stanza and stripped.startswith("[") and stripped != STANZA:
            in_stanza = False
        out.append(line)
    if not updated:
        raise ValueError(f"stanza {STANZA} missing disabled setting in {path}")
    with open(path, "w", encoding="utf-8") as handle:
        handle.writelines(out)


def mode_from_disabled(disabled: bool) -> str:
    return "infrastructure" if disabled else "threat"


def disabled_from_mode(mode: str) -> bool:
    if mode == "infrastructure":
        return True
    if mode == "threat":
        return False
    raise ValueError(f"unsupported mode: {mode}")


def reload_eventgen(session_key: str) -> Tuple[bool, str]:
    for endpoint in (EVENTGEN_DISABLE_URL, EVENTGEN_ENABLE_URL):
        try:
            response, _content = rest.simpleRequest(
                endpoint,
                sessionKey=session_key,
                method="POST",
                raiseAllErrors=True,
            )
        except Exception as exc:  # noqa: BLE001 — surface Splunk REST errors to caller
            return False, f"{endpoint}: {exc}"
        status = getattr(response, "status", None)
        if status is not None and int(status) >= 400:
            return False, f"{endpoint}: HTTP {status}"
    return True, ""


class WorkshopModeHandler(PersistentServerConnectionApplication):
    """GET current mode; POST { \"mode\": \"infrastructure\" | \"threat\" }."""

    def __init__(self, command_line: str, command_arg: str) -> None:
        super().__init__()

    def handle(self, in_string: str) -> Dict[str, Any]:
        try:
            request = json.loads(in_string)
        except json.JSONDecodeError:
            return self._json(400, {"error": "invalid_json"})

        method = str(request.get("method", "GET")).upper()
        conf_path = eventgen_conf_path()

        if not os.path.isfile(conf_path):
            return self._json(500, {"error": "eventgen_conf_missing", "path": conf_path})

        if method == "GET":
            return self._handle_get(conf_path)

        if method == "POST":
            session_key = self._session_key(request)
            if not session_key:
                return self._json(401, {"error": "unauthorized"})
            payload = self._parse_payload(request.get("payload"))
            return self._handle_post(conf_path, payload, session_key)

        return self._json(405, {"error": "method_not_allowed"})

    def _handle_get(self, conf_path: str) -> Dict[str, Any]:
        disabled = read_disabled_flag(conf_path)
        if disabled is None:
            return self._json(404, {"error": "stanza_not_found", "stanza": STANZA})
        return self._json(
            200,
            {
                "mode": mode_from_disabled(disabled),
                "stanza": STANZA.strip("[]"),
                "disabled": disabled,
            },
        )

    def _handle_post(
        self, conf_path: str, payload: Dict[str, Any], session_key: str
    ) -> Dict[str, Any]:
        mode = payload.get("mode")
        if not isinstance(mode, str) or mode not in MODES:
            return self._json(
                400,
                {
                    "error": "invalid_mode",
                    "allowed": sorted(MODES),
                    "message": "mode must be infrastructure or threat",
                },
            )

        previous_disabled = read_disabled_flag(conf_path)
        if previous_disabled is None:
            return self._json(404, {"error": "stanza_not_found", "stanza": STANZA})

        disabled = disabled_from_mode(mode)
        try:
            write_disabled_flag(conf_path, disabled)
        except ValueError as exc:
            return self._json(500, {"error": "write_failed", "message": str(exc)})

        reloaded, reload_error = reload_eventgen(session_key)
        body = {
            "mode": mode,
            "stanza": STANZA.strip("[]"),
            "disabled": disabled,
            "previous_mode": mode_from_disabled(previous_disabled),
            "eventgen_reloaded": reloaded,
        }
        if not reloaded:
            body["reload_error"] = reload_error
            body["hint"] = "If data does not change within ~2 minutes, run: make restart"
        return self._json(200, body)

    @staticmethod
    def _session_key(request: Dict[str, Any]) -> str:
        session = request.get("session") or {}
        return (
            request.get("system_authtoken")
            or request.get("systemAuthtoken")
            or session.get("authtoken")
            or ""
        )

    @staticmethod
    def _parse_payload(payload: Any) -> Dict[str, Any]:
        if payload is None:
            return {}
        if isinstance(payload, dict):
            return payload
        if isinstance(payload, str) and payload.strip():
            try:
                parsed = json.loads(payload)
            except json.JSONDecodeError:
                return {}
            return parsed if isinstance(parsed, dict) else {}
        return {}

    @staticmethod
    def _json(status: int, body: Dict[str, Any]) -> Dict[str, Any]:
        return {
            "status": status,
            "headers": {"Content-Type": "application/json"},
            "payload": json.dumps(body),
        }
