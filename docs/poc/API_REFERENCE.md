# API Reference & MCP Integration

**This repository** creates Splunk role **`mcp_user`** (capabilities **`mcp_tool_execute`** and **`s4r_workshop_control`**) and user **`splunker`** (default). Clients connect with **`npx mcp-remote`** to `https://localhost:8089/services/mcp`. Tokens are minted by **`scripts/mint-mcp-token.sh`** (after **`splunk-init`**) and stored only in a mode-600 header file that client configs pass to **`mcp-remote --header-file`**.

## Splunk REST API Endpoints

### Authentication

All Splunk REST API calls require authentication. Choose one method:

#### Method 1: Basic Auth (Admin)

Load the admin password and the **`splunk_curl`** helper once per shell, from the repo root:

```bash
set -a; . ./.env; set +a
. scripts/splunk-api-env.sh
splunk_curl -k https://localhost:8089/services/server/info
```

**`splunk_curl`** hands the credentials to curl as a config on a file descriptor. Avoid **`curl -u "admin:${SPLUNK_ADMIN_PASSWORD}"`**: any local user can read process arguments with **`ps`**. Plain **`curl -u admin`** (no password) prompts for it, which is also safe. Later admin examples on this page use **`splunk_curl`**.

#### Method 2: Splunk MCP (encrypted bearer token)

To check the token your clients already use, run **`make verify-mcp-remote`**. It reads the header file, calls `tools/list` directly and through **`npx mcp-remote`**, and mints nothing.

For a one-off probe, mint a token explicitly. Each mint adds an active token to the MCP Server registry; the next **`make update-mcp-clients`** revokes it.

```bash
TOKEN="$(./scripts/mint-mcp-token.sh)"
curl -kfsS -X POST "https://localhost:8089/services/mcp" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq .
```

### Core Endpoints Used

#### 1. Roles Management

##### Create Role

```bash
POST /services/authorization/roles
Content-Type: application/x-www-form-urlencoded

name=mcp_user
capabilities=mcp_tool_execute
```

##### List Roles

```bash
GET /services/authorization/roles
```

##### Get Role Details

```bash
GET /services/authorization/roles/mcp_user
```

##### Update Role

```bash
POST /services/authorization/roles/mcp_user
capabilities=mcp_tool_execute
```

#### 2. Users Management

##### Create User

```bash
POST /services/authentication/users
Content-Type: application/x-www-form-urlencoded

name=splunker
password=${SPLUNK_SPLUNKER_PASSWORD}
roles=user
roles=mcp_user
tz=Europe/Brussels
```

##### List Users

```bash
GET /services/authentication/users
```

##### Get User Details

```bash
GET /services/authentication/users/splunker
```

##### Update User Password

```bash
POST /services/authentication/users/splunker
password=${NEW_SPLUNK_SPLUNKER_PASSWORD}
```

#### 3. MCP Token Management

This repo’s MCP access is via the Splunk MCP Server app’s encrypted token flow. The generic Splunk endpoint `/services/authorization/tokens` is **not** the same thing and is not used for MCP in this repo. All calls below run as **admin**.

##### Ensure the encryption key pair

```bash
POST /services/mcp_token/key-pair
```

HTTP **201** means created, **409** means it already exists. **`scripts/mint-mcp-token.sh`** calls it before every mint.

##### Mint a token for `splunker`

```bash
POST /services/mcp_token/tokens
username=splunker
output_mode=json
```

Returns `{"token": "<encrypted>"}`. The token cannot outlive the encryption key.

##### List and revoke tokens

```bash
GET /services/mcp_token/tokens?scope=all&owner_username=splunker&output_mode=json
DELETE /services/mcp_token/tokens/<token_id>
```

**`scripts/prune-mcp-tokens.sh`** keeps the newest active token of the MCP user and deletes the older ones. **`scripts/mcp-client.sh update-all`** runs it after rewriting every configured client.

#### 4. Server Information

##### Get Server Info

```bash
GET /services/server/info
```

Returns server name, version, build, and status.

##### Get Server Status

```bash
GET /services/server/status
```

### MCP Server Endpoint

The Splunk MCP endpoint is a **JSON-RPC `POST`** handler at `/services/mcp` (not `GET`).

