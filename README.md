# splunk-mcp

Local **proof-of-concept** for running **Splunk Enterprise** with the **Splunk MCP Server** app and connecting it to **Claude Desktop** or **Cursor** via the Model Context Protocol (MCP), using Docker Compose and optional 1Password CLI secret injection.

## What you get

- Splunk Web at `https://localhost:8000` and the management API (including MCP) on `https://localhost:8089`
- Splunkbase apps pulled at container start (including Splunk MCP Server)
- A setup container that configures MCP SSL settings for dev, creates user `dd`, and stores an encrypted MCP token in `.secrets/splunk-token`
- Optional indexing of Claude Desktop logs into Splunk (`claude_logs` index) on macOS

## Requirements

- Docker Desktop (or compatible engine) with Compose
- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`) if you use `make init` / `make up` as written
- `make`, `bash`, `curl`, `jq`
- Node/npm available for `npx mcp-remote` (used by the Claude and Cursor MCP client configs)

## Quick start

```bash
make init    # op inject: tpl.env → .env (edit tpl.env first if your vault paths differ)
make up      # start Splunk, wait for token, update Claude Desktop config when token appears
```

Then restart **Claude Desktop** so it picks up `~/Library/Application Support/Claude/claude_desktop_config.json`.

For **Cursor**, after the token exists:

```bash
make cursor-mcp   # writes .cursor/mcp.json
```

Restart Cursor or reload MCP servers.

## Common commands

| Command | Purpose |
| -------- | -------- |
| `make help` | List all targets |
| `make up` | `init` + `docker compose up -d` + wait for token + `claude-update` |
| `make down` | Stop stack |
| `make logs` | Follow Splunk (`so1`) logs |
| `make status` | Compose status + quick API readiness |
| `make claude-update` | Merge Splunk MCP into Claude Desktop config |
| `make cursor-mcp` | Merge Splunk MCP into `.cursor/mcp.json` |
| `make clean` | Destructive: remove volumes and local `.env` / token (prompts first) |

## Documentation

| Doc | Description |
| --- | --- |
| [docs/README.md](docs/README.md) | Index of all documentation |
| [docs/OVERVIEW.md](docs/OVERVIEW.md) | Architecture, flows, and components |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | `compose.yml`, `tpl.env`, secrets, clients |
| [docs/SECURITY.md](docs/SECURITY.md) | Dev-only risks and hardening notes |
| [docs/QUICK_START.md](docs/QUICK_START.md) | Short procedural checklist |
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Detailed install and verification |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Deeper design reference |
| [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | REST/MCP-related endpoints |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common failures |
| [docs/SA-S4R-APP.md](docs/SA-S4R-APP.md) | Bundled sample app and Eventgen |

## Security

This repo is aimed at **local development**: self-signed TLS, disabled SSL verification in `mcp-remote`, and secrets in `.env` / `.secrets`. Do not expose the stack to untrusted networks without redesign. See [docs/SECURITY.md](docs/SECURITY.md).

## Repository layout (high level)

```text
splunk-mcp/
├── compose.yml              # Splunk + one-shot init container
├── Makefile                 # init, up, client config helpers
├── tpl.env                  # Template for op inject → .env (not secrets by itself)
├── scripts/                 # setup-splunk.sh, Claude/Cursor MCP writers
├── SA-S4R/                  # Sample Splunk app (Eventgen demo data)
├── .secrets/                # splunk-token (git-ignored, chmod 600)
└── docs/                    # Extended documentation
```

---

Adapt `tpl.env` and your vault items to your environment before running `make init`.
