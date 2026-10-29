#!/usr/bin/env bash
# Docker-free checks that SA-S4R keeps the CIM Web mapping wired up (no Splunk needed).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

die() { echo "FAIL: $*" >&2; exit 1; }

APP=SA-S4R

# props.conf: every CIM field the Web data model reads from this sourcetype
for field in src dest site url_domain http_method http_referrer http_user_agent bytes_out; do
  grep -Eq "^FIELDALIAS-cim_[a-z_]+ = .*AS ${field}( |$)" "${APP}/default/props.conf" \
    || die "props.conf has no FIELDALIAS for ${field}"
done
for field in http_referrer_domain http_user_agent_length url url_length vendor_product; do
  grep -Eq "^EVAL-${field} = " "${APP}/default/props.conf" || die "props.conf has no EVAL for ${field}"
done

# Workshop searches use the cart verb in `action`; CIM must not overwrite it.
if grep -Eq '^EVAL-action = |^FIELDALIAS-[A-Za-z_]+ = .* AS action( |$)' "${APP}/default/props.conf"; then
  die "props.conf redefines action"
fi
grep -q '^EXTRACT-action = ' "${APP}/default/props.conf" || die "props.conf lost the action extraction"

# dest, site and url come from host, not from constants in props.conf
if grep -Eq '^EVAL-(dest|site|url_domain) = ' "${APP}/default/props.conf"; then
  die "props.conf hard-codes dest, site or url_domain; they come from host"
fi
# host comes from Eventgen ([global] reaches every sample stanza), so no index-time override is needed
grep -Eq '^host = www\.buttercupenterprises\.com$' "${APP}/default/eventgen.conf" \
  || die "eventgen.conf [global] does not set the shop host"
awk '$0 == "[global]" {f=1; next} /^\[/ {f=0} f && /^host = /{ok=1} END {exit !ok}' "${APP}/default/eventgen.conf" \
  || die "host is not set in eventgen.conf [global]"
if grep -q 's4r_set_host' "${APP}/default/props.conf" "${APP}/default/transforms.conf"; then
  die "the index-time host override is back; set host in eventgen.conf instead"
fi

# the tag that marks the events as CIM Web, and the exports that let a CIM install see it
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

# this repo does not install the CIM app: the mapping stays, the Splunkbase pin must not come back
if grep -Eq 'splunkbase\.splunk\.com/app/1621/' compose.yml; then
  die "compose.yml installs the CIM app (Splunkbase 1621); the S4R stack does not need it"
fi

echo "OK: SA-S4R keeps CIM Web field names and the web tag, and the stack does not install the CIM app"
