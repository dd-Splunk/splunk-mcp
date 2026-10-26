#!/usr/bin/env bash
# Print resolved compose.yml for manual checks.
# Usage: ./scripts/compose-config.sh
# Env overrides: ENV_OUT, DC, CONFIG_ENV (same as Makefile).
#
# Password and Splunkbase values are replaced with <set>. The Splunk image
# reads those from the environment, so Compose file secrets would not remove
# them from the running container.

redact_compose_secrets() {
  local line indent key val
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^([[:space:]]*)(SPLUNK_PASSWORD|SPLUNK_ADMIN_PASSWORD|SPLUNKBASE_USERNAME|SPLUNKBASE_PASSWORD|SPLUNK_SPLUNKER_PASSWORD):[[:space:]]*(.*)$ ]]; then
      indent="${BASH_REMATCH[1]}"
      key="${BASH_REMATCH[2]}"
      val="${BASH_REMATCH[3]}"
      val="${val#\"}"
      val="${val%\"}"
      val="${val#\'}"
      val="${val%\'}"
      if [[ -z "$val" || "$val" == "null" || "$val" == "~" ]]; then
        printf '%s%s: ""\n' "$indent" "$key"
      else
        printf '%s%s: <set>\n' "$indent" "$key"
      fi
    else
      printf '%s\n' "$line"
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail

  ROOT="$(cd "$(dirname "$0")/.." && pwd)"
  cd "$ROOT"

  ENV_OUT="${ENV_OUT:-.env}"
  DC="${DC:-docker compose}"

  # shellcheck source=scripts/with-splunk-env.sh
  source "${ROOT}/scripts/with-splunk-env.sh"
  # shellcheck source=scripts/load-config-env.sh
  source "${ROOT}/scripts/load-config-env.sh"
  with_splunk_env "$@"
  load_config_env

  if [[ -z "${SPLUNK_ADMIN_PASSWORD:-}" || -z "${SPLUNKBASE_USER:-}" || -z "${SPLUNKBASE_PASS:-}" || -z "${SPLUNK_SPLUNKER_PASSWORD:-}" ]]; then
    echo "Error: SPLUNK_ADMIN_PASSWORD, SPLUNKBASE_USER, SPLUNKBASE_PASS, and SPLUNK_SPLUNKER_PASSWORD must be non-empty." >&2
    echo "Set them in ${ENV_OUT} (see .env.example) or export them." >&2
    exit 1
  fi

  echo "Resolved compose.yml. SPLUNK_PASSWORD, SPLUNK_ADMIN_PASSWORD, SPLUNKBASE_USERNAME, SPLUNKBASE_PASSWORD, and SPLUNK_SPLUNKER_PASSWORD are shown as <set>." >&2
  sh -c "$DC config" | redact_compose_secrets
fi
