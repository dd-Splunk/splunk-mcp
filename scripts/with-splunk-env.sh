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
    return 0
  fi

  if [[ -n "${SPLUNK_PASSWORD:-}" ]]; then
    return 0
  fi

  echo "Error: need $ENV_OUT or SPLUNK_PASSWORD in the environment." >&2
  echo "  cp .env.example .env and set SPLUNK_PASSWORD, SPLUNKBASE_USER, SPLUNKBASE_PASS, and SPLUNK_MCP_PASSWORD" >&2
  exit 1
}
