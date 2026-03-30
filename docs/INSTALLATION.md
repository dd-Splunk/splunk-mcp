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
   - Installation: See 1Password CLI installation guide
      command-line/)
   - macOS: `brew install 1password-cli`
   - Verify: `op --version`
   - Authenticate: `op account add`

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

   - Windows: Use WSL with jq

### Step 2: Verify 1Password CLI Access

Test that the CLI can access these items:

```bash
# Test Splunk-MCP-PoC password
op read "op://Private/Splunk-MCP-PoC/password"

# Test Splunkbase username
op read "op://Private/Splunkbase/username"

# Test Splunkbase password
op read "op://Private/Splunkbase/password"
```

Each command should return the stored value without errors.

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
│   ├── setup-splunk-user.sh
│   ├── update-claude-config.sh
│   └── update-cursor-config.sh
└── docs/
```

### Step 3: Review Configuration

Check `tpl.env` to understand what secrets are needed:

```bash
cat tpl.env
```

Example content:

```bash
# Splunk Configuration
SPLUNK_IMAGE=splunk/splunk:10.0
SPLUNK_PASSWORD=op://Private/Splunk-MCP-PoC/password
SPLUNKBASE_USER=op://Private/Splunkbase/username
SPLUNKBASE_PASS=op://Private/Splunkbase/password

# Timezone
TZ=Europe/Brussels
```

## Starting the Environment

### Step 1: Start Splunk

```bash
make up
```

This command:

- Initializes environment if not done
- Pulls Splunk image (if needed)
- Starts `so1` container
- Starts `splunk-init` container
- Waits for Splunk to be ready
- Runs initialization script

**Expected output**:

```text
Starting Splunk with MCP Server app...

Splunk is starting...
Web UI will be available at: https://localhost:8000
MCP Server API: https://localhost:8089/services/mcp

Wait for Splunk to be ready (this may take 2-3 minutes). The Makefile waits for `.secrets/splunk-token` and then runs `make claude-update` when possible.
```

### Step 2: Initialize Environment

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
so1            splunk/splunk:10.0          /sbin/entrypoint... Up 2 minutes
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

### Step 9: Monitor Claude Logs (Optional)

Claude Desktop logs are indexed in `index=claude_logs` for
audit and debugging.

**View logs in Splunk Web UI:**

```bash
# In Splunk Web UI, use Search & Reporting:
index=claude_logs | stats count by host,\
  log_level
```

**Requirements:**

Claude Desktop logs indexed in claude_logs index.

- The setup script automatically creates the `claude_logs` index during initialization
- Log ingestion starts immediately after Splunk is ready

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
