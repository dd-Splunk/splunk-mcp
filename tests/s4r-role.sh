#!/usr/bin/env bash
# Docker-free check that SA-S4R defines the s4r_user role without granting it any capability.
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

echo "OK: SA-S4R defines the s4r_user role with no capability"
