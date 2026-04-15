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

# Disable SSL certificate verification (for local development)
CURL_OPTS="-k"

# Token output file (set by container, optional for host execution)
TOKEN_OUTPUT_FILE="${TOKEN_OUTPUT_FILE:-}"

OUTPUT_DIR=""
if [ -n "${TOKEN_OUTPUT_FILE}" ]; then
  OUTPUT_DIR=$(dirname "${TOKEN_OUTPUT_FILE}")
fi

LAST_HTTP_CODE=""
LAST_BODY_FILE=""

auth_curl() { # $@ = curl args excluding auth
  # Captures body + HTTP code for subsequent handling.
  # Avoid printing credentials; never echo full args.
  tmp_body="$(mktemp)"
  quiet="${AUTH_CURL_QUIET:-0}"
  req_url=""
  for arg in "$@"; do
    case "$arg" in
      http://*|https://*) req_url="$arg"; break ;;
    esac
  done

  if code="$(curl ${CURL_OPTS} -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" -sS -o "${tmp_body}" -w "%{http_code}" "$@")"; then
    :
  else
    code="000"
  fi
  LAST_HTTP_CODE="${code}"
  LAST_BODY_FILE="${tmp_body}"
  case "${code}" in
    2??|3??)
      cat "${tmp_body}"
      rm -f "${tmp_body}"
      LAST_BODY_FILE=""
      return 0
      ;;
    *)
      if [ "${quiet}" != "1" ] && [ "${quiet}" != "true" ]; then
        if [ -n "${req_url}" ]; then
          echo "❌ HTTP ${code} for ${req_url}" >&2
        else
          echo "❌ HTTP ${code} (request failed)" >&2
        fi
        cat "${tmp_body}" >&2
      fi
      # Keep body file for callers that want to inspect it; they'll clean up via cleanup_last_body.
      return 1
      ;;
  esac
}

cleanup_last_body() {
  if [ -n "${LAST_BODY_FILE}" ] && [ -f "${LAST_BODY_FILE}" ]; then
    rm -f "${LAST_BODY_FILE}" || true
  fi
  LAST_BODY_FILE=""
  LAST_HTTP_CODE=""
}

post_ok_or_409_exists() { # $1=url, rest are curl args
  url="$1"
  shift
  if AUTH_CURL_QUIET=1 auth_curl "$url" "$@"; then
    cleanup_last_body
    return 0
  fi
  if [ "${LAST_HTTP_CODE}" = "409" ]; then
    cleanup_last_body
    echo "ℹ️  Already exists: ${url}"
    return 0
  fi
  cleanup_last_body
  return 1
}

post_user_ok_or_exists() { # $1=url, rest are curl args
  url="$1"
  shift
  if AUTH_CURL_QUIET=1 auth_curl "$url" "$@"; then
    cleanup_last_body
    return 0
  fi
  if [ "${LAST_HTTP_CODE}" = "400" ] && [ -n "${LAST_BODY_FILE}" ] && grep -qi "already exists" "${LAST_BODY_FILE}" 2>/dev/null; then
    cleanup_last_body
    echo "ℹ️  User already exists"
    return 0
  fi
  cleanup_last_body
  return 1
}

must() { # run command, exit on failure
  "$@" || exit 1
}

splunk_get_json() { # $1 = URL
  auth_curl "$1"
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
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
  && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

echo " Create Index for Claude logs"
post_ok_or_409_exists "${SPLUNK_URL}/services/data/indexes" -X POST \
  -d "name=claude_logs" \
  -d "homePath=$SPLUNK_HOME/var/lib/splunk/claude_logs/db" \
  -d "coldPath=$SPLUNK_HOME/var/lib/splunk/claude_logs/colddb" \
  -d "thawedPath=$SPLUNK_HOME/var/lib/splunk/claude_logs/thaweddb" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null || echo "⚠️  Failed to create index 'claude_logs'"

if [ -d "/var/log/claude_logs" ]; then
  echo " Monitor Claude logs directory"
  auth_curl -X POST "${SPLUNK_URL}/services/data/inputs/monitor/" \
    -d "name=/var/log/claude_logs" \
    -d "index=claude_logs" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null || echo "⚠️  Monitor for 'claude_logs' may already exist"
else
  echo "ℹ️  Skipping Claude logs monitor: /var/log/claude_logs does not exist in container."
  echo "    (Enable the bind mount in compose.yml if you want host Claude logs indexed.)"
fi

DD_USERNAME="${DD_USERNAME:-dd}"
DD_PASSWORD="${DD_PASSWORD:-}"
ADD_ADMIN_ROLE="${ADD_ADMIN_ROLE:-0}"

if [ -z "${DD_PASSWORD}" ]; then
  # Prefer a dedicated password; only fall back to SPLUNK_PASSWORD if we can't persist it.
  if DD_PASSWORD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24 2>/dev/null)"; then
    :
  else
    DD_PASSWORD="${SPLUNK_PASSWORD}"
  fi
  if [ -n "${OUTPUT_DIR}" ]; then
    mkdir -p "${OUTPUT_DIR}"
    echo "${DD_PASSWORD}" > "${OUTPUT_DIR}/dd-password"
    chmod 600 "${OUTPUT_DIR}/dd-password"
    echo "✅ Generated dedicated password for ${DD_USERNAME} (saved to ${OUTPUT_DIR}/dd-password)"
  else
    echo "⚠️  DD_PASSWORD not set and TOKEN_OUTPUT_FILE not set; using a generated password that is not saved."
  fi
