#!/usr/bin/env bash
# Mint Splunk MCP encrypted bearer token (stdout only). Used for Claude/Cursor mcp-remote config.
# Splunk MCP Server 1.0+ requires encrypted tokens (not legacy JWT / cloud *.api.scs.splunk.com endpoint).
# See: https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.2/connecting-to-the-mcp-server-and-settings
# Requires Splunk on localhost:8089 and secrets from .env or op run + tpl.env.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-tpl.env}"
ENV_OUT="${ENV_OUT:-.env}"
OP="${OP:-op}"

# shellcheck source=scripts/wait-splunk-init.sh
source "${ROOT}/scripts/wait-splunk-init.sh"

# Host-side Splunk API (not Docker service name so1).
apply_splunk_api_defaults() {
  export SPLUNK_MCP_HOST="${SPLUNK_MCP_HOST:-localhost}"
  export SPLUNK_PORT="${SPLUNK_PORT:-8089}"
}

wait_for_splunk() {
  local code host port
  host="${SPLUNK_MCP_HOST:-localhost}"
  port="${SPLUNK_PORT:-8089}"
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

# Order: splunk-init (user/roles) → Splunk API → Splunkbase MCP app mcp_token endpoint.
wait_for_mcp_token() {
  local rest_user mcp_user host port url body token msg
  local attempts="${MCP_TOKEN_WAIT_ATTEMPTS:-120}"
  local interval="${MCP_TOKEN_WAIT_INTERVAL:-5}"
  local n=1

  apply_splunk_api_defaults
  host="${SPLUNK_MCP_HOST}"
  port="${SPLUNK_PORT}"
  rest_user="${SPLUNK_REST_USER:-${SPLUNK_USER:-admin}}"
  mcp_user="${SPLUNK_MCP_USER:-${SPLUNKER_USERNAME:-splunker}}"
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
      msg="$(echo "$body" | jq -r '.messages[0].text // empty' 2>/dev/null || true)"
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
  echo "  Retry: make update-cursor-config  (or MCP_CLIENT=claude)" >&2
  return 1
}

mint_token() {
  wait_for_mcp_token
}

run_mint() {
  apply_splunk_api_defaults
  mint_token
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${MINT_MCP_TOKEN_INTERNAL:-}" == "1" ]]; then
    run_mint
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
    run_mint
  elif [[ -f "$ENV_FILE" ]]; then
    command -v "$OP" >/dev/null 2>&1 || {
      echo "Error: 1Password CLI (op) not available; create $ENV_OUT from .env.example" >&2
      exit 1
    }
    exec "$OP" run --env-file="$ENV_FILE" -- env MINT_MCP_TOKEN_INTERNAL=1 "$0"
  else
    echo "Error: need $ENV_OUT or $ENV_FILE to mint MCP token." >&2
    exit 1
  fi
fi
