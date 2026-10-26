#!/usr/bin/env bash
# Docker-free checks for scripts/prune-mcp-tokens.sh (Splunk MCP Server 2.1 token registry).
# A fake curl serves a canned token listing and logs every request; no Splunk, no secrets.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/prune-mcp-tokens.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/bin"

cat >"${TMP}/bin/curl" <<'CURL'
#!/usr/bin/env bash
method=GET url=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    -X) method="${args[i + 1]}" ;;
    https://*) url="${args[i]}" ;;
  esac
done
echo "${method} ${url}" >>"${FAKE_DIR}/calls.log"
[[ "${method}" == GET ]] && cat "${FAKE_DIR}/listing.json"
[[ -n "${FAKE_FAIL_DELETE:-}" && "${method}" == DELETE ]] && exit 22
exit 0
CURL
chmod +x "${TMP}/bin/curl"

cat >"${TMP}/listing.json" <<'JSON'
{"count":5,"tokens":[
 {"token_id":"old-1","owner_username":"splunker","status":"active","created_at":"2026-10-01T10:00:00.000000Z"},
 {"token_id":"new-1","owner_username":"splunker","status":"active","created_at":"2026-10-03T10:00:00.000000Z"},
 {"token_id":"old-2","owner_username":"splunker","status":"active","created_at":"2026-10-02T10:00:00.000000Z"},
 {"token_id":"gone-1","owner_username":"splunker","status":"disabled","created_at":"2026-10-04T10:00:00.000000Z"},
 {"token_id":"other-1","owner_username":"someone","status":"active","created_at":"2026-09-01T10:00:00.000000Z"}
]}
JSON

# Runs prune_tokens with the fake curl; prints the deleted count on stdout.
run_prune() {
  local want_dry="${1:-0}"
  rm -f "${TMP}/calls.log"
  (
    export FAKE_DIR="${TMP}" PATH="${TMP}/bin:${PATH}" SPLUNK_ADMIN_PASSWORD=not-a-secret
    set --
    # shellcheck source=scripts/prune-mcp-tokens.sh
    source "${REPO}/scripts/prune-mcp-tokens.sh"
    dry_run="${want_dry}"
    prune_tokens
  )
}

# 1. Deletes only older active tokens of the MCP user, through the registry endpoint.
out="$(run_prune 0 2>"${TMP}/err")" || die "prune failed: $(cat "${TMP}/err")"
[[ "${out}" == 2 ]] || die "expected 2 deletions, got '${out}'"
deletes="$(grep '^DELETE' "${TMP}/calls.log" | sort)"
[[ "${deletes}" == "DELETE https://localhost:8089/services/mcp_token/tokens/old-1
DELETE https://localhost:8089/services/mcp_token/tokens/old-2" ]] || die "unexpected deletes: ${deletes}"
grep -q 'owner_username=splunker\|GET https://localhost:8089/services/mcp_token/tokens' "${TMP}/calls.log" \
  || die "registry listing endpoint not used"
grep -q 'authorization' "${TMP}/calls.log" && die "legacy authorization/tokens endpoint used"

# 2. Dry run reports the count but deletes nothing.
out="$(run_prune 1 2>"${TMP}/err")" || die "dry run failed"
[[ "${out}" == 2 ]] || die "dry run: expected 2, got '${out}'"
grep -q '^DELETE' "${TMP}/calls.log" && die "dry run issued DELETE"
grep -q 'would delete token old-1' "${TMP}/err" || die "dry run: no 'would delete' output"

# 3. A single active token is never deleted.
cat >"${TMP}/listing.json" <<'JSON'
{"count":1,"tokens":[{"token_id":"only","owner_username":"splunker","status":"active","created_at":"2026-10-01T10:00:00.000000Z"}]}
JSON
out="$(run_prune 0 2>/dev/null)" || die "single token: prune failed"
[[ "${out}" == 0 ]] || die "single token: expected 0, got '${out}'"
grep -q '^DELETE' "${TMP}/calls.log" && die "single token was deleted"

# 4. Empty registry is fine.
printf '{"count":0,"tokens":[]}' >"${TMP}/listing.json"
[[ "$(run_prune 0 2>/dev/null)" == 0 ]] || die "empty registry: expected 0"

# 5. A failed DELETE is a hard error.
cat >"${TMP}/listing.json" <<'JSON'
{"tokens":[
 {"token_id":"a","owner_username":"splunker","status":"active","created_at":"2026-10-01T00:00:00Z"},
 {"token_id":"b","owner_username":"splunker","status":"active","created_at":"2026-10-02T00:00:00Z"}]}
JSON
if FAKE_FAIL_DELETE=1 run_prune 0 >/dev/null 2>"${TMP}/err"; then
  die "failed DELETE should fail the prune"
fi
grep -q 'could not delete token' "${TMP}/err" || die "failed DELETE: missing error message"

echo "PASS: prune-mcp-tokens.sh (2.1 token registry)"
