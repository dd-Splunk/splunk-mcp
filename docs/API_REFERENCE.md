# API Reference & MCP Integration

## Splunk REST API Endpoints

### Authentication

All Splunk REST API calls require authentication. Choose one method:

#### Method 1: Basic Auth (Admin)

```bash
curl -k -u admin:password https://localhost:8089/services/server/info
```

#### Method 2: Bearer Token (MCP User)

```bash
curl -k -H "Authorization: Bearer <token>" \
  https://localhost:8089/services/authorization/tokens
```

### Core Endpoints Used

#### 1. Roles Management

##### Create Role

```bash
POST /services/authorization/roles
Content-Type: application/x-www-form-urlencoded

name=mcp_user
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
capability=search
capability=accelerate_datamodel
```

#### 2. Users Management

##### Create User

```bash
POST /services/authentication/users
Content-Type: application/x-www-form-urlencoded

name=dd
password=changeme
roles=mcp_user
tz=Europe/Brussels
```

##### List Users

```bash
GET /services/authentication/users
```

##### Get User Details

```bash
GET /services/authentication/users/dd
```

##### Update User Password

```bash
POST /services/authentication/users/dd
password=newpassword
```

#### 3. Token Management

##### Create Token

```bash
POST /services/authorization/tokens
Content-Type: application/x-www-form-urlencoded

status=enabled
name=dd
audience=mcp
```

Response includes token in CDATA section:

```xml
<s:key name="token"><![CDATA[eyJr...]]>
</s:key>
```

##### List Tokens

```bash
GET /services/authorization/tokens
```

##### Get Token Details

```bash
GET /services/authorization/tokens/tokens
```

##### Delete Token

```bash
DELETE /services/authorization/tokens/tokens
```

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

#### MCP Services

```bash
GET /services/mcp
Authorization: Bearer <token>
```

#### Available Tools in MCP Context

```bash
GET /services/mcp/tools
Authorization: Bearer <token>
```

## Complete API Call Examples

### Example 1: Create User and Token

```bash
#!/bin/bash
HOST="localhost:8089"
ADMIN_USER="admin"
ADMIN_PASS="password"

# Create role
curl -k -X POST https://$HOST/services/authorization/roles \
  -u "$ADMIN_USER:$ADMIN_PASS" -d "name=mcp_user"

# Create user
curl -k -X POST https://$HOST/services/authentication/users \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -d "name=dd" -d "password=changeme" -d "roles=mcp_user"

# Create token
TOKEN=$(curl -k -s -X POST https://$HOST/services/authorization/tokens \
  -u "$ADMIN_USER:$ADMIN_PASS" \
  -d "status=enabled" -d "name=dd" -d "audience=mcp" | \
  sed -n 's/.*<![CDATA[/p')

echo "Token: $TOKEN"
```

### Example 2: Search Query

```bash
#!/bin/bash

TOKEN="your-token-here"
HOST="localhost"
PORT="8089"

# Test MCP endpoint
curl -k -H "Authorization: Bearer $TOKEN" \
  https://$HOST:$PORT/services/mcp/tools | jq .

# List available MCP tools
curl -k -H "Authorization: Bearer $TOKEN" \
  https://$HOST:$PORT/services/mcp | jq .
```

### Example 3: Search via API

```bash
#!/bin/bash

TOKEN="your-token-here"
QUERY="search index=main"

# Create search job
JOB_RESPONSE=$(curl -k -s -X POST https://localhost:8089/services/search/jobs \
  -H "Authorization: Bearer $TOKEN" \
  -d "search=$QUERY")

# Extract search ID
SID=$(echo "$JOB_RESPONSE" | grep -o '<sid>[^<]*</sid>' | sed 's/<[^>]*>//g')

echo "Search ID: $SID"

# Check search status
curl -k -H "Authorization: Bearer $TOKEN" \
  https://localhost:8089/services/search/jobs/$SID
```

## Claude Desktop MCP Integration

### Configuration Structure

```json
{
  "mcpServers": {
    "splunk-mcp-server": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://localhost:8089/services/mcp",
        "--header",
        "Authorization: Bearer <token>"
      ]
    }
  }
}
```

### How It Works

1. **Claude Desktop reads config**: Loads `claude_desktop_config.json`
2. **Spawns mcp-remote**: Launches Node.js process
3. **Connects to Splunk**: Establishes HTTPS connection to MCP endpoint
4. **Sends bearer token**: Authenticates using token
5. **Claude can use tools**: All MCP tools become available to Claude

### Troubleshooting Connection

#### Check if token is still valid

```bash
# Get token creation date
curl -k -u admin:password \
  https://localhost:8089/services/authorization/tokens/
  | grep "eai:last_updated"
```

#### Regenerate token if expired

Token auto-expires after 15 days. Run `make up` again to generate new
token.

#### Test connection manually

```bash
curl -k -H "Authorization: Bearer <token>" \
  https://localhost:8089/services/mcp
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

- Tokens are JWT format
- Expiry: 15 days from creation
- Scope: Limited to token creator's capabilities
- Rotation: Generate new token before expiry

### Network Security

- Uses HTTPS with self-signed certificates (localhost only)
- Disable certificate validation only for development
- Use proper certificates in production
- Restrict network access via firewall

### User Permissions

- `mcp_user` role: Read-only search capabilities
- Cannot modify Splunk configuration
- Cannot access other users' data
- Cannot create/delete other users

## Response Formats

### Successful Response (XML)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<response>
  <messages/>
  <entry>
    <title>token_name</title>
    <id>https://localhost:8089/services/authorization/tokens/token_name</id>
    <content type="text/xml">
      <s:dict>
        <s:key name="token"><![CDATA[eyJraWQ...]]></s:key>
      </s:dict>
    </content>
  </entry>
</response>
```

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
curl -k -u admin:password \
  "https://localhost:8089/services/server/info?output_mode=json"
```

## Claude Logs Index

### Query Claude Logs

**Search all Claude logs:**

```bash
curl -k -u admin:password \
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
curl -k -u admin:password \
  "https://localhost:8089/services/data/indexes/claude_logs"
```

## Debugging API Calls

### Enable Verbose Output

```bash
curl -v -k -u admin:password https://localhost:8089/services/server/info
```

### Check Request/Response Headers

```bash
curl -i -k -u admin:password https://localhost:8089/services/server/info
```

### Use jq for JSON Parsing

```bash
curl -k -u admin:password \
  "https://localhost:8089/services/server/info?output_mode=json" | jq .
```

### Save Response to File

```bash
curl -k -u admin:password https://localhost:8089/services/server/info > response.xml
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

```bash
alias splunk-auth='curl -k -u admin:password'
alias splunk-mcp='curl -k -H "Authorization: Bearer $SPLUNK_TOKEN"'

# Export token for use in shell
export SPLUNK_TOKEN="your-token-here"

# Test MCP
splunk-mcp https://localhost:8089/services/mcp
```
