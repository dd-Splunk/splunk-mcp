#!/usr/bin/env bash
# Update or verify Splunk MCP client configs (Claude, Cursor, Goose).
#
# Usage:
#   ./scripts/mcp-client.sh update <claude|cursor|goose>
#   ./scripts/mcp-client.sh update-all [claude cursor goose ...]
#   ./scripts/mcp-client.sh park <claude|cursor|goose|all>
#   ./scripts/mcp-client.sh verify <claude|cursor|goose|all>
#
# Env: CURSOR_MCP_JSON, SPLUNK_MCP_ENDPOINT, SPLUNK_MCP_TLS_INSECURE, MCP_REMOTE_PACKAGE

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

readonly VALID_CLIENTS="claude cursor goose"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") update <claude|cursor|goose>
  $(basename "$0") update-all [claude cursor goose ...]   # one mint, write all listed clients
  $(basename "$0") park <claude|cursor|goose|all>         # remove splunk-mcp-server (no secrets)
  $(basename "$0") verify <claude|cursor|goose|all>

All clients use npx mcp-remote to https://localhost:8089/services/mcp with a minted bearer token
(stored only in client config files, not in this repo).

park prevents auto-reconnect with stale tokens during stack boot (make down calls this).
update-all mints once and updates every listed client (default: cursor goose claude).

verify runs client config checks, then an end-to-end npx mcp-remote stdio tools/list handshake.
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

# GUI apps (e.g. Claude Desktop) often inherit a minimal PATH without Homebrew.
npx_command() {
  local npx_cmd="${MCP_NPX_COMMAND:-}"
  if [[ -z "$npx_cmd" ]]; then
    npx_cmd="$(command -v npx || true)"
  fi
  [[ -n "$npx_cmd" ]] || die "npx not found in PATH (brew install node)"
  [[ -x "$npx_cmd" ]] || die "npx is not executable: $npx_cmd"
  printf '%s' "$npx_cmd"
}

mcp_remote_spec() {
  printf '%s' "${MCP_REMOTE_PACKAGE:-mcp-remote@0.8.3}"
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

# Splunk MCP Server 1.3 client shape: npx mcp-remote + encrypted bearer token
mcp_servers_block_mcp_remote_jq() {
  local endpoint="$1" token="$2" npx_cmd="$3"
  local tls_insecure="${SPLUNK_MCP_TLS_INSECURE:-1}"
  local mcp_remote
  mcp_remote="$(mcp_remote_spec)"
  jq -n \
    --arg endpoint "$endpoint" \
    --arg token "$token" \
    --arg npx_cmd "$npx_cmd" \
    --arg mcp_remote "$mcp_remote" \
    --arg tls_insecure "$tls_insecure" \
    '{
      args: ["-y", $mcp_remote, $endpoint, "--header", ("Authorization: Bearer " + $token)],
      command: $npx_cmd
    }
    | if ($tls_insecure == "1" or $tls_insecure == "true" or $tls_insecure == "yes") then
        . + {env: {NODE_TLS_REJECT_UNAUTHORIZED: "0"}}
      else . end'
}

mint_mcp_token() {
  ./scripts/mint-mcp-token.sh
}

