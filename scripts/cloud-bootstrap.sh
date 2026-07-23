#!/usr/bin/env bash
# Bootstrap a Cursor Cloud VM for the Splunk MCP PoC (Docker-in-Docker).
#
# Idempotent per VM boot: start Docker, ext4 loopback for Splunk data, cgroup workaround
# for Splunk 10.4.x, and gitignored docker-compose.override.yml + .env (when missing).
#
# Usage:
#   ./scripts/cloud-bootstrap.sh [--wipe] [--force-env] [--image IMAGE]
#
# Env (optional):
#   SPLUNK_IMAGE              default splunk/splunk:10.4.1
#   CLOUD_SPLUNKDB_IMG        default /splunkdb.img
#   CLOUD_SPLUNKDB_MOUNT      default /mnt/splunkdb
#   CLOUD_SPLUNKDB_SIZE       default 25G
#   CLOUD_FAKE_CGROUP_ROOT    default /opt/splunk-fake-cgroup
#   SPLUNKBASE_USER / SPLUNKBASE_PASS  required to create .env (e.g. Cursor Cloud secrets)
#
# After bootstrap: make up

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DC="${DC:-docker compose}"
ENV_OUT="${ENV_OUT:-.env}"
OVERRIDE_FILE="${OVERRIDE_FILE:-docker-compose.override.yml}"
SPLUNK_IMAGE="${SPLUNK_IMAGE:-splunk/splunk:10.4.1}"
CLOUD_SPLUNKDB_IMG="${CLOUD_SPLUNKDB_IMG:-/splunkdb.img}"
CLOUD_SPLUNKDB_MOUNT="${CLOUD_SPLUNKDB_MOUNT:-/mnt/splunkdb}"
CLOUD_SPLUNKDB_SIZE="${CLOUD_SPLUNKDB_SIZE:-25G}"
CLOUD_FAKE_CGROUP_ROOT="${CLOUD_FAKE_CGROUP_ROOT:-/opt/splunk-fake-cgroup}"
SPLUNK_UID="${SPLUNK_UID:-41812}"

WIPE=0
FORCE_ENV=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Bootstrap Cursor Cloud runtime state before 'make up'.

Options:
  --wipe         Stop stack, remove Compose volumes, and reformat the ext4 loopback
                 (use when changing Splunk major versions or KVStore is stuck failed)
  --force-env    Recreate $ENV_OUT even if it already exists
  --image IMAGE  Splunk image tag (default: $SPLUNK_IMAGE)
  -h, --help     Show this help

Requires SPLUNKBASE_USER and SPLUNKBASE_PASS in the environment when creating $ENV_OUT
(for example Cursor Cloud environment secrets).
EOF
}

die() {
  echo "Error: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wipe) WIPE=1; shift ;;
    --force-env) FORCE_ENV=1; shift ;;
    --image)
      [[ $# -ge 2 ]] || die "--image requires a value"
      SPLUNK_IMAGE="$2"
      shift 2
      ;;
    -h | --help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done

need_splunkbase_creds() {
  [[ -n "${SPLUNKBASE_USER:-}" && -n "${SPLUNKBASE_PASS:-}" ]] \
    || die "SPLUNKBASE_USER and SPLUNKBASE_PASS must be set (Cursor Cloud secrets or export in shell)"
}

random_password() {
  openssl rand -base64 24 | tr -d '/+=' | head -c 24
}

splunk_needs_fake_cgroup() {
  local tag="${SPLUNK_IMAGE##*:}"
  case "$tag" in
    9.* | 8.* | 7.*) return 1 ;;
    *) return 0 ;;
  esac
}

ensure_docker() {
  if docker info >/dev/null 2>&1; then
    echo "✓ Docker daemon already running"
    return 0
  fi
  echo "→ Starting Docker daemon (no systemd in Cursor Cloud)…"
  if ! command -v dockerd >/dev/null 2>&1; then
    die "dockerd not found — install Docker in the Cloud environment first"
  fi
  sudo bash -c 'dockerd >/tmp/dockerd.log 2>&1 &'
  for _ in {1..30}; do
    if docker info >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  docker info >/dev/null 2>&1 || {
    tail -20 /tmp/dockerd.log >&2 || true
    die "Docker daemon failed to start (see /tmp/dockerd.log)"
  }
  if [[ -S /var/run/docker.sock ]] && [[ ! -w /var/run/docker.sock ]]; then
    sudo chmod 666 /var/run/docker.sock
  fi
  docker run --rm hello-world >/dev/null
  echo "✓ Docker daemon ready"
}

wipe_splunk_data() {
  echo "→ Wiping Splunk data (Compose volumes + ext4 loopback)…"
  $DC down -v 2>/dev/null || true
  if mountpoint -q "$CLOUD_SPLUNKDB_MOUNT" 2>/dev/null; then
    sudo umount "$CLOUD_SPLUNKDB_MOUNT"
  fi
  if [[ -f "$CLOUD_SPLUNKDB_IMG" ]]; then
    sudo mkfs.ext4 -qF "$CLOUD_SPLUNKDB_IMG"
  fi
  echo "✓ Splunk data wiped"
}

