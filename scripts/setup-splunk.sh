#!/bin/sh
# Minimal Splunk PoC setup (idempotent):
# - Enable SA-Eventgen default modular input (modinput_eventgen://default)
# - Set Splunk MCP Server app ssl_verify=false (local dev only)
# - Add Splunk MLTK role (MLTK_ROLE) to MLTK_ROLES_USER (default: SPLUNKER_USERNAME / splunker; override e.g. admin or SPLUNK_USER)
# - Ensure an MCP-enabled Splunk user exists and persist its password + token
#
# Out of scope: claude_logs index/monitor (add via Splunk UI/REST if needed).

set -eu

SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
SPLUNK_USER="${SPLUNK_USER:-admin}"
: "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set}"
SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"

# Dedicated MCP user to create/maintain and mint the encrypted MCP token for.
# This script intentionally does NOT mint tokens for admin.
MCP_TOKEN_USERNAME="${MCP_TOKEN_USERNAME:-splunker}"

SPLUNKER_USERNAME="${SPLUNKER_USERNAME:-splunker}"
# Splunk account that receives the MLTK role. Defaults to the MCP user (SPLUNKER_USERNAME), not SPLUNK_USER (admin REST).
# Set to the same value as SPLUNK_USER in .env if the management account (e.g. admin) should have MLTK instead.
MLTK_ROLES_USER="${MLTK_ROLES_USER:-$SPLUNKER_USERNAME}"
# Role created by Splunk AI Toolkit (override if your app version uses a different name, e.g. mltk_admin).
# Set empty to skip MLTK role assignment.
MLTK_ROLE="${MLTK_ROLE:-mltk_dsdl_admin}"
SPLUNKER_PASSWORD_FILE="${SPLUNKER_PASSWORD_FILE:-.secrets/splunker-password}"
FORCE_SPLUNKER_PASSWORD="${FORCE_SPLUNKER_PASSWORD:-0}"

# If set, token is written here (mode 600). Idempotent: existing non-empty file is left
# unchanged unless FORCE_MCP_TOKEN is 1/true.
TOKEN_OUTPUT_FILE="${TOKEN_OUTPUT_FILE:-.secrets/splunk-token}"
FORCE_MCP_TOKEN="${FORCE_MCP_TOKEN:-0}"

CURL_OPTS="-k"
LAST_BODY_FILE=""

is_truthy() {
  case "${1:-}" in 1|true|yes|TRUE) return 0 ;; esac
  return 1
}

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
  LAST_BODY_FILE="${tmp_body}"
  case "${code}" in
    2??|3??)
      cat "${tmp_body}"
      rm -f "${tmp_body}"
      LAST_BODY_FILE=""
      return 0
      ;;
    *)
      if ! is_truthy "${quiet}"; then
        err_msg="❌ HTTP ${code} (request failed)"
        [ -n "${req_url}" ] && err_msg="❌ HTTP ${code} for ${req_url}"
        echo "${err_msg}" >&2
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
}

must() {
  "$@" || exit 1
}

read_secret_file() { # $1=path
  path="$1"
  if [ -f "${path}" ]; then
    # shellcheck disable=SC2002
    tr -d '\n' < "${path}"
  fi
}

generate_password() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32 | tr -d '\n'
    return
  fi
  # Fallback: CSPRNG from /dev/urandom (portable enough for our use)
  LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32
}

extract_token() { # $1=json body
  if command -v jq >/dev/null 2>&1; then
    echo "$1" | jq -r '.token // empty'
    return
  fi
  echo "$1" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p'
}

splunk_get_json() { # $1 = URL
  auth_curl "$1"
}

wait_for_disabled_value() {
  url="$1"
  expected="$2"
  i=0
  while [ "$i" -lt 30 ]; do
    current=""
    if command -v jq >/dev/null 2>&1; then
      current=$(splunk_get_json "${url}" | jq -r '.entry[0].content.disabled // empty' 2>/dev/null || true)
    fi
    if [ -n "${current}" ] && [ "${current}" = "${expected}" ]; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  return 1
}

