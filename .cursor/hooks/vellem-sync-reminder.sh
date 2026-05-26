#!/usr/bin/env bash
# After Write/StrReplace on stack/workflow files, nudge the agent to update Vellem.
# stdin: postToolUse JSON. stdout: {"additional_context":"..."} or {}.
set -euo pipefail

payload=$(cat)

python3 - "$payload" <<'PY'
import json
import os
import sys

# basename -> Vellem note title in folder splunk-mcp
NOTES = {
    "Makefile": "Boot Workflow & Makefile",
    "compose.yml": "Architecture & Components",
    "compose-up.sh": "Boot Workflow & Makefile",
    "setup-splunk.sh": "Architecture & Components",
    ".pre-commit-config.yaml": "Security & Golden Rules",
    "AGENTS.md": "Boot Workflow & Makefile",
}

PREFIXES = ("docs/",)


def rel_path(file_path: str, roots: list) -> str:
    for root in roots:
        root = root.rstrip("/") + "/"
        if file_path.startswith(root):
            return file_path[len(root) :]
    return os.path.basename(file_path)


def note_for(rel: str) -> str | None:
    base = os.path.basename(rel)
    if base in NOTES:
        return NOTES[base]
    if rel.startswith(PREFIXES) and rel.endswith(".md"):
        return "Boot Workflow & Makefile"  # or Troubleshooting — keep one nudge
    return None


def main() -> None:
    try:
        data = json.loads(sys.argv[1])
    except (json.JSONDecodeError, IndexError):
        print("{}")
        return

    tool_input = data.get("tool_input") or {}
    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except json.JSONDecodeError:
            tool_input = {}

    path = tool_input.get("path") or tool_input.get("file_path") or ""
    if not path:
        print("{}")
        return

    rel = rel_path(path, data.get("workspace_roots") or [])
    note = note_for(rel)
    if not note:
        print("{}")
        return

    msg = (
        f"Vellem sync: `{rel}` changed. Update Vellem folder `splunk-mcp` note "
        f"**{note}** (use `update_note`; no secrets). "
        f"See `.cursor/rules/vellem-memory.mdc`."
    )
    print(json.dumps({"additional_context": msg}))


if __name__ == "__main__":
    main()
PY
