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

#### 3. Start Splunk

```bash
make up
```

Wait 2-3 minutes for Splunk to fully initialize.

#### 5. Verify It Works

```bash
make status
```

Should show `Splunk is ready ✓`

Claude logs are automatically indexed in the `claude_logs` index. Search them anytime:

```bash
# View Claude logs in Splunk Web UI
# Navigate to: Search & Reporting → index=claude_logs
```

#### 6. Verify Token Generated

The token was auto-generated during `make up`. Verify it:

```bash
ls -la .secrets/splunk-token
```

#### 7. Restart Claude Desktop

- Quit Claude Desktop completely: Cmd+Q
- Reopen from Applications folder
- Splunk MCP server should now be available in tools

## Access Splunk

### Web UI

- URL: <https://localhost:8000>
- Credentials: `admin` / (your 1Password password)

### REST API

```bash
curl -k -u admin:<password> https://localhost:8089/services/server/info
```

## Commands

```bash
make status      # Check if ready
make logs        # View real-time logs
make restart     # Restart container
make down        # Stop container
make clean       # Delete all data (destructive!)
make help        # Show all targets
```

## Next Steps

1. **Query Claude Logs**: Search `index=claude_logs` in Splunk Web UI to see Claude Desktop activity
2. **Explore Splunk Web UI**: Learn the interface at <https://localhost:8000>
3. **Test Claude Integration**: Use Splunk features through Claude Desktop
4. **Add Sample Data**: Ingest test data through Splunk UI
5. **Customize Configuration**: Edit `default.yml` for your specific needs
6. **Review ARCHITECTURE.md**: Understand the system components

## Troubleshooting

See **TROUBLESHOOTING.md** for detailed solutions. Quick checks:

```bash
make status      # Verify Splunk is ready
make logs        # Check for errors
make down && make clean && make up  # Full reset
```

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
|------|----------|
| Start (includes init) | `make up` |
| Stop | `make down` |
| Restart | `make restart` |
| View logs | `make logs` |
| Check status | `make status` |
| Help | `make help` |
| Clean all | `make clean` |

---

**Ready to explore Splunk with Claude Desktop?**

Your Splunk instance is now running with MCP integration enabled. Open Claude Desktop and start using Splunk's capabilities!
