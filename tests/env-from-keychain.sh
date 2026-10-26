#!/usr/bin/env bash
# Docker-free checks for scripts/env-from-keychain.sh, using a fake 'security' (no real keychain).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="${ROOT}/scripts/env-from-keychain.sh"

die() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/env-from-keychain.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
mkdir "${TMP}/bin"

# Fake keychain: one file per service holding "account<TAB>password".
cat >"${TMP}/bin/security" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == find-generic-password ]] || exit 2
shift
svc="" want_pw=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) svc="$2"; shift 2 ;;
    -a) shift 2 ;;
    -w) want_pw=1; shift ;;
    *) exit 2 ;;
  esac
done
item="${FAKE_KEYCHAIN:?}/${svc}"
[[ -f "$item" ]] || { echo "security: item not found" >&2; exit 44; }
IFS=$'\t' read -r acct pw <"$item"
if [[ "$want_pw" == 1 ]]; then
  printf '%s\n' "$pw"
else
  printf '    "acct"<blob>="%s"\n    "svce"<blob>="%s"\n' "$acct" "$svc"
fi
EOF
chmod +x "${TMP}/bin/security"

export FAKE_KEYCHAIN="${TMP}/keychain"
mkdir "$FAKE_KEYCHAIN"
# A literal $ and spaces must survive quoting, unexpanded.
# shellcheck disable=SC2016
DEMO_PW='demo pass$1'
printf '%s\t%s\n' me "$DEMO_PW" >"${FAKE_KEYCHAIN}/S4R-demo"
printf '%s\t%s\n' sb_user 'sb pass"2' >"${FAKE_KEYCHAIN}/splunkbase"

run() { PATH="${TMP}/bin:${PATH}" ENV_OUT="${TMP}/dotenv" "$SCRIPT" "$@"; }

run >"${TMP}/out" 2>&1 || { cat "${TMP}/out" >&2; die "script failed"; }
grep -q 'demo pass\|sb pass' "${TMP}/out" && die "script printed a secret"
[[ "$(stat -c '%a' "${TMP}/dotenv" 2>/dev/null || stat -f '%Lp' "${TMP}/dotenv")" == 600 ]] \
  || die ".env is not mode 600"

# The file must load literally in bash (as with-splunk-env.sh does).
# shellcheck disable=SC1091
( set -a; . "${TMP}/dotenv"
  [[ "$SPLUNK_ADMIN_PASSWORD" == "$DEMO_PW" ]] || die "admin password wrong"
  [[ "$SPLUNK_SPLUNKER_PASSWORD" == "$DEMO_PW" ]] || die "splunker password wrong"
  [[ "$SPLUNKBASE_USER" == sb_user ]] || die "splunkbase user should come from the item account"
  [[ "$SPLUNKBASE_PASS" == 'sb pass"2' ]] || die "splunkbase password wrong"
)

# Existing file is kept without --force.
echo 'KEEP=1' >"${TMP}/dotenv"
run 2>/dev/null && die "should refuse to overwrite without --force"
grep -qx 'KEEP=1' "${TMP}/dotenv" || die "existing file was changed"
run --force >/dev/null || die "--force failed"
grep -q '^SPLUNK_ADMIN_PASSWORD=' "${TMP}/dotenv" || die "--force did not rewrite"

# Missing item fails and leaves no file.
rm -f "${TMP}/dotenv" "${FAKE_KEYCHAIN}/splunkbase"
run 2>"${TMP}/err" && die "missing splunkbase item should fail"
grep -q "keychain item 'splunkbase' not found" "${TMP}/err" || die "missing-item error lacks hint"
[[ ! -e "${TMP}/dotenv" ]] || die "partial .env written"

# A single quote cannot be written safely.
printf '%s\t%s\n' sb_user "it's" >"${FAKE_KEYCHAIN}/splunkbase"
run 2>/dev/null && die "single quote should be rejected"
[[ ! -e "${TMP}/dotenv" ]] || die ".env written despite unsafe value"
ls "${TMP}"/dotenv.* >/dev/null 2>&1 && die "temp file left behind"

grep -q 'env-from-keychain.sh' "${ROOT}/scripts/compose-up.sh" || die "compose-up has no keychain fallback"

echo "env-from-keychain: ok"
