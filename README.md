# splunk-mcp

Local **proof-of-concept** for running **Splunk Enterprise** with the **Splunk MCP Server** app and connecting **Claude Desktop** or **Cursor** via the Model Context Protocol (MCP), using Docker Compose and the **1Password CLI** (`op`) for secrets.

## What you get

- Splunk Web at `https://localhost:8000` and the management API (including MCP) on `https://localhost:8089/services/mcp`
- Splunkbase apps pulled at container start (including Splunk MCP Server)
- A one-shot init container that configures MCP for local dev, creates Splunk user `dd`, and writes an encrypted MCP token to `.secrets/splunk-token`
- Optional indexing of Claude Desktop logs into the `claude_logs` index (requires enabling the bind mount in `compose.yml`—see [docs/CONFIGURATION.md](docs/CONFIGURATION.md))

## Requirements

- Docker Desktop (or compatible engine) with Compose
- **1Password CLI** (`op`), signed in (`op signin` or desktop integration), with access to the vault items referenced in **`tpl.env`**
- `make`, `bash`, `curl`, `jq`
- Node/npm for `npx mcp-remote` (Claude / Cursor MCP client configs)

## Quick start

1. **Edit `tpl.env`** so every `op://vault/item/field` path matches **your** 1Password items (the examples in docs are illustrative; your vault layout will differ).

2. **Start the stack** (recommended — does **not** write a `.env` file on disk):

   ```bash
   make up
   ```

   If **no** `.env` exists, the Makefile runs Compose via  
   `op run --env-file=tpl.env -- docker compose …`  
   so secrets are resolved at invocation time. If `.env` **does** exist (e.g. after `make init`), Compose uses that file as usual.

3. **Optional — materialize `.env`** (legacy / CI / users who prefer a file):

   ```bash
   make init          # op inject: tpl.env → .env
   make up
   ```

4. Restart **Claude Desktop** so it loads `~/Library/Application Support/Claude/claude_desktop_config.json` (updated when the token appears).

**Cursor:** after `.secrets/splunk-token` exists:

```bash
make cursor-mcp    # merges token into .cursor/mcp.json
```

Restart Cursor or reload MCP servers.

## Common commands

| Command | Purpose |
| -------- | -------- |
| `make help` | List all targets |
| `make up` | `docker compose up -d` (with `op run` or `.env`), wait for token, run `claude-update` |
| `make init` | Optional: `op inject -i tpl.env -o .env` |
| `make down` | Stop the stack |
| `make logs` | Follow Splunk (`so1`) logs |
| `make status` | Compose status + quick API readiness |
| `make claude-update` | Merge Splunk MCP into Claude Desktop config |
| `make cursor-mcp` | Merge Splunk MCP into `.cursor/mcp.json` |
| `make verify-mcp-remote` | Smoke-test `mcp-remote` → Splunk MCP |
| `make clean` | Destructive: remove volumes and `.env` / token (prompts first) |

## Documentation

| Doc | Description |
| --- | --- |
| [docs/README.md](docs/README.md) | Index and reading order |
| [AGENTS.md](AGENTS.md) | Short contributor / agent reference |
| [docs/OVERVIEW.md](docs/OVERVIEW.md) | Architecture, flows, components |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | `compose.yml`, `tpl.env`, Makefile, clients |
| [docs/SECURITY.md](docs/SECURITY.md) | Dev-only risks and hardening notes |
| [docs/QUICK_START.md](docs/QUICK_START.md) | Minimal checklist |
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Detailed install and verification |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Design reference |
| [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | REST / MCP endpoints |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common failures |
| [docs/SA-S4R-APP.md](docs/SA-S4R-APP.md) | Bundled sample app and Eventgen |

## Security

This repo targets **local development**: self-signed TLS, `NODE_TLS_REJECT_UNAUTHORIZED=0` for `mcp-remote`, and secrets supplied via `op` or `.env` / `.secrets`. Do not expose the stack to untrusted networks without redesign. See [docs/SECURITY.md](docs/SECURITY.md).

## Repository layout (high level)

```text
splunk-mcp/
├── compose.yml              # Splunk + one-shot init container
├── Makefile                 # Compose wrappers (op run or .env), client helpers
├── tpl.env                  # Template: op:// references and non-secret defaults
├── scripts/                 # setup-splunk.sh, Claude/Cursor MCP writers
├── SA-S4R/                  # Sample Splunk app (Eventgen demo data)
├── .secrets/                # splunk-token, dd-password (git-ignored)
└── docs/                    # Extended documentation
```

**Source of truth** for behavior: `Makefile`, `compose.yml`, `scripts/setup-splunk.sh`. **Authoritative** contributor notes: [AGENTS.md](AGENTS.md).
