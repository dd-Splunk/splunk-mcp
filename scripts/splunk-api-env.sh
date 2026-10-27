#!/bin/sh
# Shared Splunk REST client defaults. Source this file, then call: splunk_api_env
#
# Also defines splunk_curl (admin REST calls without the password in argv).
#
# Sets SPLUNK_HOST, SPLUNK_PORT, SPLUNK_REST_USER, SPLUNK_MCP_USER, and the curl
# timeouts SPLUNK_CURL_CONNECT_TIMEOUT / SPLUNK_CURL_MAX_TIME (seconds) when unset.
# A value already in the environment is kept.
#
# Host scripts use the localhost default (published port 127.0.0.1:8089).
# compose.yml sets SPLUNK_HOST=so1 on splunk-init only. localhost inside that
# container is Alpine, not Splunk.

splunk_api_env() {
  SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
  SPLUNK_PORT="${SPLUNK_PORT:-8089}"
  SPLUNK_REST_USER="${SPLUNK_REST_USER:-admin}"
  SPLUNK_MCP_USER="${SPLUNK_MCP_USER:-splunker}"
  # A stalled splunkd must not hang init, mint, or toggle loops forever.
  SPLUNK_CURL_CONNECT_TIMEOUT="${SPLUNK_CURL_CONNECT_TIMEOUT:-10}"
  SPLUNK_CURL_MAX_TIME="${SPLUNK_CURL_MAX_TIME:-60}"
}

# Print $1 escaped for a double-quoted curl config value (\ and " get a backslash).
# Shell builtins only, so the secret never becomes an exec argument. Call it in $(…):
# the loop variables then die with the subshell.
splunk_curl_quote() {
  _in=$1 _out=
  while [ -n "${_in}" ]; do
    _rest=${_in#?}
    _c=${_in%"${_rest}"}
    case ${_c} in
      \\ | \") _out=${_out}\\${_c} ;;
      *) _out=${_out}${_c} ;;
    esac
    _in=${_rest}
  done
  printf '%s' "${_out}"
}

# curl as SPLUNK_REST_USER:SPLUNK_ADMIN_PASSWORD. The credentials reach curl as a config on
# fd 3 (-K), not as -u: any local user can read process arguments with ps. stdin stays free
# for the caller, e.g. --data-urlencode password@- for a second secret.
splunk_curl() {
  case ${SPLUNK_ADMIN_PASSWORD:-} in
    '') echo "Error: SPLUNK_ADMIN_PASSWORD must be set" >&2; return 1 ;;
    *"$(printf '\r')"* | *'
'*) echo "Error: SPLUNK_ADMIN_PASSWORD must not contain a line break" >&2; return 1 ;;
  esac
  curl -K /dev/fd/3 "$@" 3<<EOF
user = "$(splunk_curl_quote "${SPLUNK_REST_USER:-admin}:${SPLUNK_ADMIN_PASSWORD}")"
EOF
}
