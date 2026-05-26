## compose.yml

**Optional:** copy **`docker-compose.override.yml.example`** to **`docker-compose.override.yml`** (gitignored) to change host ports or add bind mounts without editing the main file. **`SPLUNK_APPS_URL`** in **`compose.yml`** is a comma-separated list of Splunkbase download URLs; the **`compose.yml`** comments identify each app. Current entries (app ID → name):

| App ID | App |
| ------ | --- |
| 1924 | SA-Eventgen (sample data / Eventgen modinput) |
| 4353 | Config Explorer (optional UI utility) |
| 7931 | Splunk MCP Server (required for `/services/mcp`) |
| 7245 | Splunk AI Assistant for SPL |
| 2882 | Python for Scientific Computing (Linux x86_64; MLTK / Connection Management needs this) |
| 2890 | Splunk AI Toolkit |

### Service `so1` (Splunk)

| Setting | Meaning |
| ------- | ------- |
| `image` | `${SPLUNK_IMAGE:-splunk/splunk:latest}` |
| `platform: linux/amd64` | Run x86 image on ARM via emulation when needed |
| `SPLUNK_GENERAL_TERMS` | Accepts Splunk general terms non-interactively |
| `SPLUNK_START_ARGS` | License acceptance |
| `SPLUNK_PASSWORD` | Admin password (from `.env` and/or `op run` / shell env) |
| `SPLUNKBASE_USERNAME` / `SPLUNKBASE_PASSWORD` | Splunkbase downloads |
| `SPLUNK_APPS_URL` | Comma-separated Splunkbase package URLs |
| `TZ` | Container timezone (default `Europe/Brussels` in template) |

**Ports**

- `8000` — Splunk Web
- `8089` — REST API and `/services/mcp`

**Volumes**

- Named volumes `so1-var` and `so1-etc` persist Splunk data and config.
- `./SA-S4R` is bind-mounted read-write into `/opt/splunk/etc/apps/SA-S4R`.

**Claude logs (macOS, optional)**

The sample `compose.yml` has this bind mount **commented out**. When enabled, it looks like:

```text
${HOME}/Library/Logs/Claude:/var/log/claude_logs
```

If you are not on macOS or that path does not exist, adjust or remove this mount. **`scripts/setup-splunk.sh`** does **not** create a `claude_logs` index or monitor; add those via Splunk UI or REST if you want host log ingestion.

### Service `splunk-init`

Runs after `so1` is **healthy**. Uses Alpine, installs `curl` and `jq`, then runs `setup-splunk.sh`. Mounts:

- `scripts/setup-splunk.sh` → `/setup-splunk.sh`
- `./.secrets` → `/output` (token written to **`splunk-token`**, MCP user password to **`splunker-password`** when generated—see `TOKEN_OUTPUT_FILE` / `SPLUNKER_PASSWORD_FILE` in **`compose.yml`**)

### Network and volumes

- Bridge network **`splunk`** for `so1` ↔ `splunk-init`.
- Named volumes **`so1-var`** and **`so1-etc`** (explicit names in Compose).

## tpl.env and .env

### `tpl.env.example` and `tpl.env`

- **`tpl.env.example`** is the **tracked** template (placeholder `op://` paths, safe to commit).
- **`tpl.env`** is **gitignored**. Create it once: `cp tpl.env.example tpl.env`, then edit paths for **your** vault.
- May use `op://` references for 1Password CLI **or** plain values for local testing—**never commit `tpl.env`**.
- Align vault names, item titles, and field names with your 1Password layout.

### Plain `.env` (Path B)

If **`.env` is missing**, `make up` runs:

`op run --env-file=tpl.env -- docker compose up -d`

1Password **resolves** the `op://` references and passes the values in the process environment. **Nothing in this path writes a `.env` file**—resolved secrets are not left on disk by the Makefile (aside from what Splunk/Compose do inside containers per `compose.yml`).

For a **plaintext `.env`** on disk (no 1Password at `make up` time), copy [`.env.example`](../.env.example) to **`.env`**, fill values, and run **`make up`**. Compose auto-loads **`.env`**. Use for CI or contributors without `op`.

| Situation | Use |
| --------- | --- |
| Local development with 1Password | **`tpl.env`** + **`make up`** (no `.env` file) |
| CI or no `op` | **`.env`** from **`.env.example`** (Path B in [PRESALES.md](PRESALES.md)) |
| CI with 1Password | `OP_SERVICE_ACCOUNT_TOKEN` + `op run --env-file=tpl.env -- make up` (no `.env` artifact) |

### Typical variables

| Variable | Purpose |
| -------- | ------- |
| `SPLUNK_IMAGE` | Splunk Docker image tag |
| `SPLUNK_PASSWORD` | Admin password |
| `SPLUNKBASE_USER` / `SPLUNKBASE_PASS` | Splunkbase (names in `compose.yml` map these) |
| `TZ` | Timezone |

**Note:** `compose.yml` expects `SPLUNKBASE_USER` and `SPLUNKBASE_PASS` in the environment. Define them in **`tpl.env`** or **`.env`**. Variable **names** must match what Compose references.

## Makefile targets

