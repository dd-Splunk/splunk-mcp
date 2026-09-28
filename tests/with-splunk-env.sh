#!/usr/bin/env bash
# Docker-free checks for scripts/with-splunk-env.sh (no Splunk, no real secrets).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="${ROOT}/scripts/with-splunk-env.sh"

die() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$HELPER" ]] || die "missing $HELPER"

for script in mint-mcp-token.sh register-s4r-mcp-tools.sh mcp-auth-failures.sh \
  toggle-s4r-attack-nk.sh compose-up.sh; do
  grep -q 'with_splunk_env "$@"' "${ROOT}/scripts/${script}" \
    || die "${script} does not call with_splunk_env"
done

TMP="$(mktemp -d "${TMPDIR:-/tmp}/with-splunk-env.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT

cat >"${TMP}/caller.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/with-splunk-env.sh
source "${HELPER}"
with_splunk_env "\$@"
[[ "\${SPLUNK_PASSWORD:-}" == "\${EXPECT:?}" ]] || {
  echo "secret not loaded" >&2
  exit 1
}
[[ "\${1:-}" == "\${EXPECT_ARG:?}" ]] || {
  echo "argument not forwarded" >&2
  exit 1
}
echo "ok"
EOF
chmod +x "${TMP}/caller.sh"

# Path B: source .env in-process. Must not invoke op.
printf '%s\n' 'SPLUNK_PASSWORD=your_password_here' >"${TMP}/dotenv"
op_count="${TMP}/op-count"
: >"${op_count}"
ENV_OUT="${TMP}/dotenv" \
  ENV_FILE="${TMP}/missing-tpl.env" \
  OP="${TMP}/should-not-run" \
  EXPECT=your_password_here \
  EXPECT_ARG=status \
  "${TMP}/caller.sh" status | grep -qx 'ok' || die "path B did not load dotenv"
[[ ! -s "${op_count}" ]] || die "path B invoked op"

# Path A: re-exec once under a fake op. Second invocation must not loop.
cat >"${TMP}/fake-op" <<EOF
#!/usr/bin/env bash
set -euo pipefail
count_file="${op_count}"
n=0
[[ -s "\$count_file" ]] && n="\$(tr -d '[:space:]' <"\$count_file")"
n=\$((n + 1))
printf '%s\n' "\$n" >"\$count_file"
[[ "\$n" -eq 1 ]] || { echo "op loop" >&2; exit 9; }
[[ "\${1:-}" == "run" ]] || exit 2
[[ "\${2:-}" == --env-file=* ]] || exit 3
[[ "\${3:-}" == "--" ]] || exit 4
shift 3
export SPLUNK_PASSWORD="\${OP_INJECT:?}"
exec "\$@"
EOF
chmod +x "${TMP}/fake-op"
printf '%s\n' 'SPLUNK_PASSWORD=op://YourVault/item/password' >"${TMP}/tpl.env"
ENV_OUT="${TMP}/missing.env" \
  ENV_FILE="${TMP}/tpl.env" \
  OP="${TMP}/fake-op" \
  OP_INJECT=your_splunker_password \
  EXPECT=your_splunker_password \
  EXPECT_ARG=status \
  "${TMP}/caller.sh" status | grep -qx 'ok' || die "path A did not re-exec"
[[ "$(tr -d '[:space:]' <"${op_count}")" == "1" ]] || die "path A op count"

# Neither file.
if ENV_OUT="${TMP}/no.env" ENV_FILE="${TMP}/no.tpl" "${TMP}/caller.sh" status >/dev/null 2>"${TMP}/err"; then
  die "missing files should fail"
fi
grep -q 'Path B' "${TMP}/err" || die "missing-file error lacks Path B hint"

# tpl.env present, op binary missing.
if ENV_OUT="${TMP}/no.env" ENV_FILE="${TMP}/tpl.env" OP="${TMP}/no-such-op" \
  "${TMP}/caller.sh" status >/dev/null 2>"${TMP}/err"; then
  die "missing op should fail"
fi
grep -q 'not available' "${TMP}/err" || die "missing-op error"

for secret_file in tpl.env.example .env.example; do
  if grep -E '^(SPLUNK_IMAGE|TZ)=' "${ROOT}/${secret_file}" >/dev/null; then
    die "${secret_file} still sets SPLUNK_IMAGE or TZ"
  fi
done
grep -E '^SPLUNK_IMAGE=' "${ROOT}/config.env" >/dev/null || die "config.env missing SPLUNK_IMAGE"
grep -E '^TZ=' "${ROOT}/config.env" >/dev/null || die "config.env missing TZ"
grep -q 'load_config_env' "${ROOT}/scripts/compose-up.sh" || die "compose-up does not load config.env"
if grep -E 'SPLUNK_(REST|MCP|MLTK)_USER:-|MLTK_ROLE|SPLUNK_MLTK_USER' \
  "${ROOT}/scripts/"*.sh "${ROOT}/compose.yml" >/dev/null; then
  die "scripts still read identity overrides from the environment"
fi

echo "with-splunk-env: ok"
