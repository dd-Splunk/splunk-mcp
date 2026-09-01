#!/usr/bin/env bash
# stdio launcher for Splunk MCP via mcp-remote (Goose and other clients).
# Sets NODE_TLS_REJECT_UNAUTHORIZED for the local PoC self-signed Splunk cert.
set -euo pipefail

npx_cmd="${MCP_NPX_COMMAND:-}"
if [[ -z "$npx_cmd" ]]; then
  for candidate in /opt/homebrew/bin/npx /usr/local/bin/npx "$(command -v npx 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      npx_cmd="$candidate"
      break
    fi
  done
fi
[[ -n "$npx_cmd" ]] || {
  echo "mcp-remote-splunk.sh: npx not found (set MCP_NPX_COMMAND)" >&2
  exit 1
}

tls_insecure="${SPLUNK_MCP_TLS_INSECURE:-1}"
if [[ "$tls_insecure" == "1" || "$tls_insecure" == "true" || "$tls_insecure" == "yes" ]]; then
  export NODE_TLS_REJECT_UNAUTHORIZED=0
fi

exec "$npx_cmd" -y mcp-remote "$@"