| Target | Behavior |
| ------ | -------- |
| `up` | `scripts/compose-up.sh` (`.env` or `op run --env-file=tpl.env`), wait for `.secrets/splunk-token`, then `update-mcp-clients` |
| `update-mcp-clients` | `scripts/mcp-client.sh update` for claude, cursor, goose |
| `update-mcp-client` | One client: `MCP_CLIENT=claude\|cursor\|goose` |
| `update-claude-config` / `update-cursor-config` / `update-goose-config` | Aliases for `update-mcp-client` |
| `verify-mcp-remote` | `scripts/mcp-client.sh verify` (`MCP_VERIFY_CLIENT=all` by default) |
| `down` / `restart` / `logs` / `status` | Lifecycle only (no secrets / `op` required) |
| `clean` | `docker compose down -v` then remove `.env` / token file (no `op` required) |

## scripts/setup-splunk.sh

Full behavior, diagrams, and REST details: **[SETUP_SPLUNK_SCRIPT.md](SETUP_SPLUNK_SCRIPT.md)**.

Runs **inside** `splunk-init` with `SPLUNK_HOST=so1`. It:

1. Enables the **SA-Eventgen** default modular input when the app is installed.
2. Sets MCP server `ssl_verify=false` via REST (dev convenience).
3. Ensures Splunk role **`mcp_user`** exists with capability **`mcp_tool_execute`** (required by MCP).
4. Creates user **`splunker`** (defaults; override with **`SPLUNKER_USERNAME`**) with Splunk roles **`user`** + **`mcp_user`**.
5. Adds role **`mltk_admin`** to **`MLTK_ROLES_USER`** (default **`SPLUNKER_USERNAME`** / **`splunker`**, i.e. the MCP user, not the REST account **`SPLUNK_USER`**) for **Splunk AI Toolkit**; set **`MLTK_ROLES_USER`** in **`.env`** to **`admin`** if the management account should get MLTK.
6. Requests an **encrypted MCP token** from `.../Splunk_MCP_Server/mcp_token?username=<MCP_TOKEN_USERNAME>&output_mode=json` (default **`splunker`**).
7. Writes the token to **`TOKEN_OUTPUT_FILE`** (`.secrets/splunk-token` on the host).

Password handling: if **`SPLUNKER_PASSWORD_FILE`** is missing or empty, a password is generated and written there (default **`.secrets/splunker-password`**; **`splunk-init`** sets **`/output/splunker-password`** so it persists on the host). Set **`FORCE_SPLUNKER_PASSWORD=1`** to rotate when the file already exists.

## Claude Desktop configuration

- Path: **`~/Library/Application Support/Claude/claude_desktop_config.json`** (macOS).
- `scripts/mcp-client.sh update claude` merges `mcpServers.splunk-mcp-server` without destroying other servers.
- Uses **`jq`**; backs up invalid JSON with a timestamped file.

## Cursor configuration

- Default output: **`.cursor/mcp.json`** (override with `CURSOR_MCP_JSON`).
- `scripts/mcp-client.sh update cursor` merges **`splunk-mcp-server`** the same way as Claude.
- Example placeholder without secrets: **`.cursor/mcp.json.example`**.

## Goose configuration

- Path: **`~/.config/goose/config.yaml`** (Unix/Linux and macOS).
- Goose uses **extensions** with `type: stdio` for MCP server configuration (different from Claude's format).
- `scripts/mcp-client.sh update goose` adds `splunk-mcp-server` as an extension entry under `extensions` section.
- Idempotent: safely updates or creates the extension without corrupting existing config.
- Requires Python 3 for YAML regex manipulation.

## Environment overrides (optional)

| Variable | Used by | Purpose |
| -------- | ------- | ------- |
| `SPLUNK_HOST` | Client scripts | Default `localhost` |
| `SPLUNK_PORT` | Client scripts | Default `8089` |
| `SPLUNKER_USERNAME` | `setup-splunk.sh` | Splunk account to create/update (default `splunker`) |
| `MLTK_ROLES_USER` | `setup-splunk.sh` | Which Splunk user gets `mltk_admin` (default: same as `SPLUNKER_USERNAME`; set `admin` to match `SPLUNK_USER`) |
| `MCP_TOKEN_USERNAME` | `setup-splunk.sh` | User name passed to `mcp_token` (default `splunker`; must match the MCP user) |
| `SPLUNKER_PASSWORD_FILE` | `setup-splunk.sh` | Host path for generated or supplied password (init: `/output/splunker-password` → `.secrets/splunker-password`) |
| `TOKEN_OUTPUT_FILE` / `FORCE_MCP_TOKEN` | `setup-splunk.sh` | Token output path and optional regeneration |
| `CURSOR_MCP_JSON` | `mcp-client.sh` (cursor) | Output path |
| `MCP_CLIENT` | `update-mcp-client` | `claude`, `cursor`, or `goose` |
| `MCP_VERIFY_CLIENT` | `verify-mcp-remote` | `all` (default), or one client |

## See also

- [OVERVIEW.md](OVERVIEW.md) — how pieces fit together
- [SECURITY.md](SECURITY.md) — TLS and token handling
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when ports or inject fail
