#!/bin/sh
# Setup Splunk user, role, and authentication token
# Also configures Claude Desktop with the generated Splunk MCP token

set -e

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

echo "🔐 Disabling MCP server SSL verification for local development..."
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "ssl_verify=false" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

echo " Create Index for Claude logs"
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/data/indexes" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=claude_logs" \
  -d "homePath=$SPLUNK_HOME/var/lib/splunk/claude_logs/db" \
  -d "coldPath=$SPLUNK_HOME/var/lib/splunk/claude_logs/colddb" \
  -d "thawedPath=$SPLUNK_HOME/var/lib/splunk/claude_logs/thaweddb" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Index 'claude_logs' may already exist"

echo " Monitor Claude logs directory"
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/data/inputs/monitor/" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=/var/log/claude_logs" \
  -d "index=claude_logs" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Monitor for 'claude_logs' may already exist"

echo "🔄 Setting up Splunk user 'dd' and role 'mcp_user'..."

# 1. Create the role "mcp_user"
echo "📋 Creating role 'mcp_user'..."
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/authorization/roles" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=mcp_tool_execute" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Role may already exist"

# 2. Create the user "dd"
echo "👤 Creating user 'dd'..."
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/authentication/users" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=dd" \
  -d "password=${SPLUNK_PASSWORD}" \
  -d roles="user" \
  -d roles="admin" \
  -d roles="mcp_tool_execute" \
  -d tz="Europe/Brussels" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  User may already exist"

# 3. Encrypted MCP token (Splunk MCP Server 1.x+; plain /authorization/tokens JWTs are rejected by /services/mcp)
echo "🔑 Creating encrypted MCP token for user 'dd' (Splunk MCP app mcp_token REST handler)..."
TOKEN_RESPONSE=$(curl ${CURL_OPTS} -s -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
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

echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Splunk Configuration:"
echo "  User: dd"
echo "  Role: mcp_user"
echo "  Token: ${TOKEN:0:50}... (truncated)"
echo ""
echo "⚠️  Token saved to: ${TOKEN_OUTPUT_FILE:-<not saved>}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
