# AGENTS.md

Repo-specific guidance for AI agents and contributors working in `splunk-mcp`.

## What this repo is

- **Purpose**: local PoC that runs **Splunk Enterprise** in Docker and exposes **Splunk MCP Server** on `https://localhost:8089/services/mcp`.
- **Client bridge**: **Claude Desktop**, **Cursor**, and **Goose** use **`npx mcp-remote`** to `https://localhost:8089/services/mcp` (token minted at `make update-*-config` after **`splunk-init`** completes; stored only in client config, not the repo). See `make update-mcp-clients` or `make update-mcp-client MCP_CLIENT=…`. **SE / presales**: **`docs/PRESALES.md`**.
- **Sample app**: **`SA-S4R`** (UI label **Splunk4Rookies**) — bind-mounted Eventgen traffic, lookups, dashboard assets. Workshop hub: **`docs/s4r/README.md`**. SPL runbook: **`docs/S4R-SPL-CATALOG.md`**. Data: **`docs/SA-S4R-APP.md`**. Dashboard layout: **`docs/S4R-DASHBOARD.md`**. Agents: **`docs/S4R-AGENTS.md`** + **`.cursor/agents/`**.
- **Session memory (Vellem)**: when the **vellem** MCP server is enabled in Cursor, start with **`search_notes_semantic`** on folder **`splunk-mcp`** (boot, verify, troubleshooting) before deep doc reads. Use **`list_expiring_contexts`** to avoid stale notes. After demos or non-obvious fixes, capture outcomes in Vellem (**`add_decision_note`** / **`append_to_daily`**) — not in git. Splunk MCP handles live data; Vellem holds repo-specific memory (no secrets).

## Golden rules (don’t break these)

- **Never commit secrets**:
  - `.env` (admin password, Splunkbase creds, MCP user password)
  - **`tpl.env`** (local `op://` paths to **your** vault—gitignored; start from tracked **`tpl.env.example`**)
  - `.cursor/mcp.json` if it contains a live bearer token (expected after `make update-cursor-config`)
  - `~/.config/goose/config.yaml` if it contains a live bearer token (expected after `make update-goose-config`)
- **Do not paste tokens/passwords** into issues, PRs, or logs.
- **Keep changes idempotent**: `make up` / `splunk-init` should be safe to run repeatedly.

## How the stack boots

- **`make up`**: runs **`scripts/compose-up.sh`** → **`docker compose up -d`** with secrets from **either** a gitignored **`.env`** on disk **or** **`op run --env-file=tpl.env`** when `.env` is absent (requires signed-in `op`). See **`Makefile`** for exact behavior.
- **`compose-up.sh`** requires non-empty **`SPLUNK_PASSWORD`**, **`SPLUNKBASE_USER`**, **`SPLUNKBASE_PASS`**, and **`SPLUNK_MCP_PASSWORD`** (both Path A and Path B), then **`scripts/wait-splunk-init.sh`** blocks until **`splunk-init`** exits **0**.
- **`make down`**, **`make logs`**, **`make restart`**, **`make status`**, **`make clean`**: plain **`docker`** / **`docker compose`** only—no `op` or project secrets required.
- **`make up`**: runs **`make update-mcp-clients`** (Claude, Cursor, Goose). Bearer tokens are written only to client configs, not the repo.
- **Secrets paths:** **Path A** — `tpl.env` + `op run` (no plaintext `.env`); **Path B** — hand-written **`.env`** from **`.env.example`** (plain values; Compose auto-loads it). If **`.env` is absent**, **`make up`** uses `op run --env-file=tpl.env`.
- **`splunk-init`** runs **`scripts/setup-splunk.sh`** after **`so1`** is healthy.

## What `scripts/setup-splunk.sh` does

Splunk REST bootstrap (see **`docs/CONFIGURATION.md` § Appendix: setup-splunk.sh** for detail):

- MCP dev: **`ssl_verify=false`** on the Splunk MCP Server app (local dev only).
- **SA-Eventgen**: enables the default modular input when the app is installed.
- **Identity**: Splunk role **`mcp_user`** with capability **`mcp_tool_execute`**; user **`splunker`** (overridable via **`SPLUNK_MCP_USER`**) with roles **`user`** + **`mcp_user`**; MCP token minted for the same user. Optional **`MLTK_ROLE`** / **`SPLUNK_MLTK_USER`** only when Splunk AI Toolkit is installed manually (not in **`SPLUNK_APPS_URL`**).
- **Token**: encrypted MCP token is minted by **`scripts/mint-mcp-token.sh`** (after **`splunk-init`** exits) and written only to client configs (not the repo).
- **Password**: MCP user password is provided via **`SPLUNK_MCP_PASSWORD`** (env).

