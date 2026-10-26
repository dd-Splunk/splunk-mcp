#!/usr/bin/env bash
# Update or verify Splunk MCP client configs (Claude Desktop, Claude Code, Cursor).
#
# Usage:
#   ./scripts/mcp-client.sh update <claude|claude-code|cursor>
#   ./scripts/mcp-client.sh update-all [claude claude-code cursor ...]
#   ./scripts/mcp-client.sh park <claude|claude-code|cursor|all>
#   ./scripts/mcp-client.sh verify <claude|claude-code|cursor|all>
#   ./scripts/mcp-client.sh write-shape [claude claude-code cursor ...]  # fixture token, no Splunk
#   ./scripts/mcp-client.sh verify-config <claude|claude-code|cursor|all>
#
# Env: CURSOR_MCP_JSON, CLAUDE_MCP_JSON, CLAUDE_CODE_MCP_JSON, SPLUNK_MCP_ENDPOINT,
#      SPLUNK_MCP_TLS_INSECURE, MCP_REMOTE_PACKAGE, MCP_SHAPE_TOKEN

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

readonly VALID_CLIENTS="claude claude-code cursor"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") update <claude|claude-code|cursor>
  $(basename "$0") update-all [claude claude-code cursor ...]  # one mint, write all listed clients
  $(basename "$0") park <claude|claude-code|cursor|all>        # remove splunk-mcp-server (no secrets)
  $(basename "$0") verify <claude|claude-code|cursor|all>
  $(basename "$0") write-shape [claude claude-code cursor ...]  # fixture token; no mint / Docker
  $(basename "$0") verify-config <claude|claude-code|cursor|all>

All clients use npx mcp-remote to https://localhost:8089/services/mcp with a minted bearer token
(stored only in client config files, not in this repo).

park prevents auto-reconnect with stale tokens during stack boot (make down calls this).
update-all mints once and updates every listed client (default: cursor claude claude-code).

verify runs client config checks (all: configured clients only), then an end-to-end npx mcp-remote stdio tools/list handshake.
write-shape / verify-config check JSON shape only (MCP_SHAPE_TOKEN fixture; no Splunk).
EOF
  exit "${1:-0}"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

# Bearer tokens live in these files. Tighten mode after every write (update or park).
restrict_client_config_mode() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  chmod 600 "$file" || die "could not chmod 600 $file"
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

# Splunk MCP Server 2.0 client shape: npx mcp-remote + encrypted bearer token
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
    token="$(mint_mcp_token)" || die "could not mint MCP token (is Splunk up? secrets in .env?)"
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
  restrict_client_config_mode "$file"
  echo "Updated $label: $file ($npx_cmd mcp-remote → $endpoint)"
  echo "Bearer token stored in client config only (not in this repo)."
}

update_claude() {
  update_json_mcp_remote \
    "$(client_config_path claude)" \
    "Claude Desktop"
  echo "Restart Claude Desktop (Cmd+Q) for changes to take effect."
}

update_claude_code() {
  update_json_mcp_remote \
    "$(client_config_path claude-code)" \
    "Claude Code"
  echo "Start a new Claude Code session (or run /mcp) and approve the project server splunk-mcp-server."
}

update_cursor() {
  update_json_mcp_remote \
    "$(client_config_path cursor)" \
    "Cursor"
  echo "Restart Cursor or reload MCP servers."
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
  restrict_client_config_mode "$file"
}

park_client() {
  local client="$1"
  case "$client" in
    claude) park_json_mcp_remote "$(client_config_path claude)" "Claude Desktop" ;;
    claude-code) park_json_mcp_remote "$(client_config_path claude-code)" "Claude Code" ;;
    cursor) park_json_mcp_remote "$(client_config_path cursor)" "Cursor" ;;
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
    claude | claude-code | cursor)
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
    clients=(cursor claude claude-code)
  else
    clients=("$@")
  fi

  command -v jq >/dev/null 2>&1 || die "jq required (brew install jq)"
  for client in "${clients[@]}"; do
    valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS)"
  done

  endpoint=$(splunk_mcp_endpoint)
  npx_cmd="$(npx_command)"
  token="$(mint_mcp_token)" || die "could not mint MCP token (is Splunk up? secrets in .env?)"

  for client in "${clients[@]}"; do
    case "$client" in
      claude)
        update_json_mcp_remote "$(client_config_path claude)" "Claude Desktop" "$token"
        ;;
      claude-code)
        update_json_mcp_remote "$(client_config_path claude-code)" "Claude Code" "$token"
        ;;
      cursor)
        update_json_mcp_remote "$(client_config_path cursor)" "Cursor" "$token"
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
  if [[ " ${clients[*]} " == *" claude-code "* ]]; then
    echo "Start a new Claude Code session (or run /mcp) and approve the project server splunk-mcp-server."
  fi
}

