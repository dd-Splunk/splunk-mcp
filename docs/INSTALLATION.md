# Installation & setup

**Presales or customer demo?** Use **[PRESALES.md](PRESALES.md)** for the happy path, time budget, and client steps; use this file for **hardware, 1Password item layout, and long-form** setup. [QUICK_START.md](QUICK_START.md) is a minimal command list. If anything fails, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Prerequisites

### System

| Tier | CPUs | RAM | Disk (free) |
| ---- | ---- | --- | ----------- |
| Minimum | 2 | 4 GB | ~10 GB |
| Recommended | 4 | 8 GB | ~20 GB |

### Software

| Tool | Purpose | Verify |
| ---- | ------- | ------ |
| Docker + Compose | Splunk containers | `docker --version` |
| 1Password CLI (`op`) | Secrets from local `tpl.env` | `op --version` (sign in: `op account add` or desktop integration) |
| `make`, `bash` | `Makefile` workflows | `make --version` |
| `curl`, `jq` | Scripts / REST | `curl --version`, `jq --version` |
| Node/npm | `npx mcp-remote` for MCP clients | `node --version` |

Optional: **Git** to clone; an editor (e.g. VS Code) to edit `tpl.env` (from **`tpl.env.example`**) and `compose.yml`.

**Windows:** Prefer **WSL2** with Docker so `make` and paths behave like the docs (macOS/Linux).

**Without 1Password:** you can still run the stack with a git-ignored **`.env`** file containing plain values for `SPLUNK_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, and optional `SPLUNK_IMAGE` / `TZ`. See **[PRESALES.md](PRESALES.md)** (Path B).

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
SPLUNK_IMAGE=splunk/splunk:latest
SPLUNK_PASSWORD=op://YourVault/YourItem/password
SPLUNKBASE_USER=op://YourVault/Splunkbase/username
SPLUNKBASE_PASS=op://YourVault/Splunkbase/password
TZ=Europe/Brussels
```

Expected layout includes `Makefile`, `compose.yml`, `tpl.env.example`, local `tpl.env` (after copy), `scripts/` (including `setup-splunk.sh`, `update-*-config.sh`, `verify-mcp-remote.sh`), and `SA-S4R/`. See root [README.md](../README.md) for the full picture.

## Start the stack

```bash
make up
```

This runs **`docker compose up -d`** using **`.env`** if present, otherwise **`op run --env-file=tpl.env`**. It starts **`so1`**, runs **`splunk-init`** after Splunk is healthy, waits for **`.secrets/splunk-token`**, then runs **`make update-claude-config`**, **`make update-cursor-config`**, and **`make update-goose-config`**.

For Path B (plain **`.env`** without 1Password at runtime), see [CONFIGURATION.md](CONFIGURATION.md#plain-env-path-b).

Allow **several minutes** on first run (image pull, Splunk, Splunkbase downloads). Watch progress:

```bash
make logs
make status    # expect "Splunk is ready ✓" when healthy
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

After **`.secrets/splunk-token`** exists:

| Client | Action |
| ------ | ------ |
| **Claude Desktop** (macOS) | **`make up`** runs **`update-claude-config`**. Quit Claude fully (**Cmd+Q**), then reopen. Config: `~/Library/Application Support/Claude/claude_desktop_config.json`. |
| **Cursor** | **`make up`** runs **`update-cursor-config`** (writes **`.cursor/mcp.json`**). Restart Cursor or reload MCP servers. |
| **Goose** | **`make up`** runs **`update-goose-config`**. Restart Goose. |

Shell smoke test:

```bash
make verify-mcp-remote
```

## Optional: Claude logs in Splunk

If you want a **`claude_logs`** index, create it in Splunk (UI or REST). Log **files** are ingested only if you uncomment the Claude log bind mount in **`compose.yml`**, point it at a real path on your host, and add a monitor input. Then search: `index=claude_logs`. Details: [CONFIGURATION.md](CONFIGURATION.md).

## Confirm MCP endpoint

Replace `<token>` with the contents of **`.secrets/splunk-token`** (treat it as a secret; do not commit it):

```bash
curl -k -H "Authorization: Bearer <token>" https://localhost:8089/services/mcp
```

In Claude Desktop, open a chat and confirm **splunk-mcp-server** tools appear.

## Troubleshooting

Use **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** for Docker, ports, `op` auth, Splunkbase downloads, and token timeouts. Common quick checks: `make logs`, `make status`, confirm **`tpl.env`** paths and Splunkbase credentials.

## Security (local PoC)

This setup targets **trusted localhost** use: self-signed TLS, dev-oriented MCP settings. Do not treat it as production-ready. See [SECURITY.md](SECURITY.md). Do not commit **`.env`**, **`.secrets/`**, or client files containing live tokens.

## Next steps

- [PRESALES.md](PRESALES.md) — SE demo runbook and checklist  
- [CONFIGURATION.md](CONFIGURATION.md) — ports, env vars, clients  
- [OVERVIEW.md](OVERVIEW.md) — architecture  
- [SA-S4R-APP.md](SA-S4R-APP.md) — bundled sample app  

```bash
make help
```
