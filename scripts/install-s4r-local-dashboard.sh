#!/usr/bin/env bash
# Copy Buttercup workshop dashboard assets from local.example/ to local/ (gitignored).
# Idempotent; safe to re-run after pulling repo updates.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${ROOT}/SA-S4R"
SRC="${APP}/local.example"
DST="${APP}/local"

if [[ ! -d "${SRC}" ]]; then
  echo "Error: missing ${SRC}" >&2
  exit 1
fi

mkdir -p "${DST}"
# Preserve other local/ customizations; overlay workshop files from the template.
cp -R "${SRC}/." "${DST}/"

echo "Installed Buttercup workshop assets under ${DST}/"
echo "  - props.conf (platform field extraction, Lab 4)"
echo "  - data/ui/nav/local.xml (app tab)"
echo "  - data/ui/views/buttercup_enterprises_dashboard.xml"
echo "  - metadata/local.meta"
echo ""
echo "If Splunk is running: make restart"
