#!/usr/bin/env bash
# Write .env from environment variables (invoked under: op run --env-file=tpl.env -- ...).
# Uses the same secret resolution as `make up`, so tpl.env can use op:// references with
# spaces in vault/item/field paths (unlike `op inject`, which breaks unenclosed refs at spaces).
set -euo pipefail

OUT="${1:-.env}"
umask 077

: "${SPLUNK_PASSWORD:?SPLUNK_PASSWORD must be set (op run failed to resolve tpl.env)}"
: "${SPLUNKBASE_USER:?SPLUNKBASE_USER must be set}"
: "${SPLUNKBASE_PASS:?SPLUNKBASE_PASS must be set}"

{
  printf 'SPLUNK_IMAGE=%s\n' "${SPLUNK_IMAGE:-splunk/splunk:latest}"
  printf 'SPLUNK_PASSWORD=%s\n' "$SPLUNK_PASSWORD"
  printf 'SPLUNKBASE_USER=%s\n' "$SPLUNKBASE_USER"
  printf 'SPLUNKBASE_PASS=%s\n' "$SPLUNKBASE_PASS"
  printf 'TZ=%s\n' "${TZ:-Europe/Brussels}"
} >"$OUT"

echo "Wrote ${OUT}"