## Complete API Call Examples

### Example 1: Create role + user (admin basic auth)

```bash
#!/bin/bash
set -euo pipefail

HOST="localhost:8089"
ADMIN_USER="admin"
: "${SPLUNK_ADMIN_PASSWORD:?Set SPLUNK_ADMIN_PASSWORD first}"
: "${SPLUNK_SPLUNKER_PASSWORD:?Set SPLUNK_SPLUNKER_PASSWORD first}"

# Create role (matches setup-splunk.sh)
curl -k -X POST https://$HOST/services/authorization/roles \
  -u "$ADMIN_USER:$SPLUNK_ADMIN_PASSWORD" -d "name=mcp_user" -d "capabilities=mcp_tool_execute"

# Create user
curl -k -X POST https://$HOST/services/authentication/users \
  -u "$ADMIN_USER:$SPLUNK_ADMIN_PASSWORD" \
  -d "name=splunker" -d "password=$SPLUNK_SPLUNKER_PASSWORD" -d "roles=user" -d "roles=mcp_user"
```

### Example 2: List MCP tools (Splunk MCP Server)

```bash
TOKEN="$(./scripts/mint-mcp-token.sh)"
curl -kfsS -X POST "https://localhost:8089/services/mcp" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H 'Content-Type: application/json' \
  -H 'Accept: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq .
```

### Example 3: Direct SPL via basic auth (recommended for “direct SPL” tests)

```bash
curl -k -u splunker \
  "https://localhost:8089/services/search/jobs?output_mode=json" \
  -d 'search=index=main | stats values(sourcetype) AS Sourcetype'
```

## Claude Desktop / Cursor MCP Integration

