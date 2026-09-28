#!/usr/bin/env bash
# Source this file, then call: load_config_env
#
# Reads CONFIG_ENV (default config.env) and exports only SPLUNK_IMAGE and TZ.
# Other keys in that file are ignored. Call after secrets are loaded so these
# two values win over leftover copies in tpl.env or .env.

load_config_env() {
  local line key val
  CONFIG_ENV="${CONFIG_ENV:-config.env}"
  [[ -f "$CONFIG_ENV" ]] || {
    echo "Error: missing $CONFIG_ENV (SPLUNK_IMAGE and TZ)." >&2
    exit 1
  }
  SPLUNK_IMAGE=""
  TZ=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    key="${line%%=*}"
    val="${line#*=}"
    case "$key" in
      SPLUNK_IMAGE) SPLUNK_IMAGE="$val" ;;
      TZ) TZ="$val" ;;
    esac
  done <"$CONFIG_ENV"
  export SPLUNK_IMAGE TZ
  : "${SPLUNK_IMAGE:?SPLUNK_IMAGE must be set in $CONFIG_ENV}"
  : "${TZ:?TZ must be set in $CONFIG_ENV}"
}
