#!/usr/bin/env bash
# Update or verify Splunk MCP client configs (Claude, Cursor, Goose).
#
# Usage:
#   ./scripts/mcp-client.sh update <claude|cursor|goose>
#   ./scripts/mcp-client.sh verify <claude|cursor|goose|all>
#
# Env: CURSOR_MCP_JSON, SPLUNK_MCP_ENDPOINT, SPLUNK_MCP_TLS_INSECURE

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

readonly VALID_CLIENTS="claude cursor goose"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") update <claude|cursor|goose>
  $(basename "$0") verify <claude|cursor|goose|all>

All clients use npx mcp-remote to https://localhost:8089/services/mcp with a minted bearer token
(stored only in client config files, not in this repo).
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

splunk_mcp_endpoint() {
  printf '%s' "${SPLUNK_MCP_ENDPOINT:-https://localhost:8089/services/mcp}"
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

# Splunk MCP Server 1.2 client shape: npx mcp-remote + encrypted bearer token
mcp_servers_block_mcp_remote_jq() {
  local endpoint="$1" token="$2"
  local tls_insecure="${SPLUNK_MCP_TLS_INSECURE:-1}"
  jq -n \
    --arg endpoint "$endpoint" \
    --arg token "$token" \
    --arg tls_insecure "$tls_insecure" \
    '{
      args: ["-y", "mcp-remote", $endpoint, "--header", ("Authorization: Bearer " + $token)],
      command: "npx"
    }
    | if ($tls_insecure == "1" or $tls_insecure == "true" or $tls_insecure == "yes") then
        . + {env: {NODE_TLS_REJECT_UNAUTHORIZED: "0"}}
      else . end'
}

mint_mcp_token() {
  ./scripts/mint-mcp-token.sh
}

update_json_mcp_remote() {
  local file="$1" label="$2"
  command -v jq >/dev/null 2>&1 || die "jq required for $label (brew install jq)"
  local endpoint token block current
  endpoint=$(splunk_mcp_endpoint)
  token="$(mint_mcp_token)" || die "could not mint MCP token (is Splunk up? secrets in .env or tpl.env?)"
  mkdir -p "$(dirname "$file")"
  block=$(mcp_servers_block_mcp_remote_jq "$endpoint" "$token")
  if [[ -f "$file" ]] && current=$(cat "$file") && echo "$current" | jq empty 2>/dev/null; then
    if ! updated=$(echo "$current" | jq \
      --argjson splunk_mcp "$block" \
      '.mcpServers |= (. // {}) | .mcpServers["splunk-mcp-server"] = $splunk_mcp'); then
      die "failed to merge $label JSON"
    fi
    echo "$updated" | jq '.' >"$file"
  else
    [[ -f "$file" ]] && cp "$file" "${file}.backup.$(date +%s)"
    merge_json_mcp_server "$file" "$block"
  fi
  echo "Updated $label: $file (npx mcp-remote → $endpoint)"
  echo "Bearer token stored in client config only (not in this repo)."
}

update_claude() {
  update_json_mcp_remote \
    "${HOME}/Library/Application Support/Claude/claude_desktop_config.json" \
    "Claude Desktop"
  echo "Restart Claude Desktop (Cmd+Q) for changes to take effect."
}

update_cursor() {
  update_json_mcp_remote \
    "${CURSOR_MCP_JSON:-$ROOT/.cursor/mcp.json}" \
    "Cursor"
  echo "Restart Cursor or reload MCP servers."
}

