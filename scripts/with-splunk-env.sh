#!/usr/bin/env bash
# Load Splunk secrets for host scripts (Path B .env, or Path A op run + tpl.env).
# Source this file, then call: with_splunk_env "$@"
#
# Path B: source $ENV_OUT (default .env) into the current process and return.
# Path A: re-exec this script under `op run --env-file=$ENV_FILE` (default tpl.env).
# The re-exec sets SPLUNK_MCP_ENV_LOADED=1 so the second pass does not loop.
#
# Does not validate which variables are set. Callers check SPLUNK_PASSWORD and friends.

with_splunk_env() {
  ENV_FILE="${ENV_FILE:-tpl.env}"
  ENV_OUT="${ENV_OUT:-.env}"
  OP="${OP:-op}"

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

  if [[ -f "$ENV_FILE" ]]; then
    command -v "$OP" >/dev/null 2>&1 || {
      echo "Error: 1Password CLI (op) not available; create $ENV_OUT from .env.example (Path B) or install/sign in to op." >&2
      exit 1
    }
    exec "$OP" run --env-file="$ENV_FILE" -- env SPLUNK_MCP_ENV_LOADED=1 "$0" "$@"
  fi

  echo "Error: need $ENV_OUT or $ENV_FILE for Splunk secrets." >&2
  echo "  Path B: cp .env.example .env and set values" >&2
  echo "  Path A: cp tpl.env.example tpl.env and run: op signin" >&2
  exit 1
}
