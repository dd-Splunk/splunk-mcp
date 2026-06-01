# splunk-mcp

Local **proof-of-concept**: run **Splunk Enterprise** in Docker with the **Splunk MCP Server** app, and connect **Cursor**, **Claude Desktop**, or **Goose** via **`npx mcp-remote`** (Splunk 1.2 canonical config). Secrets come from the **1Password CLI** (`op` + `tpl.env`) or a git-ignored **`.env`** (no 1Password required).

## First time here? (Presales / SE demo)

1. Read **[docs/PRESALES.md](docs/PRESALES.md)** end-to-end—it is the **demo runbook** (secrets, time budget, Cursor-first steps, checklist, handoff).
2. Copy **`tpl.env.example` → `tpl.env`** and fix every `op://` path, **or** copy **`.env.example` → `.env`** and fill plain values (see PRESALES **Path A / Path B**).
3. Run **`make up`** (updates Claude, Cursor, and Goose configs), restart clients as needed, then **`make verify-mcp-remote`**.

Do not block a live meeting on a cold start: **first `make up` can take many minutes** (pulls, Splunk, Splunkbase apps, init).

## What you get

| Endpoint | Use |
| -------- | --- |
| `https://localhost:8000` | Splunk Web |
| `https://localhost:8089/services/mcp` | Splunk MCP Server (`npx mcp-remote` + token in client config only) |

Splunkbase apps (see **`compose.yml`** for IDs, including **Splunk MCP Server**) install at container start. A one-shot init configures MCP for local dev and creates/updates user **`splunker`** (role **`mcp_user`**, capability **`mcp_tool_execute`). **`make up`** waits for **`splunk-init`**, mints tokens, and updates Claude, Cursor, and Goose (tokens stay out of git).

**Not included in init:** a **`claude_logs`** index or file monitors. Optional ingestion is described in [docs/CONFIGURATION.md](docs/CONFIGURATION.md) if you uncomment the bind mount in `compose.yml`.

## Requirements

- Docker with Compose, **`make`**, `bash`, **`curl`**, **`jq`**
- **Secrets:** 1Password + **`tpl.env`** *or* **`.env`** (see [docs/PRESALES.md](docs/PRESALES.md))
- **Node** / **npm** for `npx mcp-remote` (all MCP clients)
- **Splunkbase** account with download rights (used for `SPLUNK_APPS_URL`)

## Quick commands

```bash
make up                      # start stack, update all MCP clients
make status                  # is Splunk answering?
make update-mcp-client MCP_CLIENT=cursor   # one client
make verify-mcp-remote       # verify all clients + Splunk MCP API (default)
make down                    # stop (no op / .env needed)
```

| Command | Purpose |
| ------- | ------- |
| `make help` | All targets |
| `make up` | Compose up, then **`update-mcp-clients`** |
| `make update-mcp-clients` | Update Claude, Cursor, and Goose configs |
| `make update-mcp-client` | One client (`MCP_CLIENT=claude\|cursor\|goose`) |
| `make verify-mcp-remote` | Config check + Splunk MCP `tools/list` (`MCP_VERIFY_CLIENT=all` default) |
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
├── Makefile
├── tpl.env.example / .env.example     # Tracked; copy to tpl.env or .env (gitignored)
├── scripts/                            # compose-up, setup-splunk, mint-mcp-token, mcp-client
├── SA-S4R/                             # Sample app (Eventgen)
└── docs/
```

**Behavior:** `Makefile`, `compose.yml`, `scripts/compose-up.sh`, `scripts/setup-splunk.sh`. License: [LICENSE](LICENSE) (MIT).
