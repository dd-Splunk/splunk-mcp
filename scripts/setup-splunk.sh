#!/bin/sh
# Setup Splunk instance for this PoC:
# - Configure MCP app (ssl_verify=false for local dev)
# - Create claude_logs index + monitor
# - Create user dd + role mcp_tool_execute
# - Generate encrypted MCP token (saved to TOKEN_OUTPUT_FILE)
# - Enable SA-Eventgen default modular input (modinput_eventgen://default)

set -eu

# Splunk connection details
SPLUNK_HOME="${SPLUNK_HOME:-/opt/splunk}"
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
SPLUNK_USER="${SPLUNK_USER:-admin}"
SPLUNK_PASSWORD="${SPLUNK_PASSWORD}"
SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"

# Claude Desktop configuration details (macOS)
CLAUDE_CONFIG_DIR="${HOME}/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="${CLAUDE_CONFIG_DIR}/claude_desktop_config.json"
SPLUNK_MCP_ENDPOINT="${SPLUNK_MCP_ENDPOINT:-https://localhost:8089/services/mcp}"

# Disable SSL certificate verification (for local development)
CURL_OPTS="-k"

# Token output file (set by container, optional for host execution)
TOKEN_OUTPUT_FILE="${TOKEN_OUTPUT_FILE:-}"

auth_curl() {
  # Avoid echoing credentials; always use basic auth in curl invocation.
  curl ${CURL_OPTS} -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" "$@"
}

splunk_get_json() {
  # $1 = URL
  auth_curl -sS "$1"
}

wait_for_disabled_value() {
  # $1 = URL, $2 = expected disabled value (0/1/true/false)
  url="$1"
  expected="$2"
  i=0
  while [ "$i" -lt 30 ]; do
    if command -v jq >/dev/null 2>&1; then
      current=$(splunk_get_json "${url}" | jq -r '.entry[0].content.disabled // empty' 2>/dev/null || true)
    else
      current=""
    fi
    if [ -n "${current}" ] && [ "${current}" = "${expected}" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  return 1
}

echo "🔐 Disabling MCP server SSL verification for local development..."
auth_curl -X POST "${SPLUNK_URL}/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server" \
  -d "ssl_verify=false" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

echo " Create Index for Claude logs"
auth_curl -X POST "${SPLUNK_URL}/services/data/indexes" \
  -d "name=claude_logs" \
  -d "homePath=$SPLUNK_HOME/var/lib/splunk/claude_logs/db" \
  -d "coldPath=$SPLUNK_HOME/var/lib/splunk/claude_logs/colddb" \
  -d "thawedPath=$SPLUNK_HOME/var/lib/splunk/claude_logs/thaweddb" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Index 'claude_logs' may already exist"

echo " Monitor Claude logs directory"
auth_curl -X POST "${SPLUNK_URL}/services/data/inputs/monitor/" \
  -d "name=/var/log/claude_logs" \
  -d "index=claude_logs" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Monitor for 'claude_logs' may already exist"

echo "🔄 Setting up Splunk user 'dd' and role 'mcp_user'..."

# 1. Create the role "mcp_user"
echo "📋 Creating role 'mcp_user'..."
auth_curl -X POST "${SPLUNK_URL}/services/authorization/roles" \
  -d "name=mcp_tool_execute" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Role may already exist"

# 2. Create the user "dd"
echo "👤 Creating user 'dd'..."
auth_curl -X POST "${SPLUNK_URL}/services/authentication/users" \
  -d "name=dd" \
  -d "password=${SPLUNK_PASSWORD}" \
  -d roles="user" \
  -d roles="admin" \
  -d roles="mcp_tool_execute" \
  -d tz="Europe/Brussels" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  User may already exist"

# 3. Encrypted MCP token (Splunk MCP Server 1.x+; plain /authorization/tokens JWTs are rejected by /services/mcp)
echo "🔑 Creating encrypted MCP token for user 'dd' (Splunk MCP app mcp_token REST handler)..."
TOKEN_RESPONSE=$(auth_curl -sS \
  "${SPLUNK_URL}/servicesNS/${SPLUNK_USER}/Splunk_MCP_Server/mcp_token?username=dd&output_mode=json")

if command -v jq >/dev/null 2>&1; then
  TOKEN=$(echo "${TOKEN_RESPONSE}" | jq -r '.token // empty')
else
  TOKEN=$(echo "${TOKEN_RESPONSE}" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
fi

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to create encrypted MCP token"
    echo "Response: ${TOKEN_RESPONSE}"
    exit 1
fi

# Save token to file if TOKEN_OUTPUT_FILE is specified (container mode)
if [ -n "${TOKEN_OUTPUT_FILE}" ]; then
    echo "💾 Saving token to ${TOKEN_OUTPUT_FILE}..."
    echo "${TOKEN}" > "${TOKEN_OUTPUT_FILE}"
    chmod 600 "${TOKEN_OUTPUT_FILE}"
    echo "✅ Token saved with restricted permissions (600)"
fi

echo "🎛️  Enabling Eventgen modular input (SA-Eventgen: modinput_eventgen://default)..."
EVENTGEN_INPUT_URL="${SPLUNK_URL}/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default"

# Enable it (idempotent). Prefer the enable endpoint; some handlers reject setting "disabled" directly.
if auth_curl -X POST "${EVENTGEN_INPUT_URL}/enable" 2>/dev/null; then
  echo "✅ Eventgen modinput enabled via /enable"
else
  auth_curl -X POST "${EVENTGEN_INPUT_URL}" \
    -d "disabled=0" \
    -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null \
    && echo "✅ Eventgen modinput enablement POST sent (disabled=0)" || echo "⚠️  Failed to enable Eventgen modinput (app missing or endpoint changed)"
fi

# Verify it is enabled (disabled=0). Allow retries to tolerate startup race.
if command -v jq >/dev/null 2>&1; then
  if wait_for_disabled_value "${EVENTGEN_INPUT_URL}?output_mode=json" "0"; then
    echo "✅ Verified: Eventgen modinput is enabled (disabled=0)"
  else
    echo "⚠️  Could not verify Eventgen modinput state via REST (expected disabled=0)."
    echo "    Check manually: ${EVENTGEN_INPUT_URL}?output_mode=json"
  fi
else
  echo "⚠️  jq not available; skipping verification of Eventgen modinput."
fi

echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Splunk Configuration:"
echo "  User: dd"
echo "  Role: mcp_user"
echo "  Token: ${TOKEN:0:50}... (truncated)"
echo ""
echo "⚠️  Token saved to: ${TOKEN_OUTPUT_FILE:-<not saved>}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
