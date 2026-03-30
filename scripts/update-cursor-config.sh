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
  echo "  curl -skS -u admin:PASSWORD \"https://${SPLUNK_HOST}:${SPLUNK_PORT}/servicesNS/admin/Splunk_MCP_Server/mcp_token?username=dd&output_mode=json\" | jq -r .token > .secrets/splunk-token"
  exit 1
fi

TOKEN=$(tr -d '\n' < "$TOKEN_FILE")
if [[ -z "$TOKEN" ]]; then
  echo "Token file is empty: $TOKEN_FILE"
  exit 1
fi

mkdir -p .cursor

BLOCK=$(jq -n \
  --arg url "https://${SPLUNK_HOST}:${SPLUNK_PORT}/services/mcp" \
  --arg token "$TOKEN" \
  '{command: "npx", args: ["-y", "mcp-remote", $url, "--header", ("Authorization: Bearer " + $token)], env: {"NODE_TLS_REJECT_UNAUTHORIZED": "0"}}')

# Merge into mcpServers.splunk-mcp-server without clobbering other servers
if [[ -f "$OUT" ]] && jq empty "$OUT" 2>/dev/null; then
  jq --argjson block "$BLOCK" '.mcpServers = (.mcpServers // {}) | .mcpServers["splunk-mcp-server"] = $block' "$OUT" | jq '.' > "${OUT}.tmp"
  mv "${OUT}.tmp" "$OUT"
else
  jq -n --argjson block "$BLOCK" '{mcpServers: {"splunk-mcp-server": $block}}' | jq '.' > "$OUT"
fi

echo "Wrote Cursor MCP config: $OUT"
echo "Token source: $TOKEN_FILE (${#TOKEN} chars)"
echo "Restart Cursor (or reload MCP) so the Splunk tools appear."
