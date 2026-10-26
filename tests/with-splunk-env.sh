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
[[ "\${SPLUNK_ADMIN_PASSWORD:-}" == "\${EXPECT:?}" ]] || {
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

# .env is sourced in-process.
printf '%s\n' 'SPLUNK_ADMIN_PASSWORD=your_password_here' >"${TMP}/dotenv"
env -u SPLUNK_MCP_ENV_LOADED \
  ENV_OUT="${TMP}/dotenv" \
  EXPECT=your_password_here \
  EXPECT_ARG=status \
  "${TMP}/caller.sh" status | grep -qx 'ok' || die "dotenv did not load"

# No file: an already-exported password is enough.
env -u SPLUNK_MCP_ENV_LOADED \
  ENV_OUT="${TMP}/missing.env" \
  SPLUNK_ADMIN_PASSWORD=your_splunker_password \
  EXPECT=your_splunker_password \
  EXPECT_ARG=status \
  "${TMP}/caller.sh" status | grep -qx 'ok' || die "inherited env did not load"

# .env wins over a different inherited value.
printf '%s\n' 'SPLUNK_ADMIN_PASSWORD=from_file' >"${TMP}/dotenv"
env -u SPLUNK_MCP_ENV_LOADED \
  ENV_OUT="${TMP}/dotenv" \
  SPLUNK_ADMIN_PASSWORD=from_env \
  EXPECT=from_file \
  EXPECT_ARG=status \
  "${TMP}/caller.sh" status | grep -qx 'ok' || die ".env did not override the environment"

# Neither file nor password.
if env -u SPLUNK_MCP_ENV_LOADED -u SPLUNK_ADMIN_PASSWORD \
  ENV_OUT="${TMP}/no.env" "${TMP}/caller.sh" status >/dev/null 2>"${TMP}/err"; then
  die "missing secrets should fail"
fi
grep -q '.env.example' "${TMP}/err" || die "missing-secret error lacks .env.example hint"

# Old variable names fail with a rename hint.
printf '%s\n' 'SPLUNK_PASSWORD=your_password_here' >"${TMP}/old.env"
if env -u SPLUNK_MCP_ENV_LOADED -u SPLUNK_ADMIN_PASSWORD \
  ENV_OUT="${TMP}/old.env" "${TMP}/caller.sh" status >/dev/null 2>"${TMP}/err"; then
  die "old SPLUNK_PASSWORD name should fail"
fi
grep -q 'renamed to SPLUNK_ADMIN_PASSWORD' "${TMP}/err" || die "old-name error lacks rename hint"
if env -u SPLUNK_MCP_ENV_LOADED -u SPLUNK_SPLUNKER_PASSWORD \
  ENV_OUT="${TMP}/missing.env" SPLUNK_ADMIN_PASSWORD=x SPLUNK_MCP_PASSWORD=y \
  "${TMP}/caller.sh" status >/dev/null 2>"${TMP}/err"; then
  die "old SPLUNK_MCP_PASSWORD name should fail"
fi
grep -q 'renamed to SPLUNK_SPLUNKER_PASSWORD' "${TMP}/err" || die "old-name error lacks rename hint"

# Container shortcut: splunk-init already has secrets and does not mount .env.
(
  # shellcheck source=scripts/with-splunk-env.sh
  source "${HELPER}"
  ENV_OUT="${TMP}/no.env" SPLUNK_MCP_ENV_LOADED=1 with_splunk_env status
) || die "SPLUNK_MCP_ENV_LOADED should skip the .env lookup"

if grep -E 'op run|tpl\.env|1Password' "${ROOT}/scripts/"*.sh "${ROOT}/Makefile" >/dev/null; then
  die "scripts or Makefile still reference 1Password"
fi

if grep -E '^(SPLUNK_IMAGE|TZ)=' "${ROOT}/.env.example" >/dev/null; then
  die ".env.example still sets SPLUNK_IMAGE or TZ"
fi
grep -E '^SPLUNK_IMAGE=' "${ROOT}/config.env" >/dev/null || die "config.env missing SPLUNK_IMAGE"
grep -E '^TZ=' "${ROOT}/config.env" >/dev/null || die "config.env missing TZ"
grep -q 'load_config_env' "${ROOT}/scripts/compose-up.sh" || die "compose-up does not load config.env"
grep -q 'load_config_env' "${ROOT}/scripts/compose-config.sh" || die "compose-config does not load config.env"
grep -q 'redact_compose_secrets' "${ROOT}/scripts/compose-config.sh" || die "compose-config does not redact secrets"

# shellcheck source=scripts/compose-config.sh
source "${ROOT}/scripts/compose-config.sh"
redacted="$(printf '%s\n' \
  '    image: splunk/splunk:10.6.0' \
  '    SPLUNK_PASSWORD: your_password_here' \
  '    SPLUNK_ADMIN_PASSWORD: your_password_here' \
  '    SPLUNKBASE_USERNAME: "your_password_here"' \
  '    SPLUNKBASE_PASSWORD: '"'"'your_password_here'"'" \
  '    SPLUNK_SPLUNKER_PASSWORD: ""' \
  '    TZ: Europe/Brussels' | redact_compose_secrets)"
printf '%s\n' "$redacted" | grep -qx '    image: splunk/splunk:10.6.0' || die "image line changed"
printf '%s\n' "$redacted" | grep -qx '    TZ: Europe/Brussels' || die "timezone line changed"
printf '%s\n' "$redacted" | grep -qx '    SPLUNK_PASSWORD: <set>' || die "so1 password not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNK_ADMIN_PASSWORD: <set>' || die "password not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNKBASE_USERNAME: <set>' || die "splunkbase user not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNKBASE_PASSWORD: <set>' || die "splunkbase password not redacted"
printf '%s\n' "$redacted" | grep -qx '    SPLUNK_SPLUNKER_PASSWORD: ""' || die "empty splunker password should stay empty"
if printf '%s\n' "$redacted" | grep -q 'your_password_here'; then
  die "redaction left a secret value"
fi

cat >"${TMP}/dotenv" <<'EOF'
SPLUNK_ADMIN_PASSWORD=your_password_here
SPLUNKBASE_USER=your_password_here
SPLUNKBASE_PASS=your_password_here
SPLUNK_SPLUNKER_PASSWORD=your_password_here
EOF
cat >"${TMP}/fake-dc" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' \
  "image: ${SPLUNK_IMAGE}" \
  "SPLUNK_ADMIN_PASSWORD: ${SPLUNK_ADMIN_PASSWORD}" \
  "TZ: ${TZ}"
EOF
chmod +x "${TMP}/fake-dc"
rendered="$(ENV_OUT="${TMP}/dotenv" \
  CONFIG_ENV="${ROOT}/config.env" DC="${TMP}/fake-dc" \
  "${ROOT}/scripts/compose-config.sh")"
printf '%s\n' "$rendered" | grep -qx "image: $(sed -n 's/^SPLUNK_IMAGE=//p' "${ROOT}/config.env")" \
  || die "compose-config did not apply SPLUNK_IMAGE"
printf '%s\n' "$rendered" | grep -qx 'SPLUNK_ADMIN_PASSWORD: <set>' || die "compose-config printed a password"
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
grep -q 'releases/download/latest/SA-S4R.spl' "${ROOT}/compose.yml" \
  || die "compose.yml must install SA-S4R from the GitHub latest release"
if grep -q 'SA-S4R:/opt/splunk/etc/apps/SA-S4R' "${ROOT}/compose.yml"; then
  die "compose.yml still bind-mounts the SA-S4R app tree"
fi

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
