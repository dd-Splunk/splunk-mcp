#!/usr/bin/env bash
# Compare compose.yml SPLUNK_APPS_URL pins to Splunkbase current defaults.
# No secrets. Public API: https://splunkbase.splunk.com/api/v1/app/<id>/release/
#
# Exit 0: printed OK / STALE / MISSING / SKIP (MISSING is a next-boot 404 risk).
# Exit 1: compose.yml could not be parsed, or STRICT=1 and any pin is MISSING.
# Env: COMPOSE_FILE (default compose.yml), STRICT=1, SPLUNKBASE_PIN_TIMEOUT (default 15)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPOSE_FILE="${COMPOSE_FILE:-compose.yml}"
STRICT="${STRICT:-0}"
TIMEOUT="${SPLUNKBASE_PIN_TIMEOUT:-15}"

if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "error: missing ${COMPOSE_FILE}" >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || {
  echo "error: python3 is required for Splunkbase pin checks" >&2
  exit 1
}

export COMPOSE_FILE TIMEOUT STRICT
python3 - <<'PY'
import json
import os
import re
import sys
import urllib.error
import urllib.request
from urllib.parse import urlparse

compose_path = os.environ["COMPOSE_FILE"]
timeout = float(os.environ.get("TIMEOUT", "15"))
strict = os.environ.get("STRICT", "0").lower() in ("1", "true", "yes")

text = open(compose_path, encoding="utf-8").read()
match = re.search(r"^\s*SPLUNK_APPS_URL:\s*(\S+)", text, re.MULTILINE)
if not match:
    print("error: SPLUNK_APPS_URL not found in", compose_path, file=sys.stderr)
    sys.exit(1)

pins = []
skipped = []
for url in match.group(1).split(","):
    url = url.strip().rstrip(",")
    if not url:
        continue
    host = urlparse(url).hostname or ""
    parsed = re.search(r"/app/(\d+)/release/([^/]+)/download", url)
    if host != "splunkbase.splunk.com":
        skipped.append(url)
        continue
    if not parsed:
        print("error: could not parse app id/version from", url, file=sys.stderr)
        sys.exit(1)
    pins.append((parsed.group(1), parsed.group(2), url))

if not pins:
    print("error: no Splunkbase pins in SPLUNK_APPS_URL", file=sys.stderr)
    sys.exit(1)

print("=== Splunkbase pins (compose.yml vs api/v1/app/<id>/release/) ===")
print(f"{'app':<8} {'pin':<12} {'latest':<12} status")

worst = "OK"
any_skip = False
for app_id, pin, _url in pins:
    api = f"https://splunkbase.splunk.com/api/v1/app/{app_id}/release/"
    req = urllib.request.Request(
        api,
        headers={"User-Agent": "splunk-mcp-pin-check/1.0", "Accept": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
        print(f"{app_id:<8} {pin:<12} {'?':<12} SKIP ({exc.__class__.__name__})")
        any_skip = True
        continue

    if not isinstance(body, list) or not body:
        print(f"{app_id:<8} {pin:<12} {'?':<12} SKIP (empty release list)")
        any_skip = True
        continue

    names = [str(item.get("name", "")) for item in body if item.get("name")]
    latest = names[0] if names else "?"
    if pin == latest:
        status = "OK"
    elif pin in names:
        status = "STALE"
        if worst == "OK":
            worst = "STALE"
    else:
        status = "MISSING"
        worst = "MISSING"
    print(f"{app_id:<8} {pin:<12} {latest:<12} {status}")

for url in skipped:
    print(f"{'—':<8} {'—':<12} {'—':<12} SKIP (not Splunkbase) {url}")

if any_skip and worst == "OK":
    worst = "SKIP"

print(f"RESULT: {worst}")
sys.stdout.flush()
if worst == "MISSING":
    print(
        "MISSING pin is not on Splunkbase — next make up can 404 and leave so1 unhealthy "
        "(ansible: Error downloading ... Not Found). Bump only /release/VERSION/ in compose.yml; "
        "see docs/poc/CONFIGURATION.md § Version bump workflow.",
        file=sys.stderr,
    )
elif worst == "STALE":
    print(
        "STALE: pin still publishes but Splunkbase default is newer. Optional bump before the next make up.",
        file=sys.stderr,
    )

if strict and worst == "MISSING":
    sys.exit(1)
sys.exit(0)
PY
