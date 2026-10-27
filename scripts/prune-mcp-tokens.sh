#!/usr/bin/env bash
# Delete superseded Splunk MCP bearer tokens: keep only the newest active token
# (latest created_at) of the MCP user in the Splunk MCP Server 2.1 token registry,
# and delete the rest. Run right after minting.
#
# Every mint-mcp-token.sh call creates a new token that stays valid until the
# encryption key expires (up to 180 days). Callers must have rewritten every client
# config with the newest token first.
#
# Usage: ./scripts/prune-mcp-tokens.sh [--dry-run]
# Secrets via scripts/with-splunk-env.sh. Prints the number of tokens deleted.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck source=scripts/splunk-api-env.sh
source "${ROOT}/scripts/splunk-api-env.sh"

dry_run=0
case "${1:-}" in
  "") ;;
  --dry-run) dry_run=1 ;;
  *)
    echo "Usage: $(basename "$0") [--dry-run]" >&2
    exit 1
    ;;
esac

prune_tokens() {
  local base listing stale id deleted=0
  splunk_api_env
  : "${SPLUNK_ADMIN_PASSWORD:?SPLUNK_ADMIN_PASSWORD must be set}"
  command -v jq >/dev/null 2>&1 || {
    echo "Error: jq required" >&2
    exit 1
  }
  base="https://${SPLUNK_HOST}:${SPLUNK_PORT}/services/mcp_token/tokens"

  listing="$(splunk_curl -ksf \
    --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
    -G --data-urlencode output_mode=json --data-urlencode scope=all \
    --data-urlencode "owner_username=${SPLUNK_MCP_USER}" "$base")" \
    || {
      echo "Error: could not list tokens at ${base} (Splunk MCP Server 2.1.0+ required)" >&2
      exit 1
    }

  # Active tokens older than the newest one (created_at is ISO 8601, so it sorts as text).
  stale="$(printf '%s' "$listing" | jq -r --arg user "$SPLUNK_MCP_USER" '
    [.tokens[] | select(.owner_username == $user and .status == "active")] as $t
    | ($t | map(.created_at) | max // "") as $newest
    | $t[] | select(.created_at < $newest) | .token_id')"

  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if [[ "$dry_run" == 1 ]]; then
      echo "would delete token ${id:0:8}…" >&2
    else
      splunk_curl -ksf -o /dev/null -X DELETE \
        --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
        "${base}/${id}" \
        || {
          echo "Error: could not delete token ${id:0:8}…" >&2
          exit 1
        }
    fi
    deleted=$((deleted + 1))
  done <<<"$stale"
  echo "$deleted"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # shellcheck source=scripts/with-splunk-env.sh
  source "${ROOT}/scripts/with-splunk-env.sh"
  with_splunk_env "$@"
  prune_tokens
fi
