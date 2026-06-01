# splunk-mcp

Local **proof-of-concept**: run **Splunk Enterprise** in Docker with the **Splunk MCP Server** app, and connect **Cursor** or **Claude Desktop** via **`npx mcp-remote`** (Splunk 1.2 canonical config) or **Goose** via a local MCP proxy + stdio bridge. Secrets come from the **1Password CLI** (`op` + `tpl.env`) or a git-ignored **`.env`** (no 1Password required).

## First time here? (Presales / SE demo)

1. Read **[docs/PRESALES.md](docs/PRESALES.md)** end-to-end—it is the **demo runbook** (secrets, time budget, Cursor-first steps, checklist, handoff).
2. Copy **`tpl.env.example` → `tpl.env`** and fix every `op://` path, **or** copy **`.env.example` → `.env`** and fill plain values (see PRESALES **Path A / Path B**).
3. Run **`make up`** (updates Claude, Cursor, and Goose configs), restart clients as needed, then **`make verify-mcp-remote`**.

Do not block a live meeting on a cold start: **first `make up` can take many minutes** (pulls, Splunk, Splunkbase apps, init).

## What you get

| Endpoint | Use |
| -------- | --- |
| `https://localhost:8000` | Splunk Web |
| `http://localhost:${MCP_PROXY_PORT:-8090}/mcp` | Local MCP proxy (no bearer tokens in client configs) |

Splunkbase apps (see **`compose.yml`** for IDs, including **Splunk MCP Server**) install at container start. A one-shot init configures MCP for local dev and creates/updates user **`splunker`** (role **`mcp_user`**, capability **`mcp_tool_execute`). The `mcp-proxy` service mints the encrypted MCP token at runtime and holds it in memory. **`make up`** runs **`make update-mcp-clients`** (Claude, Cursor, Goose) without embedding secrets.

**Not included in init:** a **`claude_logs`** index or file monitors. Optional ingestion is described in [docs/CONFIGURATION.md](docs/CONFIGURATION.md) if you uncomment the bind mount in `compose.yml`.

## Requirements

- Docker with Compose, **`make`**, `bash`, **`curl`**, **`jq`**
- **Secrets:** 1Password + **`tpl.env`** *or* **`.env`** (see [docs/PRESALES.md](docs/PRESALES.md))
- **Node** / **npm** for `npx mcp-remote` (Claude/Cursor) and the Goose stdio bridge
- **Splunkbase** account with download rights (used for `SPLUNK_APPS_URL`)

## Quick commands

```bash
make up                      # start stack, update all MCP clients
make status                  # is Splunk answering?
make update-mcp-client MCP_CLIENT=cursor   # one client
make verify-mcp-remote       # verify all clients + MCP proxy (default)
make down                    # stop (no op / .env needed)
```

| Command | Purpose |
| ------- | ------- |
| `make help` | All targets |
| `make up` | Compose up, then **`update-mcp-clients`** |
| `make update-mcp-clients` | Update Claude, Cursor, and Goose configs |
| `make update-mcp-client` | One client (`MCP_CLIENT=claude\|cursor\|goose`) |
| `make verify-mcp-remote` | Config check + MCP proxy (`MCP_VERIFY_CLIENT=all` default) |
| `make clean` | Destructive: volumes + **`.env`** (prompts; no `op` needed) |

## Documentation (by audience)

| Doc | Audience |
| --- | -------- |
| **[docs/PRESALES.md](docs/PRESALES.md)** | **SE / presales: demo prep and flow** |
| [docs/QUICK_START.md](docs/QUICK_START.md) | Short technical checklist (points at PRESALES for demos) |
| [docs/INSTALLATION.md](docs/INSTALLATION.md) | Detailed install and verification |
| [docs/CONFIGURATION.md](docs/CONFIGURATION.md) | `compose.yml`, env files, client configs |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Failures: Splunkbase, ports, token, MCP |
| [docs/OVERVIEW.md](docs/OVERVIEW.md) | Architecture |
| [AGENTS.md](AGENTS.md) | Contributors and AI agent rules |

## Security

Local development defaults: self-signed TLS, dev-oriented MCP settings, secrets in `op` / `.env`. Do not expose this stack to untrusted networks as-is. See [docs/SECURITY.md](docs/SECURITY.md).

## CI

Pushes/PRs to **`main`** / **`master`**: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs **pre-commit** (shellcheck + markdownlint). One-time setup: `pip install pre-commit && pre-commit install`. Check all files: `pre-commit run --all-files`.

## Repository layout (high level)

```text
splunk-mcp/
├── compose.yml                         # Splunk + one-shot init
├── docker-compose.override.yml.example # Optional: copy to docker-compose.override.yml
├── Makefile
├── tpl.env.example / .env.example     # Tracked; copy to tpl.env or .env (gitignored)
├── scripts/                            # compose-up.sh, setup-splunk.sh, client config writers, verify
├── mcp-proxy/                           # local MCP proxy (token held in memory)
├── SA-S4R/                             # Sample app (Eventgen)
└── docs/
```

**Behavior:** `Makefile`, `compose.yml`, `scripts/compose-up.sh`, `scripts/setup-splunk.sh`. License: [LICENSE](LICENSE) (MIT).
