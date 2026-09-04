## compose.yml

**`SPLUNK_APPS_URL`** in **`compose.yml`** is a comma-separated list of Splunkbase download URLs; the **`compose.yml`** comments identify each app. Current entries (app ID → name):

| App ID | App | Pinned release |
| ------ | --- | -------------- |
| 1924 | SA-Eventgen (sample data / Eventgen modinput) | 8.2.1 |
| 4353 | Config Explorer (optional UI utility) | 1.8.26 |
| 7931 | Splunk MCP Server (required for `/services/mcp`) | 2.0.0 |
| 7245 | Splunk AI Assistant | 2.3.2 |

Check current Splunkbase releases: `https://splunkbase.splunk.com/api/v1/app/<id>/release/` (first entry is latest). Update the `/release/VERSION/` segment in **`compose.yml`** when bumping.

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

### Local overrides (optional)

Docker Compose merges **`docker-compose.override.yml`** automatically when present (file is **gitignored**). Create it at the repo root for host-specific ports or mounts instead of editing tracked **`compose.yml`**.

```yaml
services:
  so1:
    # Host ports already in use (default mapping is 8000 / 8089 on localhost)
    ports:
      - "127.0.0.1:9000:8000"
      - "127.0.0.1:9089:8089"
    # macOS: optional Claude Desktop log bind mount (see commented line in compose.yml)
    volumes:
      - ${HOME}/Library/Logs/Claude:/var/log/claude_logs:rw
```

Use only the blocks you need. If you remap **8089**, set **`SPLUNK_MCP_ENDPOINT`** (and re-run **`make update-mcp-clients`**) to the new URL. Do not commit secrets or machine-specific paths.

### Service `splunk-init`

Runs after `so1` is **healthy**. Uses Alpine, installs `curl` and `jq`, then runs `setup-splunk.sh`. Mounts:

- `scripts/setup-splunk.sh` → `/setup-splunk.sh`
- No host secrets mount (this repo does not write tokens/passwords to disk). See `compose.yml` for `SPLUNK_REST_USER`, `SPLUNK_MCP_USER`, `SPLUNK_MCP_PASSWORD`.

### MCP token minting and S4R tools (host)

- **`scripts/wait-splunk-init.sh`** — blocks until the **`splunk-init`** container exits `0` (`compose-up.sh` runs this after `docker compose up`).
- **`scripts/register-s4r-mcp-tools.sh`** — after init: `POST /services/mcp_tools` for **SA-S4R** (`make up` runs this; also `make register-s4r-mcp-tools`).
- **`scripts/mint-mcp-token.sh`** — after init: waits for Splunk API, polls **`mcp_token`**, prints encrypted token to stdout.
- **`make update-mcp-client`** writes the token into Claude / Cursor / Goose configs only.

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

For a **plaintext `.env`** on disk (no 1Password at `make up` time), copy [`.env.example`](../../.env.example) to **`.env`**, fill values, and run **`make up`**. Compose auto-loads **`.env`**. Use for CI or contributors without `op`.

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
| `up` | `scripts/compose-up.sh` (`.env` or `op run --env-file=tpl.env`), then `update-all` (`MCP_UPDATE_ON_BOOT`, default `cursor`), then `register-s4r-mcp-tools` |
| `down` | `scripts/mcp-client.sh park all` (no secrets), then `docker compose down` |
| `park-mcp-clients` | `scripts/mcp-client.sh park all` — remove `splunk-mcp-server` from client configs |
| `update-mcp-clients` | `scripts/mcp-client.sh update-all` for cursor, goose, claude (one mint) |
| `update-mcp-client` | One client: `MCP_CLIENT=claude\|cursor\|goose` |
| `update-claude-config` / `update-cursor-config` / `update-goose-config` | Aliases for `update-mcp-client` |
| `verify-mcp-remote` | `scripts/mcp-client.sh verify` — client config + direct `tools/list` + **`npx mcp-remote` stdio** e2e (`MCP_VERIFY_CLIENT=all` by default) |
| `verify` | Runs `status`, then `verify-mcp-remote` |
| `demo-prep` | Runs `status`, then `verify-mcp-remote`, and prints the live-demo warm-stack reminder. Cursor: **`/demo-prep`** skill |
| `cloud-bootstrap` | `scripts/cloud-bootstrap.sh` — Cursor Cloud VM prep before `make up` (`CLOUD_BOOTSTRAP_ARGS` for flags) |
| `restart` / `logs` / `status` | Lifecycle only (no secrets / `op` required) |
| `clean` | `scripts/mcp-client.sh park all`, then `docker compose down -v`, then remove `.env` (no `op` required). Prompts unless **`make clean-y`** or **`CLEAN_YES=1`** |
| `clean-y` | Non-interactive **`clean`** (for automation, e.g. `make clean-y && make up`) |
| `s4r-attack-nk-enable` | **Shell fallback:** sets **`disabled = false`** on NK Eventgen stanza; run **`make restart`**. Prefer MCP **`SA-S4R_apply_nk_demo_state`** (`mode=threat`) — no restart |
| `s4r-attack-nk-disable` | **Shell fallback:** sets **`disabled = true`**. Prefer MCP **`SA-S4R_apply_nk_demo_state`** (`mode=infrastructure`) |
| `s4r-attack-nk-status` | **Shell fallback:** prints NK stanza enabled/disabled. Prefer MCP **`SA-S4R_query_nk_demo_state`** |
| `register-s4r-mcp-tools` | Host `POST /services/mcp_tools` for **SA-S4R** (also run by `make up`); re-run after editing `s4r_mcp_tools.json` |
| `marp-preview` / `marp-serve` / `marp-html` | Preview, serve, or export the S4R presenter deck under `demo-slides/` |