update_json_mcp_remote() {
  local file="$1" label="$2" token="${3:-}"
  command -v jq >/dev/null 2>&1 || die "jq required for $label (brew install jq)"
  local endpoint block current npx_cmd
  endpoint=$(splunk_mcp_endpoint)
  npx_cmd="$(npx_command)"
  if [[ -z "$token" ]]; then
    token="$(mint_mcp_token)" || die "could not mint MCP token (is Splunk up? secrets in .env or tpl.env?)"
  fi
  mkdir -p "$(dirname "$file")"
  block=$(mcp_servers_block_mcp_remote_jq "$endpoint" "$token" "$npx_cmd")
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
  echo "Updated $label: $file ($npx_cmd mcp-remote → $endpoint)"
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

apply_goose_splunk_mcp() {
  local token="$1"
  command -v jq >/dev/null 2>&1 || die "jq required for Goose (brew install jq)"
  local endpoint header tls_insecure dir file npx_cmd wrapper
  endpoint=$(splunk_mcp_endpoint)
  npx_cmd="$(npx_command)"
  header="Authorization: Bearer ${token}"
  tls_insecure="${SPLUNK_MCP_TLS_INSECURE:-1}"
  wrapper="${ROOT}/scripts/mcp-remote-splunk.sh"
  [[ -x "$wrapper" ]] || die "missing executable wrapper: $wrapper"
  dir="${HOME}/.config/goose"
  file="${dir}/config.yaml"
  mkdir -p "$dir"
  [[ -f "$file" ]] || printf 'extensions: {}\n' >"$file"
  python3 - "$file" "$endpoint" "$header" "$tls_insecure" "$wrapper" "$npx_cmd" <<'PY'
import re
import sys

config_file, endpoint, header, tls_insecure, wrapper, npx_cmd = sys.argv[1:7]
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

env_block = "    envs: {}\n    env_keys: []\n"
if tls_insecure.lower() in ("1", "true", "yes"):
    env_block = """    envs:
      NODE_TLS_REJECT_UNAUTHORIZED: "0"
      MCP_NPX_COMMAND: {npx_cmd!r}
      SPLUNK_MCP_TLS_INSECURE: "1"
    env_keys:
      - NODE_TLS_REJECT_UNAUTHORIZED
""".format(npx_cmd=npx_cmd)

new_entry = f"""
  splunk-mcp-server:
    enabled: true
    type: stdio
    name: splunk-mcp-server
    description: Splunk MCP Server
    cmd: {wrapper!r}
    args:
      - {endpoint!r}
      - --header
      - {header!r}
{env_block}    timeout: 300
    bundled: null
    available_tools: []"""

content = content[:end_of_line] + new_entry + content[end_of_line:]
with open(config_file, "w", encoding="utf-8") as f:
    f.write(content)
PY
  echo "Updated Goose: $file ($wrapper → $endpoint)"
}

update_goose() {
  local token
  token="$(mint_mcp_token)" || die "could not mint MCP token"
  apply_goose_splunk_mcp "$token"
  echo "Bearer token stored in Goose config only (not in this repo)."
  echo "Restart Goose for changes to take effect."
}

remove_goose_splunk_mcp() {
  local file="${HOME}/.config/goose/config.yaml"
  [[ -f "$file" ]] || return 0
  grep -q 'splunk-mcp-server:' "$file" || return 0
  python3 - "$file" <<'PY'
import re
import sys

config_file = sys.argv[1]
with open(config_file, encoding="utf-8") as f:
    content = f.read()
pattern = r'^\s{2}splunk-mcp-server:.*?(?=\n\s{2}[a-zA-Z_]|\n[a-zA-Z_]|\Z)'
new_content = re.sub(pattern, "", content, flags=re.MULTILINE | re.DOTALL)
if new_content != content:
    with open(config_file, "w", encoding="utf-8") as f:
        f.write(new_content)
PY
  echo "Parked Goose: removed splunk-mcp-server from $file"
}

park_json_mcp_remote() {
  local file="$1" label="$2"
  [[ -f "$file" ]] || return 0
  command -v jq >/dev/null 2>&1 || return 0
  jq empty "$file" 2>/dev/null || return 0
  if jq -e '.mcpServers["splunk-mcp-server"]' "$file" >/dev/null 2>&1; then
    jq 'del(.mcpServers["splunk-mcp-server"])' "$file" >"${file}.tmp"
    mv "${file}.tmp" "$file"
    echo "Parked $label: removed splunk-mcp-server from $file"
  fi
}

park_client() {
  local client="$1"
  case "$client" in
    claude) park_json_mcp_remote "$(client_config_path claude)" "Claude Desktop" ;;
    cursor) park_json_mcp_remote "$(client_config_path cursor)" "Cursor" ;;
    goose) remove_goose_splunk_mcp ;;
  esac
}

cmd_park() {
  local target="${1:-all}"
  case "$target" in
    all)
      for c in $VALID_CLIENTS; do
        park_client "$c"
      done
      ;;
    claude | cursor | goose)
      valid_client "$target" || die "unknown client '$target' (use: $VALID_CLIENTS or all)"
      park_client "$target"
      ;;
    *)
      die "unknown park target '$target' (use: $VALID_CLIENTS or all)"
      ;;
  esac
}

