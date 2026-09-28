#!/bin/sh
# Splunk PoC bootstrap over HTTPS REST (idempotent; safe to re-run via make up / splunk-init).
#
# Execution order:
#   1. Enable SA-Eventgen modinput_eventgen://default (required; init fails if still disabled)
#   2. Splunk MCP Server: ssl_verify=false (local dev only; uses curl -k)
#   3. Role mcp_user with mcp_tool_execute (required) and s4r_workshop_control (best-effort after SA-S4R load)
#   4. User splunker: roles user + mcp_user
#   5. SA-S4R MCP tools: register-s4r-mcp-tools.sh (batch replace, enable, saved-search reload)
#
# splunk-init mounts this directory's scripts and SA-S4R/default/s4r_mcp_tools.json.
# Compose sets SPLUNK_MCP_ENV_LOADED=1 so the registrar does not look for .env or op.
#
# Required env: SPLUNK_PASSWORD.
# SPLUNK_MCP_PASSWORD is required on first user creation and when FORCE_SPLUNK_MCP_PASSWORD=1.
# REST host, port, and account names: scripts/splunk-api-env.sh.
# compose.yml sets SPLUNK_HOST=so1. localhost inside splunk-init is that container.
# FORCE_SPLUNK_MCP_PASSWORD (0; 1|true|yes forces password reset).
#
# Out of scope: claude_logs index or file monitors — see docs/poc/CONFIGURATION.md.
# Full variable table and flows: docs/poc/CONFIGURATION.md#appendix-setup-splunksh

set -eu

_here=$(dirname "$0")
_here=$(cd "${_here}" && pwd)
# shellcheck source=scripts/splunk-api-env.sh
. "${_here}/splunk-api-env.sh"
splunk_api_env

: "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set}"
SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"

: "${SPLUNK_MCP_PASSWORD:=}"
FORCE_SPLUNK_MCP_PASSWORD="${FORCE_SPLUNK_MCP_PASSWORD:-0}"

CURL_OPTS="-k"
LAST_BODY_FILE=""

# True for 1, true, yes (any case) — used by FORCE_* flags.
is_truthy() {
  case "${1:-}" in 1|true|yes|TRUE) return 0 ;; esac
  return 1
}

# curl with SPLUNK_REST_USER:SPLUNK_PASSWORD; prints body on 2xx/3xx, else stderr unless AUTH_CURL_QUIET=1.
auth_curl() { # $@ = curl args excluding auth
  tmp_body="$(mktemp)"
  quiet="${AUTH_CURL_QUIET:-0}"
  req_url=""
  for arg in "$@"; do
    case "$arg" in
      http://*|https://*) req_url="$arg"; break ;;
    esac
  done

  if code="$(curl ${CURL_OPTS} -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" -sS -o "${tmp_body}" -w "%{http_code}" "$@")"; then
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

# Normalize Splunk REST disabled (0/1, true/false, strings) to 0 or 1.
normalize_disabled() {
  case "${1:-}" in
    0|false|False|FALSE) echo "0" ;;
    1|true|True|TRUE) echo "1" ;;
    *) echo "${1:-}" ;;
  esac
}

