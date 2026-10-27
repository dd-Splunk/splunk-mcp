#!/usr/bin/env bash
# Docker-free checks for scripts/mcp-auth-failures.sh. A fake curl returns a canned search
# export and records the SPL it was sent; no Splunk, no secrets.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/mcp-auth-failures.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/bin"

cat >"${TMP}/bin/curl" <<'CURL'
#!/usr/bin/env bash
for arg in "$@"; do
  [[ "${arg}" == search=* ]] && printf '%s\n' "${arg}" >"${FAKE_DIR}/spl.log"
done
cat "${FAKE_DIR}/response"
CURL
chmod +x "${TMP}/bin/curl"

# Runs mcp_auth_failures against the canned response $1; prints its stdout.
run() {
  printf '%b' "$1" >"${TMP}/response"
  FAKE_DIR="${TMP}" PATH="${TMP}/bin:${PATH}" SPLUNK_ADMIN_PASSWORD=test \
    bash -c '. "$0"; mcp_auth_failures' "${REPO}/scripts/mcp-auth-failures.sh" 2>/dev/null
}

# 1. A quiet window (Splunk returns 0,0 for stats count) is GO, not an error.
out="$(run '"tool_calls","failed_auths"\n0,0\n')" || die "empty window treated as an error"
grep -qx 'tool_calls=0 failed_auths=0 window=30m' <<<"${out}" || die "unexpected output: ${out}"
grep -q '^GO:' <<<"${out}" || die "empty window is not GO"

# 2. stats count(), not sum(): sum() returns no row when nothing matched.
grep -q 'stats count(eval(' "${TMP}/spl.log" || die "summary search does not use stats count()"
grep -q 'sum(' "${TMP}/spl.log" && die "summary search uses sum(), which returns no row on a quiet window"

# 3. Auth failures are reported.
out="$(run '"tool_calls","failed_auths"\r\n3,1\r\n')" || die "failure run errored"
grep -qx 'tool_calls=3 failed_auths=1 window=30m' <<<"${out}" || die "unexpected output: ${out}"
grep -q '^FIX:' <<<"${out}" || die "failed_auths=1 is not FIX"

# 4. A failed search (here a 401 body) is still an error.
if run '<response><messages><msg type="ERROR">Unauthorized</msg></messages></response>\n' >/dev/null; then
  die "401 response accepted"
fi

echo "OK: mcp-auth-failures counts a quiet window as 0 and still fails on errors"
