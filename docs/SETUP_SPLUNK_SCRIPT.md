# `scripts/setup-splunk.sh` — reference and flow

This document describes **[`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh)**: what it configures, how it behaves idempotently, which environment variables it reads, and how its helper functions fit together. It complements the shorter summary in [CONFIGURATION.md](CONFIGURATION.md).

## Purpose

The script bootstraps a **local Splunk Enterprise PoC** so that:

1. The **Splunk MCP Server** app can be used via the local MCP proxy with dev-friendly TLS settings.
2. **SA-Eventgen** sample data can run via the default modular input, when the app is installed.
3. The Splunk user **`SPLUNK_MLTK_USER`** (default **same as `SPLUNK_MCP_USER`**, e.g. **`splunker`**) receives the **`MLTK_ROLE`** (default **`mltk_dsdl_admin`**) when the **Splunk AI Toolkit** app is installed (separate from **`SPLUNK_REST_USER`**, which is only the REST **login**; override **`SPLUNK_MLTK_USER`** in **`.env`** to **`admin`** if the admin account should have MLTK).
4. Splunk has a dedicated **MCP execution identity**: Splunk role **`mcp_user`** (capability **`mcp_tool_execute`**) and local user **`splunker`** by default. Token minting happens at runtime in the local proxy (in memory).

The script is **`/bin/sh`**, uses **`set -eu`**, and talks to Splunk only through **HTTPS REST** (`curl -k` for local dev).

**Out of scope:** **`claude_logs`** index and monitors—add them in Splunk if you enable the bind mount (see [CONFIGURATION.md](CONFIGURATION.md)).

## Where it runs

In this repository, Compose starts an **`splunk-init`** one-shot container **after** `so1` (Splunk) is healthy. That container installs `curl` and `jq`, then executes this script. See [`compose.yml`](../compose.yml).

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
| `SPLUNK_MCP_USER` | `splunker` | MCP user (from `.env` when set in `compose.yml`) |
| `SPLUNK_MLTK_USER` | `splunker` (or `SPLUNK_MCP_USER` from compose) | MLTK role target; override in `.env` (e.g. `admin`) |
| `MLTK_ROLE` | `mltk_dsdl_admin` | Splunk role assigned in step 5 |
| `SPLUNK_PASSWORD` | *(secret)* | REST password |
| `SPLUNK_MCP_PASSWORD` | *(secret)* | Password for the MCP execution user |

You can run the script manually on a host that reaches Splunk, with the same variables.

## Configuration variables

| Variable | Default | Meaning |
| -------- | ------- | ------- |
| `SPLUNK_HOST` | `localhost` | REST host |
| `SPLUNK_PORT` | `8089` | REST port |
| `SPLUNK_REST_USER` | `admin` | Authenticated user for REST (namespace for `mcp_token` call) |
| `SPLUNK_PASSWORD` | *(required)* | Admin password; **must** be set in the environment |
| `SPLUNK_MCP_USER` | `splunker` | Splunk user to create or update |
| `SPLUNK_MLTK_USER` | *same as `SPLUNK_MCP_USER`* | User that receives `MLTK_ROLE` (set `admin` in `.env` to use the management account) |
| `MLTK_ROLE` | `mltk_dsdl_admin` | Splunk role from MLTK to assign; empty skips assignment |
| `SPLUNK_MCP_PASSWORD` | *(required in this repo)* | Password for the MCP execution user |
| `AUTH_CURL_QUIET` | *(internal)* | When `1`/`true`, suppresses stderr from failed `auth_curl` (used by helpers) |

Deprecated names (still read if new names unset): `SPLUNK_USER`, `SPLUNKER_USERNAME`, `MLTK_ROLES_USER`, `SPLUNKER_PASSWORD_FILE`, `FORCE_SPLUNKER_PASSWORD`, `MCP_TOKEN_USERNAME`. **`compose.yml`** maps the first three into `SPLUNK_REST_USER`, `SPLUNK_MCP_USER`, and `SPLUNK_MLTK_USER` so legacy **`.env`** keys work without listing every name on the container.

**Refuses to run** if `SPLUNK_MCP_USER` is `admin` (tokens must not target the admin account).

## End-to-end execution order

High-level phases match the source order in the script.

```mermaid
flowchart TD
  A[Start set -eu] --> B[Enable Eventgen modinput]
  B --> C[MCP app: ssl_verify=false]
  C --> D[Ensure role mcp_user + capability mcp_tool_execute]
  D --> E[Resolve splunker password from env]
  E --> F[Create or update user SPLUNK_MCP_USER]
  F --> D2[Add MLTK_ROLE to SPLUNK_MLTK_USER]
  D2 --> K[Done]
```

## Sequence: REST interactions

The script uses **basic auth** on every `auth_curl` call: `-u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}"` with `curl -k`.

