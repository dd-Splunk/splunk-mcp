## Purpose

This repository packages a **repeatable local environment** for:

1. Running **Splunk Enterprise** in Docker with the **Splunk MCP Server** application from Splunkbase.
2. Provisioning a dedicated Splunk user suitable for MCP tool execution.
3. Wiring **Claude Desktop**, **Cursor**, and **Goose** via **`npx mcp-remote`** (encrypted bearer token in client config only).

It is a **proof-of-concept**: fast iteration on Splunk + LLM tooling, not a production deployment template.

## Why MCP here

The [Model Context Protocol](https://modelcontextprotocol.io/) lets a client (Claude, Cursor) discover tools and resources exposed by a server. Splunk’s MCP Server app exposes Splunk operations through `/services/mcp`. This repo automates:

- Installing dependencies (Splunkbase downloads at container start).
- Post-start configuration (SSL verify flag for dev, user/role/token).
- MCP client configuration with encrypted bearer tokens (client files only, not committed).

## Major components

### Splunk container (`so1`)

- Image: `splunk/splunk` (tag from `SPLUNK_IMAGE` in `.env`, default `latest` in `tpl.env.example` / local `tpl.env`).
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
- Ensures Splunk role/user prerequisites for MCP are present (idempotent). This repo does not write the MCP token to disk.

### Splunkbase applications

`compose.yml` sets `SPLUNK_APPS_URL` to a comma-separated list of Splunkbase download URLs. At build/start, Splunk pulls these apps. Installed from Splunkbase: **SA-Eventgen** (1924), **Config Explorer** (4353), **Splunk MCP Server** (7931), **Splunk AI Assistant for SPL** (7245), **Python for Scientific Computing** (2882), and **Splunk AI Toolkit** (2890). The stack expects the **Splunk MCP Server** app (namespace `Splunk_MCP_Server`) to be present so REST calls in `setup-splunk.sh` succeed. Pin details and the full table live in [CONFIGURATION.md](CONFIGURATION.md#composeyml).

You need valid **Splunkbase** credentials supplied via **local `tpl.env`** (copy from **`tpl.env.example`**) or a plain **`.env`** (Path B): define **`SPLUNKBASE_USER`** and **`SPLUNKBASE_PASS`**; Compose maps them to the container variables `SPLUNKBASE_USERNAME` / `SPLUNKBASE_PASSWORD`.

### Client connections

Per [Splunk MCP Server 1.2](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.2/connecting-to-the-mcp-server-and-settings), **Claude**, **Cursor**, and **Goose** use **`npx mcp-remote`** to **`https://localhost:8089/services/mcp`** with an **encrypted** bearer token (`make update-mcp-clients`).

```text
npx mcp-remote https://localhost:8089/services/mcp --header "Authorization: Bearer …"
```

### Secrets flow

1. **`tpl.env.example`** (tracked) → copy to **`tpl.env`** (gitignored): `op://vault/item/field` references and non-secret defaults. **Align paths with your vault**; documentation examples use illustrative item names.
2. **Preferred (`make up` without `.env`)**: the Makefile runs Compose under  
   `op run --env-file=tpl.env -- docker compose …`  
   so variables are injected **at process invocation** and nothing is written to `.env`.
3. **Alternative (Path B)**: hand-written **`.env`** from **`.env.example`**; Compose auto-loads it and **`make up`** uses plain `docker compose`.
4. **Compose** supplies `SPLUNK_PASSWORD`, Splunkbase credentials, and related env vars to the `so1` and `splunk-init` services.
5. **Clients:** encrypted tokens are minted by **`scripts/mint-mcp-token.sh`** (after **`splunk-init`**) and stored only in client config files.

## Authentication model (as implemented)

| Actor | Mechanism | Notes |
| ----- | --------- | ----- |
| Splunk admin | Username/password (`admin` + `SPLUNK_PASSWORD`) | Used in setup script REST calls |
| MCP clients | `npx mcp-remote` → `/services/mcp` | Encrypted bearer token in client config; optional `NODE_TLS_REJECT_UNAUTHORIZED=0` for self-signed dev TLS |
| Token mint | `scripts/mint-mcp-token.sh` | After **`splunk-init`**; Splunk MCP app **`mcp_token`** for **`SPLUNK_MCP_USER`** (default **`splunker`**) |
| User **`splunker`** | Password from env | Password is provided via `.env` (Path B) or `op run` (Path A) as `SPLUNK_MCP_PASSWORD` |

The setup script creates Splunk role **`mcp_user`** and assigns capability **`mcp_tool_execute`** to that role (the MCP app checks the **capability**, not the role name).

## End-to-end flow

```text
make up
  → docker compose up -d (env from .env if present, else op run --env-file=tpl.env)
  → so1 starts Splunk, downloads apps, becomes healthy
  → splunk-init runs setup-splunk.sh
      → enable SA-Eventgen default modinput (when app present)
      → POST mcp server ssl_verify=false (dev)
      → create/update role mcp_user with capability mcp_tool_execute
      → add MLTK_ROLE to SPLUNK_MLTK_USER (default splunker; override in .env)
      → create user splunker (roles: user + mcp_user)
  → Makefile: update-mcp-clients (tokens to client configs only)

Optional: make update-mcp-client MCP_CLIENT=cursor (or aliases update-*-config)
  → refresh one client config without a full stack recycle

User restarts Claude Desktop, Cursor, or Goose
  → client spawns npx mcp-remote → https://localhost:8089/services/mcp
```

## Sample data (SA-S4R)

The **SA-S4R** app ships **Eventgen** configuration and samples to generate synthetic **`access_combined`** events into the **main** index. See [SA-S4R-APP.md](SA-S4R-APP.md).

## Related reading

- [CONFIGURATION.md](CONFIGURATION.md) — file-by-file reference
- [SECURITY.md](SECURITY.md) — threat model and limitations
- [ARCHITECTURE.md](ARCHITECTURE.md) — complementary detail and diagrams
