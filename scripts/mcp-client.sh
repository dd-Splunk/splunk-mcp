#!/usr/bin/env bash
# Update or verify Splunk MCP client configs (Claude, Cursor, Goose).
#
# Usage:
#   ./scripts/mcp-client.sh update <claude|cursor|goose> [token-file]
#   ./scripts/mcp-client.sh verify <claude|cursor|goose|all> [token-file]
#
# Env: SPLUNK_HOST, SPLUNK_PORT, CURSOR_MCP_JSON (cursor output path)

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

readonly VALID_CLIENTS="claude cursor goose"
TOKEN_FILE="${TOKEN_FILE:-.secrets/splunk-token}"
SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
SPLUNK_PORT="${SPLUNK_PORT:-8089}"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") update <claude|cursor|goose> [token-file]
  $(basename "$0") verify <claude|cursor|goose|all> [token-file]

Default token file: ${TOKEN_FILE}
EOF
  exit "${1:-0}"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

valid_client() {
  local c="$1"
  case " $VALID_CLIENTS " in
    *" $c "*) return 0 ;;
    *) return 1 ;;
  esac
}

read_token() {
  local file="$1"
  [[ -f "$file" ]] || die "token file not found: $file (run: make up)"
  [[ -r "$file" ]] || die "token file not readable: $file"
  local t
  t=$(tr -d '\r\n' <"$file")
  [[ -n "$t" ]] || die "token file is empty: $file"
  printf '%s' "$t"
}

splunk_mcp_url() {
  printf 'https://%s:%s/services/mcp' "$SPLUNK_HOST" "$SPLUNK_PORT"
}

# JSON mcpServers block (Claude + Cursor)
mcp_servers_block_jq() {
  local url token
  url="$1"
  token="$2"
  jq -n \
    --arg url "$url" \
    --arg token "$token" \
    '{
      command: "npx",
      args: ["-y", "mcp-remote", $url, "--header", ("Authorization: Bearer " + $token)],
      env: {NODE_TLS_REJECT_UNAUTHORIZED: "0"}
    }'
}

merge_json_mcp_server() {
  local out_path="$1"
  local block="$2"
  mkdir -p "$(dirname "$out_path")"
  if [[ -f "$out_path" ]] && jq empty "$out_path" 2>/dev/null; then
    jq --argjson block "$block" \
      '.mcpServers = (.mcpServers // {}) | .mcpServers["splunk-mcp-server"] = $block' \
      "$out_path" >"${out_path}.tmp"
    mv "${out_path}.tmp" "$out_path"
  else
    jq -n --argjson block "$block" '{mcpServers: {"splunk-mcp-server": $block}}' >"$out_path"
  fi
}

merge_json_mcp_server_python() {
  local out_path="$1" url="$2" token="$3"
  python3 - "$out_path" "$url" "$token" <<'PY'
import json
import os
import sys

out_path, url, token = sys.argv[1], sys.argv[2], sys.argv[3]
block = {
    "command": "npx",
    "args": ["-y", "mcp-remote", url, "--header", f"Authorization: Bearer {token}"],
    "env": {"NODE_TLS_REJECT_UNAUTHORIZED": "0"},
}
data = {}
try:
    with open(out_path, encoding="utf-8") as f:
        data = json.load(f)
except FileNotFoundError:
    pass
except json.JSONDecodeError:
    pass
data.setdefault("mcpServers", {})
data["mcpServers"]["splunk-mcp-server"] = block
tmp = out_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, out_path)
PY
}

update_claude() {
  local token="$1"
  command -v jq >/dev/null 2>&1 || die "jq required for Claude config (brew install jq)"
  local url dir file block current
  url=$(splunk_mcp_url)
  dir="${HOME}/Library/Application Support/Claude"
  file="${dir}/claude_desktop_config.json"
  mkdir -p "$dir"
  block=$(mcp_servers_block_jq "$url" "$token")
  if [[ -f "$file" ]] && current=$(cat "$file") && echo "$current" | jq empty 2>/dev/null; then
    if ! updated=$(echo "$current" | jq \
      --argjson splunk_mcp "$block" \
      '.mcpServers |= (. // {}) | .mcpServers["splunk-mcp-server"] = $splunk_mcp'); then
      die "failed to merge Claude Desktop JSON"
    fi
    echo "$updated" | jq '.' >"$file"
  else
    [[ -f "$file" ]] && cp "$file" "${file}.backup.$(date +%s)"
    merge_json_mcp_server "$file" "$block"
  fi
  echo "Updated Claude Desktop: $file"
  echo "Restart Claude Desktop (Cmd+Q) for changes to take effect."
}

update_cursor() {
  local token="$1"
  local url out block
  url=$(splunk_mcp_url)
  out="${CURSOR_MCP_JSON:-.cursor/mcp.json}"
  if command -v jq >/dev/null 2>&1; then
    block=$(mcp_servers_block_jq "$url" "$token")
    merge_json_mcp_server "$out" "$block"
  else
    merge_json_mcp_server_python "$out" "$url" "$token"
  fi
  echo "Updated Cursor MCP config: $out"
  echo "Restart Cursor or reload MCP servers."
}

