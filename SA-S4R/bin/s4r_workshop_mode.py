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
    CONFIG_ENDPOINT,
    STANZA,
    EventgenConfigError,
    read_disabled_flag,
    write_disabled_flag,
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
        session_key = self._session_key(request)

        if method == "GET":
            if not session_key:
                return self._json(401, {"error": "unauthorized"})
            return self._handle_get(session_key)

        if method == "POST":
            if not session_key:
                return self._json(401, {"error": "unauthorized"})
            payload = self._parse_payload(request.get("payload"))
            return self._handle_post(payload, session_key)

        return self._json(405, {"error": "method_not_allowed"})

    def _handle_get(self, session_key: str) -> Dict[str, Any]:
        try:
            disabled = read_disabled_flag(session_key)
        except EventgenConfigError as exc:
            return self._config_error(exc)
        if disabled is None:
            return self._json(404, {"error": "stanza_not_found", "stanza": STANZA})
        return self._json(
            200,
            {
                "mode": mode_from_disabled(disabled),
                "stanza": STANZA.strip("[]"),
                "disabled": disabled,
                "config_endpoint": CONFIG_ENDPOINT,
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

        try:
            previous_disabled = read_disabled_flag(session_key)
        except EventgenConfigError as exc:
            return self._config_error(exc)
        if previous_disabled is None:
            return self._json(404, {"error": "stanza_not_found", "stanza": STANZA})

        disabled = disabled_from_mode(mode)
        try:
            write_disabled_flag(session_key, disabled)
        except EventgenConfigError as exc:
            return self._config_error(exc)

        reloaded, reload_error = reload_eventgen(session_key)
        body = {
            "mode": mode,
            "stanza": STANZA.strip("[]"),
            "disabled": disabled,
            "previous_mode": mode_from_disabled(previous_disabled),
            "config_endpoint": CONFIG_ENDPOINT,
            "eventgen_reloaded": reloaded,
        }
        if not reloaded:
            body["error"] = "eventgen_reload_failed"
            body["reload_error"] = reload_error
            body["hint"] = (
                "Eventgen stanza was updated but the modinput did not reload. "
                "Run: make restart"
            )
            return self._json(503, body)
        return self._json(200, body)

    @staticmethod
    def _config_error(exc: EventgenConfigError) -> Dict[str, Any]:
        status = exc.status if exc.status in (401, 403, 404) else 502
        error = "eventgen_config_failed"
        if status == 404:
            error = "stanza_not_found"
        elif status in (401, 403):
            error = "unauthorized"
        return WorkshopModeHandler._json(
            status,
            {"error": error, "message": str(exc), "stanza": STANZA},
        )

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
