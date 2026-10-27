#!/usr/bin/env bash
# Docker-free checks for splunk_curl (scripts/splunk-api-env.sh): the admin password reaches
# curl through a -K config on fd 3, never through its arguments. A fake curl records both.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
die() { echo "FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/splunk-curl.XXXXXX")"
trap 'rm -rf "${TMP}"' EXIT
mkdir -p "${TMP}/bin"

# Writes argv to args.log, the -K config to config.log, and stdin to stdin.log.
cat >"${TMP}/bin/curl" <<'CURL'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${FAKE_DIR}/args.log"
[[ "$1" == -K ]] || { echo "first argument is not -K" >&2; exit 2; }
cat "$2" >"${FAKE_DIR}/config.log"
[[ -t 0 ]] || cat >"${FAKE_DIR}/stdin.log"
CURL
chmod +x "${TMP}/bin/curl"

# Runs splunk_curl under the given shell with the fake curl.
run() { # $1 = shell, $2 = password, rest = curl args
  local shell="$1" pw="$2"
  shift 2
  # shellcheck disable=SC2016 # $0 and $@ belong to the inner shell
  FAKE_DIR="${TMP}" PATH="${TMP}/bin:${PATH}" SPLUNK_ADMIN_PASSWORD="${pw}" \
    "${shell}" -c '. "$0"; splunk_curl "$@"' "${REPO}/scripts/splunk-api-env.sh" "$@"
}

# shellcheck disable=SC2016 # literal $ and backticks are the point
pw='p@ss "q" \x\\y $HOME `id` é'
# shellcheck disable=SC2016
want='user = "admin:p@ss \"q\" \\x\\\\y $HOME `id` é"'

# 1. Quotes and backslashes are escaped; nothing else is expanded. Both the bash scripts
#    and setup-splunk.sh (#!/bin/sh) source the helper.
for shell in bash sh; do
  run "${shell}" "${pw}" -s https://localhost:8089/services/server/info </dev/null \
    || die "${shell}: splunk_curl failed"
  [[ "$(cat "${TMP}/config.log")" == "${want}" ]] \
    || die "${shell}: unexpected config: $(cat "${TMP}/config.log")"
  # 2. The password is not an argument.
  grep -qF 'p@ss' "${TMP}/args.log" && die "${shell}: password in curl arguments"
  [[ "$(tail -1 "${TMP}/args.log")" == https://localhost:8089/services/server/info ]] \
    || die "${shell}: caller arguments not passed through"
done

# 3. SPLUNK_REST_USER is honoured.
SPLUNK_REST_USER=ops run bash secret -s https://x </dev/null || die "custom user failed"
[[ "$(cat "${TMP}/config.log")" == 'user = "ops:secret"' ]] || die "SPLUNK_REST_USER ignored"

# 4. stdin stays free for a second secret (setup-splunk.sh sends the splunker password there).
printf '%s' 'splunker-pw' | run bash secret --data-urlencode password@- https://x \
  || die "stdin run failed"
[[ "$(cat "${TMP}/stdin.log")" == splunker-pw ]] || die "stdin not passed to curl"

# 5. A line break would end the config line and inject curl options, so it is refused.
if run bash "$(printf 'a\nb')" https://x </dev/null 2>/dev/null; then
  die "password with a newline accepted"
fi
if run bash '' https://x </dev/null 2>/dev/null; then
  die "empty password accepted"
fi

# 6. No script passes the admin password to curl -u again.
if grep -nE -- '-u "?\$\{?[A-Za-z_]*\}?:\$\{?SPLUNK_ADMIN_PASSWORD' "${REPO}"/scripts/*.sh; then
  die "scripts pass SPLUNK_ADMIN_PASSWORD on the curl command line (use splunk_curl)"
fi

# 7. No script shadows the helper: a local splunk_curl that calls splunk_curl recurses
#    without end (each call forks a $(…) subshell).
if grep -nE '^[[:space:]]*(function[[:space:]]+)?splunk_curl(_quote)?[[:space:]]*\(\)' "${REPO}"/scripts/*.sh \
  | grep -v '^[^:]*/splunk-api-env\.sh:'; then
  die "scripts redefine splunk_curl (only scripts/splunk-api-env.sh may define it)"
fi

echo "OK: splunk_curl keeps the admin password out of curl arguments"