wait_for_disabled_value() {
  url="$1"
  expected="$2"
  i=0
  while [ "$i" -lt 30 ]; do
    current=""
    if command -v jq >/dev/null 2>&1; then
      # `//` treats JSON false as missing, so a disabled=false input looks unset.
      current=$(splunk_get_json "${url}" | jq -r '
        .entry[0].content.disabled
        | if . == null then empty else tostring end
      ' 2>/dev/null || true)
      current="$(normalize_disabled "${current}")"
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
# This PoC always ships SA-Eventgen in SPLUNK_APPS_URL. A "healthy" empty index
# is worse than a failed init — do not warn-and-continue.
echo "🎛️  Enabling Eventgen modular input (SA-Eventgen: modinput_eventgen://default)..."
EVENTGEN_INPUT_URL="${SPLUNK_URL}/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required to verify Eventgen is enabled (splunk-init installs jq)" >&2
  exit 1
fi

if ! AUTH_CURL_QUIET=1 auth_curl "${EVENTGEN_INPUT_URL}?output_mode=json" >/dev/null; then
  cleanup_last_body
  echo "error: SA-Eventgen modinput not found at ${EVENTGEN_INPUT_URL}" >&2
  echo "  This PoC requires Splunkbase app 1924 in SPLUNK_APPS_URL. Check docker logs so1." >&2
  exit 1
fi
cleanup_last_body

eventgen_enabled=0
if AUTH_CURL_QUIET=1 auth_curl -X POST "${EVENTGEN_INPUT_URL}/enable" >/dev/null; then
  eventgen_enabled=1
  echo "✅ Eventgen modinput enabled via /enable"
fi
if [ "${eventgen_enabled}" = "0" ]; then
  cleanup_last_body
  if AUTH_CURL_QUIET=1 auth_curl -X POST "${EVENTGEN_INPUT_URL}" \
    -d "disabled=0" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null; then
    echo "✅ Eventgen modinput enablement POST sent (disabled=0)"
  else
    cleanup_last_body
    echo "error: failed to enable Eventgen modinput (POST /enable and disabled=0 both failed)" >&2
    exit 1
  fi
fi
cleanup_last_body

if wait_for_disabled_value "${EVENTGEN_INPUT_URL}?output_mode=json" "0"; then
  echo "✅ Verified: Eventgen modinput is enabled (disabled=0)"
else
  echo "error: Eventgen modinput is still disabled after enable (expected disabled=0)" >&2
  echo "  Check: ${EVENTGEN_INPUT_URL}?output_mode=json" >&2
  exit 1
fi

# --- 2. MCP dev TLS ---
echo "🔐 Disabling MCP server SSL verification for local development..."
auth_curl -X POST "${SPLUNK_URL}/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server" \
  -d "ssl_verify=false" \
  -H "Content-Type: application/x-www-form-urlencoded" >/dev/null \
  && echo "✅ SSL verification disabled" || echo "⚠️  SSL verification setting may already be disabled"

# --- 3. MCP role (mcp_user) ---
# Grant mcp_tool_execute first. Unknown custom capabilities (s4r_workshop_control
# before SA-S4R authorize.conf is loaded, or a bad stanza) make Splunk reject the
# entire role POST — then splunker is never created and mcp_token mint hangs.
echo "👤 Ensuring role 'mcp_user' exists with capability mcp_tool_execute and srchJobsQuota=5..."
ROLE_URL="${SPLUNK_URL}/services/authorization/roles/mcp_user"
ROLE_COLLECTION="${SPLUNK_URL}/services/authorization/roles"

role_exists=0
AUTH_CURL_QUIET=1 auth_curl "${ROLE_URL}?output_mode=json" >/dev/null && role_exists=1
cleanup_last_body

if [ "${role_exists}" = "1" ]; then
  must auth_curl -X POST "${ROLE_URL}" \
    -d "capabilities=mcp_tool_execute" \
    -d "srchJobsQuota=5" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
  echo "✅ Updated role mcp_user (mcp_tool_execute, srchJobsQuota=5)"
else
  must auth_curl -X POST "${ROLE_COLLECTION}" \
    -d "name=mcp_user" \
    -d "capabilities=mcp_tool_execute" \
    -d "srchJobsQuota=5" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
  echo "✅ Created role mcp_user (mcp_tool_execute, srchJobsQuota=5)"
fi
cleanup_last_body

echo "👤 Granting s4r_workshop_control on mcp_user (after SA-S4R authorize.conf load)..."
AUTH_CURL_QUIET=1 auth_curl -X POST "${SPLUNK_URL}/services/apps/local/SA-S4R/_reload" >/dev/null || true
cleanup_last_body
s4r_cap_ok=0
n=0
while [ "$n" -lt 8 ]; do
  if AUTH_CURL_QUIET=1 auth_curl -X POST "${ROLE_URL}" \
    -d "capabilities=mcp_tool_execute" \
    -d "capabilities=s4r_workshop_control" \
    -d "srchJobsQuota=5" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null; then
    s4r_cap_ok=1
    echo "✅ Granted s4r_workshop_control on mcp_user"
    break
  fi
  cleanup_last_body
  n=$((n + 1))
  sleep 2
  AUTH_CURL_QUIET=1 auth_curl -X POST "${SPLUNK_URL}/services/apps/local/SA-S4R/_reload" >/dev/null || true
  cleanup_last_body
done
if [ "${s4r_cap_ok}" = "0" ]; then
  echo "⚠️  Could not grant s4r_workshop_control (REST handler still uses mcp_tool_execute). Check SA-S4R/default/authorize.conf stanza [capability::s4r_workshop_control]."
fi
cleanup_last_body

# --- 4. MCP user (splunker) ---
echo "🧑 Ensuring Splunk user '${SPLUNK_MCP_USER}' exists with roles user + mcp_user..."

USER_URL="${SPLUNK_URL}/services/authentication/users/${SPLUNK_MCP_USER}"
user_exists=0
AUTH_CURL_QUIET=1 auth_curl "${USER_URL}?output_mode=json" >/dev/null && user_exists=1
cleanup_last_body

set -- -d "roles=user" -d "roles=mcp_user" -d "locked-out=false"
[ "${user_exists}" = "0" ] && [ -z "${SPLUNK_MCP_PASSWORD}" ] && {
  echo "❌ SPLUNK_MCP_PASSWORD must be set to create the MCP user '${SPLUNK_MCP_USER}'." >&2
  exit 1
}

if is_truthy "${FORCE_SPLUNK_MCP_PASSWORD}"; then
  [ -n "${SPLUNK_MCP_PASSWORD}" ] || {
    echo "❌ FORCE_SPLUNK_MCP_PASSWORD is set but SPLUNK_MCP_PASSWORD is empty." >&2
    exit 1
  }
  set -- -d "password=${SPLUNK_MCP_PASSWORD}" "$@"
fi

if [ "${user_exists}" = "1" ]; then
  user_ok_msg="✅ Updated user ${SPLUNK_MCP_USER}"
  is_truthy "${FORCE_SPLUNK_MCP_PASSWORD}" && user_ok_msg="${user_ok_msg} (password + roles)"
  ! is_truthy "${FORCE_SPLUNK_MCP_PASSWORD}" && user_ok_msg="${user_ok_msg} (roles)"
  must auth_curl -X POST "${USER_URL}" "$@" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
  echo "${user_ok_msg}"
fi
if [ "${user_exists}" = "0" ]; then
  must auth_curl -X POST "${SPLUNK_URL}/services/authentication/users" \
    -d "name=${SPLUNK_MCP_USER}" -d "password=${SPLUNK_MCP_PASSWORD}" "$@" \
    -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
  echo "✅ Created user ${SPLUNK_MCP_USER} (roles user + mcp_user)"
fi
cleanup_last_body

# --- 5. SA-S4R MCP tools (fails init if register or enable fails) ---
echo "Registering SA-S4R MCP tools..."
"${_here}/register-s4r-mcp-tools.sh"

echo "✅ Setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  MCP user: ${SPLUNK_MCP_USER}"
echo "  MCP user password: <provided via SPLUNK_MCP_PASSWORD>"
echo "  MCP token: <mint via scripts/mint-mcp-token.sh; client configs only>"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
