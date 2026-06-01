# Splunk-MCP (to-be spec)

## Purpose

Provide a self-contained local Splunk environment that demonstrates:

- Splunk MCP Server access from MCP clients
- Splunk AI Toolkit installed and usable by admins
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
  - Always receives Splunk AI Toolkit role: `mltk_dsdl_admin`
- **MCP user**
  - Splunk roles: `user` + `mcp_user`
  - `mcp_user` must include capability `mcp_tool_execute`
  - Must not receive AI Toolkit admin roles (model configuration remains admin-only)

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

- Splunk AI Toolkit (2890)
- Splunk AI Assistant for SPL (7245)
- Config Explorer (4353)
- Python for Scientific Computing (2882)
- SA-Eventgen (1924)
- Splunk MCP Server (7931)

### SA-S4R custom app

`SA-S4R` provides the Splunk 4 Rookies-like dataset:

- `product_codes.csv` lookup table
- `access_combined` samples for SA-Eventgen

## MCP client support

Supported clients:

- Cursor
- Claude Desktop
- Mistral (Vibe)
- Goose

### Connection pattern

- A local MCP proxy/bridge runs as a Docker Compose service (`mcp-proxy`)
- The proxy listens on loopback only (localhost)
- The proxy authenticates upstream using an encrypted MCP token minted at runtime
  - The token is minted by the proxy using Splunk REST credentials and held in memory only
  - The token is refreshed each boot (new token per `make up`)
- Upstream TLS: dev-friendly “skip verify” is supported behind an explicit setting

### Client config generation

- Client config files may be written to disk only if they contain no secrets
- Configs should be repo-local when possible; otherwise use the client’s required default path
- Client configs must not embed bearer tokens; they should run a local stdio bridge that talks to the local proxy
- **Goose:** `update goose` writes an **absolute** path to the bridge script and uses the **`envs`** field (not `env`); Goose’s session cwd is often not the repo root

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

- The MCP proxy is up and reachable locally
- At least one MCP call succeeds (e.g., a search runs successfully)
- Eventgen is producing events for the SA-S4R dataset
- **Direct SPL (basic auth)**: as Splunk user `splunker`, the following SPL returns results and includes `access_combined` in the returned `Sourcetype` list:
  - `index=main | stats values(sourcetype) AS "Sourcetype"`
- **MCP tool SPL**: via Splunk MCP, call the `splunk_run_query` tool with the same SPL above; the returned results include `access_combined`
- Cursor MCP test: using Cursor, the following prompt succeeds via Splunk MCP and the result includes `access_combined`:
  - `using Splunk MCP, list all non internal sourcetypes`
