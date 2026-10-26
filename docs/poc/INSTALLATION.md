# Installation & setup

**Presales or customer demo?** Use **[PRESALES.md](PRESALES.md)** for the happy path, time budget, and client steps; use this file for **hardware and long-form** setup. Quick commands: [PRESALES.md § Technical quick reference](PRESALES.md#technical-quick-reference). If anything fails, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Prerequisites

### System

| Tier | CPUs | RAM | Disk (free) |
| ---- | ---- | --- | ----------- |
| Minimum | 2 | 4 GB | ~10 GB |
| Recommended | 4 | 8 GB | ~20 GB |

### Supported platforms

| Platform | Status | Notes |
| -------- | ------ | ----- |
| macOS + Docker Desktop | Supported for local demos | Primary laptop path; Claude Desktop config helper uses the macOS config path. Apple Silicon runs Splunk as `linux/amd64` via emulation. |
| Linux + Docker Engine / Compose | Supported for developer use | Works with the same `make` targets when Docker can run Linux containers and ports `8000` / `8089` are free. |
| Cursor Cloud | Supported with bootstrap | Run `make cloud-bootstrap` once per VM boot before `make up`; runtime `.env` and `docker-compose.override.yml` are gitignored and VM-local. |
| Windows + WSL2 + Docker | Best effort | Use a Linux shell in WSL2 for `make` and paths. Client config paths may need manual adjustment, especially Claude Desktop. |
| Native Windows shell without WSL2 | Unsupported | The scripts assume Bash, Unix paths, and Docker Compose behavior matching macOS/Linux. |

### Software

| Tool | Purpose | Verify |
| ---- | ------- | ------ |
| Docker + Compose | Splunk containers | `docker --version`, `docker compose version`, `docker info` |
| `make`, `bash` | `Makefile` workflows | `make --version` |
| `curl`, `jq` | Scripts / REST | `curl --version`, `jq --version` |
| Node/npm | `npx mcp-remote` for MCP clients | `node --version`, `npx --version` |

Optional: **Git** to clone; an editor (e.g. VS Code) to edit `.env` (from **`.env.example`**) and `compose.yml`.

**Windows:** Prefer **WSL2** with Docker so `make` and paths behave like the docs (macOS/Linux).

Create a gitignored **`.env`** with `SPLUNK_ADMIN_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, and `SPLUNK_SPLUNKER_PASSWORD`. Image and timezone are in tracked **`config.env`**. See **[PRESALES.md](PRESALES.md)**.

### Cursor Cloud

Cursor Cloud VMs need one-time **per-boot** bootstrap before `make up` because Docker-in-Docker and Splunk's data filesystem are not ready by default. Add Cursor Cloud environment secrets **`SPLUNKBASE_USER`** and **`SPLUNKBASE_PASS`**, then run:

```bash
make cloud-bootstrap
make up
make verify
```

This writes gitignored local runtime files (`.env` and `docker-compose.override.yml`). Bootstrap generates **`SPLUNK_ADMIN_PASSWORD`** and **`SPLUNK_SPLUNKER_PASSWORD`** into the local `.env` when they are not already set; use those values for admin login and MCP user resets, but do not paste or commit them. Flags such as `--wipe`, `--image`, and `--force-env` are documented in [CONFIGURATION.md § Cursor Cloud bootstrap](CONFIGURATION.md#cursor-cloud-bootstrap); common VM-specific failures are in [TROUBLESHOOTING.md § Cursor Cloud](TROUBLESHOOTING.md#cursor-cloud-docker-in-docker).

## Secrets

You need four values:

1. **`SPLUNK_ADMIN_PASSWORD`** — Splunk `admin` password.
2. **`SPLUNKBASE_USER`** and **`SPLUNKBASE_PASS`** — [Splunkbase](https://splunkbase.splunk.com/) account that can download apps.
3. **`SPLUNK_SPLUNKER_PASSWORD`** — password of the Splunk user `splunker` (the MCP execution user).

## Clone and configure

```bash
git clone <repository-url> splunk-mcp
cd splunk-mcp
cp .env.example .env
chmod 600 .env
```

Edit **`.env`** (gitignored). Leave the values unquoted. Image and timezone are in tracked **`config.env`**, not in **`.env`**.

Expected layout includes `Makefile`, `compose.yml`, `.env.example`, local `.env` (after copy), `scripts/` (including `setup-splunk.sh`, `compose-up.sh`, `mcp-client.sh`), and `SA-S4R/`. See root [README.md](../../README.md) for the full picture.

## Preflight before first `make up`

Run these from the repo root before a fresh install or handoff. They do not print secrets.

```bash
docker info >/dev/null
docker info --format 'CPUs={{.NCPU}} MemBytes={{.MemTotal}}'
docker compose version
make --version
jq --version
curl --version
node --version
npx --version
python3 --version
python3 -c "import yaml"
curl -fsS https://splunkbase.splunk.com/ >/dev/null
```

Then confirm the secret file exists and is non-empty. Do not print it:

```bash
test -s .env
```

Network and ports:

- The host must reach **splunkbase.splunk.com** and the container registry that serves `SPLUNK_IMAGE`.
- Ports **8000** and **8089** must be free, or remapped in a gitignored `docker-compose.override.yml`; if 8089 changes, set `SPLUNK_MCP_ENDPOINT` before updating client configs.
- The first cold boot can take **20–45 minutes** when images and Splunkbase apps are not cached. Warm restarts are usually much shorter, but still wait for `splunk-init` and MCP token minting to finish.

## Start the stack

```bash
make up
```

This runs **`docker compose up -d`** using **`.env`** (or exported variables when that file is absent). It starts **`so1`**, runs **`splunk-init`** after Splunk is healthy, then mints an MCP token and updates client configs (**`MCP_UPDATE_ON_BOOT`**, default **`cursor`**), then registers SA-S4R MCP tools.

After **`splunk-init`** exits, **`scripts/mcp-client.sh update-all`** writes client configs pointing at **`https://localhost:8089/services/mcp`**. For every client on boot: `make up MCP_UPDATE_ON_BOOT="cursor claude claude-code"`.

Secret file details: [CONFIGURATION.md](CONFIGURATION.md#configenv-and-env).

Watch progress:

```bash
make logs
make status    # splunk-init line + "Splunk is ready ✓"; exits non-zero if init failed or Splunk running but API not ready (exit 0 when stack stopped)
```

## Splunk Web

1. Open `https://localhost:8000`.
2. Log in as **admin** with **`SPLUNK_ADMIN_PASSWORD`** from gitignored `.env` (hand-written locally, or generated by Cloud bootstrap).
3. Accept the self-signed certificate warning (local dev only).

REST smoke test (replace `<password>`):

```bash
curl -k -u "admin:<password>" https://localhost:8089/services/server/info
```

## MCP clients

After `make up` completes:

| Client | Action |
| ------ | ------ |
| **Cursor** (default) | **`make up`** updates **`.cursor/mcp.json`** (`MCP_UPDATE_ON_BOOT=cursor`). Restart Cursor or reload MCP servers. |
| **Claude Desktop** (macOS) | Run **`make update-mcp-client MCP_CLIENT=claude`** or **`make up MCP_UPDATE_ON_BOOT="cursor claude"`**. Quit Claude fully (**Cmd+Q**), then reopen. Config: `~/Library/Application Support/Claude/claude_desktop_config.json`. |
| **Claude Code** | Run **`make update-mcp-client MCP_CLIENT=claude-code`** or include **`claude-code`** in **`MCP_UPDATE_ON_BOOT`**. Writes gitignored **`.mcp.json`** at the repo root; start a new Claude Code session in the repo and approve **splunk-mcp-server** (or check with **`/mcp`**). |

Shell smoke test for the default Cursor path:

```bash
make verify-mcp-remote MCP_VERIFY_CLIENT=cursor
```

All-client acceptance is:

```bash
make update-mcp-clients
make verify
```

Exit code **0** means the stack status check passed, selected client config checks passed, Splunk MCP answered `tools/list`, and the `npx mcp-remote` stdio handshake worked. Data-level acceptance for SA-S4R is listed in [SPECS.md](SPECS.md#acceptance-criteria-minimum).

## Optional: Claude logs in Splunk

If you want a **`claude_logs`** index, create it in Splunk (UI or REST). Log **files** are ingested only if you uncomment the Claude log bind mount in **`compose.yml`**, point it at a real path on your host, and add a monitor input. Then search: `index=claude_logs`. Details: [CONFIGURATION.md](CONFIGURATION.md).

## Confirm MCP endpoint

```bash
make verify-mcp-remote
```

In Claude Desktop, open a chat and confirm **splunk-mcp-server** tools appear.

## Troubleshooting

Use **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for Docker, ports, Splunkbase downloads, and token timeouts. Common quick checks: `make logs`, `make status`, and confirm **`.env`** has Splunkbase credentials.

## Security (local PoC)

This setup targets **trusted localhost** use: self-signed TLS, dev-oriented MCP settings. Do not treat it as production-ready. See [SECURITY.md](SECURITY.md). Do not commit **`.env`** or client files containing live MCP bearer tokens. Passwords live only in that file or in the process environment.

## Next steps

- [PRESALES.md](PRESALES.md) — SE demo runbook and checklist  
- [CONFIGURATION.md](CONFIGURATION.md) — ports, env vars, clients  
- [ARCHITECTURE.md](ARCHITECTURE.md) — architecture  
- [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) — bundled sample app  

```bash
make help
```
