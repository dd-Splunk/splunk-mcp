#!/usr/bin/env python3
"""Load/dump Goose config.yaml for the splunk-mcp-server extension (no regex splice)."""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "error: PyYAML is required for Goose config\n"
        "  pip3 install pyyaml\n"
        "  Homebrew Python (PEP 668): python3 -m pip install --user --break-system-packages pyyaml\n"
    )
    sys.exit(1)

EXTENSION_NAME = "splunk-mcp-server"

# First-run bug: "extensions: {}" then an indented mapping (invalid YAML).
_BROKEN_EMPTY_EXTENSIONS = re.compile(
    r"^(extensions:\s*)\{\}\s*\n(?=[ \t]{2}\S)",
    re.MULTILINE,
)


def _die(msg: str) -> None:
    sys.stderr.write(f"error: {msg}\n")
    sys.exit(1)


def load_mapping(path: Path) -> dict[str, Any]:
    if not path.is_file() or path.stat().st_size == 0:
        return {}
    raw = path.read_text(encoding="utf-8")
    if not raw.strip():
        return {}

    def parse(text: str) -> Any:
        data = yaml.safe_load(text)
        return {} if data is None else data

    try:
        data = parse(raw)
    except yaml.YAMLError:
        repaired = _BROKEN_EMPTY_EXTENSIONS.sub(r"\1\n", raw, count=1)
        try:
            data = parse(repaired)
        except yaml.YAMLError as exc:
            _die(f"invalid Goose YAML in {path}: {exc}")
    if not isinstance(data, dict):
        _die(f"Goose config must be a YAML mapping: {path}")
    return data


def dump_mapping(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    text = yaml.safe_dump(
        data,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
        width=4096,
    )
    path.write_text(text, encoding="utf-8")


def _extensions(data: dict[str, Any]) -> dict[str, Any]:
    ext = data.get("extensions")
    if ext is None or ext == {}:
        return {}
    if not isinstance(ext, dict):
        _die("Goose config key extensions: must be a mapping")
    return dict(ext)


def splunk_entry(
    endpoint: str,
    header: str,
    tls_insecure: str,
    wrapper: str,
    npx_cmd: str,
) -> dict[str, Any]:
    entry: dict[str, Any] = {
        "enabled": True,
        "type": "stdio",
        "name": EXTENSION_NAME,
        "description": "Splunk MCP Server",
        "cmd": wrapper,
        "args": [endpoint, "--header", header],
        "timeout": 300,
        "bundled": None,
        "available_tools": [],
    }
    insecure = tls_insecure.lower() in ("1", "true", "yes")
    if insecure:
        entry["envs"] = {
            "NODE_TLS_REJECT_UNAUTHORIZED": "0",
            "MCP_NPX_COMMAND": npx_cmd,
            "SPLUNK_MCP_TLS_INSECURE": "1",
        }
        entry["env_keys"] = ["NODE_TLS_REJECT_UNAUTHORIZED"]
    else:
        entry["envs"] = {}
        entry["env_keys"] = []
    return entry


def cmd_upsert(args: argparse.Namespace) -> None:
    path = Path(args.file)
    data = load_mapping(path)
    ext = _extensions(data)
    ext[EXTENSION_NAME] = splunk_entry(
        args.endpoint,
        args.header,
        args.tls_insecure,
        args.wrapper,
        args.npx_cmd,
    )
    data["extensions"] = ext
    dump_mapping(path, data)


def cmd_remove(args: argparse.Namespace) -> None:
    path = Path(args.file)
    if not path.is_file():
        return
    data = load_mapping(path)
    ext = _extensions(data)
    if EXTENSION_NAME not in ext:
        return
    del ext[EXTENSION_NAME]
    data["extensions"] = ext
    dump_mapping(path, data)


def cmd_verify(args: argparse.Namespace) -> None:
    path = Path(args.file)
    if not path.is_file():
        _die(f"goose config missing: {path}")
    data = load_mapping(path)
    ext = _extensions(data)
    section = ext.get(EXTENSION_NAME)
    if not isinstance(section, dict):
        _die(f"goose config has no {EXTENSION_NAME} extension in {path}")
    cmd = str(section.get("cmd") or "")
    blob = yaml.safe_dump(section, default_flow_style=False)
    if "mcp-stdio-http-bridge" in blob:
        _die(
            "goose splunk-mcp-server still uses removed scripts/mcp-stdio-http-bridge.mjs "
            "(run: make update-mcp-client MCP_CLIENT=goose)"
        )
    if re.search(r"\bMCP_URL\b", blob):
        _die(
            "goose splunk-mcp-server still uses legacy MCP_URL proxy layout "
            "(run: make update-mcp-client MCP_CLIENT=goose)"
        )
    if re.search(r"\bnode\b", cmd) and ".mjs" in blob:
        _die(
            "goose splunk-mcp-server still uses node + bridge script "
            "(run: make update-mcp-client MCP_CLIENT=goose)"
        )
    if "npx" not in cmd and "mcp-remote-splunk.sh" not in cmd:
        _die("goose splunk-mcp-server should use mcp-remote-splunk.sh or npx in cmd")
    if "mcp-remote" not in blob and "mcp-remote-splunk.sh" not in cmd:
        _die("goose splunk-mcp-server should use mcp-remote (directly or via wrapper)")
    tls = os.environ.get("SPLUNK_MCP_TLS_INSECURE", "1").lower()
    if tls in ("1", "true", "yes"):
        envs = section.get("envs") or {}
        if (
            "NODE_TLS_REJECT_UNAUTHORIZED" not in envs
            and "mcp-remote-splunk.sh" not in cmd
        ):
            _die(
                "goose splunk-mcp-server missing NODE_TLS_REJECT_UNAUTHORIZED "
                "(run: make update-mcp-client MCP_CLIENT=goose)"
            )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    up = sub.add_parser("upsert", help="set extensions.splunk-mcp-server")
    up.add_argument("file")
    up.add_argument("endpoint")
    up.add_argument("header")
    up.add_argument("tls_insecure")
    up.add_argument("wrapper")
    up.add_argument("npx_cmd")
    up.set_defaults(func=cmd_upsert)

    rm = sub.add_parser("remove", help="delete extensions.splunk-mcp-server")
    rm.add_argument("file")
    rm.set_defaults(func=cmd_remove)

    ver = sub.add_parser("verify", help="check splunk-mcp-server shape")
    ver.add_argument("file")
    ver.set_defaults(func=cmd_verify)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
