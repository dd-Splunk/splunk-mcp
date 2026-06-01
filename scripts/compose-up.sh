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

maybe_load_legacy_mcp_password() {
  # Migration helper: older flows wrote the MCP user password to disk.
  # If SPLUNK_MCP_PASSWORD is unset/empty, reuse that file so existing users
  # can boot without immediately editing tpl.env/.env.
  # Opt-in only: set ALLOW_LEGACY_SECRETS=1 to enable.
  if [[ "${ALLOW_LEGACY_SECRETS:-0}" == "1" && -z "${SPLUNK_MCP_PASSWORD:-}" && -r ".secrets/splunker-password" ]]; then
    SPLUNK_MCP_PASSWORD="$(tr -d '\r\n' < .secrets/splunker-password)"
    export SPLUNK_MCP_PASSWORD
  fi
}

if [[ -f "$ENV_OUT" ]]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_OUT" || {
    echo "Error: could not read $ENV_OUT (see .env.example)."
    exit 1
  }
  set +a
  maybe_load_legacy_mcp_password
  if [[ -z "${SPLUNK_PASSWORD:-}" || -z "${SPLUNKBASE_USER:-}" || -z "${SPLUNKBASE_PASS:-}" || -z "${SPLUNK_MCP_PASSWORD:-}" ]]; then
    echo "Error: $ENV_OUT must set SPLUNK_PASSWORD, SPLUNKBASE_USER, SPLUNKBASE_PASS, and SPLUNK_MCP_PASSWORD."
    exit 1
  fi
  echo "Using $ENV_OUT for Compose."
  sh -c "$DC up -d --build"
  ./scripts/wait-splunk-init.sh
  exit 0
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
exec "$OP" run --env-file="$ENV_FILE" -- sh -c "
  if [ \"\${ALLOW_LEGACY_SECRETS:-0}\" = \"1\" ] && [ -z \"\${SPLUNK_MCP_PASSWORD:-}\" ] && [ -r .secrets/splunker-password ]; then
    export SPLUNK_MCP_PASSWORD=\"\$(tr -d '\r\n' < .secrets/splunker-password)\"
  fi
  if [ -z \"\${SPLUNK_PASSWORD:-}\" ] || [ -z \"\${SPLUNKBASE_USER:-}\" ] || [ -z \"\${SPLUNKBASE_PASS:-}\" ] || [ -z \"\${SPLUNK_MCP_PASSWORD:-}\" ]; then
    echo \"Error: SPLUNK_PASSWORD, SPLUNKBASE_USER, SPLUNKBASE_PASS, and SPLUNK_MCP_PASSWORD must be non-empty after op run.\" >&2
    echo \"Fix op:// paths in ${ENV_FILE}. Test with: op read \\\"op://...\\\"\" >&2
    exit 1
  fi
  ${DC} up -d --build
  ./scripts/wait-splunk-init.sh
"
