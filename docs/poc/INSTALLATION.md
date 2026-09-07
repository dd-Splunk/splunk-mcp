# Installation & setup

**Presales or customer demo?** Use **[PRESALES.md](PRESALES.md)** for the happy path, time budget, and client steps; use this file for **hardware, 1Password item layout, and long-form** setup. Quick commands: [PRESALES.md § Technical quick reference](PRESALES.md#technical-quick-reference). If anything fails, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

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
| 1Password CLI (`op`) | Secrets from local `tpl.env` | `op --version` (sign in: `op account add` or desktop integration) |
| `make`, `bash` | `Makefile` workflows | `make --version` |
| `curl`, `jq` | Scripts / REST | `curl --version`, `jq --version` |
| Node/npm | `npx mcp-remote` for MCP clients | `node --version`, `npx --version` |

Optional: **Git** to clone; an editor (e.g. VS Code) to edit `tpl.env` (from **`tpl.env.example`**) and `compose.yml`.

**Windows:** Prefer **WSL2** with Docker so `make` and paths behave like the docs (macOS/Linux).

**Without 1Password:** you can still run the stack with a git-ignored **`.env`** file containing plain values for `SPLUNK_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, and optional `SPLUNK_IMAGE` / `TZ`. See **[PRESALES.md](PRESALES.md)** (Path B).

### Cursor Cloud

Cursor Cloud VMs need one-time **per-boot** bootstrap before `make up` because Docker-in-Docker and Splunk's data filesystem are not ready by default. Add Cursor Cloud environment secrets **`SPLUNKBASE_USER`** and **`SPLUNKBASE_PASS`**, then run:

```bash
make cloud-bootstrap
make up
make verify
```

This writes gitignored local runtime files (`.env` and `docker-compose.override.yml`). Flags such as `--wipe`, `--image`, and `--force-env` are documented in [CONFIGURATION.md § Cursor Cloud bootstrap](CONFIGURATION.md#cursor-cloud-bootstrap); common VM-specific failures are in [TROUBLESHOOTING.md § Cursor Cloud](TROUBLESHOOTING.md#cursor-cloud-docker-in-docker).

## 1Password

### Create items (example names)

Use any vault you control. Names below are **illustrative**—they must match whatever you put in **`tpl.env`**.

1. **Splunk admin password** — e.g. a Login item whose **password** field holds the Splunk `admin` password.
2. **Splunkbase** — a Login item with **username** and **password** for [Splunkbase](https://splunkbase.splunk.com/) (required for app downloads at container start).

### Align `tpl.env`

Either create items that match each `op://vault/item/field` in **`tpl.env`**, or edit **`tpl.env`** so every path resolves in your vault. Without that, `make up` (with `op run`) will fail.

### Test reads

Substitute paths to match **`tpl.env`**:

```bash
op read "op://YourVault/YourItem/password"
op read "op://YourVault/Splunkbase/username"
op read "op://YourVault/Splunkbase/password"
```

## Clone and configure

```bash
git clone <repository-url> splunk-mcp
cd splunk-mcp
cp tpl.env.example tpl.env
```

Edit **`tpl.env`** (gitignored) so every `op://` path matches your vault. Review the tracked example anytime:

```bash
cat tpl.env.example
```

Example shape (paths must be yours in **`tpl.env`**):

```bash
SPLUNK_IMAGE=splunk/splunk:10.4.1
SPLUNK_PASSWORD=op://YourVault/YourItem/password
SPLUNKBASE_USER=op://YourVault/Splunkbase/username
SPLUNKBASE_PASS=op://YourVault/Splunkbase/password
SPLUNK_MCP_PASSWORD=op://YourVault/Splunk-MCP/splunker-password
TZ=Europe/Brussels
```

Expected layout includes `Makefile`, `compose.yml`, `tpl.env.example`, local `tpl.env` (after copy), `scripts/` (including `setup-splunk.sh`, `compose-up.sh`, `mcp-client.sh`), and `SA-S4R/`. See root [README.md](../../README.md) for the full picture.

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
curl -fsS https://splunkbase.splunk.com/ >/dev/null
```

Then validate the chosen secrets path:

```bash
# Path A: confirm op is signed in and each tpl.env reference resolves.
op account list
op read "op://YourVault/Splunkbase/username"

# Path B: confirm .env exists and has all required keys populated.
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

This runs **`docker compose up -d`** using **`.env`** if present, otherwise **`op run --env-file=tpl.env`**. It starts **`so1`**, runs **`splunk-init`** after Splunk is healthy, then mints an MCP token and updates client configs (**`MCP_UPDATE_ON_BOOT`**, default **`cursor`**), then registers SA-S4R MCP tools.

After **`splunk-init`** exits, **`scripts/mcp-client.sh update-all`** writes client configs pointing at **`https://localhost:8089/services/mcp`**. For all three clients on boot: `make up MCP_UPDATE_ON_BOOT="cursor goose claude"`.

For Path B (plain **`.env`** without 1Password at runtime), see [CONFIGURATION.md](CONFIGURATION.md#plain-env-path-b).

Watch progress:

```bash
make logs
make status    # splunk-init line + "Splunk is ready ✓"; exits non-zero if init failed or Splunk running but API not ready (exit 0 when stack stopped)
```

## Splunk Web

1. Open `https://localhost:8000`.
2. Log in as **admin** with the password from your secret store (not committed in git).
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
| **Claude Desktop** (macOS) | Run **`make update-mcp-client MCP_CLIENT=claude`** or **`make up MCP_UPDATE_ON_BOOT="cursor goose claude"`**. Quit Claude fully (**Cmd+Q**), then reopen. Config: `~/Library/Application Support/Claude/claude_desktop_config.json`. |
| **Goose** | Run **`make update-mcp-client MCP_CLIENT=goose`** or include **`goose`** in **`MCP_UPDATE_ON_BOOT`**. Restart Goose. |

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

Use **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for Docker, ports, `op` auth, Splunkbase downloads, and token timeouts. Common quick checks: `make logs`, `make status`, confirm **`tpl.env`** paths and Splunkbase credentials.

## Security (local PoC)

This setup targets **trusted localhost** use: self-signed TLS, dev-oriented MCP settings. Do not treat it as production-ready. See [SECURITY.md](SECURITY.md). Do not commit **`.env`**, **`tpl.env`**, or client files containing live MCP bearer tokens. (Legacy **`.secrets/`** is gitignored and only used when **`ALLOW_LEGACY_SECRETS=1`** — tokens are not written there.)

## Next steps

- [PRESALES.md](PRESALES.md) — SE demo runbook and checklist  
- [CONFIGURATION.md](CONFIGURATION.md) — ports, env vars, clients  
- [ARCHITECTURE.md](ARCHITECTURE.md) — architecture  
- [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) — bundled sample app  

```bash
make help
```
