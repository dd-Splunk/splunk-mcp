# Architecture

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

## Splunkbase applications

`compose.yml` sets `SPLUNK_APPS_URL` to a comma-separated list of Splunkbase download URLs. Installed from Splunkbase: **SA-Eventgen** (1924), **Config Explorer** (4353), **Splunk MCP Server** (7931), **Splunk AI Assistant for SPL** (7245), **Python for Scientific Computing** (2882), and **Splunk AI Toolkit** (2890). Pin details and the full table live in [CONFIGURATION.md](CONFIGURATION.md#composeyml).

You need valid **Splunkbase** credentials via **`tpl.env`** or **`.env`** (Path B): **`SPLUNKBASE_USER`** and **`SPLUNKBASE_PASS`**.

## Client connections

Per [Splunk MCP Server 1.2](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.2/connecting-to-the-mcp-server-and-settings), **Claude**, **Cursor**, and **Goose** use **`npx mcp-remote`** to **`https://localhost:8089/services/mcp`** with an **encrypted** bearer token (`make update-mcp-clients`).

## Secrets flow

1. **`tpl.env.example`** → copy to **`tpl.env`** (gitignored): `op://` references and non-secret defaults.
2. **`make up` without `.env`**: `op run --env-file=tpl.env -- docker compose …` (nothing written to disk).
3. **Path B**: hand-written **`.env`** from **`.env.example`**; Compose auto-loads it.
4. **Clients:** tokens minted by **`scripts/mint-mcp-token.sh`** after **`splunk-init`**; stored only in client configs.

## Sample data (SA-S4R)

The **SA-S4R** app ships **Eventgen** configuration for synthetic **`access_combined`** events in **`main`**. See [SA-S4R-APP.md](SA-S4R-APP.md) and workshop hub [s4r/README.md](s4r/README.md).

| Mode | Makefile | Narrative |
| ---- | -------- | --------- |
| Infrastructure (default) | `make s4r-attack-nk-disable` | Uniform ~40% errors (503/404); IT Ops leads |
| Active threat (optional) | `make s4r-attack-nk-enable` then `make restart` | NK geo on failed purchases; Security leads |

Agentic analysis: [S4R-AGENTS.md](S4R-AGENTS.md).

## System components

### 1. Splunk Enterprise Container (so1)

- **Image**: `splunk/splunk:latest` (configurable via `SPLUNK_IMAGE` env var)
- **Platform**: `linux/amd64`
- **Ports**:
  - `8000`: Splunk Web UI
  - `8089`: Splunk Management API / MCP Server endpoint
- **Health Status**: Uses embedded Splunk healthcheck
- **Restart Policy**: Always (auto-restart if container crashes)

### 2. Splunk Initialization Container (splunk-init)

- **Image**: `alpine:latest` (installs `curl` and `jq` at container start)
- **Purpose**: Runs initialization setup script after Splunk is healthy
- **Dependency**: Waits for `so1` service to be healthy
- **Restart Policy**: No (runs once and stops)
- **Script**: `scripts/setup-splunk.sh`

### 3. Data Persistence

#### Named Volumes

- **so1-var**: Stores Splunk variable data
  - Indexes (add **`claude_logs`** yourself if you want Claude Desktop log ingestion)
  - Logs
  - KV Store data
  
- **so1-etc**: Stores Splunk configuration files
  - User configs
  - App configurations
  - Authorization settings

#### Bind Mounts

- **Claude logs (optional)**: In `compose.yml`, uncomment  
  `${HOME}/Library/Logs/Claude:/var/log/claude_logs`  
  on macOS so logs are visible inside the container. The minimal **`setup-splunk.sh`** does **not** create the index or monitor; configure those in Splunk if you enable this mount.

#### Local Files

- **compose.yml**: Docker Compose configuration
- **tpl.env.example**: Tracked template; copy to **tpl.env** (gitignored) for real `op://` paths
- **.env**: Optional runtime file (git-ignored), hand-written from **`.env.example`** (Path B)
- **SA-S4R/**: Bundled sample Splunk app (bind-mounted into `$SPLUNK_HOME/etc/apps`)

### 4. Claude Logs Index

- **Index Name**: `claude_logs` — create in Splunk if you want this data (`setup-splunk.sh` does not create it)
- **Data Source**: Host path mounted into the container **only if** you enable the bind mount above
- **Purpose**: Optional capture of Claude Desktop logs into Splunk
- **Monitoring**: Add a Splunk **monitor** input on `/var/log/claude_logs` after the mount is active
- **Retention**: Follows Splunk default retention policies

### 5. Network

- **Type**: Bridge network (`splunk`)
- **Services**: so1, splunk-init
- **DNS**: Container names resolve within the network

## Initialization Flow

```text
make up
  ├─ docker compose up -d (secrets: .env if present, else op run --env-file=tpl.env; create tpl.env via cp tpl.env.example tpl.env)
  │  ├─ so1 (Splunk)
  │  │  ├─ Pull image
  │  │  ├─ Start container
  │  │  ├─ Install apps from SPLUNK_APPS_URL
  │  │  └─ Wait for health
  │  └─ splunk-init (waits for so1 healthy)
  └─ setup-splunk.sh (after so1 healthy)
     ├─ Enable Eventgen modinput (if SA-Eventgen present)
     ├─ Create/update role: mcp_user (capability mcp_tool_execute)
     ├─ Create user: splunker
     └─ (Token minted after splunk-init; stored only in client configs)

```

## Security Architecture

### Authentication Layers

1. **Container to Container**: Network isolation via bridge network
2. **API Authentication**:
   - Admin operations: Username/password (admin user)
   - MCP operations: Bearer token from `scripts/mint-mcp-token.sh` in client config
3. **Transport Security**: HTTPS with self-signed certificates (localhost only)
4. **Credential Management**: 1Password CLI integration

### User Roles

| User | Role(s) | Auth | Scope | Expiry |
| ---- | ------- | ---- | ----- | ------ |
| `splunker` | `user`, `mcp_user` (holds `mcp_tool_execute` capability) | Bearer token (MCP) | MCP (PoC) | Per Splunk MCP / token policy |
| `admin` | Built-in | Password | Full admin | N/A |

The setup script assigns Splunk role **`mcp_user`** and ensures capability **`mcp_tool_execute`** is present on that role. It does **not** grant **`admin`** to the MCP user (add manually in Splunk only if you accept the risk).

### Environment variables

Supplied to Compose via **`.env`** (Path B) **or** **`op run --env-file=tpl.env`** (default `make up` when `.env` is absent; **`tpl.env`** is local, from **`cp tpl.env.example tpl.env`**). Example shape:

```bash
SPLUNK_IMAGE=splunk/splunk:latest
SPLUNK_PASSWORD=<secret>
SPLUNKBASE_USER=<splunkbase user>
SPLUNKBASE_PASS=<splunkbase password>
TZ=Europe/Brussels
```

**Splunk Enterprise build** is determined by the Docker image tag (default `latest` resolves to whatever you last pulled—verify with Splunk Web **Settings → Server settings** or `services/server/info`). **Splunk MCP Server** app builds are pinned by **`SPLUNK_APPS_URL`** in `compose.yml` (Splunkbase download URLs).

## Claude Desktop Integration

### Connection Flow

```text
Claude Desktop
      │
      ├─ Reads: ~/Library/Application Support/Claude/claude_desktop_config.json (macOS)
      │
      └─ Spawns: npx mcp-remote → https://localhost:8089/services/mcp + encrypted bearer token
```

### Token Management

- **Generation**: `splunk-init` runs `setup-splunk.sh`, which calls the Splunk MCP Server app’s **`mcp_token`** endpoint for **`SPLUNK_MCP_USER`** (default **`splunker`**).
- **Storage**: Client config files only (not the repo).
- **Expiry**: Depends on Splunk MCP app and token settings (docs may cite ~15 days as a rule of thumb—verify in your build).
- **Renewal**: Re-run `make update-mcp-client` to mint a new token.

## Configuration Files

### compose.yml

- Docker Compose service definitions
- Volume mounts
- Network configuration
- Environment variables

### setup-splunk.sh

- Creates or updates Splunk role **`mcp_user`** with capability **`mcp_tool_execute`**
- Creates **`splunker`** user (`SPLUNK_MCP_USER`) with roles **`user`** + **`mcp_user`**
- Uses `SPLUNK_MCP_PASSWORD` (env) for the MCP user (no password written to disk)
- Enables SA-Eventgen default modinput when the app is installed
- Dependencies: `curl`, `jq` (installed in `splunk-init`)

Host **Claude** / **Cursor** / **Goose** configs are updated by **`scripts/mcp-client.sh`** via **`make update-mcp-clients`** (invoked by **`make up`**), not by this script. Goose uses **`envs`** for TLS overrides (see **`docs/CONFIGURATION.md`**).

### Makefile

- Automation targets
- 1Password integration
- Docker command shortcuts

## Data Flow

### Splunk Startup

1. Container starts with environment variables
2. Splunk accepts license and terms
3. Splunk MCP Server app is installed
4. Splunk services start
5. Healthcheck begins

### Initialization

1. splunk-init waits for healthcheck to pass
2. Runs setup-splunk.sh
3. Creates role and user via REST API
4. Client uses minted bearer token against `/services/mcp`
5. Makefile runs `update-mcp-clients` on the host (tokens to client configs only, not the repo)
6. splunk-init container exits (`restart: "no"`)

### MCP Operation

1. Client spawns **`npx mcp-remote`** with streamable HTTP to `/services/mcp` and an encrypted bearer token
2. Splunk MCP Server processes the request (tool prefixes `splunk_`, `saia_`)
3. Response is returned to the client

## Scalability Considerations

### Current Limitations

- Single Splunk instance (no clustering)
- Local filesystem persistence
- Single MCP endpoint
- Self-signed certificates (localhost only)

### Future Enhancements

- Splunk clustering for HA
- External volume storage
- Multiple MCP endpoints
- Certificate management
- Load balancing

## Disaster Recovery

### Data Backup

```bash
# Backup volumes
docker run --rm -v so1-var:/data -v ~/backups:/backup \
  alpine tar czf /backup/so1-var.tar.gz -C /data .

docker run --rm -v so1-etc:/data -v ~/backups:/backup \
  alpine tar czf /backup/so1-etc.tar.gz -C /data .
```

### Recovery Process

1. Remove current containers: `make down`
2. Remove volumes: `docker volume rm so1-var so1-etc`
3. Restore backups to volumes
4. Start services: `make up`

## Performance Tuning

### Resource Requirements

- **Minimum**: 2 CPU cores, 4GB RAM
- **Recommended**: 4+ CPU cores, 8GB RAM
- **Optimal**: 8+ CPU cores, 16GB RAM

### Volume Performance

- Named volumes: Better performance than bind mounts
- so1-var: Heavy I/O for indexing
- so1-etc: Moderate I/O for configs

## Troubleshooting Architecture

### Container Health

- `docker compose ps`: Check service status
- `make logs`: View real-time logs
- `docker inspect <container>`: Detailed inspection

### Network Issues

- `docker network inspect splunk`: Network details
- `docker exec so1 ifconfig`: IP configuration
- `docker exec so1 curl -k https://localhost:8089`: API connectivity

### Volume Issues

- `docker volume inspect so1-var`: Volume details
- `docker volume inspect so1-etc`: Permissions check
- `docker exec so1 df -h`: Disk space usage

## Related reading

- [CONFIGURATION.md](CONFIGURATION.md) — Compose, env, clients, `setup-splunk.sh` appendix
- [SECURITY.md](SECURITY.md) — threat model and limitations
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — failures and recovery
- [s4r/README.md](s4r/README.md) — Splunk4Rookies workshop docs