fi

echo "🔄 Setting up Splunk user '${DD_USERNAME}' and role 'mcp_tool_execute'..."

# 1. Create the role "mcp_tool_execute"
echo "📋 Creating role 'mcp_tool_execute'..."
post_ok_or_409_exists "${SPLUNK_URL}/services/authorization/roles" -X POST \
  -d "name=mcp_tool_execute" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null || echo "⚠️  Failed to create role 'mcp_tool_execute'"

# Ensure required capabilities are assigned to the role.
# Splunk MCP checks for the *capability* "mcp_tool_execute" (not just role name).
echo "🔧 Ensuring role 'mcp_tool_execute' has required capabilities..."
must auth_curl -X POST "${SPLUNK_URL}/services/authorization/roles/mcp_tool_execute" \
  -d "capabilities=mcp_tool_execute" \
  -d "capabilities=search" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
echo "✅ Role capabilities ensured"

# 2. Create the user
echo "👤 Creating user '${DD_USERNAME}'..."
post_user_ok_or_exists "${SPLUNK_URL}/services/authentication/users" -X POST \
  -d "name=${DD_USERNAME}" \
  -d "password=${DD_PASSWORD}" \
  -d roles="user" \
  -d roles="mcp_tool_execute" \
  -d tz="Europe/Brussels" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null || echo "⚠️  Failed to create user '${DD_USERNAME}'"

if [ "${ADD_ADMIN_ROLE}" = "1" ] || [ "${ADD_ADMIN_ROLE}" = "true" ]; then
  echo "⚠️  Granting admin role to '${DD_USERNAME}' (requested via ADD_ADMIN_ROLE=${ADD_ADMIN_ROLE})"
  auth_curl -X POST "${SPLUNK_URL}/services/authentication/users/${DD_USERNAME}" \
    -d roles="admin" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null || echo "⚠️  Could not grant admin role (user may not exist yet)"
fi

# 3. Encrypted MCP token (Splunk MCP Server 1.x+; plain /authorization/tokens JWTs are rejected by /services/mcp)
echo "🔑 Creating encrypted MCP token for user '${DD_USERNAME}' (Splunk MCP app mcp_token REST handler)..."
TOKEN_RESPONSE=$(must auth_curl -sS \
  "${SPLUNK_URL}/servicesNS/${SPLUNK_USER}/Splunk_MCP_Server/mcp_token?username=${DD_USERNAME}&output_mode=json")

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
if must auth_curl -X POST "${EVENTGEN_INPUT_URL}/enable" >/dev/null; then
  echo "✅ Eventgen modinput enabled via /enable"
else
  auth_curl -X POST "${EVENTGEN_INPUT_URL}" \
    -d "disabled=0" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
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
echo "  User: ${DD_USERNAME}"
echo "  Role: mcp_tool_execute"
echo "  Token saved: $( [ -n \"${TOKEN_OUTPUT_FILE}\" ] && echo \"yes\" || echo \"no\" )"
echo ""
echo "⚠️  Token saved to: ${TOKEN_OUTPUT_FILE:-<not saved>}"
if [ -n "${OUTPUT_DIR}" ] && [ -f "${OUTPUT_DIR}/dd-password" ]; then
  echo "⚠️  ${DD_USERNAME} password saved to: ${OUTPUT_DIR}/dd-password"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
