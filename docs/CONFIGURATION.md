## compose.yml

**Optional:** copy **`docker-compose.override.yml.example`** to **`docker-compose.override.yml`** (gitignored) to change host ports or add bind mounts without editing the main file. **`SPLUNK_APPS_URL`** in **`compose.yml`** includes comments identifying each Splunkbase app ID.

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

**Claude logs (macOS)**

The sample compose file mounts:

```text
${HOME}/Library/Logs/Claude:/var/log/claude_logs
```

If you are not on macOS or that path does not exist, adjust or remove this mount. The setup script only creates a monitor input when `/var/log/claude_logs` exists inside the container.

### Service `splunk-init`

Runs after `so1` is **healthy**. Uses Alpine, installs `curl` and `jq`, then runs `setup-splunk.sh`. Mounts:

- `scripts/setup-splunk.sh` → `/setup-splunk.sh`
- `./.secrets` → `/output` (token written to `splunk-token`)

### Network and volumes

- Bridge network **`splunk`** for `so1` ↔ `splunk-init`.
- Named volumes **`so1-var`** and **`so1-etc`** (explicit names in Compose).

## tpl.env and .env

### `tpl.env.example` and `tpl.env`

- **`tpl.env.example`** is the **tracked** template (placeholder `op://` paths, safe to commit).
- **`tpl.env`** is **gitignored**. Create it once: `cp tpl.env.example tpl.env`, then edit paths for **your** vault.
- May use `op://` references for 1Password CLI **or** plain values for local testing—**never commit `tpl.env`**.
- Align vault names, item titles, and field names with your 1Password layout.

### Generating `.env` (optional)

```bash
make init   # runs: op run --env-file=tpl.env -- scripts/materialize-env.sh .env
```

Requires a local **`tpl.env`**, `op` signed in, and access to the referenced items. If you skip this, use **`make up`** without `.env` so the Makefile runs Compose via `op run --env-file=tpl.env` (see `Makefile`).

### Typical variables

| Variable | Purpose |
| -------- | ------- |
| `SPLUNK_IMAGE` | Splunk Docker image tag |
| `SPLUNK_PASSWORD` | Admin password |
| `SPLUNKBASE_USER` / `SPLUNKBASE_PASS` | Splunkbase (names in `compose.yml` map these) |
| `TZ` | Timezone |

**Note:** `compose.yml` expects `SPLUNKBASE_USER` and `SPLUNKBASE_PASS` in the environment. Define them in `tpl.env` (and/or `.env` after `make init`). Variable **names** must match what Compose references.

## Makefile targets

| Target | Behavior |
| ------ | -------- |
| `init` | Optional: materialize `.env` via `op run` + `scripts/materialize-env.sh` (skip if `.env` exists unless `FORCE=1`) |
| `up` | `docker compose up -d` (via `op run --env-file=tpl.env` when `.env` is absent), wait for `.secrets/splunk-token`, then `claude-update` |
| `claude-update` | Runs `scripts/update-claude-config.sh` |
| `goose-update` | Runs `scripts/update-goose-config.sh` → `~/.config/goose/config.yaml` |
| `cursor-mcp` | Runs `scripts/update-cursor-config.sh` → `.cursor/mcp.json` |
| `down` / `restart` / `logs` / `status` | Plain `docker compose` (no `op` or `.env` required—lifecycle only) |
| `clean` | `docker compose down -v` then remove `.env` / token file (no `op` required) |

## scripts/setup-splunk.sh

Runs **inside** `splunk-init` with `SPLUNK_HOST=so1`. It:

1. Sets MCP server `ssl_verify=false` via REST (dev convenience).
2. Ensures index `claude_logs` and a monitor for `/var/log/claude_logs` (idempotent).
3. Creates role **`mcp_tool_execute`** and ensures it has capability `mcp_tool_execute` (required by MCP).
4. Creates user **`dd`** with roles `user` and `mcp_tool_execute` (no `admin` unless `ADD_ADMIN_ROLE=1`).
5. Requests an **encrypted MCP token** from `.../Splunk_MCP_Server/mcp_token?username=dd&output_mode=json`.
6. Writes the token to `TOKEN_OUTPUT_FILE` (`.secrets/splunk-token` on the host).

The init script also generates a dedicated password for `dd` if `DD_PASSWORD` is not provided and persists it to `$(dirname TOKEN_OUTPUT_FILE)/dd-password` (git-ignored).

## Claude Desktop configuration

- Path: **`~/Library/Application Support/Claude/claude_desktop_config.json`** (macOS).
- `update-claude-config.sh` merges `mcpServers.splunk-mcp-server` without destroying other servers.
- Uses **`jq`**; backs up invalid JSON with a timestamped file.

## Cursor configuration

- Default output: **`.cursor/mcp.json`** (override with `CURSOR_MCP_JSON`).
- `update-cursor-config.sh` merges **`splunk-mcp-server`** the same way as Claude.
- Example placeholder without secrets: **`.cursor/mcp.json.example`**.

## Goose configuration

- Path: **`~/.config/goose/config.yaml`** (Unix/Linux and macOS).
- Goose uses **extensions** with `type: stdio` for MCP server configuration (different from Claude's format).
- `update-goose-config.sh` adds `splunk-mcp-server` as an extension entry under `extensions` section.
- Idempotent: safely updates or creates the extension without corrupting existing config.
- Requires Python 3 for YAML regex manipulation.

## Environment overrides (optional)

| Variable | Used by | Purpose |
| -------- | ------- | ------- |
| `SPLUNK_HOST` | Client scripts | Default `localhost` |
| `SPLUNK_PORT` | Client scripts | Default `8089` |
| `CURSOR_MCP_JSON` | `update-cursor-config.sh` | Output path |

## See also

- [OVERVIEW.md](OVERVIEW.md) — how pieces fit together
- [SECURITY.md](SECURITY.md) — TLS and token handling
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when ports or inject fail
