#!/bin/sh
# Setup Splunk user, role, and authentication token
# Also configures Claude Desktop with the generated Splunk MCP token

set -e

# Splunk connection details
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
SPLUNK_USER="${SPLUNK_USER:-admin}"
SPLUNK_PASSWORD="${SPLUNK_PASSWORD}"
SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"

# Claude Desktop configuration details
CLAUDE_CONFIG_DIR="/Users/dodessy/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="${CLAUDE_CONFIG_DIR}/claude_desktop_config.json"
SPLUNK_MCP_ENDPOINT="${SPLUNK_MCP_ENDPOINT:-https://localhost:8089/services/mcp}"

# Disable SSL certificate verification (for local development)
CURL_OPTS="-k"

# Token output file (set by container, optional for host execution)
TOKEN_OUTPUT_FILE="${TOKEN_OUTPUT_FILE:-}"

echo "🔐 Disabling MCP server SSL verification for local development..."
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/servicesNS/nobody/Splunk_MCP_Server//configs/conf-mcp/server" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "ssl_verify=false" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

echo "🔄 Setting up Splunk user 'dd' and role 'mcp_user'..."

# 1. Create the role "mcp_user"
echo "📋 Creating role 'mcp_user'..."
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/authorization/roles" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=mcp_user" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  Role may already exist"

# 2. Create the user "dd"
echo "👤 Creating user 'dd'..."
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/authentication/users" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=dd" \
  -d "password=${SPLUNK_PASSWORD}" \
  -d roles="user" \
  -d roles="admin" \
  -d roles="mcp_user" \
  -d tz="Europe/Brussels" \
  -H "Content-Type: application/x-www-form-urlencoded" 2>/dev/null || echo "⚠️  User may already exist"

# 3. Assign capabilities to role "mcp_user"
# 4. Create authentication token for user "dd" valid for 15 days
echo "🔑 Creating authentication token for user 'dd' (audience=mcp, 15 days validity)..."
TOKEN_RESPONSE=$(curl ${CURL_OPTS} -s -X POST "${SPLUNK_URL}/services/authorization/tokens" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "status=enabled" \
  -d "name=dd" \
  -d "audience=mcp" \
  -H "Content-Type: application/x-www-form-urlencoded")

TOKEN=$(echo "${TOKEN_RESPONSE}" | sed -n 's/.*<!\[CDATA\[\(.*\)\]\].*/\1/p' | head -1)

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to create token"
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
