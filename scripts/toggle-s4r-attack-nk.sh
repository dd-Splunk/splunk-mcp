#!/usr/bin/env bash
# Toggle SA-S4R North Korea attack Eventgen stanza (attack.nk.purchase.sample).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENTGEN_CONF="${ROOT}/SA-S4R/default/eventgen.conf"
STANZA="[attack.nk.purchase.sample]"

usage() {
  cat <<EOF
Usage: $(basename "$0") <enable|disable|status>

  enable   Set disabled = false on ${STANZA} (active threat workshop mode)
  disable  Set disabled = true (default infrastructure-failure mode)
  status   Print whether the attack stanza is enabled

After enable/disable, restart Eventgen or Splunk so the modinput reloads:
  docker compose restart so1
EOF
}

set_disabled() {
  local value="$1"
  if [[ ! -f "${EVENTGEN_CONF}" ]]; then
    echo "error: missing ${EVENTGEN_CONF}" >&2
    exit 1
  fi
  if ! grep -qF "${STANZA}" "${EVENTGEN_CONF}"; then
    echo "error: stanza ${STANZA} not found in eventgen.conf" >&2
    exit 1
  fi
  awk -v stanza="${STANZA}" -v disabled="${value}" '
    $0 == stanza { in_stanza=1 }
    in_stanza && /^disabled = / { print "disabled = " disabled; next }
    in_stanza && /^\[/ && $0 != stanza { in_stanza=0 }
    { print }
  ' "${EVENTGEN_CONF}" > "${EVENTGEN_CONF}.tmp"
  mv "${EVENTGEN_CONF}.tmp" "${EVENTGEN_CONF}"
}

current_disabled() {
  awk -v stanza="${STANZA}" '
    $0 == stanza { in_stanza=1; next }
    in_stanza && /^disabled = / { print $3; exit }
    in_stanza && /^\[/ { exit }
  ' "${EVENTGEN_CONF}"
}

is_enabled() {
  local disabled
  disabled="$(current_disabled)"
  [[ "${disabled}" == "false" || "${disabled}" == "0" ]]
}

cmd="${1:-}"
case "${cmd}" in
  enable)
    set_disabled false
    echo "NK attack stanza enabled (disabled = false)."
    echo "Restart Splunk/Eventgen: docker compose restart so1"
    ;;
  disable)
    set_disabled true
    echo "NK attack stanza disabled (disabled = true)."
    echo "Restart Splunk/Eventgen: docker compose restart so1"
    ;;
  status)
    disabled="$(current_disabled)"
    if [[ -z "${disabled}" ]]; then
      echo "NK attack stanza: not found"
      exit 1
    fi
    if is_enabled; then
      echo "NK attack stanza: enabled"
    else
      echo "NK attack stanza: disabled"
    fi
    ;;
  -h | --help | help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