ensure_mltk_role() {
  MLTK_USER_URL="${SPLUNK_URL}/services/authentication/users/${MLTK_ROLES_USER}"

  if ! AUTH_CURL_QUIET=1 auth_curl "${MLTK_USER_URL}?output_mode=json" >/dev/null; then
    cleanup_last_body
    echo "⚠️  User ${MLTK_ROLES_USER} not found; skipping ${MLTK_ROLE} (create the user first or set MLTK_ROLES_USER to an existing account)"
    return
  fi
  cleanup_last_body

  if ! command -v jq >/dev/null 2>&1; then
    echo "⚠️  jq not found; install jq to merge ${MLTK_ROLE} with existing roles for ${MLTK_ROLES_USER}, or assign the role in Splunk Web"
    return
  fi

  mltk_user_json="$(auth_curl "${MLTK_USER_URL}?output_mode=json" || true)"
  if [ -z "$mltk_user_json" ]; then
    echo "⚠️  Empty user response; skipping ${MLTK_ROLE}"
    return
  fi

  roles_merged="$(echo "$mltk_user_json" | jq -r --arg r "${MLTK_ROLE}" \
    '([.entry[0].content.roles[]?] + [$r]) | unique | .[]' 2>/dev/null || true)"
  if [ -z "$roles_merged" ]; then
    echo "⚠️  Could not read roles for ${MLTK_ROLES_USER}; skipping ${MLTK_ROLE}"
    return
  fi

  set --
  for r in $roles_merged; do
    set -- "$@" -d "roles=${r}"
  done
  auth_curl -X POST "${MLTK_USER_URL}" "$@" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
    && echo "✅ Updated user ${MLTK_ROLES_USER} (role ${MLTK_ROLE} ensured)" \
    || echo "⚠️  Could not add ${MLTK_ROLE} to ${MLTK_ROLES_USER} (is Splunk AI Toolkit installed? The role is created by that app.)"
  cleanup_last_body
}

# --- 1. Eventgen modular input ---
echo "🎛️  Enabling Eventgen modular input (SA-Eventgen: modinput_eventgen://default)..."
EVENTGEN_INPUT_URL="${SPLUNK_URL}/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default"

eventgen_enabled=0
if AUTH_CURL_QUIET=1 auth_curl -X POST "${EVENTGEN_INPUT_URL}/enable" >/dev/null; then
  eventgen_enabled=1
  echo "✅ Eventgen modinput enabled via /enable"
fi
if [ "${eventgen_enabled}" = "0" ]; then
  cleanup_last_body
  auth_curl -X POST "${EVENTGEN_INPUT_URL}" \
    -d "disabled=0" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
    && echo "✅ Eventgen modinput enablement POST sent (disabled=0)" \
    || echo "⚠️  Failed to enable Eventgen modinput (app missing or endpoint changed)"
fi
cleanup_last_body

if command -v jq >/dev/null 2>&1; then
  eventgen_verified=0
  wait_for_disabled_value "${EVENTGEN_INPUT_URL}?output_mode=json" "0" && eventgen_verified=1
  if [ "${eventgen_verified}" = "1" ]; then
    echo "✅ Verified: Eventgen modinput is enabled (disabled=0)"
  fi
  if [ "${eventgen_verified}" = "0" ]; then
    echo "⚠️  Could not verify Eventgen modinput state via REST (expected disabled=0)."
    echo "    Check manually: ${EVENTGEN_INPUT_URL}?output_mode=json"
  fi
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "⚠️  jq not available; skipping verification of Eventgen modinput."
fi

# --- 2. MCP dev TLS ---
echo "🔐 Disabling MCP server SSL verification for local development..."
auth_curl -X POST "${SPLUNK_URL}/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server" \
  -d "ssl_verify=false" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
  && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

# --- 3. MCP role (mcp_user) ---
echo "👤 Ensuring role 'mcp_user' exists with capability mcp_tool_execute..."
ROLE_URL="${SPLUNK_URL}/services/authorization/roles/mcp_user"

role_exists=0
AUTH_CURL_QUIET=1 auth_curl "${ROLE_URL}?output_mode=json" >/dev/null && role_exists=1
cleanup_last_body

if [ "${role_exists}" = "1" ]; then
  set -- -X POST "${ROLE_URL}" -d "capabilities=mcp_tool_execute"
  role_ok_msg="✅ Updated role mcp_user (capabilities=mcp_tool_execute)"
  role_fail_msg="⚠️  Failed to update role mcp_user"
fi
if [ "${role_exists}" = "0" ]; then
  set -- -X POST "${SPLUNK_URL}/services/authorization/roles" \
    -d "name=mcp_user" -d "capabilities=mcp_tool_execute"
  role_ok_msg="✅ Created role mcp_user (capabilities=mcp_tool_execute)"
  role_fail_msg="⚠️  Failed to create role mcp_user"
fi
auth_curl "$@" -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
  && echo "${role_ok_msg}" || echo "${role_fail_msg}"
cleanup_last_body

# --- 4. Dedicated MCP user (splunker) ---
if [ "${MCP_TOKEN_USERNAME}" = "admin" ] || [ "${SPLUNKER_USERNAME}" = "admin" ]; then
  echo "❌ Refusing to mint MCP tokens for admin. Set MCP_TOKEN_USERNAME and SPLUNKER_USERNAME to a non-admin user." >&2
  exit 1
fi

echo "🧑 Ensuring Splunk user '${SPLUNKER_USERNAME}' exists with roles user + mcp_user..."

