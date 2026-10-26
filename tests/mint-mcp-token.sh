#!/usr/bin/env bash
# Docker-free checks for scripts/mint-mcp-token.sh (Splunk MCP Server 2.1 token API).
# A fake curl on PATH answers from per-endpoint response queues; no Splunk, no secrets.
# Subshell-local env is intentional: each scenario sources the script fresh.
# shellcheck disable=SC2030,SC2031
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mint-mcp-token.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/bin"

# Each call to an endpoint pops one "code|body" line from its queue file; the
# last line repeats. Every request is logged as "METHOD URL" to calls.log.
cat >"${TMP}/bin/curl" <<'EOF'
#!/usr/bin/env bash
method=GET url="" want_code=0
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    -X) method="${args[i + 1]}" ;;
    -w) want_code=1 ;;
    https://*) url="${args[i]}" ;;
  esac
done
echo "${method} ${url}" >>"${FAKE_DIR}/calls.log"
case "${url}" in
  */mcp_token/key-pair) q="${FAKE_DIR}/keypair.q" ;;
  */mcp_token/tokens) q="${FAKE_DIR}/tokens.q" ;;
  *) q="${FAKE_DIR}/other.q" ;;
esac
if [[ ! -s "${q}" ]]; then
  printf '404|{"error":true,"details":"Unknown resource"}' >"${q}"
fi
line="$(head -n 1 "${q}")"
if [[ "$(wc -l <"${q}")" -gt 1 ]]; then
  tail -n +2 "${q}" >"${q}.next" && mv "${q}.next" "${q}"
fi
code="${line%%|*}"
body="${line#*|}"
printf '%s' "${body}"
[[ "${want_code}" -eq 1 ]] && printf '\n%s' "${code}"
exit 0
EOF
chmod +x "${TMP}/bin/curl"

# Runs wait_for_mcp_token in a subshell with the fake curl; prints token on stdout.
# Usage: run_mint <keypair queue file content> <tokens queue file content>
run_mint() {
  rm -f "${TMP}/calls.log" "${TMP}/keypair.q" "${TMP}/tokens.q" "${TMP}/other.q"
  printf '%b' "$1" >"${TMP}/keypair.q"
  printf '%b' "$2" >"${TMP}/tokens.q"
  (
    export FAKE_DIR="${TMP}" PATH="${TMP}/bin:${PATH}"
    export SPLUNK_ADMIN_PASSWORD=not-a-secret MCP_TOKEN_WAIT_ATTEMPTS=4 MCP_TOKEN_WAIT_INTERVAL=0
    # shellcheck source=scripts/mint-mcp-token.sh
    source "${REPO}/scripts/mint-mcp-token.sh"
    wait_splunk_init() { :; }
    wait_for_splunk() { :; }
    wait_for_mcp_token
  )
}

calls() { cat "${TMP}/calls.log"; }

# 1. No key yet: key-pair is created (201), then the token is minted.
out="$(run_mint '201|{"status":"generated","valid_until":"2027-04-24T00:00:00Z"}\n' \
  '200|{"token":"ENC-TOKEN-1"}\n' 2>"${TMP}/err")" || die "key-missing path failed: $(cat "${TMP}/err")"
[[ "${out}" == "ENC-TOKEN-1" ]] || die "key-missing: token was '${out}'"
grep -q 'Created MCP token encryption key (valid until 2027-04-24T00:00:00Z)' "${TMP}/err" \
  || die "key-missing: no key-created notice"
[[ "$(calls)" == "POST https://localhost:8089/services/mcp_token/key-pair
POST https://localhost:8089/services/mcp_token/tokens" ]] || die "key-missing: unexpected calls: $(calls)"

# 2. Key already exists (409): no notice, token minted.
out="$(run_mint '409|{"error":true,"code":"key_exists"}\n' '200|{"token":"ENC-TOKEN-2"}\n' 2>"${TMP}/err")" \
  || die "key-exists path failed"
[[ "${out}" == "ENC-TOKEN-2" ]] || die "key-exists: token was '${out}'"
grep -q 'Created MCP token encryption key' "${TMP}/err" && die "key-exists: spurious key-created notice"

# 3. Key-pair succeeds only after the app finishes loading (404 first).
out="$(run_mint '404|{"error":true}\n404|{"error":true}\n201|{"valid_until":"x"}\n' \
  '200|{"token":"ENC-TOKEN-3"}\n' 2>/dev/null)" || die "warm-up path failed"
[[ "${out}" == "ENC-TOKEN-3" ]] || die "warm-up: token was '${out}'"

# 4. Key deleted between calls: tokens answers 400, key-pair is recreated, mint retried.
out="$(run_mint '409|{}\n201|{"valid_until":"y"}\n' \
  '400|{"error":true,"message":"No active encryption keys exist to create tokens."}\n200|{"token":"ENC-TOKEN-4"}\n' \
  2>/dev/null)" || die "key-deleted path failed"
[[ "${out}" == "ENC-TOKEN-4" ]] || die "key-deleted: token was '${out}'"
[[ "$(grep -c 'key-pair' "${TMP}/calls.log")" -eq 2 ]] || die "key-deleted: key-pair not re-posted: $(calls)"

# 5. Wrong admin password: fails fast on 401 without ever posting a token.
if run_mint '401|{"messages":[{"text":"Unauthorized"}]}\n' '200|{"token":"never"}\n' >"${TMP}/out" 2>"${TMP}/err"; then
  die "401 should fail"
fi
grep -q 'rejected admin credentials (HTTP 401)' "${TMP}/err" || die "401: missing credentials hint"
grep -q 'mcp_token/tokens' "${TMP}/calls.log" && die "401: tokens endpoint was called"
[[ "$(wc -l <"${TMP}/calls.log")" -eq 1 ]] || die "401: expected a single call"

# 6. Never uses the pre-2.1 endpoint.
run_mint '409|{}\n' '200|{"token":"T"}\n' >/dev/null 2>&1
grep -q 'servicesNS' "${TMP}/calls.log" && die "legacy servicesNS/mcp_token endpoint still used"

# 7. Gives up (non-zero) when the endpoint never becomes usable, naming the reason.
if run_mint '404|{"error":true,"details":"Unknown resource"}\n' '404|{}\n' >/dev/null 2>"${TMP}/err"; then
  die "persistent 404 should fail"
fi
grep -q 'Splunk MCP Server app (7931, 2.1.0+)' "${TMP}/err" || die "give-up message missing 2.1.0 hint"

# 8. Error-message extraction handles all three Splunk/app shapes.
(
  # shellcheck source=scripts/mint-mcp-token.sh
  source "${REPO}/scripts/mint-mcp-token.sh"
  [[ "$(parse_mcp_token_wait_reason '{"messages":[{"text":"native"}]}')" == "native" ]] || exit 1
  [[ "$(parse_mcp_token_wait_reason '{"error":true,"message":"app message"}')" == "app message" ]] || exit 2
  [[ "$(parse_mcp_token_wait_reason '{"error":true,"details":"Unknown resource"}')" == "Unknown resource" ]] || exit 3
  [[ "$(parse_mcp_token_wait_reason '')" == "empty response" ]] || exit 4
  [[ "$(parse_mcp_token_body '{"token":"abc","message":"capped"}')" == "abc" ]] || exit 5
) || die "message/token parsing failed (step $?)"

echo "PASS: mint-mcp-token.sh (2.1 key-pair + tokens API)"
