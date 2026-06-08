#!/usr/bin/env bash
# Print splunk-init container status (for make status).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/wait-splunk-init.sh
source "${ROOT}/scripts/wait-splunk-init.sh"

report_splunk_init_status
