# Splunk-MCP (to-be spec)

## Purpose

Provide a self-contained local Splunk environment that demonstrates:

- Splunk MCP Server access from MCP clients
- A non-admin MCP execution identity operating on a Splunk 4 Rookies-like dataset (via SA-S4R + Eventgen)

## Target platform

- Splunk Enterprise runs as a Linux/amd64 container
- Default Splunk version is pinned to Splunk Enterprise 10.4 (see the pinned image tag in `compose.yml`)
- Apple Silicon is supported via amd64 emulation only (no native Splunk image requirement)
- Other containers must not hardcode a `platform:` unless strictly required

## Identity and authorization model

### Splunk users

- **Admin user**: `admin`
  - Used for bootstrap REST calls and administrative configuration
- **MCP user**: `splunker` (default; configurable)
  - Used as the MCP execution identity and token target
  - Must not be `admin`

### Roles and capabilities

- **Admin user**
  - Splunk role: `admin`
- **MCP user**
  - Splunk roles: `user` + `mcp_user`
  - `mcp_user` must include capability `mcp_tool_execute`

### AI SPL command

- The `ai` SPL command is available to all users and must not require special role/capability.

## Secrets and credentials (requirements)

- No secrets committed to git
- No secrets written to repo files on disk as part of normal operation
- 1Password is optional: the stack must support both
  - a plain `.env` flow, and
  - a secrets-manager flow (e.g., `op run`)
- Secrets must not be echoed to logs

## Splunk apps

### Splunkbase apps (pinned by default)

The stack installs pinned versions of these apps (by Splunkbase ID):

- Splunk AI Assistant for SPL (7245)
- Config Explorer (4353)
- SA-Eventgen (1924)
- Splunk MCP Server (7931)

Splunk AI Toolkit (2890) and Python for Scientific Computing (2882) are out of scope; install manually from Splunkbase if needed.

### SA-S4R custom app

`SA-S4R` provides the Splunk 4 Rookies-like dataset:

- **`product_codes`** lookup (`lookups/product_codes.csv`)
- `access_combined` samples for SA-Eventgen

## MCP client support

Supported clients:

- Cursor
- Claude Desktop
- Mistral (Vibe)
- Goose

### Connection pattern

- Clients connect with **`npx mcp-remote`** to Splunk’s **`/services/mcp`** (HTTPS on localhost:8089).
- **`scripts/mint-mcp-token.sh`** waits for **`splunk-init`** to exit, then polls the Splunk MCP Server **`mcp_token`** REST endpoint.
- Encrypted bearer tokens are written only to client config files (not the repo); refresh with `make update-mcp-client`.
- Dev TLS: optional `NODE_TLS_REJECT_UNAUTHORIZED=0` when **`SPLUNK_MCP_TLS_INSECURE=1`** (self-signed Splunk cert).

### Client config generation

- Bearer tokens live only in client config files (gitignored where applicable), not in the repo.
- **Claude Desktop**, **Cursor**, and **Goose** use the same **`npx mcp-remote`** shape per Splunk MCP Server 1.2.
- **Goose:** `update goose` uses **`envs`** (not `env`) for TLS env vars.

## Tooling and UX requirements

- Use Docker Compose for orchestration
- Use `make` targets for:
  - start/stop/status/logs/restart/clean
  - bootstrap/init
  - generate/update MCP client configs
  - verify stack health and MCP connectivity

## Upgrades and version policy

- Splunk Enterprise image is pinned (10.4 by default)
- Splunkbase app versions/URLs are pinned by default
- `make upgrade-apps` updates the pinned Splunkbase download URLs to the latest compatible versions using automated discovery

## Acceptance criteria (minimum)

The environment is “working” when all of the following pass:

- Splunk MCP at `https://localhost:8089/services/mcp` answers `tools/list` with a minted token
- At least one MCP call succeeds (e.g., a search runs successfully)
- Eventgen is producing events for the SA-S4R dataset
- **Direct SPL (basic auth)**: as Splunk user `splunker`, the following SPL returns results and includes `access_combined` in the returned `Sourcetype` list:
  - `index=main | stats values(sourcetype) AS "Sourcetype"`
- **MCP tool SPL**: via Splunk MCP, call the `splunk_run_query` tool with the same SPL above; the returned results include `access_combined`
- Cursor MCP test: using Cursor, the following prompt succeeds via Splunk MCP and the result includes `access_combined`:
  - `using Splunk MCP, list all non internal sourcetypes`
