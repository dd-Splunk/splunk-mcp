#!/usr/bin/env bash
# Docker-free checks on how setup-splunk.sh sets the capabilities of the mcp_user role.
# Splunk replaces the whole capability list on a role POST, so an early POST that carries only
# some capabilities would strip the rest on every re-run of init.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

SETUP=scripts/setup-splunk.sh
WANT="mcp_tool_execute s4r_workshop_control list_introspection"

# 1. Existing role: the update POST must not send any capabilities.
exists_block="$(awk '
  /^if \[ "\$\{role_exists\}" = "1" \]; then$/ {f=1; next}
  f && /^else$/ {exit}
  f {print}
' "${SETUP}")"
[[ -n "${exists_block}" ]] || die "could not find the role_exists branch in ${SETUP}"
if grep -q 'capabilities=' <<<"${exists_block}"; then
  die "the existing-role update POST sends capabilities and would strip the rest (replace semantics)"
fi
grep -q 'srchJobsQuota=5' <<<"${exists_block}" || die "the existing-role update POST lost srchJobsQuota=5"

# 2. The grant loop (inside the s4r_cap_ok retry) sets the full list in one POST.
grant_block="$(awk '
  /^while \[ "\$n" -lt 8 \]; do$/ {f=1}
  f {print}
  f && /^done$/ {exit}
' "${SETUP}")"
[[ -n "${grant_block}" ]] || die "could not find the capability grant loop in ${SETUP}"
for cap in ${WANT}; do
  grep -q "\"capabilities=${cap}\"" <<<"${grant_block}" || die "the grant loop does not set ${cap}"
done
n_caps="$(grep -c '"capabilities=' <<<"${grant_block}")"
[[ "${n_caps}" -eq 3 ]] || die "the grant loop must send exactly the 3 expected capabilities (found ${n_caps})"

# 3. A new role is created with mcp_tool_execute only (the others need the SA-S4R reload first).
create_block="$(awk '
  /^if \[ "\$\{role_exists\}" = "1" \]; then$/ {f=1}
  f && /^else$/ {g=1; next}
  g && /^fi$/ {exit}
  g {print}
' "${SETUP}")"
grep -q '"capabilities=mcp_tool_execute"' <<<"${create_block}" || die "the role create POST lost mcp_tool_execute"

echo "OK: mcp_user capabilities are set once, in full (${WANT}); the existing-role update sends none"
