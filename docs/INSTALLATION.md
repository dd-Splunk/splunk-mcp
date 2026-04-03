# Installation & Setup Guide

## Prerequisites

Before starting, ensure you have the following installed and configured:

### Required Software

1. **Docker Desktop**
   - macOS: [Download from Docker Hub](
      https://www.docker.com/products/docker-desktop)
   - Linux: `sudo apt-get install docker.io`
   - Windows: Docker Desktop
   - Verify: `docker --version`

2. **1Password CLI (op)**
   - Documentation: [1Password CLI](https://developer.1password.com/docs/cli/)
   - macOS: `brew install 1password-cli`
   - Verify: `op --version`
   - Authenticate: `op account add` or use desktop app integration

3. **Make Utility**
   - macOS: Pre-installed (part of Xcode)
   - Linux: `sudo apt-get install make`
   - Windows: Use WSL or alternatives (e.g., `choco install make`)
   - Verify: `make --version`

4. **jq** (JSON processor)
   - macOS: `brew install jq`
   - Linux: `sudo apt-get install jq`
   - Windows: Use WSL for jq
   - Verify: `jq --version`

5. **curl** (already included on most systems)
   - Verify: `curl --version`

### Optional Tools

- **Git**: For cloning the repository
  - Verify: `git --version`

- **VS Code**: For editing configuration files
  - URL: <https://code.visualstudio.com>

## 1Password Setup

### Step 1: Create 1Password Items

Store credentials in 1Password Private vault:

#### Item 1: Splunk-MCP-PoC

1. Open 1Password
2. Click the `+` button to create a new item
3. Select "Login" as the type
4. Set the following:
   - **Title**: `Splunk-MCP-PoC`
   - **Username**: `admin` (or leave empty)
   - **Password**: Your desired Splunk admin password
   - **Vault**: Private

5. Click Save

#### Item 2: Splunkbase

1. Create another "Login" item
2. Set the following:
   - **Title**: `Splunkbase`
   - **Username**: Your Splunkbase username
   - **Password**: Your Splunkbase password
   - **Vault**: Private

3. Click Save

### Step 2: Align `tpl.env`

The **`tpl.env`** file in this repository must reference vault items **you** can read with `op`. Item titles and vault names in this guide (`Splunk-MCP-PoC`, `Private`, etc.) are **examples**. Either:

- Create items that match the `op://` paths in **`tpl.env`**, or  
- Edit **`tpl.env`** so each `op://vault/item/field` matches your account.

Without that alignment, `make init` and `make up` (which uses `op run` when `.env` is absent) will fail.

### Step 3: Verify 1Password CLI Access

Test that the CLI can access these items:

```bash
# Test Splunk-MCP-PoC password
op read "op://YourVault/YourItem/password"

# Test Splunkbase username
op read "op://YourVault/Splunkbase/username"

# Test Splunkbase password
op read "op://YourVault/Splunkbase/password"
```

Each command should return the stored value without errors. If you use different item paths, substitute those in the `op read` tests to match **`tpl.env`**.

## Repository Setup

### Step 1: Clone Repository

```bash
git clone <repository-url> splunk-mcp
cd splunk-mcp
```

### Step 2: Verify File Structure

Ensure you have these files:

```text
splunk-mcp/
├── .gitignore
├── Makefile
├── README.md
├── compose.yml
├── tpl.env              # 1Password template
├── SA-S4R/              # Sample app
├── scripts/
│   ├── setup-splunk.sh
│   ├── update-claude-config.sh
│   └── update-cursor-config.sh
└── docs/
```

### Step 3: Review Configuration

Check `tpl.env` to understand what secrets are needed:

```bash
cat tpl.env
```

Example shape (paths **must** match your vault; see **Step 2** above):

```bash
# Splunk Configuration
SPLUNK_IMAGE=splunk/splunk:latest
SPLUNK_PASSWORD=op://YourVault/YourItem/password
SPLUNKBASE_USER=op://YourVault/Splunkbase/username
SPLUNKBASE_PASS=op://YourVault/Splunkbase/password

# Timezone
TZ=Europe/Brussels
```

## Starting the Environment

### Step 1: Start Splunk

```bash
make up
```

This command:

- Runs **`docker compose up -d`** with secrets from **`.env`** (if present) or **`op run --env-file=tpl.env`** (if `.env` is absent)
- Pulls the Splunk image when needed
- Starts **`so1`**, then **`splunk-init`** after Splunk is healthy
- Waits for **`.secrets/splunk-token`**, then runs **`make claude-update`**

Optional: run **`make init`** first to create **`.env`** via `op inject` (see [CONFIGURATION.md](CONFIGURATION.md)).

**Expected output**:

```text
Starting Splunk with MCP Server app...

Splunk is starting...
Web UI will be available at: https://localhost:8000
MCP Server API: https://localhost:8089/services/mcp

Wait for Splunk to be ready (this may take 2-3 minutes). The Makefile waits for `.secrets/splunk-token` and then runs `make claude-update` when possible.
```

### Step 2: Monitor startup

Wait 2-3 minutes for Splunk to fully start and initialize. You can monitor progress:

```bash
make logs
```

Look for messages like:

- `Splunk initialized`
- `Executing setup scripts`
- `Splunk is ready`

### Step 3: Wait for Initialization

```bash
make status
```

Expected output:

```text
Checking Splunk container status...
NAME           IMAGE                       COMMAND             STATUS
so1            splunk/splunk:latest        /sbin/entrypoint... Up 2 minutes
splunk-init    alpine:latest               sh -c ...          Exited (0)

Splunk is ready ✓
```

### Step 4: Verify Splunk is Ready

Open your browser and navigate to:

```text
https://localhost:8000
```

- **Username**: `admin`
- **Password**: (the password you set in 1Password)

Accept the self-signed certificate warning (localhost only).

## Claude Desktop Configuration

### Step 5: Access Splunk Web UI

The token is automatically generated during `make up`. Verify it exists:

```bash
ls -la .secrets/splunk-token
```

Claude Desktop config was automatically updated during startup.

### Step 6: Verify Token Generated

Check that Claude Desktop configuration was created:

```bash
cat ~/Library/Application\ Support/Claude/\
  claude_desktop_config.json
```

Should contain:

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
        "Authorization: Bearer eyJraWQiOi..."
      ]
    }
  }
}
```

### Step 8: Restart Claude Desktop

1. Quit Claude Desktop completely: Cmd+Q
2. Reopen from Applications folder
3. Splunk MCP should now be available

### Step 9: Claude logs in Splunk (optional)

The **`claude_logs`** index is created during setup, but **log files are only ingested** if Claude’s log directory is mounted into **`so1`** (see commented bind mount in **`compose.yml`**). Uncomment the macOS path, ensure it exists on the host, then recreate the stack.

**Search (when data is present):**

```splunk
index=claude_logs
```

## Verify Everything Works

### Test Splunk API

```bash
# Get Splunk server info
curl -k -u admin:<password> https://localhost:8089/services/server/info