splunker_pw_skip=0
SPLUNKER_PASSWORD_VALUE=""
if [ -s "${SPLUNKER_PASSWORD_FILE}" ] && ! is_truthy "${FORCE_SPLUNKER_PASSWORD}"; then
  SPLUNKER_PASSWORD_VALUE="$(read_secret_file "${SPLUNKER_PASSWORD_FILE}")"
  [ -n "${SPLUNKER_PASSWORD_VALUE}" ] && splunker_pw_skip=1
fi

if [ "${splunker_pw_skip}" = "0" ]; then
  SPLUNKER_PASSWORD_VALUE="$(generate_password)"
  if [ -z "${SPLUNKER_PASSWORD_VALUE}" ]; then
    echo "❌ Failed to generate password for ${SPLUNKER_USERNAME}" >&2
    exit 1
  fi
  pw_dir="$(dirname "${SPLUNKER_PASSWORD_FILE}")"
  mkdir -p "${pw_dir}"
  echo "${SPLUNKER_PASSWORD_VALUE}" > "${SPLUNKER_PASSWORD_FILE}"
  chmod 600 "${SPLUNKER_PASSWORD_FILE}"
  echo "✅ Generated password saved to ${SPLUNKER_PASSWORD_FILE} (mode 600)"
fi
if [ "${splunker_pw_skip}" = "1" ]; then
  echo "ℹ️  Using existing password file: ${SPLUNKER_PASSWORD_FILE}"
fi

USER_URL="${SPLUNK_URL}/services/authentication/users/${SPLUNKER_USERNAME}"
user_exists=0
AUTH_CURL_QUIET=1 auth_curl "${USER_URL}?output_mode=json" >/dev/null && user_exists=1
cleanup_last_body

set -- -d "roles=user" -d "roles=mcp_user"
[ "${splunker_pw_skip}" = "0" ] && set -- -d "password=${SPLUNKER_PASSWORD_VALUE}" "$@"

if [ "${user_exists}" = "1" ]; then
  user_ok_msg="✅ Updated user ${SPLUNKER_USERNAME}"
  [ "${splunker_pw_skip}" = "0" ] && user_ok_msg="${user_ok_msg} (password + roles)"
  [ "${splunker_pw_skip}" = "1" ] && user_ok_msg="${user_ok_msg} (roles)"
  user_fail_msg="⚠️  Failed to update user ${SPLUNKER_USERNAME}"
  auth_curl -X POST "${USER_URL}" "$@" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
    && echo "${user_ok_msg}" || echo "${user_fail_msg}"
fi
if [ "${user_exists}" = "0" ]; then
  auth_curl -X POST "${SPLUNK_URL}/services/authentication/users" \
    -d "name=${SPLUNKER_USERNAME}" "$@" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
    && echo "✅ Created user ${SPLUNKER_USERNAME} (roles user + mcp_user)" \
    || echo "⚠️  Failed to create user ${SPLUNKER_USERNAME}"
fi
cleanup_last_body

# --- 5. MLTK role (Splunk AI Toolkit) for MLTK_ROLES_USER ---
if [ -z "${MLTK_ROLE}" ]; then
  echo "ℹ️  MLTK_ROLE unset/empty; skipping MLTK role assignment"
fi
if [ -n "${MLTK_ROLE}" ]; then
  echo "👤 Ensuring user '${MLTK_ROLES_USER}' has role ${MLTK_ROLE}..."
  ensure_mltk_role
fi

# --- 6. Encrypted MCP token (splunker) ---
token_skip=0
if [ -n "${TOKEN_OUTPUT_FILE}" ] && [ -s "${TOKEN_OUTPUT_FILE}" ] && ! is_truthy "${FORCE_MCP_TOKEN}"; then
  token_skip=1
fi

if [ "${token_skip}" = "1" ]; then
  echo "ℹ️  Encrypted MCP token file already exists and is non-empty: ${TOKEN_OUTPUT_FILE}"
  echo "    Skipping token generation (set FORCE_MCP_TOKEN=1 to regenerate)."
fi

if [ "${token_skip}" = "0" ]; then
  echo "🔑 Creating encrypted MCP token for Splunk user '${MCP_TOKEN_USERNAME}'..."
  TOKEN_RESPONSE=$(must auth_curl -sS \
    "${SPLUNK_URL}/servicesNS/${SPLUNK_USER}/Splunk_MCP_Server/mcp_token?username=${MCP_TOKEN_USERNAME}&output_mode=json")

  TOKEN="$(extract_token "${TOKEN_RESPONSE}")"
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
  fi
  if [ -z "${TOKEN_OUTPUT_FILE}" ]; then
    echo "ℹ️  TOKEN_OUTPUT_FILE unset; token created in Splunk but not written to disk."
  fi
fi

echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MCP user: ${SPLUNKER_USERNAME}"
echo "  MCP user password file: ${SPLUNKER_PASSWORD_FILE}"
echo "  MCP token user: ${MCP_TOKEN_USERNAME}"
echo "  Token file: ${TOKEN_OUTPUT_FILE:-<not saved>}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
