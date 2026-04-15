# AGENTS.md

Repo-specific guidance for AI agents and contributors working in `splunk-mcp`.

## What this repo is

- **Purpose**: local PoC that runs **Splunk Enterprise** in Docker and exposes **Splunk MCP Server** on `https://localhost:8089/services/mcp`.
- **Client bridge**: Claude Desktop, Cursor, or Goose connect via `npx mcp-remote` (see `make claude-update`, `make cursor-mcp`, `make goose-update`).

## Golden rules (don’t break these)

- **Never commit secrets**:
  - `.env` (admin password, Splunkbase creds)
  - **`tpl.env`** (local `op://` paths to **your** vault—gitignored; start from tracked **`tpl.env.example`**)
  - `.secrets/*` (encrypted MCP token, **`splunker`** password file)
  - `.cursor/mcp.json` if it contains a live Bearer token
  - `~/.config/goose/config.yaml` (token in extension config)
- **Do not paste tokens/passwords** into issues, PRs, or logs.
- **Keep changes idempotent**: `make up` / `splunk-init` should be safe to run repeatedly.

## How the stack boots

- **`make up`**: **`docker compose up -d`** with secrets from **either** a gitignored **`.env`** on disk **or** **`op run --env-file=tpl.env`** when `.env` is absent (requires signed-in `op`). See **`Makefile`** for exact behavior.
- **`make down`**, **`make logs`**, **`make restart`**, **`make status`**, **`make clean`**: plain **`docker`** / **`docker compose`** only—no `op` or project secrets required.
- When **`.env`** is absent, **`make up`** runs **`check-env-for-up`** so **`op run`** yields non-empty **`SPLUNK_PASSWORD`**, **`SPLUNKBASE_USER`**, **`SPLUNKBASE_PASS`** before Splunk starts.
- **`make init`** (optional): `op run --env-file=tpl.env -- scripts/materialize-env.sh .env`—skipped if `.env` exists unless **`FORCE=1`**.
- **`make up`**: waits for **`.secrets/splunk-token`**, then runs **`make claude-update`**.
- **`splunk-init`** runs **`scripts/setup-splunk.sh`** after **`so1`** is healthy.

## What `scripts/setup-splunk.sh` does

Splunk REST bootstrap (see **`docs/SETUP_SPLUNK_SCRIPT.md`** for detail):

- MCP dev: **`ssl_verify=false`** on the Splunk MCP Server app (local dev only).
- **SA-Eventgen**: enables the default modular input when the app is installed.
- **Identity**: Splunk role **`mcp_user`** with capability **`mcp_tool_execute`**; user **`splunker`** (overridable via **`SPLUNKER_USERNAME`** / **`MCP_TOKEN_USERNAME`**) with roles **`user`** + **`mcp_user`**.
- **Token**: encrypted MCP token from the app’s **`mcp_token`** endpoint → **`TOKEN_OUTPUT_FILE`** (host **`.secrets/splunk-token`** when using **`compose.yml`**).
- **Password**: generated or read from **`SPLUNKER_PASSWORD_FILE`** (default **`.secrets/splunker-password`**; **`splunk-init`** uses **`/output/splunker-password`**).

**Not** in this script: **`claude_logs`** index or file monitors. Optional ingestion: enable the bind mount in **`compose.yml`**, create the index and monitor in Splunk—**`docs/CONFIGURATION.md`**.

## Client configuration scripts

- **`scripts/update-claude-config.sh`** → `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)
- **`scripts/update-cursor-config.sh`** → **`.cursor/mcp.json`**
- **`scripts/update-goose-config.sh`** → **`~/.config/goose/config.yaml`** (stdio extension entry)

## Quick verification

| Question | Command / check |
| -------- | ----------------- |
| Splunk up? | `make status` |
| MCP client path OK? | `make verify-mcp-remote` |
| Eventgen modinput? | `curl -k -u admin:<password> "https://localhost:8089/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default?output_mode=json"` |

## Makefile knobs

- **`TOKEN_FILE`**: token path (default **`.secrets/splunk-token`**)
- **`ENV_FILE`**: file for `op run` (default **`tpl.env`**)
- **`ENV_EXAMPLE`**: tracked template (default **`tpl.env.example`**)
- **`ENV_OUT`**: materialized env (default **`.env`**)
- **`OP`**, **`DC`**: 1Password CLI and docker compose command
- **`make wait-token`**: waits on **`$(TOKEN_FILE)`** (used by **`make up`**)

## Common failure modes

- **“User lacks required mcp_tool_execute capability”** — Role **`mcp_user`** missing the capability. Re-run setup or POST **`capabilities=mcp_tool_execute`** to **`/services/authorization/roles/mcp_user`** (see **`scripts/setup-splunk.sh`**).
- **No data in `claude_logs`** — This repo does not create that index or inputs. Confirm bind mount, index, and monitor in Splunk (**`docs/CONFIGURATION.md`**).

## Change discipline

- Prefer small commits; keep **`make up`**, **`make status`**, **`make verify-mcp-remote`** working.
- When changing **`Makefile`**, **`compose.yml`**, or **`scripts/setup-splunk.sh`**, update **`docs/CONFIGURATION.md`**, **`docs/OVERVIEW.md`**, and/or **`docs/TROUBLESHOOTING.md`** as needed.
- Markdown edits: **`make lint-md`** (or **`make lint-md-fix`**) — see **`.markdownlint-cli2.jsonc`**.
- **License:** contributions are under **[LICENSE](LICENSE)** (MIT).
