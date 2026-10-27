#!/usr/bin/env bash
# Mint Splunk MCP encrypted bearer token (stdout only). Used for Claude/Cursor mcp-remote config.
# Splunk MCP Server 2.1+ requires tokens encrypted with the server's key pair (not legacy JWT /
# cloud *.api.scs.splunk.com endpoint). The key pair is created here on first use (idempotent):
#   POST /services/mcp_token/key-pair  -> 201 created, 409 already exists
#   POST /services/mcp_token/tokens    -> {"token": "<encrypted>"} (admin may pass username=<owner>)
# See: https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/connecting-to-the-mcp-server-and-settings
# Requires Splunk on localhost:8089. Secrets via scripts/with-splunk-env.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_OUT="${ENV_OUT:-.env}"

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
      --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
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
  msg="$(echo "$body" | jq -r '.messages[0].text // .message // .details // empty' 2>/dev/null || true)"
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

# Order: splunk-init (user/roles) → Splunk API → MCP app key pair → token for splunker.
wait_for_mcp_token() {
  local rest_user mcp_user host port base response code body token msg
  local attempts="${MCP_TOKEN_WAIT_ATTEMPTS:-120}"
  local interval="${MCP_TOKEN_WAIT_INTERVAL:-5}"
  local n=1 key_ready=0

  splunk_api_env
  host="${SPLUNK_HOST}"
  port="${SPLUNK_PORT}"
  rest_user="${SPLUNK_REST_USER}"
  mcp_user="${SPLUNK_MCP_USER}"
  : "${SPLUNK_ADMIN_PASSWORD:?SPLUNK_ADMIN_PASSWORD must be set}"

  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq required to parse mcp_token response" >&2
    exit 1
  }

  wait_splunk_init
  wait_for_splunk

  base="https://${host}:${port}/services/mcp_token"
  echo "Waiting for Splunk MCP Server mcp_token endpoint…" >&2

  while [[ "$n" -le "$attempts" ]]; do
    if [[ "$key_ready" -eq 0 ]]; then
      # Last line is the HTTP status (000 when the connection fails or times out).
      response="$(splunk_curl -k -s \
        --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
        -X POST -d output_mode=json -w '\n%{http_code}' "${base}/key-pair" 2>/dev/null || true)"
      code="${response##*$'\n'}"
      body="${response%$'\n'*}"
      # Splunk answered server/info above, so 401 here is a wrong password, not a
      # warming-up app. Retrying would only burn the full wait.
      if [[ "$code" == "401" ]]; then
        echo "Error: Splunk rejected ${rest_user} credentials (HTTP 401) at https://${host}:${port}." >&2
        echo "  Check SPLUNK_ADMIN_PASSWORD in ${ENV_OUT} matches the running so1 admin password." >&2
        return 1
      fi
      if [[ "$code" == "201" ]]; then
        echo "Created MCP token encryption key (valid until $(echo "$body" | jq -r '.valid_until // "unknown"' 2>/dev/null))." >&2
        key_ready=1
      elif [[ "$code" == "409" ]]; then
        key_ready=1
      fi
    fi

    if [[ "$key_ready" -eq 1 ]]; then
      response="$(splunk_curl -k -s \
        --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
        -X POST --data-urlencode "username=${mcp_user}" -d output_mode=json \
        -w '\n%{http_code}' "${base}/tokens" 2>/dev/null || true)"
      code="${response##*$'\n'}"
      body="${response%$'\n'*}"
      if [[ "$code" == "401" ]]; then
        echo "Error: Splunk rejected ${rest_user} credentials (HTTP 401) at https://${host}:${port}." >&2
        echo "  Check SPLUNK_ADMIN_PASSWORD in ${ENV_OUT} matches the running so1 admin password." >&2
        return 1
      fi
      token="$(parse_mcp_token_body "$body")"
      if [[ -n "$token" ]]; then
        printf '%s' "$token"
        return 0
      fi
      # Key deleted out from under us (rotation): create it again on the next pass.
      if [[ "$body" == *"No active encryption keys"* ]]; then
        key_ready=0
      fi
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
  echo "  Check: Splunk MCP Server app (7931, 2.1.0+), splunk-init (docker logs splunk-init), user ${mcp_user}." >&2
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
