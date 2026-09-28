#!/usr/bin/env bash
# Toggle SA-S4R North Korea attack Eventgen stanza (attack.nk.purchase.sample).
# Writes through Splunk config REST so local/eventgen.conf stays a Splunk-managed override.
# Secrets: scripts/with-splunk-env.sh (.env or op run --env-file=tpl.env).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-tpl.env}"
ENV_OUT="${ENV_OUT:-.env}"
OP="${OP:-op}"
STANZA_NAME="attack.nk.purchase.sample"
CURL_HTTP_CODE=""
CURL_BODY=""

usage() {
  cat <<EOF
Usage: $(basename "$0") <enable|disable|status>

  enable   POST disabled=false on [${STANZA_NAME}] and reload Eventgen
  disable  POST disabled=true (default infrastructure-failure mode) and reload Eventgen
  status   Print whether the attack stanza is enabled

Uses Splunk config REST (https://localhost:8089). Requires SPLUNK_PASSWORD
from ${ENV_OUT} or ${ENV_FILE}. Splunk stores the override in
SA-S4R/local/eventgen.conf; this script does not edit that file.
If the Eventgen reload fails, run: docker compose restart so1
EOF
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required" >&2
    exit 1
  fi
}

require_splunk_env() {
  SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
  SPLUNK_PORT="${SPLUNK_PORT:-8089}"
  SPLUNK_REST_USER="admin"
  : "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set}"
  SPLUNK_URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}"
  CONFIG_URL="${SPLUNK_URL}/servicesNS/nobody/SA-S4R/configs/conf-eventgen/${STANZA_NAME}"
  DISABLED_URL="${SPLUNK_URL}/servicesNS/nobody/SA-S4R/properties/eventgen/${STANZA_NAME}/disabled?output_mode=json"
}

# Prints the response body, then a final line with the HTTP status.
# Connection failures return 1. Callers must split the last line off the body
# (the request runs in a subshell under command substitution).
splunk_curl() {
  local tmp http_code
  tmp="$(mktemp)"
  if ! http_code="$(curl -sk -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
    -sS -o "${tmp}" -w "%{http_code}" "$@")"; then
    rm -f "${tmp}"
    echo "error: Splunk REST request failed" >&2
    return 1
  fi
  cat "${tmp}"
  printf '\n%s\n' "${http_code}"
  rm -f "${tmp}"
}

split_response() {
  local response="$1"
  CURL_HTTP_CODE="${response##*$'\n'}"
  CURL_BODY="${response%$'\n'*}"
}

parse_disabled() {
  local raw="$1" parsed
  if parsed="$(jq -er '
    if type == "object" then
      (.entry[0].content
        | if type == "object" then (.disabled // empty)
          elif type == "string" or type == "boolean" or type == "number" then .
          else empty end)
    elif type == "string" or type == "boolean" or type == "number" then
      .
    else
      empty
    end
    | tostring
  ' <<<"${raw}" 2>/dev/null)"; then
    printf '%s' "${parsed}"
    return 0
  fi
  printf '%s' "${raw}" | tr -d '[:space:]'
}

is_disabled_value() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    false|0|no|f) return 1 ;;
    true|1|yes|t) return 0 ;;
    *)
      echo "error: unexpected disabled value: ${1}" >&2
      return 2
      ;;
  esac
}

fetch_disabled() {
  local response
  response="$(splunk_curl "${DISABLED_URL}")" || exit 1
  split_response "${response}"
  case "${CURL_HTTP_CODE}" in
    2??) ;;
    404)
      echo "NK attack stanza: not found" >&2
      exit 1
      ;;
    *)
      echo "error: failed to read Eventgen stanza (HTTP ${CURL_HTTP_CODE})" >&2
      [[ -n "${CURL_BODY}" ]] && echo "${CURL_BODY}" >&2
      exit 1
      ;;
  esac
  parse_disabled "${CURL_BODY}"
}

reload_eventgen() {
  local action url code
  for action in disable enable; do
    url="${SPLUNK_URL}/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/${action}"
    code="$(curl -sk -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
      -sS -o /dev/null -w "%{http_code}" -X POST "${url}")" || code="000"
    case "${code}" in
      2??) ;;
      *)
        echo "error: Eventgen ${action} returned HTTP ${code}" >&2
        echo "Stanza was updated. Run: docker compose restart so1" >&2
        return 1
        ;;
    esac
  done
}

set_disabled() {
  local value="$1" response
  fetch_disabled >/dev/null
  response="$(splunk_curl -X POST "${CONFIG_URL}" \
    --data-urlencode "disabled=${value}" \
    -d "output_mode=json")" || exit 1
  split_response "${response}"
  case "${CURL_HTTP_CODE}" in
    2??)
      ;;
    *)
      echo "error: failed to update Eventgen stanza (HTTP ${CURL_HTTP_CODE})" >&2
      [[ -n "${CURL_BODY}" ]] && echo "${CURL_BODY}" >&2
      exit 1
      ;;
  esac
  reload_eventgen
}

cmd_status() {
  local disabled rc
  disabled="$(fetch_disabled)"
  if [[ -z "${disabled}" ]]; then
    echo "NK attack stanza: not found" >&2
    exit 1
  fi
  set +e
  is_disabled_value "${disabled}"
  rc=$?
  set -e
  case "${rc}" in
    0) echo "NK attack stanza: disabled" ;;
    1) echo "NK attack stanza: enabled" ;;
    *) exit 1 ;;
  esac
}

cmd_enable() {
  set_disabled false
  echo "NK attack stanza enabled (disabled=false) and Eventgen reloaded."
}

cmd_disable() {
  set_disabled true
  echo "NK attack stanza disabled (disabled=true) and Eventgen reloaded."
}

run_toggle() {
  require_jq
  require_splunk_env
  case "${1:-}" in
    enable) cmd_enable ;;
    disable) cmd_disable ;;
    status) cmd_status ;;
    -h|--help|help) usage ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  case "${cmd}" in
    enable|disable|status) ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 1
      ;;
  esac
  # shellcheck source=scripts/with-splunk-env.sh
  source "${ROOT}/scripts/with-splunk-env.sh"
  with_splunk_env "$@"
  run_toggle "${cmd}"
fi
