#!/bin/sh
# Minimal Splunk PoC setup (idempotent):
# - Enable SA-Eventgen default modular input (modinput_eventgen://default)
# - Set Splunk MCP Server app ssl_verify=false (local dev only)
# - Create and persist an encrypted MCP token for the admin Splunk user (see MCP_TOKEN_USERNAME)
#
# Out of scope: dedicated MCP user (dd), role mcp_tool_execute, claude_logs index/monitor.
# Full previous version: backup/setup-splunk.sh

set -eu

SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
SPLUNK_USER="${SPLUNK_USER:-admin}"
SPLUNK_PASSWORD="${SPLUNK_PASSWORD}"
SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"

# Splunk user name for the encrypted MCP token (default: admin)
MCP_TOKEN_USERNAME="${MCP_TOKEN_USERNAME:-admin}"

# If set, token is written here (mode 600). Idempotent: existing non-empty file is left
# unchanged unless FORCE_MCP_TOKEN is 1/true.
TOKEN_OUTPUT_FILE="${TOKEN_OUTPUT_FILE:-}"
FORCE_MCP_TOKEN="${FORCE_MCP_TOKEN:-0}"

CURL_OPTS="-k"

LAST_HTTP_CODE=""
LAST_BODY_FILE=""

auth_curl() { # $@ = curl args excluding auth
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

must() {
  "$@" || exit 1
}

splunk_get_json() { # $1 = URL
  auth_curl "$1"
}

wait_for_disabled_value() {
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

# --- 1. Eventgen modular input ---
echo "🎛️  Enabling Eventgen modular input (SA-Eventgen: modinput_eventgen://default)..."
EVENTGEN_INPUT_URL="${SPLUNK_URL}/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default"

if AUTH_CURL_QUIET=1 auth_curl -X POST "${EVENTGEN_INPUT_URL}/enable" >/dev/null; then
  echo "✅ Eventgen modinput enabled via /enable"
else
  cleanup_last_body
  auth_curl -X POST "${EVENTGEN_INPUT_URL}" \
    -d "disabled=0" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
    && echo "✅ Eventgen modinput enablement POST sent (disabled=0)" || echo "⚠️  Failed to enable Eventgen modinput (app missing or endpoint changed)"
fi
cleanup_last_body

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

# --- 2. MCP dev TLS ---
echo "🔐 Disabling MCP server SSL verification for local development..."
auth_curl -X POST "${SPLUNK_URL}/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server" \
  -d "ssl_verify=false" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
  && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

# --- 3. Encrypted MCP token (admin / MCP_TOKEN_USERNAME) ---
token_skip=0
if [ -n "${TOKEN_OUTPUT_FILE}" ] && [ -s "${TOKEN_OUTPUT_FILE}" ]; then
  if [ "${FORCE_MCP_TOKEN}" != "1" ] && [ "${FORCE_MCP_TOKEN}" != "true" ]; then
    token_skip=1
  fi
fi

if [ "${token_skip}" = "1" ]; then
  echo "ℹ️  Encrypted MCP token file already exists and is non-empty: ${TOKEN_OUTPUT_FILE}"
  echo "    Skipping token generation (set FORCE_MCP_TOKEN=1 to regenerate)."
else
  echo "🔑 Creating encrypted MCP token for Splunk user '${MCP_TOKEN_USERNAME}'..."
  TOKEN_RESPONSE=$(must auth_curl -sS \
    "${SPLUNK_URL}/servicesNS/${SPLUNK_USER}/Splunk_MCP_Server/mcp_token?username=${MCP_TOKEN_USERNAME}&output_mode=json")

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

  if [ -n "${TOKEN_OUTPUT_FILE}" ]; then
    out_dir=$(dirname "${TOKEN_OUTPUT_FILE}")
    mkdir -p "${out_dir}"
    echo "💾 Saving token to ${TOKEN_OUTPUT_FILE}..."
    echo "${TOKEN}" > "${TOKEN_OUTPUT_FILE}"
    chmod 600 "${TOKEN_OUTPUT_FILE}"
    echo "✅ Token saved with restricted permissions (600)"
  else
    echo "ℹ️  TOKEN_OUTPUT_FILE unset; token created in Splunk but not written to disk."
  fi
fi

echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MCP token user: ${MCP_TOKEN_USERNAME}"
echo "  Token file: ${TOKEN_OUTPUT_FILE:-<not saved>}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
