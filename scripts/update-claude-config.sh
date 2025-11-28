#!/bin/bash
# Update Claude Desktop configuration with Splunk MCP token
# Usage: ./update-claude-config.sh <token-file-path>

set -e

TOKEN_FILE="${1:-.secrets/splunk-token}"
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
CLAUDE_CONFIG_DIR="${HOME}/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="${CLAUDE_CONFIG_DIR}/claude_desktop_config.json"

# Validate token file exists and is readable
if [ ! -f "${TOKEN_FILE}" ]; then
    echo "❌ Token file not found: ${TOKEN_FILE}"
    echo ""
    echo "💡 To generate a token, run:"
    echo "   make up"
    echo ""
    echo "This will start Splunk and automatically generate a token."
    exit 1
fi

if [ ! -r "${TOKEN_FILE}" ]; then
    echo "❌ Token file is not readable: ${TOKEN_FILE}"
    echo "   Permissions: $(ls -l "${TOKEN_FILE}" | awk '{print $1}')"
    exit 1
fi

# Read token
TOKEN=$(cat "${TOKEN_FILE}" 2>/dev/null)

if [ -z "${TOKEN}" ]; then
    echo "❌ Token file is empty: ${TOKEN_FILE}"
    exit 1
fi

echo "🔧 Configuring Claude Desktop with Splunk MCP token..."
echo "   Token file: ${TOKEN_FILE}"
echo "   Token: ${TOKEN:0:50}... (truncated)"

# Ensure Claude Desktop config directory exists
if [ ! -d "${CLAUDE_CONFIG_DIR}" ]; then
    echo "📁 Creating Claude Desktop config directory..."
    mkdir -p "${CLAUDE_CONFIG_DIR}"
fi

# Create or read existing configuration
current_config=""
if [ ! -f "${CLAUDE_CONFIG_FILE}" ]; then
    echo "📄 Creating new Claude Desktop configuration file..."
    current_config="{}"
else
    current_config=$(cat "${CLAUDE_CONFIG_FILE}")
fi

# Validate JSON
if ! echo "${current_config}" | jq empty 2>/dev/null; then
    echo "⚠️  Invalid JSON in existing config file. Backing up and creating fresh config..."
    cp "${CLAUDE_CONFIG_FILE}" "${CLAUDE_CONFIG_FILE}.backup.$(date +%s)"
    current_config="{}"
fi

# Create the Splunk MCP server configuration block
# Use mcp-remote with NODE_TLS_REJECT_UNAUTHORIZED=0 to allow self-signed certs
splunk_mcp_config=$(cat <<EOF
{
  "command": "npx",
  "args": [
    "-y",
    "mcp-remote",
    "https://${SPLUNK_HOST}:${SPLUNK_PORT}/services/mcp",
    "--header",
    "Authorization: Bearer ${TOKEN}"
  ],
  "env": {
    "NODE_TLS_REJECT_UNAUTHORIZED": "0"
  }
}
EOF
)

# Update or create mcpServers section with jq
updated_config=$(echo "${current_config}" | jq \
  --argjson splunk_mcp "${splunk_mcp_config}" \
  '.mcpServers |= (. // {}) | .mcpServers["splunk-mcp-server"] = $splunk_mcp')

# Check if jq succeeded
if [ $? -ne 0 ]; then
    echo "❌ Failed to update JSON configuration"
    exit 1
fi

# Write updated configuration back to file
echo "${updated_config}" | jq '.' > "${CLAUDE_CONFIG_FILE}"

if [ $? -eq 0 ]; then
    echo "✅ Claude Desktop configuration updated successfully!"
    echo "📍 Config file: ${CLAUDE_CONFIG_FILE}"
    echo ""
    echo "⚠️  IMPORTANT: Restart Claude Desktop for changes to take effect"
else
    echo "❌ Failed to write Claude Desktop configuration"
    exit 1
fi