ensure_splunkdb_mount() {
  echo "→ Ensuring ext4 loopback at $CLOUD_SPLUNKDB_MOUNT…"
  sudo mkdir -p "$CLOUD_SPLUNKDB_MOUNT"
  if ! mountpoint -q "$CLOUD_SPLUNKDB_MOUNT"; then
    if [[ ! -f "$CLOUD_SPLUNKDB_IMG" ]]; then
      sudo fallocate -l "$CLOUD_SPLUNKDB_SIZE" "$CLOUD_SPLUNKDB_IMG"
      sudo mkfs.ext4 -qF "$CLOUD_SPLUNKDB_IMG"
    fi
    sudo mount -o loop "$CLOUD_SPLUNKDB_IMG" "$CLOUD_SPLUNKDB_MOUNT"
  fi
  sudo chown -R "${SPLUNK_UID}:${SPLUNK_UID}" "$CLOUD_SPLUNKDB_MOUNT"
  echo "✓ Splunk data mount ready ($(df -h "$CLOUD_SPLUNKDB_MOUNT" | awk 'NR==2 {print $2 " total, " $4 " free"}'))"
}

ensure_fake_cgroup() {
  local r="$CLOUD_FAKE_CGROUP_ROOT"
  echo "→ Ensuring fake cgroup tree at $r (Splunk 10.4.x workaround)…"
  sudo mkdir -p "$r"
  printf 'cpuset cpu io memory pids\n' | sudo tee "$r/cgroup.controllers" >/dev/null
  printf '\n' | sudo tee "$r/cgroup.subtree_control" >/dev/null
  printf 'domain\n' | sudo tee "$r/cgroup.type" >/dev/null
  for kv in \
    memory.max=8589934592 memory.high=8589934592 memory.low=0 memory.min=0 \
    memory.current=1073741824 memory.peak=1073741824 memory.swap.max=0 memory.swap.current=0 \
    cpu.max=100000; do
    printf '%s\n' "${kv#*=}" | sudo tee "$r/${kv%%=*}" >/dev/null
  done
  printf 'anon 536870912\nfile 268435456\nkernel 67108864\nslab 33554432\nsock 1048576\n' \
    | sudo tee "$r/memory.stat" >/dev/null
  printf 'low 0\nhigh 0\nmax 0\noom 0\noom_kill 0\n' | sudo tee "$r/memory.events" >/dev/null
  printf 'usage_usec 1000\nuser_usec 500\nsystem_usec 500\n' | sudo tee "$r/cpu.stat" >/dev/null
  sudo chmod -R a+r "$r"
  echo "✓ Fake cgroup tree ready"
}

write_compose_override() {
  echo "→ Writing $OVERRIDE_FILE…"
  {
    echo "services:"
    echo "  so1:"
    if splunk_needs_fake_cgroup; then
      cat <<EOF
    volumes:
      - ${CLOUD_FAKE_CGROUP_ROOT}:/sys/fs/cgroup:ro
EOF
    else
      echo "    cgroup: host"
    fi
    echo ""
    echo "volumes:"
    echo "  so1-var:"
    echo "    driver: local"
    echo "    driver_opts:"
    echo "      type: none"
    echo "      o: bind"
    echo "      device: ${CLOUD_SPLUNKDB_MOUNT}"
  } >"$OVERRIDE_FILE"
  echo "✓ Wrote $OVERRIDE_FILE (image: $SPLUNK_IMAGE)"
}

write_env_file() {
  if [[ -f "$ENV_OUT" && "$FORCE_ENV" -eq 0 ]]; then
    echo "✓ $ENV_OUT already exists (use --force-env to recreate)"
    return 0
  fi
  need_splunkbase_creds
  local admin_pw mcp_pw
  admin_pw="$(random_password)"
  mcp_pw="$(random_password)"
  cat >"$ENV_OUT" <<EOF
SPLUNK_IMAGE=${SPLUNK_IMAGE}
SPLUNK_PASSWORD=${admin_pw}
SPLUNKBASE_USER=${SPLUNKBASE_USER}
SPLUNKBASE_PASS=${SPLUNKBASE_PASS}
SPLUNK_MCP_PASSWORD=${mcp_pw}
TZ=${TZ:-Europe/Brussels}
EOF
  chmod 600 "$ENV_OUT"
  echo "✓ Created $ENV_OUT (chmod 600; passwords generated; Splunkbase creds from environment)"
}

main() {
  echo "Cursor Cloud bootstrap (Splunk MCP PoC)"
  echo "  image: ${SPLUNK_IMAGE}"
  echo ""

  ensure_docker
  if [[ "$WIPE" -eq 1 ]]; then
    wipe_splunk_data
  fi
  ensure_splunkdb_mount
  if splunk_needs_fake_cgroup; then
    ensure_fake_cgroup
  else
    echo "→ Skipping fake cgroup (not required for ${SPLUNK_IMAGE})"
  fi
  write_compose_override
  write_env_file

  echo ""
  echo "Bootstrap complete. Next:"
  echo "  make up          # start Splunk + splunk-init + MCP client configs"
  echo "  make verify      # status + MCP tools/list"
  if [[ "$WIPE" -eq 0 ]]; then
    echo ""
    echo "Tip: when changing Splunk major versions, rerun with --wipe to avoid KVStore upgrade failures."
  fi
}

main "$@"
