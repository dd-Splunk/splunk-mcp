#!/usr/bin/env bash
# Mint Splunk MCP encrypted bearer token (stdout only). Used for Claude/Cursor mcp-remote config.
# Splunk MCP Server 1.0+ requires encrypted tokens (not legacy JWT / cloud *.api.scs.splunk.com endpoint).
# See: https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/connecting-to-the-mcp-server-and-settings
# Requires Splunk on localhost:8089. Secrets via scripts/with-splunk-env.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-tpl.env}"
ENV_OUT="${ENV_OUT:-.env}"
OP="${OP:-op}"

# shellcheck source=scripts/wait-splunk-init.sh
source "${ROOT}/scripts/wait-splunk-init.sh"
# shellcheck source=scripts/splunk-api-env.sh
source "${ROOT}/scripts/splunk-api-env.sh"

wait_for_splunk() {
  local code host port
  splunk_api_env
  host="${SPLUNK_HOST}"
  port="${SPLUNK_PORT}"
  for _ in {1..60}; do
    code="$(curl -k -s -o /dev/null -w '%{http_code}' \
      "https://${host}:${port}/services/server/info" 2>/dev/null || true)"
    if [[ "$code" = "200" || "$code" = "401" ]]; then
      return 0
    fi
    sleep 2
  done
  echo "Error: Splunk API not ready at https://${host}:${port} (waited ~2 min)" >&2
  return 1
}

parse_mcp_token_body() {
  local body="$1"
  echo "$body" | jq -r '.token // .entry[0].content.token // empty' 2>/dev/null || true
}

parse_mcp_token_wait_reason() {
  local body="$1"
  local msg
  msg="$(echo "$body" | jq -r '.messages[0].text // empty' 2>/dev/null || true)"
  if [[ -n "$msg" ]]; then
    printf '%s' "$msg"
    return
  fi
  msg="$(echo "$body" | sed -n 's/.*<msg type="ERROR">\([^<]*\)<\/msg>.*/\1/p' | head -n 1)"
  if [[ -n "$msg" ]]; then
    printf '%s' "$msg"
    return
  fi
  if [[ -z "$body" ]]; then
    printf '%s' "empty response"
  fi
}

# Order: splunk-init (user/roles) → Splunk API → Splunkbase MCP app mcp_token endpoint.
wait_for_mcp_token() {
  local rest_user mcp_user host port url body token msg
  local attempts="${MCP_TOKEN_WAIT_ATTEMPTS:-120}"
  local interval="${MCP_TOKEN_WAIT_INTERVAL:-5}"
  local n=1

  splunk_api_env
  host="${SPLUNK_HOST}"
  port="${SPLUNK_PORT}"
  rest_user="${SPLUNK_REST_USER}"
  mcp_user="${SPLUNK_MCP_USER}"
  : "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set}"

  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq required to parse mcp_token response" >&2
    exit 1
  }

  wait_splunk_init
  wait_for_splunk

  url="https://${host}:${port}/servicesNS/${rest_user}/Splunk_MCP_Server/mcp_token?username=${mcp_user}&output_mode=json"
  echo "Waiting for Splunk MCP Server mcp_token endpoint…" >&2

  while [[ "$n" -le "$attempts" ]]; do
    body="$(curl -k -sS -u "${rest_user}:${SPLUNK_PASSWORD}" "$url" 2>/dev/null || true)"
    token="$(parse_mcp_token_body "$body")"
    if [[ -n "$token" ]]; then
      printf '%s' "$token"
      return 0
    fi
    if (( n % 6 == 0 )); then
      msg="$(parse_mcp_token_wait_reason "$body")"
      if [[ -n "$msg" ]]; then
        echo "  still waiting (${n}/${attempts}): ${msg}" >&2
      else
        echo "  still waiting (${n}/${attempts})…" >&2
      fi
    fi
    sleep "$interval"
    n=$((n + 1))
  done

  echo "Error: mcp_token not available after ~$((attempts * interval / 60)) min." >&2
  echo "  Check: Splunk MCP Server app (7931), splunk-init (docker logs splunk-init), user ${mcp_user}." >&2
  echo "  Retry: make update-mcp-client MCP_CLIENT=cursor  (or MCP_CLIENT=claude)" >&2
  return 1
}

mint_token() {
  wait_for_mcp_token
}

run_mint() {
  mint_token
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # shellcheck source=scripts/with-splunk-env.sh
  source "${ROOT}/scripts/with-splunk-env.sh"
  with_splunk_env "$@"
  run_mint
fi
