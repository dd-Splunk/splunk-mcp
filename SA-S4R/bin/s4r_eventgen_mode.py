"""Shared paths and helpers for NK workshop Eventgen mode (local override, not default/)."""

from __future__ import annotations

import os
from typing import Optional

STANZA = "[attack.nk.purchase.sample]"
APP_DIR = os.path.join("etc", "apps", "SA-S4R")


def splunk_home() -> str:
    return os.environ.get("SPLUNK_HOME", "/opt/splunk")


def default_eventgen_conf_path() -> str:
    return os.path.join(splunk_home(), APP_DIR, "default", "eventgen.conf")


def local_eventgen_conf_path() -> str:
    return os.path.join(splunk_home(), APP_DIR, "local", "eventgen.conf")


def read_disabled_flag_from_file(path: str) -> Optional[bool]:
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


def read_disabled_flag() -> Optional[bool]:
    """Prefer local/eventgen.conf override; fall back to default/."""
    for path in (local_eventgen_conf_path(), default_eventgen_conf_path()):
        if not os.path.isfile(path):
            continue
        disabled = read_disabled_flag_from_file(path)
        if disabled is not None:
            return disabled
    return None


def write_disabled_flag_local(disabled: bool) -> None:
    """Write workshop mode to local/eventgen.conf (gitignored; does not touch default/)."""
    value = "true" if disabled else "false"
    local_path = local_eventgen_conf_path()
    local_dir = os.path.dirname(local_path)
    os.makedirs(local_dir, exist_ok=True)

    if os.path.isfile(local_path):
        lines = open(local_path, encoding="utf-8").read().splitlines(keepends=True)
        out: list[str] = []
        in_stanza = False
        updated = False
        found_stanza = False
        for line in lines:
            stripped = line.rstrip("\n")
            if stripped == STANZA:
                in_stanza = True
                found_stanza = True
                out.append(line)
                continue
            if in_stanza and stripped.startswith("disabled = "):
                out.append(f"disabled = {value}\n")
                updated = True
                continue
            if in_stanza and stripped.startswith("[") and stripped != STANZA:
                in_stanza = False
            out.append(line)
        if not found_stanza:
            if out and not out[-1].endswith("\n"):
                out[-1] = out[-1] + "\n"
            out.append(f"{STANZA}\n")
        if not updated:
            out.append(f"disabled = {value}\n")
        with open(local_path, "w", encoding="utf-8") as handle:
            handle.writelines(out)
        return

    with open(local_path, "w", encoding="utf-8") as handle:
        handle.write(
            "# Workshop NK mode override (gitignored). Managed by SA-S4R MCP tools and make s4r-attack-nk-*.\n"
        )
        handle.write(f"{STANZA}\n")
        handle.write(f"disabled = {value}\n")