update_goose() {
  command -v jq >/dev/null 2>&1 || die "jq required for Goose (brew install jq)"
  local endpoint token header tls_insecure dir file
  endpoint=$(splunk_mcp_endpoint)
  token="$(mint_mcp_token)" || die "could not mint MCP token"
  header="Authorization: Bearer ${token}"
  tls_insecure="${SPLUNK_MCP_TLS_INSECURE:-1}"
  dir="${HOME}/.config/goose"
  file="${dir}/config.yaml"
  mkdir -p "$dir"
  [[ -f "$file" ]] || printf 'extensions: {}\n' >"$file"
  python3 - "$file" "$endpoint" "$header" "$tls_insecure" <<'PY'
import re
import sys

config_file, endpoint, header, tls_insecure = sys.argv[1:5]
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

env_block = ""
if tls_insecure.lower() in ("1", "true", "yes"):
    env_block = """
    envs:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
"""

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
      - {endpoint!r}
      - --header
      - {header!r}
    env_keys: []{env_block}
    timeout: 300
    bundled: null
    available_tools: []"""

content = content[:end_of_line] + new_entry + content[end_of_line:]
with open(config_file, "w", encoding="utf-8") as f:
    f.write(content)
PY
  echo "Updated Goose: $file (npx mcp-remote → $endpoint)"
  echo "Bearer token stored in Goose config only (not in this repo)."
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
      [[ -f "$path" ]] || die "$client config missing: $path (run: make update-mcp-client MCP_CLIENT=$client)"
      jq -e '.mcpServers["splunk-mcp-server"]' "$path" >/dev/null \
        || die "$client config has no mcpServers.splunk-mcp-server in $path"
      jq -e '.mcpServers["splunk-mcp-server"].command == "npx"' "$path" >/dev/null \
        || die "$client splunk-mcp-server should use command npx (run: make update-mcp-client MCP_CLIENT=$client)"
      jq -e '.mcpServers["splunk-mcp-server"].args | index("mcp-remote")' "$path" >/dev/null \
        || die "$client splunk-mcp-server should use mcp-remote (run: make update-mcp-client MCP_CLIENT=$client)"
      ;;
    goose)
      [[ -f "$path" ]] || die "goose config missing: $path (run: make update-mcp-client MCP_CLIENT=goose)"
      grep -q 'splunk-mcp-server:' "$path" \
        || die "goose config has no splunk-mcp-server extension in $path"
      python3 - "$path" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    block = f.read()
m = re.search(
    r"^\s{2}splunk-mcp-server:.*?(?=\n\s{2}[a-zA-Z_]|\n[a-zA-Z_]|\Z)",
    block,
    re.MULTILINE | re.DOTALL,
)
if not m:
    sys.exit("splunk-mcp-server block not found")
section = m.group(0)
if "cmd: npx" not in section and "cmd:npx" not in section.replace(" ", ""):
    sys.exit("goose splunk-mcp-server should use cmd: npx")
if "mcp-remote" not in section:
    sys.exit("goose splunk-mcp-server should use mcp-remote in args")
PY
      ;;
  esac
  echo "OK: $client config contains splunk-mcp-server ($path)"
}

verify_splunk_mcp() {
  local endpoint token tmp
  endpoint=$(splunk_mcp_endpoint)
  token="$(mint_mcp_token)" || die "could not mint MCP token for Splunk MCP verify"
  tmp=$(mktemp)
  # shellcheck disable=SC2329
  cleanup() { rm -f "${tmp:-}"; }
  trap cleanup RETURN

  if ! curl -kfsS -X POST "$endpoint" \
    -H "Authorization: Bearer ${token}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json' \
    --data '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' >"$tmp" 2>&1; then
    die "Splunk MCP request failed: $endpoint"
  fi
  if ! jq -e '.jsonrpc=="2.0" and (.result.tools|type=="array")' "$tmp" >/dev/null 2>&1; then
    die "Splunk MCP returned unexpected response: $endpoint"
  fi
  echo "OK: Splunk MCP responded to tools/list ($endpoint)."
}

cmd_update() {
  local client="${1:?}"
  valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS)"
  case "$client" in
    claude) update_claude ;;
    cursor) update_cursor ;;
    goose) update_goose ;;
  esac
}

cmd_verify() {
  local client="${1:?}"
  case "$client" in
    all)
      for c in $VALID_CLIENTS; do
        verify_client_config "$c"
      done
      verify_splunk_mcp
      ;;
    claude | cursor | goose)
      verify_client_config "$client"
      ;;
    *)
      valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS or all)"
      verify_client_config "$client"
      verify_splunk_mcp
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