cmd_update_all() {
  local clients=()
  local client token endpoint npx_cmd

  if [[ $# -eq 0 ]]; then
    clients=(cursor goose claude)
  else
    clients=("$@")
  fi

  command -v jq >/dev/null 2>&1 || die "jq required (brew install jq)"
  for client in "${clients[@]}"; do
    valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS)"
  done

  endpoint=$(splunk_mcp_endpoint)
  npx_cmd="$(npx_command)"
  token="$(mint_mcp_token)" || die "could not mint MCP token (is Splunk up? secrets in .env or tpl.env?)"

  for client in "${clients[@]}"; do
    case "$client" in
      claude)
        update_json_mcp_remote "$(client_config_path claude)" "Claude Desktop" "$token"
        ;;
      cursor)
        update_json_mcp_remote "$(client_config_path cursor)" "Cursor" "$token"
        ;;
      goose)
        apply_goose_splunk_mcp "$token"
        ;;
    esac
  done

  echo "Minted one token; updated: ${clients[*]} ($npx_cmd mcp-remote → $endpoint)"
  echo "Bearer token stored in client configs only (not in this repo)."
  if [[ " ${clients[*]} " == *" cursor "* ]]; then
    echo "Reload MCP servers in Cursor (or restart Cursor)."
  fi
  if [[ " ${clients[*]} " == *" claude "* ]]; then
    echo "Restart Claude Desktop (Cmd+Q) for changes to take effect."
  fi
  if [[ " ${clients[*]} " == *" goose "* ]]; then
    echo "Restart Goose for changes to take effect."
  fi
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
      jq -e '.mcpServers["splunk-mcp-server"].command | test("npx$")' "$path" >/dev/null \
        || die "$client splunk-mcp-server should use npx (run: make update-mcp-client MCP_CLIENT=$client)"
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
if "mcp-stdio-http-bridge" in section:
    sys.exit(
        "goose splunk-mcp-server still uses removed scripts/mcp-stdio-http-bridge.mjs "
        "(run: make update-mcp-client MCP_CLIENT=goose)"
    )
if re.search(r"\bMCP_URL\b", section):
    sys.exit(
        "goose splunk-mcp-server still uses legacy MCP_URL proxy layout "
        "(run: make update-mcp-client MCP_CLIENT=goose)"
    )
if re.search(r"cmd:\s*node\b", section) and ".mjs" in section:
    sys.exit(
        "goose splunk-mcp-server still uses node + bridge script "
        "(run: make update-mcp-client MCP_CLIENT=goose)"
    )
if not re.search(r"cmd:\s*(\S+/)?npx\b", section) and "mcp-remote-splunk.sh" not in section:
    sys.exit("goose splunk-mcp-server should use mcp-remote-splunk.sh or npx in cmd")
if "mcp-remote" not in section and "mcp-remote-splunk.sh" not in section:
    sys.exit("goose splunk-mcp-server should use mcp-remote (directly or via wrapper)")
tls_insecure = __import__("os").environ.get("SPLUNK_MCP_TLS_INSECURE", "1").lower()
if tls_insecure in ("1", "true", "yes"):
    if "NODE_TLS_REJECT_UNAUTHORIZED" not in section and "mcp-remote-splunk.sh" not in section:
        sys.exit(
            "goose splunk-mcp-server missing NODE_TLS_REJECT_UNAUTHORIZED "
            "(run: make update-mcp-client MCP_CLIENT=goose)"
        )
PY
      ;;
  esac
  echo "OK: $client config contains splunk-mcp-server ($path)"
}

verify_splunk_mcp() {
  local token="${1:?}"
  local endpoint tmp
  endpoint=$(splunk_mcp_endpoint)
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
  echo "OK: Splunk MCP direct tools/list ($endpoint)."
}

