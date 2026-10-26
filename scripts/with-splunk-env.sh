#!/usr/bin/env bash
# Load Splunk secrets for host scripts.
# Source this file, then call: with_splunk_env "$@"
#
# Sources $ENV_OUT (default .env) when that file exists.
# Otherwise uses variables already exported in the environment.
# SPLUNK_MCP_ENV_LOADED=1 skips the file (splunk-init already has the password
# in its environment and does not mount a host .env).
#
# Does not require every secret. Callers that need the full set check it.

# SPLUNK_PASSWORD and SPLUNK_MCP_PASSWORD were renamed. Fail with a hint when
# only the old name is set, instead of a vague "must be set" later.
check_renamed_splunk_vars() {
  local pair old new
  for pair in SPLUNK_PASSWORD:SPLUNK_ADMIN_PASSWORD SPLUNK_MCP_PASSWORD:SPLUNK_SPLUNKER_PASSWORD; do
    old="${pair%%:*}"
    new="${pair#*:}"
    if [[ -n "${!old:-}" && -z "${!new:-}" ]]; then
      echo "Error: ${old} was renamed to ${new}. Rename it in ${ENV_OUT} or your environment." >&2
      exit 1
    fi
  done
}

with_splunk_env() {
  ENV_OUT="${ENV_OUT:-.env}"

  if [[ "${SPLUNK_MCP_ENV_LOADED:-}" == "1" ]]; then
    return 0
  fi

  if [[ -f "$ENV_OUT" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_OUT" || {
      echo "Error: could not read $ENV_OUT (see .env.example)." >&2
      exit 1
    }
    set +a
    check_renamed_splunk_vars
    return 0
  fi

  if [[ -n "${SPLUNK_ADMIN_PASSWORD:-}" ]]; then
    check_renamed_splunk_vars
    return 0
  fi

  check_renamed_splunk_vars
  echo "Error: need $ENV_OUT or SPLUNK_ADMIN_PASSWORD in the environment." >&2
  echo "  cp .env.example .env and set SPLUNK_ADMIN_PASSWORD, SPLUNKBASE_USER, SPLUNKBASE_PASS, and SPLUNK_SPLUNKER_PASSWORD" >&2
  exit 1
}
