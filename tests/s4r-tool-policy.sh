#!/usr/bin/env bash
# Docker-free checks of restrict_s4r_mcp_tools (register-s4r-mcp-tools.sh) with a fake splunk_curl:
# it limits the SA-S4R tools to s4r_user only when the role exists and the MCP user holds it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/s4r-tool-policy.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

# shellcheck source=scripts/register-s4r-mcp-tools.sh
source "${ROOT}/scripts/register-s4r-mcp-tools.sh"

export SPLUNK_URL="https://fake:8089" SPLUNK_MCP_USER="splunker"
export SPLUNK_CURL_CONNECT_TIMEOUT=1 SPLUNK_CURL_MAX_TIME=1

# Fake of splunk_curl: logs "METHOD URL BODY", answers "<body>\n<http code>".
splunk_curl() {
  local url="" method=GET body="" prev=""
  for arg in "$@"; do
    case "${arg}" in https://*) url="${arg}" ;; esac
    [[ "${prev}" == "-X" ]] && method="${arg}"
    [[ "${prev}" == "-d" ]] && body="${arg}"
    prev="${arg}"
  done
  echo "${method} ${url} ${body}" >>"${TMP}/calls.log"
  case "${url}" in
    */authorization/roles/*) printf '{}\n%s\n' "${FAKE_ROLE_CODE:-200}" ;;
    */authentication/users/*) printf '{"entry":[{"content":{"roles":%s}}]}\n200\n' "${FAKE_USER_ROLES:-[\"user\",\"mcp_user\",\"s4r_user\"]}" ;;
    */mcp_tool_roles) printf '{}\n%s\n' "${FAKE_POST_CODE:-200}" ;;
    *) printf '{}\n404\n' ;;
  esac
}

run() { # runs restrict_s4r_mcp_tools; output in out.txt, rc in $rc, calls in calls.log
  : >"${TMP}/calls.log"
  set +e
  restrict_s4r_mcp_tools >"${TMP}/out.txt" 2>&1
  rc=$?
  set -e
  posts="$(grep -c '^POST .*/mcp_tool_roles ' "${TMP}/calls.log" || true)"
}

TOOLS_JSON="${ROOT}/SA-S4R/default/s4r_mcp_tools.json"
n_tools="$(jq '.tools | length' "${TOOLS_JSON}")"

# 1. role exists and splunker holds it: one policy per tool, each naming only s4r_user
run
[[ "${rc}" -eq 0 ]] || die "case 1 exited ${rc}"
[[ "${posts}" -eq "${n_tools}" ]] || die "case 1 posted ${posts} policies, expected ${n_tools}"
while IFS= read -r name; do
  grep -Fq "\"tool_id\": \"SA-S4R:SA-S4R_${name}\", \"roles\": [\"s4r_user\"]" "${TMP}/calls.log" \
    || die "case 1 has no s4r_user policy for ${name}"
done < <(jq -r '.tools[].name' "${TOOLS_JSON}")
grep -q "Restricted ${n_tools} SA-S4R MCP tools to role s4r_user" "${TMP}/out.txt" || die "case 1 success message missing"

# 2. role missing (older SA-S4R): warn, post nothing, do not fail
FAKE_ROLE_CODE=404 run
[[ "${rc}" -eq 0 ]] || die "case 2 must not fail init (exit ${rc})"
[[ "${posts}" -eq 0 ]] || die "case 2 posted ${posts} policies without the role"
grep -q 'not found' "${TMP}/out.txt" || die "case 2 gave no warning"

# 3. role exists but the MCP user does not hold it: the tools must not be hidden from it
FAKE_USER_ROLES='["user","mcp_user"]' run
[[ "${rc}" -eq 0 ]] || die "case 3 exited ${rc}"
[[ "${posts}" -eq 0 ]] || die "case 3 posted ${posts} policies although splunker lacks the role"
grep -q 'does not hold role' "${TMP}/out.txt" || die "case 3 gave no warning"

# 4. S4R_TOOL_ROLE empty: leave the tools open without touching Splunk
S4R_TOOL_ROLE="" run
[[ "${rc}" -eq 0 ]] || die "case 4 exited ${rc}"
[[ ! -s "${TMP}/calls.log" ]] || die "case 4 called Splunk although restriction is off"

# 5. a policy POST fails: warn per tool, no success message, do not fail init
FAKE_POST_CODE=500 run
[[ "${rc}" -eq 0 ]] || die "case 5 must not fail init (exit ${rc})"
grep -q 'it stays open' "${TMP}/out.txt" || die "case 5 gave no warning"
! grep -q 'Restricted' "${TMP}/out.txt" || die "case 5 claimed success"

# 6. another role name is honoured
S4R_TOOL_ROLE=workshop FAKE_USER_ROLES='["workshop"]' run
grep -Fq '"roles": ["workshop"]' "${TMP}/calls.log" || die "case 6 ignored S4R_TOOL_ROLE"

echo "OK: SA-S4R tools are limited to s4r_user only when the role exists and splunker holds it"
