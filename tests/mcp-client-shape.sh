#!/usr/bin/env bash
# Docker-free MCP client JSON/YAML shape checks (no mint, no Splunk).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq required"
command -v npx >/dev/null 2>&1 || die "npx required"
python3 -c "import yaml" 2>/dev/null || die "PyYAML required (pip3 install pyyaml)"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mcp-client-shape.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

export CLAUDE_MCP_JSON="${TMP}/claude.json"
export CURSOR_MCP_JSON="${TMP}/cursor.json"
export GOOSE_MCP_YAML="${TMP}/goose.yaml"
export MCP_SHAPE_TOKEN="shape-test-placeholder"
export SPLUNK_MCP_TLS_INSECURE=1

printf '%s\n' '{"mcpServers":{"other":{"command":"true"}}}' >"${CURSOR_MCP_JSON}"
cat >"${GOOSE_MCP_YAML}" <<'EOF'
GOOSE_PROVIDER: demo
extensions:
  other-ext:
    enabled: true
    cmd: echo
EOF

./scripts/mcp-client.sh write-shape cursor goose claude

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

python3 - <<PY
import os
import yaml

path = os.environ["GOOSE_MCP_YAML"]
with open(path, encoding="utf-8") as handle:
    data = yaml.safe_load(handle)
assert data["GOOSE_PROVIDER"] == "demo"
assert data["extensions"]["other-ext"]["cmd"] == "echo"
server = data["extensions"]["splunk-mcp-server"]
assert "mcp-remote-splunk.sh" in server["cmd"]
assert server["args"][0] == "https://localhost:8089/services/mcp"
print("goose YAML shape ok")
PY

./scripts/mcp-client.sh verify-config all >/dev/null

./scripts/mcp-client.sh park cursor
jq -e '.mcpServers["splunk-mcp-server"]' "${CURSOR_MCP_JSON}" >/dev/null 2>&1 \
  && die "park left splunk-mcp-server in cursor JSON"
jq -e '.mcpServers.other.command == "true"' "${CURSOR_MCP_JSON}" >/dev/null \
  || die "park removed sibling mcpServers.other"

./scripts/mcp-client.sh park goose
python3 - <<PY
import os
import yaml

path = os.environ["GOOSE_MCP_YAML"]
with open(path, encoding="utf-8") as handle:
    data = yaml.safe_load(handle)
assert "splunk-mcp-server" not in (data.get("extensions") or {})
assert data["extensions"]["other-ext"]["cmd"] == "echo"
print("goose park preserved sibling extension")
PY

if ./scripts/mcp-client.sh verify-config cursor >/dev/null 2>&1; then
  die "verify-config should fail after parking cursor"
fi

echo "OK: mcp-client JSON/YAML shape tests"
