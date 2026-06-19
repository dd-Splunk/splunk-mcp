#!/usr/bin/env bash
# Validate Buttercup Operations Dashboard panel SPL via Splunk MCP (splunk_run_query).
# Requires Splunk up and secrets (.env or tpl.env + op run).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EARLIEST="${S4R_DASHBOARD_EARLIEST:--1h}"
LATEST="${S4R_DASHBOARD_LATEST:-now}"
MAX_RESULTS="${S4R_DASHBOARD_MAX_RESULTS:-5}"
ENDPOINT="${SPLUNK_MCP_ENDPOINT:-https://localhost:8089/services/mcp}"

declare -a PANEL_NAMES=(
  "IT Ops"
  "DevOps platforms"
  "DevOps browser failures"
  "Business lost revenue"
  "Security geo"
)

declare -a PANEL_QUERIES=(
  'index=main sourcetype=access_combined | timechart count by status limit=10'
  'index=main sourcetype=access_combined | eval platform=if(isnull(platform),"Other",platform) | top limit=20 platform showperc=f'
  'index=main sourcetype=access_combined status>=400 | timechart count by useragent limit=5 useother=f'
  'index=main sourcetype=access_combined action=purchase status>=400 | lookup product_codes.csv product_id | timechart sum(product_price)'
  'index=main sourcetype=access_combined | iplocation clientip | geostats count by City'
)

command -v jq >/dev/null 2>&1 || { echo "jq required (brew install jq)" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "curl required" >&2; exit 1; }

token="$(./scripts/mint-mcp-token.sh)" || {
  echo "Could not mint MCP token. Is Splunk up?" >&2
  exit 1
}

pass=0
fail=0

for i in "${!PANEL_NAMES[@]}"; do
  name="${PANEL_NAMES[$i]}"
  query="${PANEL_QUERIES[$i]}"
  payload="$(jq -n \
    --arg query "$query" \
    --arg earliest "$EARLIEST" \
    --arg latest "$LATEST" \
    --argjson max_results "$MAX_RESULTS" \
    '{
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "splunk_run_query",
        arguments: {
          query: $query,
          earliest: $earliest,
          latest: $latest,
          max_results: $max_results
        }
      }
    }')"

  echo "==> $name"
  tmp="$(mktemp)"
  # shellcheck disable=SC2329
  cleanup() { rm -f "$tmp"; }
  trap cleanup RETURN

  if curl -kfsS -X POST "$ENDPOINT" \
    -H "Authorization: Bearer ${token}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    --data "$payload" >"$tmp" 2>&1 \
    && jq -e '.result.content // .result' "$tmp" >/dev/null 2>&1; then
    pass=$((pass + 1))
    echo "OK"
  else
    fail=$((fail + 1))
    echo "FAILED" >&2
    cat "$tmp" >&2 || true
  fi
  trap - RETURN
done

echo "Validated $pass/${#PANEL_NAMES[@]} panel queries; $fail failure(s)."
[[ "$fail" -eq 0 ]]
