# Quick Start Guide

## 5-Minute Setup

### Prerequisites

```bash
# Verify these are installed
docker --version        # Docker Desktop
op --version           # 1Password CLI
make --version         # Make utility
jq --version          # JSON processor
curl --version        # cURL (usually pre-installed)
```

If any are missing, see INSTALLATION.md for details.

### Setup Steps

#### 1. Configure 1Password (First Time Only)

Store these credentials in your 1Password Private vault:

- **Item 1: Splunk-MCP-PoC**
  - Title: `Splunk-MCP-PoC`
  - Password field: Your desired Splunk admin password

- **Item 2: Splunkbase**
  - Title: `Splunkbase`
  - Username field: Your Splunkbase username
  - Password field: Your Splunkbase password

#### 2. Clone Repository

```bash
git clone <repository-url> splunk-mcp
cd splunk-mcp
```

#### 3. Initialize Environment

```bash
make init
```

Expected output:

```
Initializing environment...
Environment initialized. Secrets injected from 1Password.
```

#### 4. Start Splunk

```bash
make up
```

Wait 2-3 minutes for Splunk to fully initialize.

#### 5. Verify It Works

```bash
make status
```

Should show `Splunk is ready ✓`

#### 6. Generate Token & Configure Claude

```bash
make token
```

This automatically:

- Creates user `dd` with role `mcp_user`
- Generates 15-day authentication token
- Updates Claude Desktop configuration file

#### 7. Restart Claude Desktop

- Quit Claude Desktop completely
- Reopen it
- Splunk MCP server should now be available

## Accessing Your Splunk Instance

### Splunk Web UI

- URL: <https://localhost:8000>
- Username: `admin`
- Password: (from 1Password)

### REST API

```bash
# Get server info
curl -k -u admin:<password> https://localhost:8089/services/server/info

# Test MCP endpoint
curl -k -H "Authorization: Bearer <token>" https://localhost:8089/services/mcp
```

## Common Commands

```bash
# Show all available commands
make help

# Stop Splunk
make down

# Restart Splunk
make restart

# View logs
make logs

# Check container status
make status

# Generate new token
make token

# Completely reset (deletes all data!)
make clean
```

## Next Steps

1. **Explore Splunk Web UI**: Learn the interface at <https://localhost:8000>
2. **Add Sample Data**: Ingest test data through Splunk UI
3. **Test Claude Integration**: Use Splunk features through Claude Desktop
4. **Customize Configuration**: Edit `default.yml` for your specific needs
5. **Review ARCHITECTURE.md**: Understand the system components
6. **Check API_REFERENCE.md**: Learn the REST API endpoints

## Troubleshooting

### Issue: Splunk not starting

```bash
# Check logs
make logs | tail -100

# Check container status
docker ps

# Try full reset
make down
make clean
make up
```

### Issue: Token generation failed

```bash
# Make sure Splunk is ready
make status

# Check Splunk logs
make logs | grep -i error

# Manually verify user exists
curl -k -u admin:<password> https://localhost:8089/services/authentication/users/dd
```

### Issue: Claude not connecting

1. Verify configuration exists:

   ```bash
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq .
   ```

2. Test endpoint manually:

   ```bash
   TOKEN="<your_token>"
   curl -k -H "Authorization: Bearer $TOKEN" https://localhost:8089/services/mcp
   ```

3. Check Claude logs:

   ```bash
   log stream --predicate 'process == "Claude"' --level debug
   ```

4. Restart Claude: Force quit and reopen

See TROUBLESHOOTING.md for more detailed solutions.

## File Structure

```
splunk-mcp/
├── compose.yml              # Docker Compose configuration
├── default.yml              # Splunk configuration
├── Makefile                 # Automation targets
├── README.md                # Main documentation
├── ARCHITECTURE.md          # System design
├── INSTALLATION.md          # Detailed setup guide
├── API_REFERENCE.md         # REST API documentation
├── TROUBLESHOOTING.md       # Common issues
├── QUICK_START.md           # This file
├── DEVELOPER_GUIDE.md       # For development
├── tpl.env                  # 1Password template
├── scripts/
│   └── setup-splunk-user.sh # Initialization script
└── .env                     # Runtime config (git-ignored)
```

## Important Notes

- **`.env` file**: Contains secrets - never commit to git
- **Token expiry**: Tokens expire after 15 days
- **Port usage**: Uses ports 8000 and 8089 (change if needed in compose.yml)
- **Data persistence**: Uses named volumes (preserved on container restart)
- **Self-signed certificates**: OK for localhost development only

## Cleanup

To completely remove Splunk (deletes all data):

```bash
make clean
```

This removes:

- Docker containers
- Named volumes (so1-var, so1-etc)
- .env file

## Getting More Help

- **Full Setup Guide**: See INSTALLATION.md
- **Troubleshooting**: See TROUBLESHOOTING.md
- **Architecture Details**: See ARCHITECTURE.md
- **API Usage**: See API_REFERENCE.md
- **Development**: See DEVELOPER_GUIDE.md
- **Splunk Docs**: <https://docs.splunk.com/>

## Quick Reference

| Task | Command |
|------|---------|
| Setup | `make init` |
| Start | `make up` |
| Stop | `make down` |
| Restart | `make restart` |
| View logs | `make logs` |
| Check status | `make status` |
| Generate token | `make token` |
| Help | `make help` |
| Clean all | `make clean` |

---

**Ready to explore Splunk with Claude Desktop?**

Your Splunk instance is now running with MCP integration enabled. Open Claude Desktop and start using Splunk's capabilities!
