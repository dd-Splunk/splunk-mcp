## Purpose

This repository packages a **repeatable local environment** for:

1. Running **Splunk Enterprise** in Docker with the **Splunk MCP Server** application from Splunkbase.
2. Provisioning a dedicated Splunk user and **encrypted MCP token** suitable for the MCP HTTP endpoint.
3. Wiring **Claude Desktop** or **Cursor** to that endpoint via **`mcp-remote`** (stdio bridge to remote HTTP MCP).

It is a **proof-of-concept**: fast iteration on Splunk + LLM tooling, not a production deployment template.

## Why MCP here

The [Model Context Protocol](https://modelcontextprotocol.io/) lets a client (Claude, Cursor) discover tools and resources exposed by a server. Splunk’s MCP Server app exposes Splunk operations through `/services/mcp`. This repo automates:

- Installing dependencies (Splunkbase downloads at container start).
- Post-start configuration (SSL verify flag for dev, user/role/token).
- Client configuration files with the bearer token.

## Major components

### Splunk container (`so1`)

- Image: `splunk/splunk` (tag from `SPLUNK_IMAGE` in `.env`, default `latest` in `tpl.env`).
- Platform: `linux/amd64` (required for Apple Silicon Macs running x86 Splunk images).
- Ports:
  - **8000**: Splunk Web.
  - **8089**: Splunk management API, including **`/services/mcp`**.
- Volumes:
  - **`so1-var`**: indexes, runtime data.
  - **`so1-etc`**: configuration under `/opt/splunk/etc`.
- Bind mount: **`./SA-S4R` → `/opt/splunk/etc/apps/SA-S4R`** for the bundled sample app.
- Optional bind mount (macOS): host Claude logs → `/var/log/claude_logs` inside the container for monitoring inputs.

### Init container (`splunk-init`)

- Runs **once** after `so1` is healthy.
- Image: **Alpine** (installs `curl` and `jq` at runtime).
- Executes **`scripts/setup-splunk.sh`** with environment pointing at Splunk on the Docker network (`SPLUNK_HOST=so1`).
- Writes the MCP token to **`.secrets/splunk-token`** on the host (mode `600`).

### Splunkbase applications

`compose.yml` sets `SPLUNK_APPS_URL` to a comma-separated list of Splunkbase download URLs. At build/start, Splunk pulls these apps. The stack expects the **Splunk MCP Server** app (namespace `Splunk_MCP_Server`) to be present so REST calls in `setup-splunk.sh` succeed.

You need valid **Splunkbase** credentials in `.env` (`SPLUNKBASE_USERNAME` / `SPLUNKBASE_PASSWORD`).

### Client bridge (`mcp-remote`)

Claude and Cursor do not speak HTTP MCP natively in the same process as the editor; configuration uses:

```text
npx -y mcp-remote https://localhost:8089/services/mcp --header "Authorization: Bearer <token>"
```

with **`NODE_TLS_REJECT_UNAUTHORIZED=0`** to accept Splunk’s default self-signed certificate on localhost. This is appropriate **only** for trusted local development.

### Secrets flow

1. **`tpl.env`**: checked-in template with `op://vault/item/field` references (and non-secret defaults). **You must align paths with your vault**; documentation examples use illustrative item names.
2. **Preferred (`make up` without `.env`)**: the Makefile runs Compose under  
   `op run --env-file=tpl.env -- docker compose …`  
   so variables are injected **at process invocation** and nothing is written to `.env`.
3. **Optional (`make init`)**: runs `op inject -i tpl.env -o .env` for a materialized `.env` (some users or CI prefer a file on disk).
4. **Compose** supplies `SPLUNK_PASSWORD`, Splunkbase credentials, and related env vars to the `so1` and `splunk-init` services.
5. **Token file** `.secrets/splunk-token` is created by `splunk-init` / `setup-splunk.sh`. **`make claude-update`** and **`make cursor-mcp`** read it to patch client JSON.

## Authentication model (as implemented)

| Actor | Mechanism | Notes |
| ----- | --------- | ----- |
| Splunk admin | Username/password (`admin` + `SPLUNK_PASSWORD`) | Used in setup script REST calls |
| MCP client (Claude/Cursor) | Bearer token | Token from Splunk MCP app’s encrypted token endpoint for user `dd` |
| User `dd` | Dedicated password (saved to `.secrets/dd-password` by init unless provided); roles include `mcp_tool_execute` | Created idempotently; see `scripts/setup-splunk.sh` |

The setup script creates Splunk role **`mcp_tool_execute`** (not a generic `mcp_user` name) and assigns it to user **`dd`**.

## End-to-end flow

```text
make up
  → docker compose up -d (env from .env if present, else op run --env-file=tpl.env)
  → so1 starts Splunk, downloads apps, becomes healthy
  → splunk-init runs setup-splunk.sh
      → POST mcp server ssl_verify=false (dev)
      → create index claude_logs + monitor (if path exists in container)
      → create role mcp_tool_execute, ensure capability mcp_tool_execute
      → create user dd (roles: user + mcp_tool_execute; admin only if ADD_ADMIN_ROLE=1)
      → GET encrypted mcp token → .secrets/splunk-token
  → Makefile: wait for token file → make claude-update

Optional: make init
  → op inject → .env  (then make up uses .env like any Compose project)

User restarts Claude Desktop or Cursor
  → mcp-remote connects to https://localhost:8089/services/mcp with Bearer token
```

## Sample data (SA-S4R)

The **SA-S4R** app ships **Eventgen** configuration and samples to generate synthetic **`access_combined`** events into the **main** index. See [SA-S4R-APP.md](SA-S4R-APP.md).

## Related reading

- [CONFIGURATION.md](CONFIGURATION.md) — file-by-file reference
- [SECURITY.md](SECURITY.md) — threat model and limitations
- [ARCHITECTURE.md](ARCHITECTURE.md) — complementary detail and diagrams
