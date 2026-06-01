# AGENTS.md

Repo-specific guidance for AI agents and contributors working in `splunk-mcp`.

## What this repo is

- **Purpose**: local PoC that runs **Splunk Enterprise** in Docker and exposes **Splunk MCP Server** on `https://localhost:8089/services/mcp`.
- **Client bridge**: **Claude Desktop**, **Cursor**, and **Goose** use **`npx mcp-remote`** to `https://localhost:8089/services/mcp` (token minted at `make update-*-config` after **`splunk-init`** completes; stored only in client config, not the repo). See `make update-mcp-clients` or `make update-mcp-client MCP_CLIENT=…`. **SE / presales**: **`docs/PRESALES.md`**.

## Golden rules (don’t break these)

- **Never commit secrets**:
  - `.env` (admin password, Splunkbase creds)
  - **`tpl.env`** (local `op://` paths to **your** vault—gitignored; start from tracked **`tpl.env.example`**)
  - `.cursor/mcp.json` if it contains a live bearer token (expected after `make update-cursor-config`)
  - `~/.config/goose/config.yaml` if it contains a live bearer token (expected after `make update-goose-config`)
- **Do not paste tokens/passwords** into issues, PRs, or logs.
- **Keep changes idempotent**: `make up` / `splunk-init` should be safe to run repeatedly.

## How the stack boots

- **`make up`**: **`docker compose up -d`** with secrets from **either** a gitignored **`.env`** on disk **or** **`op run --env-file=tpl.env`** when `.env` is absent (requires signed-in `op`). See **`Makefile`** for exact behavior.
- **`make down`**, **`make logs`**, **`make restart`**, **`make status`**, **`make clean`**: plain **`docker`** / **`docker compose`** only—no `op` or project secrets required.
- When **`.env`** is absent, **`make up`** runs **`scripts/compose-up.sh`** (`op run` + **`tpl.env`**) and checks non-empty **`SPLUNK_PASSWORD`**, **`SPLUNKBASE_USER`**, **`SPLUNKBASE_PASS`** before Splunk starts.
- **`make up`**: runs **`make update-mcp-clients`** (Claude, Cursor, Goose). Bearer tokens are written only to client configs, not the repo.
- **Secrets paths:** **Path A** — `tpl.env` + `op run` (no plaintext `.env`); **Path B** — hand-written **`.env`** from **`.env.example`** (plain values; Compose auto-loads it). If **`.env` is absent**, **`make up`** uses `op run --env-file=tpl.env`.
- **`splunk-init`** runs **`scripts/setup-splunk.sh`** after **`so1`** is healthy.

## What `scripts/setup-splunk.sh` does

Splunk REST bootstrap (see **`docs/SETUP_SPLUNK_SCRIPT.md`** for detail):

- MCP dev: **`ssl_verify=false`** on the Splunk MCP Server app (local dev only).
- **SA-Eventgen**: enables the default modular input when the app is installed.
- **Identity**: Splunk role **`mcp_user`** with capability **`mcp_tool_execute`**; MLTK role **`MLTK_ROLE`** (default **`mltk_dsdl_admin`**) on **`SPLUNK_MLTK_USER`** (default **`SPLUNK_MCP_USER`** / **`splunker`**, not the REST user **`SPLUNK_REST_USER`**) for AI Toolkit; user **`splunker`** (overridable via **`SPLUNK_MCP_USER`**) with roles **`user`** + **`mcp_user`**; MCP token minted for the same user. Set **`SPLUNK_MLTK_USER=admin`** (or the same as **`SPLUNK_REST_USER`**) in **`.env`** if the admin account should have MLTK instead; override **`MLTK_ROLE`** if your MLTK version uses a different role name.
- **Token**: encrypted MCP token is minted by **`scripts/mint-mcp-token.sh`** (after **`splunk-init`** exits) and written only to client configs (not the repo).
- **Password**: MCP user password is provided via `SPLUNK_MCP_PASSWORD` (env).

**Not** in this script: **`claude_logs`** index or file monitors. Optional ingestion: enable the bind mount in **`compose.yml`**, create the index and monitor in Splunk—**`docs/CONFIGURATION.md`**.

## Client configuration scripts

