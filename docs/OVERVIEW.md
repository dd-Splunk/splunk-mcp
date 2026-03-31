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

1. **`tpl.env`**: placeholders and/or `op://` references for 1Password CLI.
2. **`make init`** runs `op inject -i tpl.env -o .env`.
3. **Docker Compose** reads `.env` for `SPLUNK_PASSWORD`, Splunkbase credentials, etc.
4. **Token file** `.secrets/splunk-token` is created by init; **`make claude-update`** / **`make cursor-mcp`** read it to patch client JSON.

## Authentication model (as implemented)

| Actor | Mechanism | Notes |
| ----- | --------- | ----- |
| Splunk admin | Username/password (`admin` + `SPLUNK_PASSWORD`) | Used in setup script REST calls |
| MCP client (Claude/Cursor) | Bearer token | Token from Splunk MCP app’s encrypted token endpoint for user `dd` |
| User `dd` | Password same as admin in script; roles include `mcp_tool_execute` | Created idempotently; see `scripts/setup-splunk.sh` |

The setup script creates Splunk role **`mcp_tool_execute`** (not a generic `mcp_user` name) and assigns it to user **`dd`**.

## End-to-end flow

```text
make init
  → op inject → .env

make up
  → docker compose up -d
  → so1 starts Splunk, downloads apps, becomes healthy
  → splunk-init runs setup-splunk.sh
      → POST mcp server ssl_verify=false (dev)
      → create index claude_logs + monitor (if not present)
      → create role mcp_tool_execute, user dd
      → GET encrypted mcp token → .secrets/splunk-token
  → Makefile loop: when token file exists → make claude-update

User restarts Claude Desktop or Cursor
  → mcp-remote connects to https://localhost:8089/services/mcp with Bearer token
```

## Sample data (SA-S4R)

The **SA-S4R** app ships **Eventgen** configuration and samples to generate synthetic **`access_combined`** events into the **main** index. See [SA-S4R-APP.md](SA-S4R-APP.md).

## Related reading

- [CONFIGURATION.md](CONFIGURATION.md) — file-by-file reference
- [SECURITY.md](SECURITY.md) — threat model and limitations
- [ARCHITECTURE.md](ARCHITECTURE.md) — complementary detail and diagrams