**Not** in this script: **`claude_logs`** index or file monitors. Optional ingestion: enable the bind mount in **`compose.yml`**, create the index and monitor in Splunk—**`docs/CONFIGURATION.md`**.

## Client configuration scripts

- **`scripts/mcp-client.sh update <claude\|cursor\|goose>`** — Claude → `~/Library/Application Support/Claude/claude_desktop_config.json`; Cursor → **`.cursor/mcp.json`**; Goose → **`~/.config/goose/config.yaml`**
- **`scripts/mcp-client.sh verify <client\|all>`** — config check + Splunk MCP `tools/list` (`make verify-mcp-remote` defaults to **`all`**)
- **Client configs** store the **absolute path** to **`npx`** (GUI apps often lack Homebrew on `PATH`). Override at update time: **`MCP_NPX_COMMAND=/full/path/to/npx`**.

## Quick verification

| Question | Command / check |
| -------- | ----------------- |
| Stack healthy? | `make status` — **`splunk-init`** line + **Splunk is ready ✓**; exits non-zero if init failed or Splunk down |
| MCP client path OK? | `make verify-mcp-remote` (all clients) or `make verify-mcp-remote MCP_VERIFY_CLIENT=cursor` |
| Pre-demo / both checks? | `make demo-prep` (status + verify + warm-stack reminder) or `make verify` (status then verify only) |
| Init failed? | `docker logs splunk-init` (see **`docs/TROUBLESHOOTING.md`**) |
| Eventgen modinput? | `curl -k -u admin:<password> "https://localhost:8089/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default?output_mode=json"` |
| S4R workshop mode? | `make s4r-attack-nk-status` — infrastructure (default) vs NK threat; see **`docs/SA-S4R-APP.md`** |
| S4R agentic demo? | **`demo-slides/s4r-demo-slides.md`** (Marp — `make marp-preview`); script **`demo-slides/S4R-DEMO.md`**; build notes **`demo-slides/README.md`** |

## Makefile knobs

- **`ENV_FILE`**: file for `op run` (default **`tpl.env`**)
- **`ENV_EXAMPLE`**: tracked template (default **`tpl.env.example`**)
- **`ENV_OUT`**: optional plain env file for Path B (default **`.env`**)
- **`OP`**, **`DC`**: 1Password CLI and docker compose command
- **`MCP_CLIENT`**, **`MCP_VERIFY_CLIENT`**: single-client update/verify (default **`cursor`** / **`all`**)
- **`SPLUNK_MCP_ENDPOINT`**, **`SPLUNK_MCP_TLS_INSECURE`**, **`MCP_NPX_COMMAND`**: see **`docs/CONFIGURATION.md`**
- **`s4r-attack-nk-enable`** / **`s4r-attack-nk-disable`** / **`s4r-attack-nk-status`**: toggle optional NK purchase-attack Eventgen stanza; **`make restart`** after enable/disable — **`docs/SA-S4R-APP.md`**

## Common failure modes

- **“User lacks required mcp_tool_execute capability”** — Role **`mcp_user`** missing the capability. Re-run setup or POST **`capabilities=mcp_tool_execute`** to **`/services/authorization/roles/mcp_user`** (see **`scripts/setup-splunk.sh`**).
- **`splunk-init` exited non-zero** — **`make status`** prints **`FAILED (exit N)`**; Splunk may still be up but roles/token/MCP setup incomplete. **`docker logs splunk-init`**, then **`make down && make up`** or fix env and re-run init.
- **No data in `claude_logs`** — This repo does not create that index or inputs. Confirm bind mount, index, and monitor in Splunk (**`docs/CONFIGURATION.md`**).
- **MCP client cannot find `npx`** (Claude Desktop / GUI) — Re-run **`make update-mcp-client`** from a shell with Node on PATH, or set **`MCP_NPX_COMMAND`**.

## Change discipline

