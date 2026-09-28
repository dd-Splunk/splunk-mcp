"""NK workshop Eventgen mode via Splunk configuration REST (no direct conf edits)."""

from __future__ import annotations

import json
from typing import Any, Optional

STANZA_NAME = "attack.nk.purchase.sample"
STANZA = f"[{STANZA_NAME}]"
CONFIG_ENDPOINT = (
    f"/servicesNS/nobody/SA-S4R/configs/conf-eventgen/{STANZA_NAME}"
)
DISABLED_ENDPOINT = (
    f"/servicesNS/nobody/SA-S4R/properties/eventgen/{STANZA_NAME}/disabled"
)


class EventgenConfigError(Exception):
    """Splunk rejected or did not return the Eventgen stanza setting."""

    def __init__(self, message: str, status: Optional[int] = None) -> None:
        super().__init__(message)
        self.status = status


def _is_disabled(value: Any) -> bool:
    """True when Eventgen should not emit the NK stanza."""
    if isinstance(value, bool):
        return value
    text = str(value).strip().lower()
    if text in ("false", "0", "no", "f"):
        return False
    if text in ("true", "1", "yes", "t"):
        return True
    raise EventgenConfigError(f"unexpected disabled value: {value!r}")


def disabled_from_body(body: str) -> Optional[bool]:
    """Parse a properties/configs JSON document or a raw true/false/0/1 token."""
    text = body.strip()
    if not text:
        return None
    try:
        payload = json.loads(text)
    except json.JSONDecodeError:
        return _is_disabled(text)
    if isinstance(payload, (str, bool, int, float)):
        return _is_disabled(payload)
    return disabled_from_properties_payload(payload)


def disabled_from_properties_payload(payload: Any) -> Optional[bool]:
    """Parse a properties or configs JSON body. None when the stanza is absent."""
    if not isinstance(payload, dict):
        return None
    entries = payload.get("entry")
    if not isinstance(entries, list) or not entries:
        return None
    first = entries[0]
    if not isinstance(first, dict):
        return None
    content = first.get("content")
    if isinstance(content, dict):
        if "disabled" not in content:
            return None
        return _is_disabled(content.get("disabled"))
    if isinstance(content, (str, bool, int, float)):
        return _is_disabled(content)
    return None


def _decode_body(content: Any) -> str:
    if isinstance(content, bytes):
        return content.decode("utf-8", errors="replace")
    return str(content or "")


def _request(
    session_key: str,
    path: str,
    method: str = "GET",
    postargs: Optional[dict[str, str]] = None,
) -> tuple[int, str]:
    import splunk.rest as rest

    kwargs: dict[str, Any] = {
        "sessionKey": session_key,
        "method": method,
        "getargs": {"output_mode": "json"},
        "raiseAllErrors": False,
    }
    if postargs is not None:
        kwargs["postargs"] = postargs
    try:
        response, content = rest.simpleRequest(path, **kwargs)
    except Exception as exc:  # noqa: BLE001 — surface Splunk REST client errors
        raise EventgenConfigError(str(exc)) from exc
    status = int(getattr(response, "status", 0) or 0)
    return status, _decode_body(content)


def read_disabled_flag(session_key: str) -> Optional[bool]:
    """Effective disabled flag (local layered over default). None if stanza missing."""
    status, body = _request(session_key, DISABLED_ENDPOINT)
    if status == 404:
        return None
    if status < 200 or status >= 300:
        raise EventgenConfigError(f"HTTP {status}: {body[:500]}", status=status)
    return disabled_from_body(body)


def write_disabled_flag(session_key: str, disabled: bool) -> None:
    """POST disabled on the NK stanza. Splunk writes the local/ override."""
    value = "true" if disabled else "false"
    status, body = _request(
        session_key,
        CONFIG_ENDPOINT,
        method="POST",
        postargs={"disabled": value},
    )
    if status < 200 or status >= 300:
        raise EventgenConfigError(f"HTTP {status}: {body[:500]}", status=status)