```mermaid
sequenceDiagram
  participant S as setup-splunk.sh
  participant API as Splunk REST :8089
  S->>API: POST .../modinput_eventgen/default/enable (fallback disabled=0)
  S->>API: POST .../conf-mcp/server ssl_verify=false
  S->>API: GET/POST .../authorization/roles/mcp_user capabilities=mcp_tool_execute
  S->>API: GET/POST .../authentication/users/SPLUNK_MLTK_USER (merge roles, include MLTK_ROLE)
  S->>API: POST .../authentication/users (splunker, roles user + mcp_user)
```

### Endpoint reference (no secrets in URLs)

| Step | Method | Path (relative to `https://HOST:PORT`) | Notes |
| ---- | ------ | ---------------------------------------- | ----- |
| Eventgen | POST | `/servicesNS/nobody/SA-Eventgen/data/inputs/modinput_eventgen/default/enable` | Fallback: same URL with `disabled=0` |
| MCP TLS dev | POST | `/servicesNS/nobody/Splunk_MCP_Server/configs/conf-mcp/server` | Body: `ssl_verify=false` |
| Role | GET/POST | `/services/authorization/roles/mcp_user` | Body: `capabilities=mcp_tool_execute` |
| Admin + MLTK | GET/POST | `/services/authentication/users/{SPLUNK_MLTK_USER}` | GET for current `roles[]`; POST repeats `roles=` for each, including `MLTK_ROLE` |
| User | POST | `/services/authentication/users` or `.../users/{name}` | Bodies: `roles=user`, `roles=mcp_user` (splunker) |

## Helper functions

### `auth_curl`

Wraps `curl` with admin credentials, captures HTTP status and body to a temp file, and normalizes behavior:

- **2xx/3xx**: prints body to stdout, deletes temp file, returns `0`.
- **Other**: optionally prints error to stderr (unless `AUTH_CURL_QUIET` is set), returns `1`.

### `must`

Runs a command and **`exit 1`** if it fails. Used for the `mcp_token` request.

### `read_secret_file`

Loads a one-line secret from a file (legacy).

### `splunk_get_json` / `wait_for_disabled_value`

Used to poll the Eventgen stanza until `disabled=0` when `jq` is available.

## Password and token handling

- **Password**: In this repo, the MCP execution user password is supplied via `SPLUNK_MCP_PASSWORD` (env), not generated and written to disk.
- **Token**: Token minting happens in the local `mcp-proxy` service at runtime and is held in memory.

## Idempotency and safe re-runs

Designed so **`make up` / `splunk-init` repeating** does not break:

- MCP `ssl_verify=false` is posted every run; failure is non-fatal (warning).
- Role `mcp_user` is updated or created; capability is set each run.
- User create/update tolerates existing users.
- `MLTK_ROLE` is merged with existing `SPLUNK_MLTK_USER` roles (via `jq`); non-fatal if the MLTK app (and thus the role) is absent.

## Security notes (dev PoC)

- **`curl -k`** disables TLS certificate verification: appropriate only for **local/dev** Splunk with the default Splunk certificate.
- **`ssl_verify=false`** in the MCP app config is **dev-only**; do not mirror this blindly in production.
- **Secrets**: never commit `.env` / `tpl.env` or any client config containing secrets. See [AGENTS.md](../AGENTS.md) and [SECURITY.md](SECURITY.md).

## Troubleshooting pointers

| Symptom | Likely cause | Where to read more |
| ------- | ------------ | ------------------ |
| “User lacks mcp_tool_execute capability” | `mcp_user` role missing capability | [TROUBLESHOOTING.md](TROUBLESHOOTING.md), re-run setup |
| Token empty / script exits 1 | MCP app missing or wrong version | Confirm `Splunk_MCP_Server` in `SPLUNK_APPS_URL` |
| No Claude logs | Index/monitor not created (minimal script) | [CONFIGURATION.md](CONFIGURATION.md); create index/monitor in Splunk |
| Eventgen warnings | SA-Eventgen not installed or URL changed | Check Splunkbase app install and REST path |

## Related documentation

- [CONFIGURATION.md](CONFIGURATION.md) — Compose, env files, Makefile, short setup list
- [OVERVIEW.md](OVERVIEW.md) — stack overview
- [ARCHITECTURE.md](ARCHITECTURE.md) — how `splunk-init` fits the architecture
- [API_REFERENCE.md](API_REFERENCE.md) — Splunk REST and MCP token flow
