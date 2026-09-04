#!/usr/bin/env bash
# Toggle SA-S4R North Korea attack Eventgen stanza (attack.nk.purchase.sample).
# Writes to local/eventgen.conf (gitignored) so default/eventgen.conf stays pristine.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVENTGEN_DEFAULT="${ROOT}/SA-S4R/default/eventgen.conf"
EVENTGEN_LOCAL="${ROOT}/SA-S4R/local/eventgen.conf"
STANZA="[attack.nk.purchase.sample]"

usage() {
  cat <<EOF
Usage: $(basename "$0") <enable|disable|status>

  enable   Set disabled = false on ${STANZA} (active threat workshop mode)
  disable  Set disabled = true (default infrastructure-failure mode)
  status   Print whether the attack stanza is enabled

Mode overrides are written to SA-S4R/local/eventgen.conf (not tracked in git).
After enable/disable via this script, restart Eventgen or Splunk:
  docker compose restart so1
EOF
}

read_disabled_from_file() {
  local file="$1"
  awk -v stanza="${STANZA}" '
    $0 == stanza { in_stanza=1; next }
    in_stanza && /^disabled = / { print $3; exit }
    in_stanza && /^\[/ { exit }
  ' "${file}"
}

current_disabled() {
  local disabled=""
  if [[ -f "${EVENTGEN_LOCAL}" ]]; then
    disabled="$(read_disabled_from_file "${EVENTGEN_LOCAL}")"
    [[ -n "${disabled}" ]] && { printf '%s' "${disabled}"; return 0; }
  fi
  if [[ -f "${EVENTGEN_DEFAULT}" ]]; then
    disabled="$(read_disabled_from_file "${EVENTGEN_DEFAULT}")"
    [[ -n "${disabled}" ]] && { printf '%s' "${disabled}"; return 0; }
  fi
  return 1
}

write_local_disabled() {
  local value="$1"
  if [[ ! -f "${EVENTGEN_DEFAULT}" ]]; then
    echo "error: missing ${EVENTGEN_DEFAULT}" >&2
    exit 1
  fi
  if ! grep -qF "${STANZA}" "${EVENTGEN_DEFAULT}"; then
    echo "error: stanza ${STANZA} not found in default eventgen.conf" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${EVENTGEN_LOCAL}")"
  if [[ -f "${EVENTGEN_LOCAL}" ]] && grep -qF "${STANZA}" "${EVENTGEN_LOCAL}"; then
    awk -v stanza="${STANZA}" -v disabled="${value}" '
      $0 == stanza { in_stanza=1 }
      in_stanza && /^disabled = / { print "disabled = " disabled; next }
      in_stanza && /^\[/ && $0 != stanza { in_stanza=0 }
      { print }
    ' "${EVENTGEN_LOCAL}" > "${EVENTGEN_LOCAL}.tmp"
  else
    cat > "${EVENTGEN_LOCAL}.tmp" <<EOF
# Workshop NK mode override (gitignored). Managed by SA-S4R MCP tools and make s4r-attack-nk-*.
${STANZA}
disabled = ${value}
EOF
  fi
  mv "${EVENTGEN_LOCAL}.tmp" "${EVENTGEN_LOCAL}"
}

is_enabled() {
  local disabled
  disabled="$(current_disabled)"
  [[ "${disabled}" == "false" || "${disabled}" == "0" ]]
}

cmd="${1:-}"
case "${cmd}" in
  enable)
    write_local_disabled false
    echo "NK attack stanza enabled (local/eventgen.conf: disabled = false)."
    echo "Restart Splunk/Eventgen: docker compose restart so1"
    ;;
  disable)
    write_local_disabled true
    echo "NK attack stanza disabled (local/eventgen.conf: disabled = true)."
    echo "Restart Splunk/Eventgen: docker compose restart so1"
    ;;
  status)
    disabled="$(current_disabled)" || {
      echo "NK attack stanza: not found"
      exit 1
    }
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