client_config_path() {
  case "$1" in
    claude) printf '%s' "${CLAUDE_MCP_JSON:-${HOME}/Library/Application Support/Claude/claude_desktop_config.json}" ;;
    claude-code) printf '%s' "${CLAUDE_CODE_MCP_JSON:-$ROOT/.mcp.json}" ;;
    cursor) printf '%s' "${CURSOR_MCP_JSON:-$ROOT/.cursor/mcp.json}" ;;
  esac
}

verify_client_config() {
  local client="$1"
  local path
  path=$(client_config_path "$client")
  case "$client" in
    claude | claude-code | cursor)
      [[ -f "$path" ]] || die "$client config missing: $path (run: make update-mcp-client MCP_CLIENT=$client)"
      jq -e '.mcpServers["splunk-mcp-server"]' "$path" >/dev/null \
        || die "$client config has no mcpServers.splunk-mcp-server in $path"
      jq -e '.mcpServers["splunk-mcp-server"].command | test("npx$")' "$path" >/dev/null \
        || die "$client splunk-mcp-server should use npx (run: make update-mcp-client MCP_CLIENT=$client)"
      # Writer pins MCP_REMOTE_PACKAGE (mcp-remote@x.y.z). jq index() is exact, so
      # accept mcp-remote or mcp-remote@*.
      jq -e '.mcpServers["splunk-mcp-server"].args | map(tostring) | any(test("^mcp-remote(@|$)"))' "$path" >/dev/null \
        || die "$client splunk-mcp-server should use mcp-remote (run: make update-mcp-client MCP_CLIENT=$client)"
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

  if ! curl -kfsS --connect-timeout 10 --max-time 60 -X POST "$endpoint" \
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
    claude-code) update_claude_code ;;
    cursor) update_cursor ;;
  esac
}

cmd_verify() {
  local client="${1:?}" token
  cmd_verify_config "$client"
  token="$(mint_mcp_token)" || die "could not mint MCP token for verify"
  verify_splunk_mcp "$token"
  verify_mcp_remote_stdio "$token"
}

shape_token() {
  # Fixture only — never a live Splunk token. Override with MCP_SHAPE_TOKEN in tests.
  printf '%s' "${MCP_SHAPE_TOKEN:-shape-test-placeholder}"
}

write_client_shape() {
  local client="$1" token="$2"
  case "$client" in
    claude) update_json_mcp_remote "$(client_config_path claude)" "Claude Desktop" "$token" ;;
    claude-code) update_json_mcp_remote "$(client_config_path claude-code)" "Claude Code" "$token" ;;
    cursor) update_json_mcp_remote "$(client_config_path cursor)" "Cursor" "$token" ;;
    *) die "unknown client '$client' (use: $VALID_CLIENTS)" ;;
  esac
}

cmd_write_shape() {
  local clients=() client token
  if [[ $# -eq 0 ]]; then
    clients=(cursor claude claude-code)
  else
    clients=("$@")
  fi
  command -v jq >/dev/null 2>&1 || die "jq required (brew install jq)"
  for client in "${clients[@]}"; do
    valid_client "$client" || die "unknown client '$client' (use: $VALID_CLIENTS)"
  done
  token="$(shape_token)"
  for client in "${clients[@]}"; do
    write_client_shape "$client" "$token"
  done
  for client in "${clients[@]}"; do
    verify_client_config "$client"
  done
}

# True when the client config has a splunk-mcp-server entry.
client_configured() {
  local path
  path=$(client_config_path "$1")
  [[ -f "$path" ]] || return 1
  jq -e '.mcpServers["splunk-mcp-server"]' "$path" >/dev/null 2>&1
}

cmd_verify_config() {
  local client="${1:?}" found=0
  case "$client" in
    all)
      # make up only writes MCP_UPDATE_ON_BOOT clients, so skip the others.
      for c in $VALID_CLIENTS; do
        if client_configured "$c"; then
          verify_client_config "$c"
          found=1
        else
          echo "SKIP: $c has no splunk-mcp-server ($(client_config_path "$c"))"
        fi
      done
      [[ "$found" == 1 ]] || die "no client config has splunk-mcp-server (run: make update-mcp-clients)"
      ;;
    claude | claude-code | cursor)
      verify_client_config "$client"
      ;;
    *)
      die "unknown client '$client' (use: $VALID_CLIENTS or all)"
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
    write-shape)
      cmd_write_shape "$@"
      ;;
    verify-config)
      [[ $# -ge 1 ]] || usage 1
      cmd_verify_config "$@"
      ;;
    -h | --help | help) usage 0 ;;
    *) die "unknown action '$action' (use: update|update-all|park|verify|write-shape|verify-config)" ;;
  esac
}

main "$@"
