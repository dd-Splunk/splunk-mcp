## compose.yml

### Service `so1` (Splunk)

| Setting | Meaning |
| ------- | ------- |
| `image` | `${SPLUNK_IMAGE:-splunk/splunk:latest}` |
| `platform: linux/amd64` | Run x86 image on ARM via emulation when needed |
| `SPLUNK_GENERAL_TERMS` | Accepts Splunk general terms non-interactively |
| `SPLUNK_START_ARGS` | License acceptance |
| `SPLUNK_PASSWORD` | Admin password from `.env` |
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

### tpl.env

- Checked into git as a **template**.
- Contains `op://` references for 1Password CLI **or** plain values for local testing (avoid committing real secrets).
- You must align vault names, item titles, and field names with your 1Password layout. The example paths in a cloned repo may not match your account.

### Generating .env

```bash
make init   # runs: op inject -i tpl.env -o .env
```

Requires `op` signed in and access to the referenced items.

### Typical variables

| Variable | Purpose |
| -------- | ------- |
| `SPLUNK_IMAGE` | Splunk Docker image tag |
| `SPLUNK_PASSWORD` | Admin password |
| `SPLUNKBASE_USER` / `SPLUNKBASE_PASS` | Splunkbase (names in `compose.yml` map these) |
| `TZ` | Timezone |

**Note:** `compose.yml` expects `SPLUNKBASE_USER` and `SPLUNKBASE_PASS` in the environment; ensure `tpl.env` defines names that match (the Makefile injects into `.env` which Compose loads).

## Makefile targets

| Target | Behavior |
| ------ | -------- |
| `init` | `op inject` only |
| `up` | `init`, `docker compose up -d`, wait up to ~2 min for `.secrets/splunk-token`, then `claude-update` |
| `claude-update` | Runs `scripts/update-claude-config.sh` |
| `cursor-mcp` | Runs `scripts/update-cursor-config.sh` → `.cursor/mcp.json` |
| `down` / `restart` / `logs` / `status` / `clean` | As labeled in `make help` |

## scripts/setup-splunk.sh

Runs **inside** `splunk-init` with `SPLUNK_HOST=so1`. It:

1. Sets MCP server `ssl_verify=false` via REST (dev convenience).
2. Ensures index `claude_logs` and a monitor for `/var/log/claude_logs` (idempotent).
3. Creates role **`mcp_tool_execute`** and ensures it has capability `mcp_tool_execute` (required by MCP).
4. Creates user **`dd`** with roles `user` and `mcp_tool_execute` (no `admin` by default).
4. Requests an **encrypted MCP token** from `.../Splunk_MCP_Server/mcp_token?username=dd&output_mode=json`.
5. Writes the token to `TOKEN_OUTPUT_FILE` (`.secrets/splunk-token` on the host).

The init script also generates a dedicated password for `dd` if `DD_PASSWORD` is not provided and persists it to `$(dirname TOKEN_OUTPUT_FILE)/dd-password` (git-ignored).

## Claude Desktop configuration

- Path: **`~/Library/Application Support/Claude/claude_desktop_config.json`** (macOS).
- `update-claude-config.sh` merges `mcpServers.splunk-mcp-server` without destroying other servers.
- Uses **`jq`**; backs up invalid JSON with a timestamped file.

## Cursor configuration

- Default output: **`.cursor/mcp.json`** (override with `CURSOR_MCP_JSON`).
- `update-cursor-config.sh` merges **`splunk-mcp-server`** the same way as Claude.
- Example placeholder without secrets: **`.cursor/mcp.json.example`**.

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
