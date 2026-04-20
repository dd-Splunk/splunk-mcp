#!/usr/bin/env bash
# Smoke-test mcp-remote against local Splunk MCP with a correctly quoted Authorization header.
# Usage: ./scripts/verify-mcp-remote.sh [token-file]
# Exit 0 if logs show a successful proxy within ~15s.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TOKEN_FILE="${1:-.secrets/splunk-token}"
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"
URL="https://${SPLUNK_HOST}:${SPLUNK_PORT}/services/mcp"

if [[ ! -f "$TOKEN_FILE" ]]; then
  echo "Token file not found: $TOKEN_FILE"
  exit 1
fi

TOKEN=$(tr -d '\r\n' < "$TOKEN_FILE")
if [[ -z "$TOKEN" ]]; then
  echo "Token file is empty: $TOKEN_FILE"
  exit 1
fi

export NODE_TLS_REJECT_UNAUTHORIZED="${NODE_TLS_REJECT_UNAUTHORIZED:-0}"

TMP=$(mktemp)
# shellcheck disable=SC2329
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

# Log only to $TMP so the Bearer token is not printed to the terminal.
# shellcheck disable=SC2064
( npx -y mcp-remote "$URL" --header "Authorization: Bearer ${TOKEN}" >"$TMP" 2>&1 & echo $! >"${TMP}.pid" )

PID=$(cat "${TMP}.pid")
for _ in $(seq 1 30); do
  if grep -q "Proxy established successfully" "$TMP" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    echo "OK: mcp-remote connected to Splunk (Streamable HTTP)."
    exit 0
  fi
  if grep -qE "Fatal error:|Connection error:" "$TMP" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    wait "$PID" 2>/dev/null || true
    echo "FAILED — see output above."
    exit 1
  fi
  sleep 0.5
done

kill "$PID" 2>/dev/null || true
wait "$PID" 2>/dev/null || true
echo "FAILED: timed out waiting for proxy (check Splunk on ${URL})."
exit 1
