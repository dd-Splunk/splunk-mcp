# AGENTS.md

Repo-specific guidance for AI agents and contributors working in `splunk-mcp`.

## What this repo is

- **Purpose**: local PoC that runs **Splunk Enterprise** in Docker and exposes **Splunk MCP Server** on `https://localhost:8089/services/mcp`.
- **Client bridge**: Claude Desktop, Cursor, or Goose connect via `npx mcp-remote` (see `make claude-update`, `make cursor-mcp`, `make goose-update`).

## Golden rules (don’t break these)

- **Never commit secrets**:
  - `.env` (admin password, Splunkbase creds)
  - `.secrets/*` (encrypted MCP token, generated `dd` password)
  - `.cursor/mcp.json` if it contains a live Bearer token
  - `.config/goose/config.yaml` (contains token in extension config)
- **Do not paste tokens/passwords into issues/PRs/logs**.
- **Keep changes idempotent**: `make up`/`splunk-init` should be safe to run repeatedly.

## How the stack boots

- `make up` (default path): runs **`docker compose up -d`** with secrets from **either**:
  - **`.env`** on disk if it exists (e.g. after `make init`), **or**
  - **`op run --env-file=tpl.env`** if `.env` is absent (no `.env` write; requires signed-in `op`).
- **`make down`**, **`make logs`**, **`make restart`**, **`make status`**, **`make clean`** use plain **`docker`** / **`docker compose`** and do **not** require `op` or secrets for lifecycle—only the project/container names from this repo.
- **`make up`** runs **`check-env-for-up`** first when **`.env`** is absent: verifies **`op run`** yields non-empty **`SPLUNK_PASSWORD`**, **`SPLUNKBASE_USER`**, **`SPLUNKBASE_PASS`** so Splunk is not started with blank Splunkbase credentials.
- `make init` (**optional**): runs `op inject -i tpl.env -o .env` for users who want a materialized `.env` (CI, tooling that expects a file). Skips if `.env` exists unless `FORCE=1`.
- `make up`: waits for `.secrets/splunk-token`, then runs `make claude-update`.
- `splunk-init` runs `scripts/setup-splunk.sh` **after** `so1` is healthy.

## What `scripts/setup-splunk.sh` is responsible for

This script performs one-time-ish setup via Splunk REST:

- **MCP dev config**: sets `ssl_verify=false` in the Splunk MCP Server app config (dev-only).
- **Claude logs index + monitor**:
  - Ensures index `claude_logs`.
  - Creates a monitor for `/var/log/claude_logs` **only if that directory exists inside the container** (bind mount is optional in `compose.yml`).
- **MCP execution identity**:
  - Ensures role `mcp_tool_execute` exists **and** has capability `mcp_tool_execute` (required by MCP).
  - Creates user `dd` with roles `user` + `mcp_tool_execute` (admin is **not** granted by default).
  - Generates an **encrypted MCP token** for `dd` and writes it to `.secrets/splunk-token`.
  - If `DD_PASSWORD` isn’t provided, generates one and persists it to `.secrets/dd-password` (git-ignored).

## Client configuration scripts

After token generation, client config can be updated via:

- **`scripts/update-claude-config.sh`**: Updates `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS).
- **`scripts/update-cursor-config.sh`**: Updates `.cursor/mcp.json` with Splunk MCP server config.
- **`scripts/update-goose-config.sh`**: Updates `~/.config/goose/config.yaml` with Splunk MCP extension (Goose uses `type: stdio` extensions, not `mcpServers`).

## Quick verification commands

- **Is Splunk up?**
  - `make status`
- **Is MCP reachable from the client side?**
  - `make verify-mcp-remote`
- **Is Eventgen modinput enabled?**
  - `curl -k -u admin:<password> "https://localhost:8089/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default?output_mode=json"`

## Makefile knobs you can rely on

- **`TOKEN_FILE`**: path to token file (default `.secrets/splunk-token`)
- **`ENV_FILE`**: template passed to `op run` (default `tpl.env`)
- **`ENV_OUT`**: optional materialized env file (default `.env`)
- **`OP`**: 1Password CLI binary (default `op`)
- **`DC`**: docker compose command (default `docker compose`)
- **`make wait-token`**: waits for `$(TOKEN_FILE)` and fails on timeout (used by `make up`)

## Common failure modes (and what to check)

- **MCP returns “User lacks required mcp_tool_execute capability”**
  - The role exists but is missing the capability.
  - Fix is in `scripts/setup-splunk.sh`: ensure `capabilities=mcp_tool_execute`.
- **Claude logs monitor creation fails**
  - `/var/log/claude_logs` isn’t mounted into the container.
  - Enable the bind mount in `compose.yml` (macOS path) or change it for your OS.

## Suggested change discipline

- Prefer small commits that keep `make up`, `make status`, and `make verify-mcp-remote` working.
- When updating setup logic, update docs in `docs/CONFIGURATION.md`, `docs/OVERVIEW.md`, and/or `docs/TROUBLESHOOTING.md`.
- Human contributors: see **[CONTRIBUTING.md](CONTRIBUTING.md)** and **[LICENSE](LICENSE)** (MIT).
