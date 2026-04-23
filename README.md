# splunk-mcp

Local **proof-of-concept**: run **Splunk Enterprise** in Docker with the **Splunk MCP Server** app, and connect an LLM client (**Cursor**, **Claude Desktop**, or **Goose**) over the Model Context Protocol (MCP) using **`npx mcp-remote`**. Secrets come from the **1Password CLI** (`op` + `tpl.env`) or a git-ignored **`.env`** (no 1Password required).

## First time here? (Presales / SE demo)

1. Read **[docs/PRESALES.md](docs/PRESALES.md)** end-to-end—it is the **demo runbook** (secrets, time budget, Cursor-first steps, checklist, handoff).
2. Copy **`tpl.env.example` → `tpl.env`** and fix every `op://` path, **or** copy **`.env.example` → `.env`** and fill plain values (see PRESALES **Path A / Path B**).
3. Run **`make up`**, then **`make update-cursor-config`** (restart Cursor) and **`make verify-mcp-remote`**.

Do not block a live meeting on a cold start: **first `make up` can take many minutes** (pulls, Splunk, Splunkbase apps, init).

## What you get

| Endpoint | Use |
| -------- | --- |
| `https://localhost:8000` | Splunk Web |
| `https://localhost:8089/services/mcp` | Splunk MCP Server (Bearer token in **`.secrets/splunk-token`**) |

Splunkbase apps (see **`compose.yml`** for IDs, including **Splunk MCP Server**) install at container start. A one-shot init configures MCP for local dev, creates user **`splunker`** (role **`mcp_user`**, capability **`mcp_tool_execute`), and writes the encrypted MCP token. **`make up`** waits for the token, then runs **`make update-claude-config`** (macOS Claude path).

**Not included in init:** a **`claude_logs`** index or file monitors. Optional ingestion is described in [docs/CONFIGURATION.md](docs/CONFIGURATION.md) if you uncomment the bind mount in `compose.yml`.

## Requirements

- Docker with Compose, **`make`**, `bash`, **`curl`**, **`jq`**
- **Secrets:** 1Password + **`tpl.env`** *or* **`.env`** (see [docs/PRESALES.md](docs/PRESALES.md))
- **Node/npm** for `npx mcp-remote` (MCP client configs)
- **Splunkbase** account with download rights (used for `SPLUNK_APPS_URL`)

## Quick commands

```bash
make up                      # start stack, wait for token, update Claude Desktop config (macOS)
make status                  # is Splunk answering?
make update-cursor-config    # write .cursor/mcp.json from the token
make verify-mcp-remote      # smoke-test mcp-remote → Splunk MCP
make down                    # stop (no op / .env needed)
```

| Command | Purpose |
| ------- | ------- |
| `make help` | All targets |
| `make up` | Compose up, wait for **`.secrets/splunk-token`**, **`update-claude-config`** |
| `make init` | Optional: write **`.env`** (resolved secrets on disk) from `tpl.env` + `op`; you usually **do not** need this if you always use `op` with `make up` (see [docs/CONFIGURATION.md](docs/CONFIGURATION.md#generating-env-optional)) |
| `make update-claude-config` | Merge Splunk MCP into Claude Desktop config (macOS) |
| `make update-cursor-config` | Merge into **`.cursor/mcp.json`** |
| `make update-goose-config` | **~/.config/goose/config.yaml** (stdio entry) |
| `make clean` | Destructive: volumes + **`.env`** + token (prompts; no `op` needed) |

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

Local development defaults: self-signed TLS, `NODE_TLS_REJECT_UNAUTHORIZED=0` for `mcp-remote` in the generated client snippets, secrets in `op` / `.env` / **`.secrets`**. Do not expose this stack to untrusted networks as-is. See [docs/SECURITY.md](docs/SECURITY.md).

## CI

Pushes/PRs to **`main`** / **`master`**: [`.github/workflows/ci.yml`](.github/workflows/ci.yml) (**shellcheck**, **`make lint-md`**). Run the same before pushing.

## Repository layout (high level)

```text
splunk-mcp/
├── compose.yml                         # Splunk + one-shot init
├── docker-compose.override.yml.example # Optional: copy to docker-compose.override.yml
├── Makefile
├── tpl.env.example / .env.example     # Tracked; copy to tpl.env or .env (gitignored)
├── scripts/                            # setup-splunk.sh, client config writers, verify
├── SA-S4R/                             # Sample app (Eventgen)
├── .secrets/                          # splunk-token, splunker-password (gitignored)
└── docs/
```

**Behavior:** `Makefile`, `compose.yml`, `scripts/setup-splunk.sh`. License: [LICENSE](LICENSE) (MIT).