- Prefer small commits; keep **`make up`**, **`make status`**, **`make verify-mcp-remote`** working.
- When changing **`Makefile`**, **`compose.yml`**, or **`scripts/setup-splunk.sh`**, update **`docs/CONFIGURATION.md`**, **`docs/ARCHITECTURE.md`**, and/or **`docs/TROUBLESHOOTING.md`** as needed; refresh or expire Vellem **`splunk-mcp`** folder notes when behavior changes.
- Lint before push: **`pre-commit run --all-files`** (**gitleaks**, **shellcheck** on **`scripts/*.sh`**, **markdownlint-cli2** on Markdown). Requires **shellcheck** on PATH (`brew install shellcheck`) and **Node/npx**. Auto-fix Markdown: `npx --yes markdownlint-cli2 --fix`.
- **SA-S4R Splunk app:** direct Splunk UI customizations (nav, views, field extractions, saved searches) belong in **`SA-S4R/local/`** only — **never** in **`default/`** (Splunk best practice). Workshop instructions: **`SA-S4R/local/README`** (only tracked file under **`local/`**; see **`.gitignore`**). See **`docs/SA-S4R-APP.md`** § **`default/` vs `local/`**.
- **License:** contributions are under **[LICENSE](LICENSE)** (MIT).

## CI

GitHub Actions: **`ci.yml`** (**gitleaks** full history + **pre-commit**: **gitleaks**, **shellcheck** + **markdownlint**) on pushes/PRs to **`main`** / **`master`**; **`package-s4r.yml`** builds **`SA-S4R.spl`** and publishes a PoC **`latest`** release when **`SA-S4R/`** or that workflow changes (or on **`workflow_dispatch`**). See **`docs/CI_CD.md`** for triggers, permissions, and PoC limitations.

## Cursor Cloud specific instructions

This section is for cloud agents running in the Cursor Cloud VM (Docker-in-Docker inside a Firecracker microVM). Runtime state **does not persist across a fresh VM boot** — run bootstrap before `make up`.

### Quick start

1. Add **Cursor Cloud environment secrets**: `SPLUNKBASE_USER` and `SPLUNKBASE_PASS` (splunk.com account that can download Splunkbase apps).
2. Bootstrap (idempotent per boot):

   ```bash
   ./scripts/cloud-bootstrap.sh
   # or: make cloud-bootstrap
   ```

3. Start the stack:

   ```bash
   make up
   make verify
   ```

**Options:** `--wipe` reformats the ext4 Splunk data mount and removes Compose volumes (required when changing Splunk major versions — otherwise KVStore can stay `failed`). `--image splunk/splunk:9.3.2` skips the fake-cgroup workaround. `--force-env` recreates gitignored `.env`. See `./scripts/cloud-bootstrap.sh --help`.

The script writes gitignored **`docker-compose.override.yml`** (ext4 bind mount for `so1-var`; fake cgroup mount for Splunk **10.4.x**) and **`.env`** (generated admin/MCP passwords + Splunkbase creds from secrets). Default image: **`splunk/splunk:10.4.1`**.

### What the bootstrap script does

- **Docker daemon** — not auto-started (no systemd). Starts `dockerd`, fixes socket permissions, runs `hello-world`.
- **ext4 loopback** — Splunk rejects overlay/tmpfs (`unusable filesystem`). Backs `/opt/splunk/var` via `/mnt/splunkdb` ← `/splunkdb.img` (25G default).
- **Splunk 10.4.x cgroup workaround** — `splunk/splunk:10.4.x` crashes without a fake cgroup-v2 tree bind-mounted at `/sys/fs/cgroup:ro` (see script). **9.3.2** uses `cgroup: host` instead (no fake tree).
- **`.env` + override** — see quick start above.

### Manual reference (if not using the script)

<details>
<summary>Expand manual commands</summary>

- Docker: `sudo bash -c 'dockerd >/tmp/dockerd.log 2>&1 &'` then `sudo chmod 666 /var/run/docker.sock`
- ext4: see `ensure_splunkdb_mount` in `scripts/cloud-bootstrap.sh`
- Fake cgroup: see `ensure_fake_cgroup` in `scripts/cloud-bootstrap.sh`
- Override + `.env`: see `write_compose_override` / `write_env_file` in `scripts/cloud-bootstrap.sh`

</details>

### After `make up`

- **MCP token:** `make update-mcp-client MCP_CLIENT=cursor` (writes gitignored `.cursor/mcp.json`). Drive the endpoint with **`npx mcp-remote`** (session handshake); raw `curl` is unreliable for tool execution.
- **Lint:** `pre-commit run --all-files` — **gitleaks**, `shellcheck` (system) + `pre-commit` on `~/.local/bin` PATH; `markdownlint-cli2` via `npx`.
