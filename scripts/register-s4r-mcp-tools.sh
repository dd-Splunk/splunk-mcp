#!/usr/bin/env bash
# Register SA-S4R workshop MCP tools with Splunk MCP Server (idempotent batch replace).
# splunk-init runs this at the end of setup-splunk.sh. After a JSON edit, make up
# starts the exited init container again. Host-only run still loads secrets via
# scripts/with-splunk-env.sh (.env or the process environment).
#
# After registering, the tools are limited to role S4R_TOOL_ROLE (default s4r_user) with Tool Role
# Policies. Set S4R_TOOL_ROLE= (empty) to leave them open to every mcp_tool_execute user.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_OUT="${ENV_OUT:-.env}"
TOOLS_JSON="${ROOT}/SA-S4R/default/s4r_mcp_tools.json"

# shellcheck source=scripts/splunk-api-env.sh
source "${ROOT}/scripts/splunk-api-env.sh"

# A fresh install answers /services/mcp_tools with 503 until the KV Store is ready
# (often longer than the batch-replace retries below), so wait for it first.
wait_for_kvstore() {
  local waited=0 max_wait=300 status=""
  while [ "${waited}" -lt "${max_wait}" ]; do
    status="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
      "${SPLUNK_URL}/services/kvstore/status?output_mode=json" 2>/dev/null \
      | jq -r '.entry[0].content.current.status // empty' 2>/dev/null || true)"
    case "${status}" in
      ready)
        [ "${waited}" -gt 0 ] && echo "   KV Store ready after ${waited}s."
        return 0
        ;;
      failed)
        echo "error: KV Store status is failed; see docs/poc/TROUBLESHOOTING.md (KVStore status failed)" >&2
        exit 1
        ;;
    esac
    [ "${waited}" -eq 0 ] && echo "   Waiting for KV Store (status: ${status:-unknown}, up to ${max_wait}s)..."
    sleep 5
    waited=$((waited + 5))
  done
  echo "error: KV Store not ready after ${max_wait}s (last status: ${status:-unknown}); re-run make up" >&2
  exit 1
}

# Limit the SA-S4R_* tools to one role (Tool Role Policies, POST /services/mcp_tool_roles). The role
# must exist and the MCP user must hold it: otherwise the tools would vanish for the user the
# clients run as (an older SA-S4R in an existing so1-etc volume has no s4r_user role). Not fatal;
# the tools then stay open, as before. Re-running replaces each policy, so it is idempotent.
restrict_s4r_mcp_tools() {
  local role="${S4R_TOOL_ROLE-s4r_user}" response code body holders tool_name failed=0 total=0
  if [[ -z "${role}" ]]; then
    echo "   S4R_TOOL_ROLE is empty: SA-S4R tools stay open to every mcp_tool_execute user"
    return 0
  fi

  response="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
    "${SPLUNK_URL}/services/authorization/roles/${role}?output_mode=json" -w "\n%{http_code}" || true)"
  code="${response##*$'\n'}"
  if [[ ! "${code}" =~ ^2 ]]; then
    echo "⚠️  Role ${role} not found (SA-S4R older than 1.1.1?). SA-S4R tools stay open; make clean-y && make up installs the current app." >&2
    return 0
  fi

  response="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
    "${SPLUNK_URL}/services/authentication/users/${SPLUNK_MCP_USER}?output_mode=json" -w "\n%{http_code}" || true)"
  code="${response##*$'\n'}"
  body="${response%$'\n'*}"
  holders="$(jq -r --arg r "${role}" '.entry[0].content.roles // [] | index($r) // empty' <<<"${body}" 2>/dev/null || true)"
  if [[ ! "${code}" =~ ^2 || -z "${holders}" ]]; then
    echo "⚠️  ${SPLUNK_MCP_USER} does not hold role ${role}; not restricting SA-S4R tools (they would disappear for it)." >&2
    return 0
  fi

  while IFS= read -r tool_name; do
    [[ -n "${tool_name}" ]] || continue
    total=$((total + 1))
    response="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
      -X POST "${SPLUNK_URL}/services/mcp_tool_roles" \
      -H "Content-Type: application/json" \
      -d "{\"tool_id\": \"SA-S4R:SA-S4R_${tool_name}\", \"roles\": [\"${role}\"]}" \
      -w "\n%{http_code}" || true)"
    code="${response##*$'\n'}"
    if [[ ! "${code}" =~ ^2 ]]; then
      echo "⚠️  Could not restrict SA-S4R_${tool_name} to ${role} (HTTP ${code}); it stays open" >&2
      failed=$((failed + 1))
    fi
  done < <(jq -r '.tools[].name' "${TOOLS_JSON}")

  if [[ "${failed}" -eq 0 ]]; then
    echo "✅ Restricted ${total} SA-S4R MCP tools to role ${role}"
  fi
}