update_goose() {
  local token="$1"
  local url dir file
  url=$(splunk_mcp_url)
  dir="${HOME}/.config/goose"
  file="${dir}/config.yaml"
  mkdir -p "$dir"
  [[ -f "$file" ]] || printf 'extensions: {}\n' >"$file"
  python3 - "$file" "$token" "$SPLUNK_HOST" "$SPLUNK_PORT" <<'PY'
import re
import sys

config_file, token, host, port = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(config_file, encoding="utf-8") as f:
    content = f.read()

pattern = r'^\s{2}splunk-mcp-server:.*?(?=\n\s{2}[a-zA-Z_]|\n[a-zA-Z_]|\Z)'
content = re.sub(pattern, "", content, flags=re.MULTILINE | re.DOTALL)
if "extensions:" not in content:
    content = "extensions: {}\n" + content

extensions_match = re.search(r"^extensions:", content, re.MULTILINE)
if not extensions_match:
    sys.exit("extensions: section missing in Goose config")

end_of_line = content.find("\n", extensions_match.end())
if end_of_line == -1:
    end_of_line = len(content)

new_entry = f"""
  splunk-mcp-server:
    enabled: true
    type: stdio
    name: splunk-mcp-server
    description: Splunk MCP Server
    cmd: npx
    args:
      - -y
      - mcp-remote
      - https://{host}:{port}/services/mcp
      - --header
      - "Authorization: Bearer {token}"
    env:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    envs:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
    env_keys: []
    timeout: 300
    bundled: null
    available_tools: []"""

content = content[:end_of_line] + new_entry + content[end_of_line:]
with open(config_file, "w", encoding="utf-8") as f:
    f.write(content)
PY
  echo "Updated Goose: $file"
  echo "Restart Goose for changes to take effect."
}

client_config_path() {
  case "$1" in
    claude) printf '%s' "${HOME}/Library/Application Support/Claude/claude_desktop_config.json" ;;
    cursor) printf '%s' "${CURSOR_MCP_JSON:-$ROOT/.cursor/mcp.json}" ;;
    goose) printf '%s' "${HOME}/.config/goose/config.yaml" ;;
  esac
}

verify_client_config() {
  local client="$1"
  local path
  path=$(client_config_path "$client")
  case "$client" in
    claude | cursor)
      [[ -f "$path" ]] || die "$client config missing: $path (run: make update-mcp-client CLIENT=$client)"
      jq -e '.mcpServers["splunk-mcp-server"]' "$path" >/dev/null \
        || die "$client config has no mcpServers.splunk-mcp-server in $path"
      ;;
    goose)
      [[ -f "$path" ]] || die "goose config missing: $path (run: make update-mcp-client CLIENT=goose)"
      grep -q 'splunk-mcp-server:' "$path" \
        || die "goose config has no splunk-mcp-server extension in $path"
      ;;
  esac
  echo "OK: $client config contains splunk-mcp-server ($path)"
}

verify_mcp_remote() {
  local token="$1"
  local url tmp pid
  url=$(splunk_mcp_url)
  export NODE_TLS_REJECT_UNAUTHORIZED="${NODE_TLS_REJECT_UNAUTHORIZED:-0}"
  tmp=$(mktemp)
  # shellcheck disable=SC2329
  cleanup() { rm -f "$tmp" "${tmp}.pid"; }
  trap cleanup EXIT

  ( npx -y mcp-remote "$url" --header "Authorization: Bearer ${token}" >"$tmp" 2>&1 & echo $! >"${tmp}.pid" )
  pid=$(cat "${tmp}.pid")
  for _ in $(seq 1 30); do
    if grep -q "Proxy established successfully" "$tmp" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "OK: mcp-remote connected to Splunk ($url)."
      return 0
    fi
    if grep -qE "Fatal error:|Connection error:" "$tmp" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      die "mcp-remote failed (see logs in temp file; Splunk up? $url)"
    fi
    sleep 0.5
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  die "mcp-remote timed out ($url)"
}

cmd_update() {
  local client="${1:?}"
  local token_file="${2:-$TOKEN_FILE}"
  valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS)"
  local token
  token=$(read_token "$token_file")
  case "$client" in
    claude) update_claude "$token" ;;
    cursor) update_cursor "$token" ;;
    goose) update_goose "$token" ;;
  esac
}

cmd_verify() {
  local client="${1:?}"
  local token_file="${2:-$TOKEN_FILE}"
  local token
  token=$(read_token "$token_file")
  case "$client" in
    all)
      for c in $VALID_CLIENTS; do
        verify_client_config "$c"
      done
      verify_mcp_remote "$token"
      ;;
    *)
      valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS or all)"
      verify_client_config "$client"
      verify_mcp_remote "$token"
      ;;
  esac
}

main() {
  [[ $# -ge 1 ]] || usage 1
  local action="$1"
  shift
  case "$action" in
    update)
      [[ $# -ge 1 ]] || usage 1
      cmd_update "$@"
      ;;
    verify)
      [[ $# -ge 1 ]] || usage 1
      cmd_verify "$@"
      ;;
    -h | --help | help) usage 0 ;;
    *) die "unknown action '$action' (use: update|verify)" ;;
  esac
}

main "$@"