# Same path clients use: stdio → npx mcp-remote → HTTPS /services/mcp
verify_mcp_remote_stdio() {
  local token="${1:?}"
  local endpoint npx_cmd tls_insecure mcp_remote
  endpoint=$(splunk_mcp_endpoint)
  npx_cmd="$(npx_command)"
  mcp_remote="$(mcp_remote_spec)"
  tls_insecure="${SPLUNK_MCP_TLS_INSECURE:-1}"
  MCP_NPX_COMMAND="$npx_cmd" SPLUNK_MCP_ENDPOINT="$endpoint" SPLUNK_MCP_TLS_INSECURE="$tls_insecure" \
    MCP_REMOTE_PACKAGE="$mcp_remote" \
    python3 - "$token" <<'PY' || die "mcp-remote stdio tools/list failed (see errors above)"
import json
import os
import select
import subprocess
import sys
import time

token = sys.argv[1]
npx_cmd = os.environ["MCP_NPX_COMMAND"]
endpoint = os.environ["SPLUNK_MCP_ENDPOINT"]
mcp_remote = os.environ.get("MCP_REMOTE_PACKAGE", "mcp-remote@0.8.3")
tls_insecure = os.environ.get("SPLUNK_MCP_TLS_INSECURE", "1")
header = f"Authorization: Bearer {token}"

env = os.environ.copy()
if tls_insecure.lower() in ("1", "true", "yes"):
    env["NODE_TLS_REJECT_UNAUTHORIZED"] = "0"
else:
    env.pop("NODE_TLS_REJECT_UNAUTHORIZED", None)

proc = subprocess.Popen(
    [npx_cmd, "-y", mcp_remote, endpoint, "--header", header],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    bufsize=1,
    env=env,
)

def send(msg):
    proc.stdin.write(json.dumps(msg) + "\n")
    proc.stdin.flush()

def read_json(timeout=45):
    deadline = time.time() + timeout
    while time.time() < deadline:
        ready, _, _ = select.select([proc.stdout], [], [], 0.5)
        if not ready:
            if proc.poll() is not None:
                break
            continue
        line = proc.stdout.readline()
        if not line:
            break
        line = line.strip()
        if not line:
            continue
        return json.loads(line)
    return None

stderr_tail = ""
try:
    send(
        {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "splunk-mcp-verify", "version": "1.0"},
            },
        }
    )
    init_resp = read_json()
    if not init_resp or "result" not in init_resp:
        raise SystemExit(f"initialize failed: {init_resp!r}")

    send({"jsonrpc": "2.0", "method": "notifications/initialized"})
    send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
    tools_resp = read_json()
    tools = (tools_resp or {}).get("result", {}).get("tools")
    if not isinstance(tools, list):
        raise SystemExit(f"tools/list failed: {tools_resp!r}")
finally:
    proc.terminate()
    try:
        _, stderr_tail = proc.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        _, stderr_tail = proc.communicate(timeout=5)
    if proc.returncode not in (0, None, -15) and stderr_tail:
        for line in stderr_tail.strip().splitlines():
            if "Bearer" in line:
                line = line.split("Bearer", 1)[0] + "Bearer <redacted>"
            print(line, file=sys.stderr)
PY
  echo "OK: npx mcp-remote stdio tools/list ($npx_cmd → $endpoint)."
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
  local client="${1:?}" token
  case "$client" in
    all)
      for c in $VALID_CLIENTS; do
        verify_client_config "$c"
      done
      ;;
    claude | cursor | goose)
      verify_client_config "$client"
      ;;
    *)
      die "unknown client '$client' (use: $VALID_CLIENTS or all)"
      ;;
  esac
  token="$(mint_mcp_token)" || die "could not mint MCP token for verify"
  verify_splunk_mcp "$token"
  verify_mcp_remote_stdio "$token"
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
    update-all)
      cmd_update_all "$@"
      ;;
    park)
      [[ $# -ge 1 ]] || usage 1
      cmd_park "$@"
      ;;
    verify)
      [[ $# -ge 1 ]] || usage 1
      cmd_verify "$@"
      ;;
    -h | --help | help) usage 0 ;;
    *) die "unknown action '$action' (use: update|update-all|park|verify)" ;;
  esac
}

main "$@"
