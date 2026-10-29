#!/usr/bin/env bash
# Docker-free checks that SA-S4R defines the s4r_user role without granting it any capability,
# and that setup-splunk.sh gives it to the MCP user only when the app really defines it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

AUTH=SA-S4R/default/authorize.conf

grep -qx '\[role_s4r_user\]' "${AUTH}" || die "authorize.conf does not define role s4r_user"

# the role's own settings: every line up to the next stanza header
settings="$(awk '$0 == "[role_s4r_user]" {f=1; next} /^\[/ {f=0} f && NF && $0 !~ /^#/' "${AUTH}")"
[[ -z "${settings}" ]] || die "role s4r_user must carry no settings (found: ${settings})"

awk '$0 == "[authorize]" {f=1; next} /^\[/ {f=0} f && /^export = system$/ {ok=1} END {exit !ok}' \
  SA-S4R/metadata/default.meta || die "default.meta does not export authorize to system"

SETUP=scripts/setup-splunk.sh

# splunker gets the role, but a missing role (older SA-S4R) must be skipped, not fail init
grep -q '"roles=s4r_user"' "${SETUP}" || die "setup-splunk.sh does not assign s4r_user to the MCP user"
grep -Eq 'authorization/roles/s4r_user' "${SETUP}" || die "setup-splunk.sh does not check that s4r_user exists first"
grep -Eq '^set -- -d "roles=user" -d "roles=mcp_user" -d "locked-out=false"$' "${SETUP}" \
  || die "setup-splunk.sh lost the base roles (user, mcp_user)"
n_assign="$(grep -c '"roles=s4r_user"' "${SETUP}")"
[[ "${n_assign}" -eq 1 ]] || die "roles=s4r_user must be assigned in exactly one place (found ${n_assign})"
awk '/^(if|fi)( |$)/ {last=$0} /"roles=s4r_user"/ {exit !(last ~ /s4r_role_ok/)}' "${SETUP}" \
  || die "roles=s4r_user is not behind the s4r_role_ok check"

echo "OK: SA-S4R defines the s4r_user role with no capability and splunker gets it when it exists"
