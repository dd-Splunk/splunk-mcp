#!/usr/bin/env bash
# Docker-free MCP client JSON shape checks (no mint, no Splunk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq required"
command -v npx >/dev/null 2>&1 || die "npx required"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mcp-client-shape.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_MCP_JSON="${TMP}/claude.json"
export CLAUDE_CODE_MCP_JSON="${TMP}/claude-code.json"
export CURSOR_MCP_JSON="${TMP}/cursor.json"
export MCP_SHAPE_TOKEN="shape-test-placeholder"
export SPLUNK_MCP_TLS_INSECURE=1

printf '%s\n' '{"mcpServers":{"other":{"command":"true"}}}' >"${CURSOR_MCP_JSON}"

./scripts/mcp-client.sh write-shape cursor claude claude-code

jq -e '.mcpServers["splunk-mcp-server"].command | test("npx$")' "${CURSOR_MCP_JSON}" >/dev/null \
  || die "cursor command is not npx"
jq -e '.mcpServers["splunk-mcp-server"].args | map(tostring) | any(test("^mcp-remote(@|$)"))' \
  "${CURSOR_MCP_JSON}" >/dev/null || die "cursor args missing mcp-remote"
jq -e '.mcpServers["splunk-mcp-server"].args | map(tostring) | any(test("^https://localhost:8089/services/mcp$"))' \
  "${CURSOR_MCP_JSON}" >/dev/null || die "cursor missing local MCP endpoint"
jq -e '.mcpServers.other.command == "true"' "${CURSOR_MCP_JSON}" >/dev/null \
  || die "cursor write clobbered sibling mcpServers.other"
jq -e '.mcpServers["splunk-mcp-server"].env.NODE_TLS_REJECT_UNAUTHORIZED == "0"' \
  "${CURSOR_MCP_JSON}" >/dev/null || die "cursor missing TLS env"

jq -e '.mcpServers["splunk-mcp-server"].command | test("npx$")' "${CLAUDE_MCP_JSON}" >/dev/null \
  || die "claude command is not npx"
jq -e '.mcpServers["splunk-mcp-server"].args | map(tostring) | any(test("^https://localhost:8089/services/mcp$"))' \
  "${CLAUDE_CODE_MCP_JSON}" >/dev/null || die "claude-code missing local MCP endpoint"

./scripts/mcp-client.sh verify-config all >/dev/null

./scripts/mcp-client.sh park cursor
jq -e '.mcpServers["splunk-mcp-server"]' "${CURSOR_MCP_JSON}" >/dev/null 2>&1 \
  && die "park left splunk-mcp-server in cursor JSON"
jq -e '.mcpServers.other.command == "true"' "${CURSOR_MCP_JSON}" >/dev/null \
  || die "park removed sibling mcpServers.other"

./scripts/mcp-client.sh park claude-code
jq -e '.mcpServers["splunk-mcp-server"]' "${CLAUDE_CODE_MCP_JSON}" >/dev/null 2>&1 \
  && die "park left splunk-mcp-server in claude-code JSON"

if ./scripts/mcp-client.sh verify-config cursor >/dev/null 2>&1; then
  die "verify-config should fail after parking cursor"
fi

# all skips parked clients while one is still configured (claude), and fails once none are.
./scripts/mcp-client.sh verify-config all >/dev/null || die "verify-config all should skip parked clients"
./scripts/mcp-client.sh park claude
if ./scripts/mcp-client.sh verify-config all >/dev/null 2>&1; then
  die "verify-config all should fail when no client is configured"
fi

echo "OK: mcp-client JSON shape tests"
