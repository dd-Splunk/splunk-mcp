#!/bin/bash
# Update Goose configuration with Splunk MCP extension
# Usage: ./update-goose-config.sh <token-file-path>
# 
# Goose uses extensions (not mcpServers like Claude).
# MCP servers are added as extension entries with type: stdio

set -euo pipefail

TOKEN_FILE="${1:-.secrets/splunk-token}"
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
GOOSE_CONFIG_DIR="${HOME}/.config/goose"
GOOSE_CONFIG_FILE="${GOOSE_CONFIG_DIR}/config.yaml"

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
    # shellcheck disable=SC2012
    echo "   Permissions: $(ls -l "${TOKEN_FILE}" | awk '{print $1}')"
    exit 1
fi

# Read token
TOKEN=$(cat "${TOKEN_FILE}" 2>/dev/null)

if [ -z "${TOKEN}" ]; then
    echo "❌ Token file is empty: ${TOKEN_FILE}"
    exit 1
fi

echo "🔧 Configuring Goose with Splunk MCP extension..."
echo "   Token file: ${TOKEN_FILE}"
echo "   Token: ${TOKEN:0:50}... (truncated)"

# Ensure Goose config directory exists
if [ ! -d "${GOOSE_CONFIG_DIR}" ]; then
    echo "📁 Creating Goose config directory..."
    mkdir -p "${GOOSE_CONFIG_DIR}"
fi

# Ensure config file exists
if [ ! -f "${GOOSE_CONFIG_FILE}" ]; then
    echo "📄 Creating new Goose configuration file..."
    cat > "${GOOSE_CONFIG_FILE}" <<EOF
extensions: {}
EOF
fi

# Check if splunk-mcp-server already exists
if grep -q "^\s*splunk-mcp-server:" "${GOOSE_CONFIG_FILE}"; then
    echo "⚠️  splunk-mcp-server extension already exists, removing old entry..."
    # Remove the entire splunk-mcp-server extension entry
    python3 - "${GOOSE_CONFIG_FILE}" "${TOKEN}" "${SPLUNK_HOST}" "${SPLUNK_PORT}" <<'PYTHON'
import sys
import re

config_file = sys.argv[1]
token = sys.argv[2]
host = sys.argv[3]
port = sys.argv[4]

with open(config_file, 'r') as f:
    content = f.read()

# Remove old splunk-mcp-server entry (find the entry and all its indented content)
# Match the line "  splunk-mcp-server:" and all following indented lines
pattern = r'^\s{2}splunk-mcp-server:.*?(?=\n\s{2}[a-zA-Z_]|\n[a-zA-Z_]|\Z)'
content = re.sub(pattern, '', content, flags=re.MULTILINE | re.DOTALL)

# Ensure extensions section exists
if 'extensions:' not in content:
    content = 'extensions: {}\n' + content

# Find the position after "extensions:" to insert our entry
extensions_match = re.search(r'^extensions:', content, re.MULTILINE)
if extensions_match:
    # Find the end of extensions line
    end_of_line = content.find('\n', extensions_match.end())
    if end_of_line == -1:
        end_of_line = len(content)
    
    # Create the new extension entry
    new_entry = f'''
  splunk-mcp-server:
    enabled: true
    type: stdio
    name: splunk-mcp-server
    description: Splunk MCP Server
    cmd: npx
    args:
      - -y
      - mcp-remote
      - https://{host}:{port}/services/mcp
      - --header
      - "Authorization: Bearer {token}"
    env:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    envs:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    env_keys: []
    timeout: 300
    bundled: null
    available_tools: []'''
    
    # Insert after extensions:
    content = content[:end_of_line] + new_entry + content[end_of_line:]

# Write back
with open(config_file, 'w') as f:
    f.write(content)

print("✅ Goose configuration updated successfully!")
print(f"📍 Config file: {config_file}")
print("")
print("⚠️  IMPORTANT: Restart Goose for changes to take effect")
PYTHON
else
    echo "Creating new splunk-mcp-server extension entry..."
    python3 - "${GOOSE_CONFIG_FILE}" "${TOKEN}" "${SPLUNK_HOST}" "${SPLUNK_PORT}" <<'PYTHON'
import sys
import re

config_file = sys.argv[1]
token = sys.argv[2]
host = sys.argv[3]
port = sys.argv[4]

with open(config_file, 'r') as f:
    content = f.read()

# Ensure extensions section exists
if 'extensions:' not in content:
    content = 'extensions: {}\n' + content

# Find the position after "extensions:" to insert our entry
extensions_match = re.search(r'^extensions:', content, re.MULTILINE)
if extensions_match:
    # Find the end of extensions line
    end_of_line = content.find('\n', extensions_match.end())
    if end_of_line == -1:
        end_of_line = len(content)
    
    # Create the new extension entry
    new_entry = f'''
  splunk-mcp-server:
    enabled: true
    type: stdio
    name: splunk-mcp-server
    description: Splunk MCP Server
    cmd: npx
    args:
      - -y
      - mcp-remote
      - https://{host}:{port}/services/mcp
      - --header
      - "Authorization: Bearer {token}"
    env:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    envs:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    env_keys: []
    timeout: 300
    bundled: null
    available_tools: []'''
    
    # Insert after extensions:
    content = content[:end_of_line] + new_entry + content[end_of_line:]

# Write back
with open(config_file, 'w') as f:
    f.write(content)

print("✅ Goose configuration updated successfully!")
print(f"📍 Config file: {config_file}")
print("")
print("⚠️  IMPORTANT: Restart Goose for changes to take effect")
PYTHON
fi