# Test MCP endpoint
curl -k -H "Authorization: Bearer <token>" https://localhost:8089/services/mcp
```

### Test Claude Desktop Connection

1. Open Claude Desktop
2. Start a new conversation
3. You should see the Splunk MCP server listed in the available tools

## Troubleshooting Installation

### Issue: Docker not found

```bash
Error: command not found: docker
```

**Solution**: Install Docker Desktop from <https://www.docker.com/products/docker-desktop>

### Issue: 1Password CLI authentication failed

```bash
Error: Not currently authenticated. Use `op account add` to authenticate
```

**Solution**:

```bash
op account add
# Follow the prompts to sign in
```

### Issue: Splunk container crashes

**Solution**: Check logs

```bash
make logs

# If still crashing:
make down
docker volume rm so1-var so1-etc
make up  # This will reinitialize
```

### Issue: Port 8000 or 8089 already in use

**Solution**: Stop conflicting services

```bash
# Find process using port 8000
lsof -i :8000

# Kill the process
kill -9 <PID>

# Or change Splunk ports in compose.yml
```

### Issue: jq not found

```bash
Error: jq is not installed. Please install jq to proceed.
```

**Solution**: Install jq

```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

## Next Steps

After successful installation:

1. **Explore Splunk Web UI**: Learn the interface
2. **Test MCP Integration**: Use Splunk through Claude Desktop
3. **Add Data**: Ingest sample data into Splunk
4. **Customize Configuration**: Adjust `compose.yml`, `tpl.env`, or the `SA-S4R` app as needed
5. **Backup Configuration**: Save your volumes and configs

## Useful Commands

```bash
make help        # List all commands
make status      # Check if ready
make logs        # View logs
make restart     # Restart container
make down        # Stop container
make clean       # Reset all (WARNING: destructive)
```

## System Requirements

- **Minimum**: 2 CPU cores, 4GB RAM, 10GB disk space
- **Recommended**: 4 CPU cores, 8GB RAM, 20GB disk space
- **Optimal**: 8 CPU cores, 16GB RAM, 50GB disk space

## Security Reminders

1. Change default passwords in production
2. Don't commit `.env` file to version control
3. Rotate tokens regularly
4. Use proper certificates for production
5. Restrict network access to Splunk ports
6. Review and audit user roles and permissions
