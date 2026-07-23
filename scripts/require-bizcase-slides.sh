#!/usr/bin/env bash
# Fail with a clear message if local-only Claude Enterprise bizcase sources are absent.
# Usage: ./scripts/require-bizcase-slides.sh <filename under demo-slides/>
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REL="${1:?usage: require-bizcase-slides.sh <file under demo-slides/>}"
TARGET="${ROOT}/demo-slides/${REL}"

if [[ ! -f "$TARGET" ]]; then
  echo "Error: missing demo-slides/${REL}" >&2
  echo "" >&2
  echo "Claude Enterprise business case slides are local-only (gitignored: demo-slides/claude-enterprise-*)." >&2
  echo "Add the .md source under demo-slides/ locally, or see demo-slides/README.md." >&2
  exit 1
fi
