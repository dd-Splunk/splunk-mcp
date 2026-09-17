#!/usr/bin/env bash
# Admin _internal MCP auth/tool stats (last 30m). Not usable via splunker MCP.
# Usage: ./scripts/mcp-auth-failures.sh [--detail]
# Secrets: .env (Path B) or op run --env-file=tpl.env (Path A).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-tpl.env}"
ENV_OUT="${ENV_OUT:-.env}"
OP="${OP:-op}"
DETAIL="${MCP_AUTH_DETAIL:-0}"

if [[ "${1:-}" == "--detail" ]]; then
  DETAIL=1
fi

SUMMARY_SPL='index=_internal sourcetype=*mcp_monitoring_dashboard* ((event_type IN (tool_call_complete, tool_call_error)) OR event_type IN (auth_failure, auth_invalid_audience, auth_token_decode_error)) | eval is_tool_call=if(match(event_type, "^tool_call_"), 1, 0), is_auth_fail=1-is_tool_call | stats sum(is_tool_call) AS tool_calls sum(is_auth_fail) AS failed_auths'

DETAIL_SPL='index=_internal sourcetype=mcp_monitoring_dashboard event_type IN (auth_failure, auth_invalid_audience, auth_token_decode_error) | table _time source_ip error_message username | sort _time'

run_export() {
  local spl="$1"
  local host port user
  host="${SPLUNK_MCP_HOST:-localhost}"
  port="${SPLUNK_PORT:-8089}"
  user="${SPLUNK_REST_USER:-${SPLUNK_USER:-admin}}"
  : "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set}"
  curl -sk --max-time 60 -u "${user}:${SPLUNK_PASSWORD}" \
    "https://${host}:${port}/services/search/jobs/export" \
    --data-urlencode "search=search ${spl}" \
    -d output_mode=csv \
    -d earliest_time=-30m \
    -d latest_time=now
}

mcp_auth_failures() {
  local csv tool_calls failed
  csv="$(run_export "${SUMMARY_SPL}")"
  if ! printf '%s\n' "$csv" | grep -q 'tool_calls'; then
    echo "Error: unexpected search export (Splunk up? admin auth?)" >&2
    exit 1
  fi
  tool_calls="$(printf '%s\n' "$csv" | awk -F, 'NR==2 {gsub(/\r/,""); print $1}')"
  failed="$(printf '%s\n' "$csv" | awk -F, 'NR==2 {gsub(/\r/,""); print $2}')"
  tool_calls="${tool_calls:-0}"
  failed="${failed:-0}"
  [[ "$tool_calls" =~ ^[0-9]+$ ]] || tool_calls=0
  [[ "$failed" =~ ^[0-9]+$ ]] || failed=0
  echo "tool_calls=${tool_calls} failed_auths=${failed} window=30m"
  if [[ "$failed" -eq 0 ]]; then
    echo "GO: no MCP auth failures (empty activity is OK)"
  else
    echo "FIX: failed_auths=${failed} — rerun with --detail; reload MCP after make update-mcp-client MCP_CLIENT=cursor"
  fi
  if [[ "$DETAIL" == "1" && "$failed" -gt 0 ]]; then
    echo ""
    echo "=== raw auth failures ==="
    run_export "${DETAIL_SPL}"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${MCP_AUTH_FAILURES_INTERNAL:-}" == "1" ]]; then
    mcp_auth_failures
    exit 0
  fi
  if [[ -f "$ENV_OUT" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_OUT" || {
      echo "Error: could not read $ENV_OUT" >&2
      exit 1
    }
    set +a
    mcp_auth_failures
  elif [[ -f "$ENV_FILE" ]]; then
    command -v "$OP" >/dev/null 2>&1 || {
      echo "Error: 1Password CLI (op) not available; create $ENV_OUT from .env.example" >&2
      exit 1
    }
    exec "$OP" run --env-file="$ENV_FILE" -- env MCP_AUTH_FAILURES_INTERNAL=1 MCP_AUTH_DETAIL="$DETAIL" "$0"
  else
    echo "Error: need $ENV_OUT or $ENV_FILE for SPLUNK_PASSWORD." >&2
    exit 1
  fi
fi
