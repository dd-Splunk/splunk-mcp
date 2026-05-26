#!/usr/bin/env bash
# docker compose up -d with secrets (Path B .env or Path A op run + tpl.env).
# Usage: ./scripts/compose-up.sh
# Env overrides: ENV_FILE, ENV_OUT, ENV_EXAMPLE, OP, DC (same as Makefile).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_FILE="${ENV_FILE:-tpl.env}"
ENV_OUT="${ENV_OUT:-.env}"
ENV_EXAMPLE="${ENV_EXAMPLE:-tpl.env.example}"
OP="${OP:-op}"
DC="${DC:-docker compose}"

if [[ -f "$ENV_OUT" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_OUT" || {
    echo "Error: could not read $ENV_OUT (see .env.example)."
    exit 1
  }
  set +a
  if [[ -z "${SPLUNK_PASSWORD:-}" || -z "${SPLUNKBASE_USER:-}" || -z "${SPLUNKBASE_PASS:-}" ]]; then
    echo "Error: $ENV_OUT must set SPLUNK_PASSWORD, SPLUNKBASE_USER, and SPLUNKBASE_PASS."
    exit 1
  fi
  echo "Using $ENV_OUT for Compose."
  exec sh -c "$DC up -d"
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_OUT not found and $ENV_FILE missing."
  echo "  cp $ENV_EXAMPLE $ENV_FILE"
  exit 1
fi

command -v "$OP" >/dev/null 2>&1 || {
  echo "Error: 1Password CLI (op) not available."
  echo "Create $ENV_OUT from .env.example (Path B) or install/sign in to op."
  exit 1
}

# Vars must expand inside op run's child shell, not here.
if ! "$OP" run --env-file="$ENV_FILE" -- sh -c \
  "[ -n \"\${SPLUNK_PASSWORD:-}\" ] && [ -n \"\${SPLUNKBASE_USER:-}\" ] && [ -n \"\${SPLUNKBASE_PASS:-}\" ]"; then
  echo "Error: SPLUNK_PASSWORD, SPLUNKBASE_USER, and SPLUNKBASE_PASS must be non-empty after op run."
  echo "Fix op:// paths in $ENV_FILE. Test with: op read \"op://...\""
  exit 1
fi

exec "$OP" run --env-file="$ENV_FILE" -- sh -c "$DC up -d"
