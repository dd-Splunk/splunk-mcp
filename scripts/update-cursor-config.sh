#!/usr/bin/env bash
# Write Cursor MCP config for Splunk (stdio via mcp-remote + encrypted token).
# Usage: ./scripts/update-cursor-config.sh [token-file]
# Default token file: .secrets/splunk-token

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TOKEN_FILE="${1:-.secrets/splunk-token}"
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
OUT="${CURSOR_MCP_JSON:-.cursor/mcp.json}"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Token file not found: $TOKEN_FILE"
  echo "Generate one with setup-splunk-user / make up, or:"
  echo "  curl -skS -u admin:PASSWORD \"https://${SPLUNK_HOST}:${SPLUNK_PORT}/servicesNS/admin/Splunk_MCP_Server/mcp_token?username=splunker&output_mode=json\" | jq -r .token > .secrets/splunk-token"
  exit 1
fi

TOKEN=$(tr -d '\r\n' < "$TOKEN_FILE")
if [[ -z "$TOKEN" ]]; then
  echo "Token file is empty: $TOKEN_FILE"
  exit 1
fi

mkdir -p .cursor

URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}/services/mcp"

write_with_jq() {
  BLOCK=$(jq -n \
    --arg url "$URL" \
    --arg token "$TOKEN" \
    '{command: "npx", args: ["-y", "mcp-remote", $url, "--header", ("Authorization: Bearer " + $token)], env: {"NODE_TLS_REJECT_UNAUTHORIZED": "0"}}')

  # Merge into mcpServers.splunk-mcp-server without clobbering other servers
  if [[ -f "$OUT" ]] && jq empty "$OUT" 2>/dev/null; then
    jq --argjson block "$BLOCK" \
      '.mcpServers = (.mcpServers // {}) | .mcpServers["splunk-mcp-server"] = $block' \
      "$OUT" > "${OUT}.tmp"
    mv "${OUT}.tmp" "$OUT"
  else
    jq -n --argjson block "$BLOCK" '{mcpServers: {"splunk-mcp-server": $block}}' > "$OUT"
  fi
}

write_with_python() {
  python3 - "$OUT" "$URL" "$TOKEN" <<'PY'
import json, os, sys

out_path, url, token = sys.argv[1], sys.argv[2], sys.argv[3]
block = {
  "command": "npx",
  "args": ["-y", "mcp-remote", url, "--header", f"Authorization: Bearer {token}"],
  "env": {"NODE_TLS_REJECT_UNAUTHORIZED": "0"},
}

data = {}
try:
  with open(out_path, "r", encoding="utf-8") as f:
    data = json.load(f)
except FileNotFoundError:
  data = {}
except Exception:
  # If the existing file isn't valid JSON, replace it (safer than trying to patch unknown content).
  data = {}

data.setdefault("mcpServers", {})
data["mcpServers"]["splunk-mcp-server"] = block

tmp = out_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
  json.dump(data, f, indent=2, sort_keys=False)
  f.write("\n")
os.replace(tmp, out_path)
PY
}

if command -v jq >/dev/null 2>&1; then
  write_with_jq
else
  write_with_python
fi

echo "Wrote Cursor MCP config: $OUT"
echo "Token source: $TOKEN_FILE"
echo "Restart Cursor (or reload MCP) so the Splunk tools appear."
