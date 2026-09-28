#!/usr/bin/env bash
# Docker-free checks for scripts/with-splunk-env.sh (no Splunk, no real secrets).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER="${ROOT}/scripts/with-splunk-env.sh"

die() { echo "FAIL: $*" >&2; exit 1; }

[[ -f "$HELPER" ]] || die "missing $HELPER"

for script in mint-mcp-token.sh register-s4r-mcp-tools.sh mcp-auth-failures.sh \
  toggle-s4r-attack-nk.sh compose-up.sh compose-config.sh; do
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
grep -q 'load_config_env' "${ROOT}/scripts/compose-config.sh" || die "compose-config does not load config.env"
grep -q 'redact_compose_secrets' "${ROOT}/scripts/compose-config.sh" || die "compose-config does not redact secrets"

# shellcheck source=scripts/compose-config.sh
source "${ROOT}/scripts/compose-config.sh"
redacted="$(printf '%s\n' \
  '    image: splunk/splunk:10.4' \
  '    SPLUNK_PASSWORD: your_password_here' \
  '    SPLUNKBASE_USERNAME: "your_password_here"' \
  '    SPLUNKBASE_PASSWORD: '"'"'your_password_here'"'" \
  '    SPLUNK_MCP_PASSWORD: ""' \
  '    TZ: Europe/Brussels' | redact_compose_secrets)"
printf '%s\n' "$redacted" | grep -qx '    image: splunk/splunk:10.4' || die "image line changed"
printf '%s\n' "$redacted" | grep -qx '    TZ: Europe/Brussels' || die "timezone line changed"
printf '%s\n' "$redacted" | grep -qx '    SPLUNK_PASSWORD: <set>' || die "password not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNKBASE_USERNAME: <set>' || die "splunkbase user not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNKBASE_PASSWORD: <set>' || die "splunkbase password not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNK_MCP_PASSWORD: ""' || die "empty mcp password should stay empty"
if printf '%s\n' "$redacted" | grep -q 'your_password_here'; then
  die "redaction left a secret value"
fi

cat >"${TMP}/dotenv" <<'EOF'
SPLUNK_PASSWORD=your_password_here
SPLUNKBASE_USER=your_password_here
SPLUNKBASE_PASS=your_password_here
SPLUNK_MCP_PASSWORD=your_password_here
EOF
cat >"${TMP}/fake-dc" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' \
  "image: ${SPLUNK_IMAGE}" \
  "SPLUNK_PASSWORD: ${SPLUNK_PASSWORD}" \
  "TZ: ${TZ}"
EOF
chmod +x "${TMP}/fake-dc"
rendered="$(ENV_OUT="${TMP}/dotenv" ENV_FILE="${TMP}/missing-tpl.env" OP="${TMP}/should-not-run" \
  CONFIG_ENV="${ROOT}/config.env" DC="${TMP}/fake-dc" \
  "${ROOT}/scripts/compose-config.sh")"
printf '%s\n' "$rendered" | grep -qx "image: $(sed -n 's/^SPLUNK_IMAGE=//p' "${ROOT}/config.env")" \
  || die "compose-config did not apply SPLUNK_IMAGE"
printf '%s\n' "$rendered" | grep -qx 'SPLUNK_PASSWORD: <set>' || die "compose-config printed a password"
if printf '%s\n' "$rendered" | grep -q 'your_password_here'; then
  die "compose-config output contained a secret"
fi
if grep -E 'MLTK_ROLE|SPLUNK_MLTK_USER' \
  "${ROOT}/scripts/"*.sh "${ROOT}/compose.yml" >/dev/null; then
  die "scripts still read MLTK identity settings from the environment"
fi
grep -q 'SPLUNK_MCP_USER="splunker"' "${ROOT}/scripts/setup-splunk.sh" \
  && die "setup-splunk.sh overwrites SPLUNK_MCP_USER after its default"

for script in setup-splunk.sh register-s4r-mcp-tools.sh toggle-s4r-attack-nk.sh \
  mint-mcp-token.sh mcp-auth-failures.sh; do
  grep -q 'splunk_api_env' "${ROOT}/scripts/${script}" \
    || die "${script} does not use splunk_api_env"
done
if grep -E 'SPLUNK_MCP_HOST|SPLUNK_REST_USER="admin"|mcp_user="splunker"' \
  "${ROOT}/scripts/setup-splunk.sh" "${ROOT}/scripts/register-s4r-mcp-tools.sh" \
  "${ROOT}/scripts/toggle-s4r-attack-nk.sh" "${ROOT}/scripts/mint-mcp-token.sh" \
  "${ROOT}/scripts/mcp-auth-failures.sh" >/dev/null; then
  die "a REST client still hardcodes host or account names"
fi
for mount in \
  'scripts/splunk-api-env.sh:/opt/splunk-init/scripts/splunk-api-env.sh:ro' \
  'scripts/register-s4r-mcp-tools.sh:/opt/splunk-init/scripts/register-s4r-mcp-tools.sh:ro' \
  'SA-S4R/default/s4r_mcp_tools.json:/opt/splunk-init/SA-S4R/default/s4r_mcp_tools.json:ro'; do
  grep -q "${mount}" "${ROOT}/compose.yml" \
    || die "compose.yml does not mount ${mount}"
done
grep -q 'register-s4r-mcp-tools.sh' "${ROOT}/scripts/setup-splunk.sh" \
  || die "setup-splunk.sh does not register SA-S4R MCP tools"
grep -q 'SPLUNK_HOST: so1' "${ROOT}/compose.yml" || die "compose.yml must set SPLUNK_HOST=so1"

# shellcheck source=scripts/splunk-api-env.sh
source "${ROOT}/scripts/splunk-api-env.sh"
unset SPLUNK_HOST SPLUNK_PORT SPLUNK_REST_USER SPLUNK_MCP_USER
splunk_api_env
[[ "${SPLUNK_HOST}" == "localhost" && "${SPLUNK_PORT}" == "8089" \
  && "${SPLUNK_REST_USER}" == "admin" && "${SPLUNK_MCP_USER}" == "splunker" ]] \
  || die "splunk_api_env defaults"
SPLUNK_HOST=so1
splunk_api_env
[[ "${SPLUNK_HOST}" == "so1" ]] || die "splunk_api_env overwrote SPLUNK_HOST"

echo "with-splunk-env: ok"
