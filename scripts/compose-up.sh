#!/usr/bin/env bash
# docker compose up -d with secrets (scripts/with-splunk-env.sh).
# Usage: ./scripts/compose-up.sh
# Env overrides: ENV_OUT, DC (same as Makefile).

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

if [[ -z "${SPLUNK_PASSWORD:-}" || -z "${SPLUNKBASE_USER:-}" || -z "${SPLUNKBASE_PASS:-}" || -z "${SPLUNK_MCP_PASSWORD:-}" ]]; then
  echo "Error: SPLUNK_PASSWORD, SPLUNKBASE_USER, SPLUNKBASE_PASS, and SPLUNK_MCP_PASSWORD must be non-empty." >&2
  echo "Set them in ${ENV_OUT} (see .env.example) or export them before make up." >&2
  exit 1
fi
if [[ -f "$ENV_OUT" ]]; then
  echo "Using $ENV_OUT for Compose."
fi
sh -c "$DC up -d"
./scripts/wait-splunk-init.sh