Official client shape (Splunk MCP Server **2.0**): [Connecting to the MCP Server and settings](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/connecting-to-the-mcp-server-and-settings). This repo uses **encrypted bearer tokens** on **local Enterprise** only: [CONFIGURATION.md](CONFIGURATION.md#splunk-mcp-authentication-20). **Splunk Cloud** MCP is out of scope.

### Configuration Structure

Generated by `make update-mcp-client MCP_CLIENT=claude` / `claude-code` / `cursor` (minted **encrypted** token; dev self-signed TLS):

```json
{
  "mcpServers": {
    "splunk-mcp-server": {
      "args": [
        "-y",
        "mcp-remote@0.15.2",
        "https://localhost:8089/services/mcp",
        "--header-file",
        "/Users/<you>/.config/splunk-mcp/headers"
      ],
      "command": "npx",
      "env": {
        "NODE_TLS_REJECT_UNAUTHORIZED": "0"
      }
    }
  }
}
```

The header file holds one line, `Authorization: Bearer <YOUR_ENCRYPTED_TOKEN>` (mode 600). Passing the token with `--header` instead would expose it to every local user through `ps`.

`NODE_TLS_REJECT_UNAUTHORIZED=0` is for **local dev only** (self-signed Splunk cert). Omit `env` in production with valid TLS.

### How It Works

1. **Client reads config**: `claude_desktop_config.json` (Claude Desktop), `.mcp.json` (Claude Code), or `.cursor/mcp.json` (Cursor)
2. **Spawns** `npx mcp-remote` with streamable HTTP to `https://localhost:8089/services/mcp`
3. **Authenticates** with the encrypted bearer token read from the header file (minted via Splunk MCP Server app / `scripts/mint-mcp-token.sh`)
4. **Client can use tools**: built-in `splunk_*` / `saia_*` plus app tools `SA-S4R_*` (see below)

### Custom / app MCP tools (SA-S4R)

Splunk MCP Server **2.0** lets an app register tools without a standalone MCP server ([custom tools](https://help.splunk.com/en/splunk-enterprise/mcp-server-for-splunk-platform/2.0/managing-custom-tools-in-splunk-mcp-server)). This PoC:

- **Executes** tools as **`splunker`** on `POST /services/mcp` (JSON-RPC `tools/call`)
- **Registers** them as **admin** during **`splunk-init`** on `POST /services/mcp_tools` (batch replace from `SA-S4R/default/s4r_mcp_tools.json`)

Do not put admin passwords or bearer tokens in the JSON payload or in git. Implementation, definitions, and file map: [MCP-TOOLS.md](../s4r/MCP-TOOLS.md).

### Troubleshooting Connection

#### Test connection manually

```bash
make verify-mcp-remote MCP_VERIFY_CLIENT=cursor
# or mint + curl as in Example 2 above
```

**View Claude Desktop logs** (macOS)

```bash
log stream --predicate 'process == "Claude"' --level debug
```

## Rate Limiting & Performance

### API Rate Limits

- No built-in rate limiting for authenticated users
- Recommended: 100 requests per minute per user
- Token-based calls: Generally unlimited within Splunk limits

### Best Practices

1. **Batch Operations**: Combine multiple searches into single jobs
2. **Use Pagination**: Handle large result sets with pagination
3. **Index Optimization**: Search specific indexes to improve performance
4. **Time Range Filtering**: Always specify time range when possible

## Security Considerations

### Token Security

- Bearer tokens are minted by **`scripts/mint-mcp-token.sh`** and written only to the mode-600 header file outside the repo; client configs hold its path.
- Re-run **`make update-mcp-clients`** to rotate; do not paste tokens into issues or logs.

### Network Security

- Uses HTTPS with self-signed certificates (localhost only)
- Disable certificate validation only for development
- Use proper certificates in production
- Restrict network access via firewall

### User Permissions

- **`mcp_tool_execute`** capability (granted via Splunk role **`mcp_user`** in this repo): MCP tooling (see Splunk MCP Server app docs)
- **`s4r_workshop_control`** capability (same role): required to change the workshop mode
- Workshop write path is limited to **`SA-S4R_apply_nk_demo_state`** (allowlisted Eventgen mode only) — [MCP-TOOLS.md](../s4r/MCP-TOOLS.md)
- Cannot access other users' data
- Cannot create/delete other users

## Response Formats

### Error Response

```xml
<?xml version="1.0" encoding="UTF-8"?>
<response>
  <messages>
    <msg type="ERROR">Invalid credentials</msg>
  </messages>
</response>
```

### JSON Response (Alternative)

Many endpoints support JSON responses with `output_mode=json` parameter:

```bash
splunk_curl -k \
  "https://localhost:8089/services/server/info?output_mode=json"
```

## Claude Logs Index

### Query Claude Logs

**Search all Claude logs:**

```bash
splunk_curl -k \
  "https://localhost:8089/services/search/jobs" \
  -d "search=index=claude_logs" \
  -d "output_mode=json"
```

**Search by log level:**

```bash
index=claude_logs log_level=ERROR | stats count
```

**Search by time:**

```bash
index=claude_logs earliest=-1h | tail 20
```

### Index Statistics

**Get claude_logs index stats:**

```bash
splunk_curl -k \
  "https://localhost:8089/services/data/indexes/claude_logs"
```

## Debugging API Calls

### Enable Verbose Output

```bash
splunk_curl -v -k https://localhost:8089/services/server/info
```

### Check Request/Response Headers

```bash
splunk_curl -i -k https://localhost:8089/services/server/info
```

### Use jq for JSON Parsing

```bash
splunk_curl -k \
  "https://localhost:8089/services/server/info?output_mode=json" | jq .
```

### Save Response to File

```bash
splunk_curl -k https://localhost:8089/services/server/info > response.xml
```

## Advanced Topics

### Custom Search Commands

Implement custom search commands in Splunk to extend MCP functionality.

### Event Collection

Collect events via HTTP Event Collector (HEC) for ingestion through MCP.

### Knowledge Objects

Manage dashboards, reports, and searches via REST API through MCP.

### Alert Configuration

Create and manage alerts that can be triggered by MCP commands.

## Useful cURL Aliases

Add these to `.bashrc` or `.zshrc`:

Avoid aliases that embed passwords or tokens. Prefer functions that read secrets from your shell environment and pass them through **`splunk_curl`** (source **`scripts/splunk-api-env.sh`** in the same rc file, with an absolute path):

```bash
splunk_info() {
  splunk_curl -k \
    "https://localhost:8089/services/server/info?output_mode=json"
}
```

Do not paste the variable values into logs, issues, or PR descriptions.
