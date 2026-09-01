#!/usr/bin/env bash
# Register SA-S4R workshop MCP tools with Splunk MCP Server (idempotent batch replace).
# Secrets: .env (Path B) or op run --env-file=tpl.env (Path A) — same as make up / mint-mcp-token.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-tpl.env}"
ENV_OUT="${ENV_OUT:-.env}"
OP="${OP:-op}"
TOOLS_JSON="${ROOT}/SA-S4R/default/s4r_mcp_tools.json"

register_s4r_mcp_tools() {
  SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
  SPLUNK_PORT="${SPLUNK_PORT:-8089}"
  SPLUNK_REST_USER="${SPLUNK_REST_USER:-admin}"
  : "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set}"
  SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"

  if [[ ! -f "${TOOLS_JSON}" ]]; then
    echo "error: missing ${TOOLS_JSON}" >&2
    exit 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to register S4R MCP tools" >&2
    exit 1
  fi

  if ! jq empty "${TOOLS_JSON}" >/dev/null 2>&1; then
    echo "error: invalid JSON in ${TOOLS_JSON}" >&2
    exit 1
  fi

  echo "🔧 Registering SA-S4R MCP tools (batch replace)..."

  attempt=0
  max_attempts=6
  http_code=""
  body=""
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    response="$(curl -sk -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
      -X POST "${SPLUNK_URL}/services/mcp_tools" \
      -H "Content-Type: application/json" \
      --data-binary "@${TOOLS_JSON}" \
      -w "\n%{http_code}")"
    http_code="${response##*$'\n'}"
    body="${response%$'\n'*}"
    if [[ "${http_code}" =~ ^2 ]]; then
      break
    fi
    if [[ "${body}" == *"KV Store is initializing"* ]]; then
      attempt=$((attempt + 1))
      echo "   KV Store initializing; retry ${attempt}/${max_attempts}..." >&2
      sleep 5
      continue
    fi
    break
  done

  case "${http_code}" in
    2??)
      echo "✅ SA-S4R MCP tools registered (HTTP ${http_code})"
      if [[ -n "${body}" ]]; then
        registered="$(jq -r '.registered_count // empty' <<<"${body}" 2>/dev/null || true)"
        deleted="$(jq -r '.deleted_count // empty' <<<"${body}" 2>/dev/null || true)"
        [[ -n "${registered}" ]] && echo "   registered_count=${registered}"
        [[ -n "${deleted}" ]] && echo "   deleted_count=${deleted}"
      fi
      ;;
    *)
      echo "⚠️  Failed to register SA-S4R MCP tools (HTTP ${http_code})" >&2
      [[ -n "${body}" ]] && echo "${body}" >&2
      exit 1
      ;;
  esac

  while IFS= read -r tool_name; do
    [[ -n "${tool_name}" ]] || continue
    mcp_name="SA-S4R_${tool_name}"
    tool_id="SA-S4R:${mcp_name}"
    enable_response="$(curl -sk -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
      -X POST "${SPLUNK_URL}/services/mcp_tools" \
      -H "Content-Type: application/json" \
      -d "{\"tool_id\": \"${tool_id}\", \"tool_name\": \"${mcp_name}\", \"enabled\": true, \"override\": true}" \
      -w "\n%{http_code}" -o /tmp/s4r-mcp-enable.json)"
    enable_code="${enable_response##*$'\n'}"
    if [[ "${enable_code}" =~ ^2 ]]; then
      echo "✅ Enabled ${tool_id}"
    else
      echo "⚠️  Failed to enable ${tool_id} (HTTP ${enable_code})" >&2
      [[ -f /tmp/s4r-mcp-enable.json ]] && cat /tmp/s4r-mcp-enable.json >&2
    fi
  done < <(jq -r '.tools[].name' "${TOOLS_JSON}")

  # Pick up new/updated savedsearches.conf stanzas without a full restart.
  reload_code="$(curl -sk -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
    -o /dev/null -w "%{http_code}" \
    -X POST "${SPLUNK_URL}/servicesNS/nobody/SA-S4R/configs/conf-savedsearches/_reload" \
    -d output_mode=json)"
  if [[ "${reload_code}" =~ ^2 ]]; then
    echo "✅ Reloaded SA-S4R saved searches (HTTP ${reload_code})"
  else
    echo "⚠️  Saved-search reload returned HTTP ${reload_code} (run make restart if MCP saved-search tools 404)" >&2
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "${REGISTER_S4R_MCP_INTERNAL:-}" == "1" ]]; then
    register_s4r_mcp_tools
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
    register_s4r_mcp_tools
  elif [[ -f "$ENV_FILE" ]]; then
    command -v "$OP" >/dev/null 2>&1 || {
      echo "Error: 1Password CLI (op) not available; create $ENV_OUT from .env.example" >&2
      exit 1
    }
    exec "$OP" run --env-file="$ENV_FILE" -- env REGISTER_S4R_MCP_INTERNAL=1 "$0"
  else
    echo "Error: need $ENV_OUT or $ENV_FILE for SPLUNK_PASSWORD." >&2
    echo "  Path B: cp .env.example .env and set SPLUNK_PASSWORD" >&2
    echo "  Path A: cp tpl.env.example tpl.env and run: op signin" >&2
    exit 1
  fi
fi
