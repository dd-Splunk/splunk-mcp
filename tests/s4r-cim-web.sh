#!/usr/bin/env bash
# Docker-free checks that SA-S4R keeps the CIM Web mapping wired up (no Splunk needed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

APP=SA-S4R

# props.conf: every CIM field the Web data model reads from this sourcetype
for field in src http_method http_referrer http_user_agent bytes_out; do
  grep -Eq "^FIELDALIAS-cim_[a-z_]+ = .*AS ${field}( |$)" "${APP}/default/props.conf" \
    || die "props.conf has no FIELDALIAS for ${field}"
done
for field in http_referrer_domain http_user_agent_length site dest url url_domain url_length vendor_product; do
  grep -Eq "^EVAL-${field} = " "${APP}/default/props.conf" || die "props.conf has no EVAL for ${field}"
done

# Workshop searches use the cart verb in `action`; CIM must not overwrite it.
if grep -Eq '^EVAL-action = |^FIELDALIAS-[A-Za-z_]+ = .* AS action( |$)' "${APP}/default/props.conf"; then
  die "props.conf redefines action"
fi
grep -q '^EXTRACT-action = ' "${APP}/default/props.conf" || die "props.conf lost the action extraction"

# the tag that puts the events in the Web data model, and the exports that let Splunk_SA_CIM see it
grep -Eq '^search = .*sourcetype=access_combined' "${APP}/default/eventtypes.conf" \
  || die "eventtypes.conf does not match access_combined"
etype="$(sed -n 's/^\[\(s4r_[a-z_]*\)\]$/\1/p' "${APP}/default/eventtypes.conf" | head -1)"
[[ -n "${etype}" ]] || die "eventtypes.conf has no s4r_* eventtype"
awk -v s="[eventtype=${etype}]" '$0 == s {f=1; next} /^\[/ {f=0} f && /^web = enabled$/ {ok=1} END {exit !ok}' \
  "${APP}/default/tags.conf" || die "tags.conf does not tag ${etype} as web"
for stanza in eventtypes tags; do
  awk -v s="[${stanza}]" '$0 == s {f=1; next} /^\[/ {f=0} f && /^export = system$/ {ok=1} END {exit !ok}' \
    "${APP}/metadata/default.meta" || die "default.meta does not export ${stanza} to system"
done

# the Web data model ships in the CIM app, so compose must install it
grep -Eq 'SPLUNK_APPS_URL:.*splunkbase\.splunk\.com/app/1621/release/[0-9.]+/download/' compose.yml \
  || die "compose.yml does not install the Splunk CIM app (Splunkbase 1621)"

echo "OK: SA-S4R maps access_combined to CIM Web and compose installs the CIM app"
