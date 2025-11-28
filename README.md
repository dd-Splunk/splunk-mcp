# Splunk MCP Server - PoC Environment

> Proof of Concept environment for testing the Splunk MCP (Model Context Protocol) Server with Claude Desktop.

[![Docker](https://img.shields.io/badge/Docker-ready-blue)](#prerequisites)
[![Splunk 10.0](https://img.shields.io/badge/Splunk-10.0-brightgreen)](#overview)
[![MCP 0.2.4](https://img.shields.io/badge/MCP%20Server-0.2.4-brightgreen)](#overview)

## Overview

This setup provides a complete PoC environment for Splunk MCP integration:

| Component | Details |
|-----------|---------|
| **Splunk Enterprise** | Standalone instance (so1) with MCP Server app (v0.2.4) |
| **Authentication** | Custom user `dd` with `mcp_user` role + JWT token (15-day validity) |
| **Claude Integration** | Automated Claude Desktop configuration via `make claude-update` |
| **Secrets Management** | 1Password CLI integration for secure credential handling |

## Quick Start

### Prerequisites

- ✅ Docker Desktop running
- ✅ 1Password CLI (`op`) installed and logged in
- ✅ Make utility (macOS/Linux)

### Setup (< 5 minutes)

```bash
# 1. Initialize environment (injects secrets from 1Password)
make init

# 2. Start Splunk and MCP server
make up

# 3. Update Claude Desktop with token
make claude-update

# 4. Restart Claude Desktop to activate MCP connection
```

### Verify Setup

```bash
# Check Splunk is running
curl -k https://localhost:8089/services/server/info -u admin:$SPLUNK_PASSWORD

# View Claude MCP config
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers'
```

## Key Commands

| Command | Purpose |
|---------|---------|
| `make help` | Show all available commands |
| `make init` | Create `.env` with 1Password secrets |
| `make up` | Start containers + auto-configure Claude |
| `make down` | Stop containers |
| `make logs` | View real-time logs |
| `make status` | Check Splunk readiness |
| `make clean` | Delete all volumes (careful!) |

## Architecture

```text
┌─────────────────────────────────────────┐
│     Claude Desktop                      │
│  (with MCP configuration)               │
└────────────┬────────────────────────────┘
             │ Bearer Token Auth
             ↓
┌─────────────────────────────────────────┐
│  Splunk MCP Server (Port 8089)          │
│  ├─ User: dd                            │
│  ├─ Role: mcp_user                      │
│  └─ SSL: Disabled (dev)                 │
└─────────────────────────────────────────┘
```

## Configuration Files

| File | Purpose | Details |
|------|---------|---------|
| `compose.yml` | Container orchestration | Services: so1 (Splunk), splunk-init (setup) |
| `default.yml` | Splunk default config | Mounts at `/opt/splunk/etc/system/default/` |
| `tpl.env` | Environment template | Git-safe template for `.env` |
| `.env` | Secret credentials | **Git-ignored** - created by `make init` |
| `Makefile` | Build automation | Targets for setup, start, token management |

## File Structure

```text
splunk-mcp/
├── docs/                    # Detailed documentation
│   ├── QUICK_START.md      # 5-minute reference
│   ├── INSTALLATION.md     # Step-by-step setup
│   ├── ARCHITECTURE.md     # System design details
│   ├── DEVELOPER_GUIDE.md  # Development workflow
│   ├── API_REFERENCE.md    # REST endpoints
│   └── TROUBLESHOOTING.md  # Problem solving
├── scripts/                 # Automation scripts
│   ├── setup-splunk-user.sh        # Container init
│   └── update-claude-config.sh     # Claude config update
├── .secrets/               # Token storage (600 permissions)
├── compose.yml            # Docker Compose config
├── Makefile               # Build automation
├── default.yml            # Splunk configuration
├── tpl.env                # Environment template
└── README.md              # This file
```

## Security Notes

⚠️ **Development Only**

- SSL verification **disabled** locally (`NODE_TLS_REJECT_UNAUTHORIZED=0`)
- Self-signed certificates used in Splunk
- All tokens have **15-day expiry**
- Token file (`.secrets/splunk-token`) has **600 permissions**

## 1Password Setup

Before running `make init`, ensure these credentials exist in 1Password:

```text
Vault: Private
├── Splunk-MCP-PoC
│   └── password: [your_admin_password]
└── Splunkbase
    ├── username: [your_splunkbase_email]
    └── password: [your_splunkbase_token]
```

> Splunkbase credentials are required to download the MCP Server app.

## Access Information

| Service | URL | Credentials |
|---------|-----|-------------|
| **Splunk UI** | <https://localhost:8089> | admin / `$SPLUNK_PASSWORD` |
| **MCP Endpoint** | <https://localhost:8089/services/mcp> | User: dd / Token: saved |
| **Claude Desktop** | Native app | Auto-configured |
| **Claude Logs** | Index: `claude_logs` | Automatically indexed |

## Common Tasks

### View Real-Time Logs

```bash
make logs
```

### Regenerate Token

```bash
# Token is auto-saved to .secrets/splunk-token
# To update Claude config with new token:
make claude-update
```

### Restart Splunk

```bash
make restart
```

### Clean Start

```bash
make clean && make init && make up
```

## Troubleshooting

### Splunk Won't Start?

```bash
# Check Docker status
docker ps -a

# View logs
make logs

# For detailed help, see docs/TROUBLESHOOTING.md
```

### Claude MCP Connection Failed?

1. Verify Claude config: `cat ~/Library/Application\ Support/Claude/claude_desktop_config.json`
2. Check token is saved: `cat .secrets/splunk-token`
3. Restart Claude Desktop after running `make claude-update`

### 1Password Issues?

```bash
# Verify 1Password CLI works
op vault list

# Make init should create .env
make init
```

## Documentation

Detailed documentation is available in the `docs/` directory:

| Document | Purpose | Audience |
|----------|---------|----------|
| [QUICK_START.md](docs/QUICK_START.md) | 5-minute reference | Everyone |
| [INSTALLATION.md](docs/INSTALLATION.md) | Detailed setup | First-time users |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design | Developers |
| [API_REFERENCE.md](docs/API_REFERENCE.md) | REST endpoints | API users |
| [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) | Development | Developers |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Problem solving | When stuck |

**Choose your path:**

- 🚀 **New to this?** → [QUICK_START.md](docs/QUICK_START.md) (5 min)
- 🔧 **Want details?** → [INSTALLATION.md](docs/INSTALLATION.md)
- 🏗️ **Understanding design?** → [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 🐛 **Something broken?** → [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- 💻 **Extending it?** → [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md)

## Environment Variables

Set automatically by `make init` from 1Password:

```bash
SPLUNK_HOST=localhost
SPLUNK_PORT=8089
SPLUNK_USER=admin
SPLUNK_PASSWORD=<from_1password>
SPLUNKBASE_USERNAME=<from_1password>
SPLUNKBASE_PASSWORD=<from_1password>
```

## Version Information

| Component | Version |
|-----------|---------|
| Splunk Enterprise | 10.0 |
| MCP Server App | 0.2.4 |
| Docker Compose | Latest |
| Alpine Linux | Latest |

## Next Steps

1. ✅ Run `make init && make up`
2. ✅ Run `make claude-update`
3. ✅ Restart Claude Desktop
4. ✅ Start using Splunk tools in Claude!

## Support

**Need help?** Check these in order:

1. This README's troubleshooting section
2. [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
3. [docs/QUICK_START.md](docs/QUICK_START.md) for common tasks
4. Related documentation in `docs/` directory

---

**Last Updated**: November 2025  
**Status**: ✅ Production Ready PoC  
**Documentation**: Complete and consolidated
