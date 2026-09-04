"""REST endpoint to read/set Buttercup workshop Eventgen mode (infrastructure vs NK threat)."""

from __future__ import annotations

import json
import os
import sys
from typing import Any, Dict, Tuple

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import splunk.rest as rest
from splunk.persistconn.application import PersistentServerConnectionApplication

from s4r_eventgen_mode import (
    STANZA,
    default_eventgen_conf_path,
    local_eventgen_conf_path,
    read_disabled_flag,
    write_disabled_flag_local,
)

MODES = frozenset({"infrastructure", "threat"})
EVENTGEN_DISABLE_URL = (
    "/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/disable"
)
EVENTGEN_ENABLE_URL = (
    "/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/enable"
)


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
        if not os.path.isfile(default_eventgen_conf_path()):
            return self._json(
                500,
                {
                    "error": "eventgen_conf_missing",
                    "path": default_eventgen_conf_path(),
                },
            )

        if method == "GET":
            return self._handle_get()

        if method == "POST":
            session_key = self._session_key(request)
            if not session_key:
                return self._json(401, {"error": "unauthorized"})
            payload = self._parse_payload(request.get("payload"))
            return self._handle_post(payload, session_key)

        return self._json(405, {"error": "method_not_allowed"})

    def _handle_get(self) -> Dict[str, Any]:
        disabled = read_disabled_flag()
        if disabled is None:
            return self._json(404, {"error": "stanza_not_found", "stanza": STANZA})
        return self._json(
            200,
            {
                "mode": mode_from_disabled(disabled),
                "stanza": STANZA.strip("[]"),
                "disabled": disabled,
                "config_path": local_eventgen_conf_path(),
            },
        )

    def _handle_post(
        self, payload: Dict[str, Any], session_key: str
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

        previous_disabled = read_disabled_flag()
        if previous_disabled is None:
            return self._json(404, {"error": "stanza_not_found", "stanza": STANZA})

        disabled = disabled_from_mode(mode)
        try:
            write_disabled_flag_local(disabled)
        except OSError as exc:
            return self._json(500, {"error": "write_failed", "message": str(exc)})

        reloaded, reload_error = reload_eventgen(session_key)
        body = {
            "mode": mode,
            "stanza": STANZA.strip("[]"),
            "disabled": disabled,
            "previous_mode": mode_from_disabled(previous_disabled),
            "config_path": local_eventgen_conf_path(),
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