register_s4r_mcp_tools() {
  splunk_api_env
  : "${SPLUNK_ADMIN_PASSWORD:?SPLUNK_ADMIN_PASSWORD must be set}"
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
  wait_for_kvstore

  attempt=0
  max_attempts=6
  http_code=""
  body=""
  while [ "${attempt}" -lt "${max_attempts}" ]; do
    response="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
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

  enable_body="$(mktemp "${TMPDIR:-/tmp}/s4r-mcp-enable.XXXXXX")"
  rm_enable_body() { rm -f "${enable_body:-}"; }
  trap rm_enable_body EXIT

  enable_failed=0
  while IFS= read -r tool_name; do
    [[ -n "${tool_name}" ]] || continue
    mcp_name="SA-S4R_${tool_name}"
    tool_id="SA-S4R:${mcp_name}"
    enable_response="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
      -X POST "${SPLUNK_URL}/services/mcp_tools" \
      -H "Content-Type: application/json" \
      -d "{\"tool_id\": \"${tool_id}\", \"tool_name\": \"${mcp_name}\", \"enabled\": true, \"override\": true}" \
      -w "\n%{http_code}" -o "${enable_body}")"
    enable_code="${enable_response##*$'\n'}"
    if [[ "${enable_code}" =~ ^2 ]]; then
      echo "✅ Enabled ${tool_id}"
    else
      echo "⚠️  Failed to enable ${tool_id} (HTTP ${enable_code})" >&2
      [[ -s "${enable_body}" ]] && cat "${enable_body}" >&2
      enable_failed=$((enable_failed + 1))
    fi
  done < <(jq -r '.tools[].name' "${TOOLS_JSON}")
  if [[ "${enable_failed}" -gt 0 ]]; then
    echo "error: failed to enable ${enable_failed} SA-S4R MCP tool(s); clients will not see SA-S4R_* until this succeeds" >&2
    exit 1
  fi

  # Pick up new/updated savedsearches.conf stanzas without a full restart.
  reload_code="$(splunk_curl -sSk --connect-timeout "${SPLUNK_CURL_CONNECT_TIMEOUT}" --max-time "${SPLUNK_CURL_MAX_TIME}" \
    -o /dev/null -w "%{http_code}" \
    -X POST "${SPLUNK_URL}/servicesNS/nobody/SA-S4R/configs/conf-savedsearches/_reload" \
    -d output_mode=json)"
  if [[ "${reload_code}" =~ ^2 ]]; then
    echo "✅ Reloaded SA-S4R saved searches (HTTP ${reload_code})"
  else
    echo "error: saved-search reload returned HTTP ${reload_code}; MCP saved-search tools may 404 until this succeeds (make restart)" >&2
    exit 1
  fi

  restrict_s4r_mcp_tools
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # shellcheck source=scripts/with-splunk-env.sh
  source "${ROOT}/scripts/with-splunk-env.sh"
  with_splunk_env "$@"
  register_s4r_mcp_tools
fi