- **`scripts/mcp-client.sh update <claude\|cursor\|goose>`** — Claude → `~/Library/Application Support/Claude/claude_desktop_config.json`; Cursor → **`.cursor/mcp.json`**; Goose → **`~/.config/goose/config.yaml`**
- **`scripts/mcp-client.sh verify <client\|all>`** — config check + Splunk MCP `tools/list` (`make verify-mcp-remote` defaults to **`all`**)

## Vellem (Cursor memory)

When **Vellem** is in **`.cursor/mcp.json`**, agents should use it as repo-local memory (see **`.cursor/rules/vellem-memory.mdc`**).

- **Read first:** `search_notes` / `get_note` in folder **`splunk-mcp`** before re-scanning docs.
- **Write back:** `add_note` or `update_note` after architecture, setup, or troubleshooting discoveries; `append_to_daily` for short session summaries.
- **Stay in sync:** Vellem is not automatic—when you change **`Makefile`**, **`compose.yml`**, **`scripts/setup-splunk.sh`**, secrets flow, or contributor lint/CI, update the matching note in folder **`splunk-mcp`** (see **`.cursor/rules/vellem-memory.mdc`** § *Keep Vellem in sync*). Trust **`make help`** and docs over Vellem if they disagree. **`.cursor/hooks.json`** nudges the agent after **Write**/**StrReplace** on key workflow files.
- **Never store secrets** in Vellem (tokens, passwords, `.env` values).
- **Vellem entry** (macOS, merge manually or keep alongside Splunk): `"command": "/Applications/Vellem.app/Contents/Resources/vellem-mcp"`. Example: **`.cursor/mcp.json.example`**.

## Quick verification

| Question | Command / check |
| -------- | ----------------- |
| Splunk up? | `make status` |
| MCP client path OK? | `make verify-mcp-remote` (all clients) or `make verify-mcp-remote MCP_VERIFY_CLIENT=cursor` |
| Eventgen modinput? | `curl -k -u admin:<password> "https://localhost:8089/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default?output_mode=json"` |

## Makefile knobs

- **`ENV_FILE`**: file for `op run` (default **`tpl.env`**)
- **`ENV_EXAMPLE`**: tracked template (default **`tpl.env.example`**)
- **`ENV_OUT`**: optional plain env file for Path B (default **`.env`**)
- **`OP`**, **`DC`**: 1Password CLI and docker compose command
- **`SPLUNK_MCP_ENDPOINT`**, **`SPLUNK_MCP_TLS_INSECURE`**: see **`docs/CONFIGURATION.md`**

## Common failure modes

- **“User lacks required mcp_tool_execute capability”** — Role **`mcp_user`** missing the capability. Re-run setup or POST **`capabilities=mcp_tool_execute`** to **`/services/authorization/roles/mcp_user`** (see **`scripts/setup-splunk.sh`**).
- **No data in `claude_logs`** — This repo does not create that index or inputs. Confirm bind mount, index, and monitor in Splunk (**`docs/CONFIGURATION.md`**).

## Change discipline

- Prefer small commits; keep **`make up`**, **`make status`**, **`make verify-mcp-remote`** working.
- When changing **`Makefile`**, **`compose.yml`**, or **`scripts/setup-splunk.sh`**, update **`docs/CONFIGURATION.md`**, **`docs/OVERVIEW.md`**, and/or **`docs/TROUBLESHOOTING.md`** as needed—and **Vellem** folder **`splunk-mcp`** if you use it (especially **Boot Workflow & Makefile**).
- Markdown edits: run **`pre-commit`** (markdownlint-cli2 via **`.pre-commit-config.yaml`** / **`.markdownlint-cli2.jsonc`**). Auto-fix: `npx --yes markdownlint-cli2 --fix`.
- **License:** contributions are under **[LICENSE](LICENSE)** (MIT).

## CI

GitHub Actions: **`ci.yml`** (**pre-commit**: shellcheck + markdownlint) on pushes/PRs to **`main`** / **`master`**; **`package-s4r.yml`** builds **`SA-S4R.spl`** and publishes a PoC **`latest`** release when **`SA-S4R/`** or that workflow changes (or on **`workflow_dispatch`**). See **`docs/CI_CD.md`** for triggers, permissions, and PoC limitations.