Workshop behavior and validation SPL: **[SA-S4R-APP.md](../s4r/SA-S4R-APP.md)** (Workshop modes). Marp deck mechanics: **[demo-slides/README.md](../../demo-slides/README.md)**.

## scripts/setup-splunk.sh

Summary of what runs **inside** `splunk-init` with `SPLUNK_HOST=so1`:

1. Enables the **SA-Eventgen** default modular input when the app is installed.
2. Sets MCP server `ssl_verify=false` via REST (dev convenience).
3. Ensures Splunk role **`mcp_user`** exists with capability **`mcp_tool_execute`** and **`srchJobsQuota=5`** (parallel S4R agent headroom).
4. Creates or updates user **`splunker`** (override with **`SPLUNK_MCP_USER`**) with roles **`user`** + **`mcp_user`**, and clears **`locked-out`** (idempotent unlock on every init).
5. Optionally adds **`MLTK_ROLE`** to **`SPLUNK_MLTK_USER`** when **`MLTK_ROLE`** is set (skipped by default; Splunk AI Toolkit is not installed by this stack).
6. Uses `SPLUNK_MCP_PASSWORD` from env; this repo does not write passwords to disk.

**Full reference** (REST tables, diagrams, idempotency): [Appendix: setup-splunk.sh](#appendix-setup-splunksh).

## Splunk MCP authentication (1.3)

Splunk MCP Server **1.3** supports two client authentication patterns. This PoC automates **encrypted bearer tokens** only; OAuth is documented for **Splunk Cloud** presales (manual client setup).

Official references:

- [About MCP Server (1.3)](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/about-mcp-server-for-splunk-platform)
- [Connecting and settings (1.3)](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/connecting-to-the-mcp-server-and-settings)
- [OAuth for MCP Server (1.3)](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/oauth-for-mcp-server)
- [Connect Cursor via OAuth (1.3)](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/connect-cursor-to-splunk-mcp-server)

### Encrypted bearer token (default for this repo)

| Aspect | Detail |
| ------ | ------ |
| **When** | Local Enterprise Docker PoC, workshops, Claude Desktop, Goose, or any client using **`npx mcp-remote`** |
| **How** | Mint encrypted token (MCP app UI or **`scripts/mint-mcp-token.sh`** → `mcp_token` REST); client sends **`Authorization: Bearer <token>`** |
| **Automation** | **`make update-mcp-clients`** writes token into client configs only (not git) |
| **Splunk side** | User needs **`mcp_tool_execute`**; token mint via admin REST uses MCP app **`mcp_token`** endpoint |
| **Security** | Encrypted tokens work **only** for MCP (not general Splunk REST); rotate via MCP app; **Invalidate Keys** revokes all encrypted tokens |

Client shape matches Splunk’s 1.3 sample: **`npx mcp-remote`**, streamable HTTP endpoint, bearer header. For self-signed localhost certs, server **`ssl_verify=false`** (setup script) plus client **`NODE_TLS_REJECT_UNAUTHORIZED=0`** when **`SPLUNK_MCP_TLS_INSECURE=1`**.

### OAuth 2.1 (Splunk Cloud — manual)

| Aspect | Detail |
| ------ | ------ |
| **When** | Customer **Splunk Cloud** stack with OAuth Clients enabled (MCP app **1.2.1+**; Splunk **10.3.2512.11+**, ideally **10.5.2506.3+**) |
| **How** | Admin creates OAuth client in Splunk Web; user signs in via browser (Authorization Code + PKCE); client holds short-lived access tokens—**no long-lived bearer in config** |
| **Cursor** | Native MCP config: **`url`** + **`auth`** (`CLIENT_ID`, `CLIENT_SECRET`, scopes **`openid`**, **`offline_access`**); redirect **`cursor://anysphere.cursor-mcp/oauth/callback`** |
| **Not automated here** | **`make update-mcp-client`** does not configure OAuth; see [PRESALES.md](PRESALES.md#splunk-cloud-stacks-oauth-vs-this-poc) |
| **Prerequisite** | Token-based MCP auth must still be enabled on the stack; OAuth is an alternative **client** path |

Splunk documents OAuth as **Splunk Cloud Platform**–focused. This repo’s local Docker Enterprise stack should keep **encrypted token** auth.

## Claude Desktop configuration

- Path: **`~/Library/Application Support/Claude/claude_desktop_config.json`** (macOS).
- Matches Splunk MCP Server **1.3** [client configuration](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/connecting-to-the-mcp-server-and-settings): **`npx mcp-remote`**, endpoint **`https://localhost:8089/services/mcp`**, **`Authorization: Bearer`** with an **encrypted** token.
- `make update-claude-config` mints the token via **`scripts/mint-mcp-token.sh`** (Splunk app `mcp_token` REST). Splunk must be up. Token is stored **only** in Claude’s config, not in this repo.
- **`NODE_TLS_REJECT_UNAUTHORIZED=0`** is written when **`SPLUNK_MCP_TLS_INSECURE`** is `1` (default for this PoC; self-signed Splunk only). Set **`SPLUNK_MCP_TLS_INSECURE=0`** to omit `env` if using proper TLS.
- Uses **`jq`**; backs up invalid JSON with a timestamped file.

## Cursor configuration

- Default output: **`.cursor/mcp.json`** (override with `CURSOR_MCP_JSON`; gitignored if it contains a live token).
- Same **1.3** `npx mcp-remote` entry as Claude (**`make update-cursor-config`**). For **Splunk Cloud OAuth** instead of bearer tokens, see [Splunk MCP authentication (1.3)](#splunk-mcp-authentication-13) and [PRESALES.md](PRESALES.md#splunk-cloud-stacks-oauth-vs-this-poc).
- Example shape: **`.cursor/mcp.json.example`** (see Splunk doc link in Claude section above).

## Goose configuration

- Path: **`~/.config/goose/config.yaml`** (Unix/Linux and macOS).
- Same Splunk MCP Server **1.3** token pattern as Claude/Cursor: endpoint **`https://localhost:8089/services/mcp`**, encrypted bearer token via **`scripts/mcp-remote-splunk.sh`** wrapper (not raw `npx` in `cmd`).
- Goose uses **extensions** with `type: stdio` (different YAML shape from Claude’s `mcpServers`).
- `scripts/mcp-client.sh update goose` adds or updates the `splunk-mcp-server` extension entry via **`scripts/mcp-remote-splunk.sh`** (sets `NODE_TLS_REJECT_UNAUTHORIZED` in-process; Goose Desktop may not forward `envs` reliably).
- TLS dev override also uses Goose’s **`envs`** and **`env_keys`** (not `env`), e.g. `NODE_TLS_REJECT_UNAUTHORIZED=0` when **`SPLUNK_MCP_TLS_INSECURE=1`**.
- Idempotent: safely updates or creates the extension without corrupting existing config.
- Requires Python 3 for YAML regex manipulation.

## Environment overrides (optional)

| Variable | Used by | Purpose |
| -------- | ------- | ------- |
| `SPLUNK_MCP_ENDPOINT` | `mcp-client.sh` | Splunk MCP URL for `mcp-remote` (default `https://localhost:8089/services/mcp`) |
| `SPLUNK_MCP_TLS_INSECURE` | `mcp-client.sh` | If `1` (default), add `NODE_TLS_REJECT_UNAUTHORIZED=0` to Claude/Cursor config and Goose `envs` / wrapper (dev/self-signed only) |
| `SPLUNK_MCP_USER` | `setup-splunk.sh` | Splunk account to create/update (default `splunker`) |
| `SPLUNK_MLTK_USER` | `setup-splunk.sh` | Which Splunk user gets `MLTK_ROLE` when set (default: same as `SPLUNK_MCP_USER`) |
| `MLTK_ROLE` | `setup-splunk.sh` | MLTK Splunk role to assign; empty by default (Splunk AI Toolkit not in `SPLUNK_APPS_URL`) |
| `CURSOR_MCP_JSON` | `mcp-client.sh` (cursor) | Output path |
| `MCP_CLIENT` | `update-mcp-client` | `claude`, `cursor`, or `goose` |
| `MCP_VERIFY_CLIENT` | `verify-mcp-remote` | `all` (default), or one client |

## Cursor Cloud bootstrap

Cursor Cloud VMs (Docker-in-Docker, no systemd) need one-time **per-boot** setup before `make up`. Use:

```bash
./scripts/cloud-bootstrap.sh    # or: make cloud-bootstrap
make up
make verify
```

**Prerequisites (`.env` creation):** prefer **Path A** — **`tpl.env`** with your `op://` paths + **`op`** signed in (or **`OP_SERVICE_ACCOUNT_TOKEN`** in Cursor Cloud secrets). Fallback **Path B:** set **`SPLUNKBASE_USER`** / **`SPLUNKBASE_PASS`** only in Cursor Cloud secrets (admin/MCP passwords are generated).

| Flag / env | Purpose |
| ---------- | ------- |
| `--wipe` | Reformat ext4 Splunk data + `docker compose down -v` (use when changing Splunk major versions) |
| `--image IMAGE` / `SPLUNK_IMAGE` | Default `splunk/splunk:10.4.1` |
| `--force-env` | Recreate gitignored `.env` |
| `ENV_FILE` | 1Password template (default **`tpl.env`**) |
| `OP_SERVICE_ACCOUNT_TOKEN` | Headless **`op`** on Cursor Cloud (no desktop sign-in) |
| `CLOUD_SPLUNKDB_MOUNT` | Default `/mnt/splunkdb` (bind-mounted as `so1-var`) |

Writes gitignored **`docker-compose.override.yml`** (ext4 bind + fake cgroup for 10.4.x). Full notes: [AGENTS.md](../../AGENTS.md) § Cursor Cloud.

## See also

- [ARCHITECTURE.md](ARCHITECTURE.md) — how pieces fit together
- [SECURITY.md](SECURITY.md) — TLS and token handling
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when ports or inject fail

---

## Appendix: setup-splunk.sh

Reference for **[`scripts/setup-splunk.sh`](../../scripts/setup-splunk.sh)**: configuration, idempotent behavior, environment variables, and REST flow.

### Purpose

The script bootstraps a **local Splunk Enterprise PoC** so that:

1. The **Splunk MCP Server** app is configured for local dev (e.g. **`ssl_verify=false`** on the app).
2. **SA-Eventgen** sample data can run via the default modular input, when the app is installed.
3. Optionally, **`SPLUNK_MLTK_USER`** receives **`MLTK_ROLE`** when **`MLTK_ROLE`** is set in env (skipped by default; Splunk AI Toolkit is out of scope for this PoC).
4. Splunk has a dedicated **MCP execution identity**: role **`mcp_user`** (capability **`mcp_tool_execute`**) and user **`splunker`** by default. Token minting is **`scripts/mint-mcp-token.sh`** after **`splunk-init`** (not in this script).

The script is **`/bin/sh`**, uses **`set -eu`**, and talks to Splunk only through **HTTPS REST** (`curl -k` for local dev).

**Out of scope:** **`claude_logs`** index and monitors—add them in Splunk if you enable the bind mount (see **Claude logs (macOS, optional)** under `compose.yml` above). SA-S4R MCP tool registration is **`scripts/register-s4r-mcp-tools.sh`** on the host after this script exits.

### Where it runs

Compose starts **`splunk-init`** **after** `so1` is healthy. That container installs `curl` and `jq`, then executes this script. See [`compose.yml`](../../compose.yml).

```mermaid
flowchart LR
  subgraph host["Host"]
    script["scripts/setup-splunk.sh"]
  end
  subgraph docker["Docker network splunk"]
    so1["so1 Splunk :8089"]
    init["splunk-init Alpine"]
  end
  script -->|"bind mount"| init
  init -->|"HTTPS REST admin auth"| so1
```

Typical environment inside `splunk-init` (from Compose):

| Variable | Example | Role |
| -------- | ------- | ---- |
| `SPLUNK_HOST` | `so1` | REST hostname on the Docker network |
| `SPLUNK_PORT` | `8089` | Management port |
| `SPLUNK_REST_USER` | `admin` | REST login user |
| `SPLUNK_MCP_USER` | `splunker` | MCP user |
| `SPLUNK_MLTK_USER` | `splunker` | MLTK role target |
| `MLTK_ROLE` | *(empty)* | Optional Splunk AI Toolkit role; step 5 skipped when unset |
| `SPLUNK_PASSWORD` | *(secret)* | REST password |
| `SPLUNK_MCP_PASSWORD` | *(secret)* | Password for the MCP execution user |

### Configuration variables

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `SPLUNK_HOST` | `localhost` | REST host |
| `SPLUNK_PORT` | `8089` | REST port |
| `SPLUNK_REST_USER` | `admin` | Authenticated user for REST |
| `SPLUNK_PASSWORD` | *(required)* | Admin password |
| `SPLUNK_MCP_USER` | `splunker` | Splunk user to create or update |
| `SPLUNK_MLTK_USER` | *same as `SPLUNK_MCP_USER`* | User that receives `MLTK_ROLE` |
| `MLTK_ROLE` | *(empty)* | MLTK Splunk role; set only if AI Toolkit is installed manually |
| `SPLUNK_MCP_PASSWORD` | *(required in this repo)* | Password for the MCP execution user |

Deprecated names (still read if new names unset): `SPLUNK_USER`, `SPLUNKER_USERNAME`, `MLTK_ROLES_USER`, `SPLUNKER_PASSWORD_FILE`, `FORCE_SPLUNKER_PASSWORD`, `MCP_TOKEN_USERNAME`.

**Refuses to run** if `SPLUNK_MCP_USER` is `admin` (tokens must not target the admin account).

### Execution order

```mermaid
flowchart TD
  A[Start set -eu] --> B[Enable Eventgen modinput]
  B --> C[MCP app: ssl_verify=false]
  C --> D[Ensure role mcp_user + mcp_tool_execute + s4r_workshop_control]
  D --> E[Resolve splunker password from env]
  E --> F[Create or update user SPLUNK_MCP_USER]
  F --> D2[Add MLTK_ROLE to SPLUNK_MLTK_USER]
  D2 --> K[Done]
```

### REST interactions

The script uses **basic auth** on every `auth_curl` call: `-u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}"` with `curl -k`.

| Step | Method | Path (relative to `https://HOST:PORT`) | Notes |
| ---- | ------ | ---------------------------------------- | ----- |
| Eventgen | POST | `/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/enable` | Fallback: same URL with `disabled=0` |
| MCP TLS dev | POST | `/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server` | Body: `ssl_verify=false` |
| Role | GET/POST | `/services/authorization/roles/mcp_user` | Body: `capabilities=mcp_tool_execute`, `capabilities=s4r_workshop_control`, `srchJobsQuota=5` |
| Admin + MLTK | GET/POST | `/services/authentication/users/{SPLUNK_MLTK_USER}` | Merge `roles[]`, including `MLTK_ROLE` |
| User | POST | `/services/authentication/users` or `.../users/{name}` | Bodies: `roles=user`, `roles=mcp_user`, `locked-out=false` |

### Helper functions

- **`auth_curl`** — wraps `curl` with admin credentials; 2xx/3xx returns body, else fails.
- **`must`** — runs a command and **`exit 1`** on failure.
- **`splunk_get_json` / `wait_for_disabled_value`** — poll Eventgen stanza when `jq` is available.

### Idempotency

Designed so **`make up` / `splunk-init` repeating** does not break: MCP `ssl_verify=false`, role/user updates, and MLTK role merge tolerate re-runs.

### Security notes (dev PoC)

- **`curl -k`** and **`ssl_verify=false`** are **dev-only**; see [SECURITY.md](SECURITY.md).
- Never commit `.env` / `tpl.env` or client configs with secrets. See [AGENTS.md](../../AGENTS.md).

### Troubleshooting pointers

| Symptom | Likely cause | Where to read more |
| ------- | ------------ | ------------------ |
| “User lacks mcp_tool_execute capability” | `mcp_user` role missing capability | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) |
| Token empty / script exits 1 | MCP app missing or wrong version | Confirm `Splunk_MCP_Server` in `SPLUNK_APPS_URL` |
| No Claude logs | Index/monitor not created | Create index/monitor in Splunk |
| Eventgen warnings | SA-Eventgen not installed | Check Splunkbase app install |
