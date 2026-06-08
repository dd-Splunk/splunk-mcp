#!/usr/bin/env bash
# Wait until the splunk-init one-shot container has exited successfully.
# Usage: ./scripts/wait-splunk-init.sh
# Env: SPLUNK_INIT_CONTAINER (default splunk-init), SPLUNK_INIT_WAIT_ATTEMPTS (default 180),
#      SPLUNK_INIT_WAIT_INTERVAL (default 5)

set -euo pipefail

SPLUNK_INIT_CONTAINER="${SPLUNK_INIT_CONTAINER:-splunk-init}"
SPLUNK_INIT_WAIT_ATTEMPTS="${SPLUNK_INIT_WAIT_ATTEMPTS:-180}"
SPLUNK_INIT_WAIT_INTERVAL="${SPLUNK_INIT_WAIT_INTERVAL:-5}"

wait_splunk_init() {
  local status exit_code n=1

  command -v docker >/dev/null 2>&1 || {
    echo "Warning: docker not found; skipping splunk-init wait" >&2
    return 0
  }

  if ! docker inspect "$SPLUNK_INIT_CONTAINER" >/dev/null 2>&1; then
    echo "Warning: ${SPLUNK_INIT_CONTAINER} container not found; skipping init wait (run make up?)" >&2
    return 0
  fi

  echo "Waiting for ${SPLUNK_INIT_CONTAINER} to finish…" >&2

  while [[ "$n" -le "$SPLUNK_INIT_WAIT_ATTEMPTS" ]]; do
    status="$(docker inspect -f '{{.State.Status}}' "$SPLUNK_INIT_CONTAINER" 2>/dev/null || true)"
    case "$status" in
      exited)
        exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$SPLUNK_INIT_CONTAINER")"
        if [[ "$exit_code" = "0" ]]; then
          echo "${SPLUNK_INIT_CONTAINER} completed successfully." >&2
          return 0
        fi
        echo "Error: ${SPLUNK_INIT_CONTAINER} exited with code ${exit_code}" >&2
        docker logs "$SPLUNK_INIT_CONTAINER" --tail 40 >&2 || true
        return 1
        ;;
      running | created)
        if (( n % 6 == 0 )); then
          echo "  still running (${n}/${SPLUNK_INIT_WAIT_ATTEMPTS})…" >&2
        fi
        ;;
      *)
        echo "Error: ${SPLUNK_INIT_CONTAINER} status=${status:-unknown}" >&2
        return 1
        ;;
    esac
    sleep "$SPLUNK_INIT_WAIT_INTERVAL"
    n=$((n + 1))
  done

  echo "Error: ${SPLUNK_INIT_CONTAINER} did not finish within ~$((SPLUNK_INIT_WAIT_ATTEMPTS * SPLUNK_INIT_WAIT_INTERVAL / 60)) min." >&2
  return 1
}

# One-line summary for make status. Returns 0 unless the container exited non-zero.
report_splunk_init_status() {
  local status exit_code

  command -v docker >/dev/null 2>&1 || {
    echo "splunk-init: docker not found"
    return 0
  }

  if ! docker inspect "$SPLUNK_INIT_CONTAINER" >/dev/null 2>&1; then
    echo "splunk-init: not found (run make up)"
    return 0
  fi

  status="$(docker inspect -f '{{.State.Status}}' "$SPLUNK_INIT_CONTAINER")"
  case "$status" in
    exited)
      exit_code="$(docker inspect -f '{{.State.ExitCode}}' "$SPLUNK_INIT_CONTAINER")"
      if [[ "$exit_code" = "0" ]]; then
        echo "splunk-init: completed successfully (exit 0)."
        return 0
      fi
      echo "splunk-init: FAILED (exit ${exit_code}) — run: docker logs ${SPLUNK_INIT_CONTAINER}"
      return 1
      ;;
    running)
      echo "splunk-init: still running (setup in progress)…"
      return 0
      ;;
    created)
      echo "splunk-init: created (not started yet)…"
      return 0
      ;;
    *)
      echo "splunk-init: unexpected status=${status}"
      return 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  wait_splunk_init
fi
