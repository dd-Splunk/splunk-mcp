---
name: usage
description: >-
  Show splunk-mcp repo usage — make targets, MCP park/boot, SA-S4R MCP tools
  (SA-S4R_*), Buttercup agents, and doc pointers. Use when the user invokes
  /usage or asks for repo commands, quick start, cheat sheet, or how to use
  this project.
disable-model-invocation: true
---

# /usage — splunk-mcp quick reference

When the user invokes **`/usage`**, respond with a concise cheat sheet. Do not dump long doc sections — link to sources.

## Workflow

1. **Optional health snapshot** (fast, read-only):
   - `make status` — stack + splunk-init
   - **`SA-S4R_query_nk_demo_state`** (Splunk MCP) when MCP is connected; else `make s4r-attack-nk-status`
   - Skip if user only wants static help (e.g. "what commands exist?")

2. **Output** using the template below. Fill **Status** from step 1 when run.

3. **Do not** paste secrets, tokens, or `.env` values.

## Output template

```markdown
## splunk-mcp usage

**Status:** [Splunk ready ✓ / init failed / down — from `make status` if run] · **S4R mode:** [infrastructure / threat — from `SA-S4R_query_nk_demo_state` or `make s4r-attack-nk-status` if run]

**Endpoints:** Splunk Web https://localhost:8000 · MCP https://localhost:8089/services/mcp

### Stack (daily)
| Command | Purpose |
| ------- | ------- |
| `make up` | Boot → mint token (`MCP_UPDATE_ON_BOOT`, default `cursor`) → register S4R MCP tools |
| `make down` | Park MCP clients, then stop containers |
| `make restart` | Restart Splunk only — **required after shell** `s4r-attack-nk-*` toggle; **not** needed after MCP `SA-S4R_apply_nk_demo_state` (reloads Eventgen) |
| `make status` | Health + splunk-init exit code |
| `make logs` | Follow Splunk logs |
| `make verify` | `make status` + `verify-mcp-remote` (default: all clients) |
| `make demo-prep` | Shell: status + MCP verify + warm-stack tip — use **`/demo-prep`** for full go/no-go (+ auth SPL) |
| `make clean` | Destructive: park MCP, remove volumes + `.env` |
| `make clean-y` | Same as `clean` without prompt (e.g. `make clean-y && make up`) |

### MCP clients
| Command | Purpose |
| ------- | ------- |
| `make park-mcp-clients` | Remove `splunk-mcp-server` from configs (no secrets; `make down` does this) |
| `make update-mcp-client MCP_CLIENT=cursor` | Mint token + refresh one client (`claude` \| `goose` \| `cursor`) |
| `make update-mcp-clients` | One mint → cursor, goose, claude |
| `make up MCP_UPDATE_ON_BOOT="cursor goose claude"` | Refresh all three clients on boot |
| `make verify-mcp-remote` | Config + Splunk MCP `tools/list` + `npx mcp-remote` (default `MCP_VERIFY_CLIENT=all`) |
| `make verify-mcp-remote MCP_VERIFY_CLIENT=cursor` | Cursor-only verify |

**After `make up`:** reload **splunk-mcp-server** in Cursor Settings → MCP (or restart Cursor).

If agents report "Splunk MCP unavailable": `make update-mcp-client MCP_CLIENT=cursor`, reload MCP.

### Buttercup / S4R (workshop)
| Prompt / ask | Purpose |
| ------------ | ------- |
| "What workshop mode are we in?" → **`SA-S4R_query_nk_demo_state`** | Infrastructure (default) vs threat |
| "Start the NK attack storyline" → **`SA-S4R_apply_nk_demo_state`** (`mode: threat`); then **`SA-S4R_validate_nk_attack_traffic`** (~1–2 min) | Enable threat demo (**write** — explicit user ask only) |
| "Return to infrastructure mode" → **`SA-S4R_apply_nk_demo_state`** (`mode: infrastructure`) | Disable NK storyline (**write** — explicit user ask only) |
| "Is the shop losing money?" → **`SA-S4R_summarize_purchase_health`** | Business Analytics KPIs (24h) |
| "Where are failed purchases concentrated?" → **`SA-S4R_geo_failed_purchases`** | Security geo hotspots (24h) |
| "As Buttercup Power User: … delegate to all four teams" | IT Ops · DevOps · Business · Security — `.cursor/agents/s4r-*.md` |
| `make register-s4r-mcp-tools` | Re-register after editing `SA-S4R/default/s4r_mcp_tools.json` |
| `make marp-preview` | S4R slide deck |

**Shell fallback** (no MCP): `make s4r-attack-nk-status` · `make s4r-attack-nk-enable` / `disable` then **`make restart`**

### S4R MCP tools (`SA-S4R_*`)
Five tools registered on `make up` (Splunk MCP Server **2.x** names them `SA-S4R_<name>`). Prefer over hand-written SPL when the question matches. Detail: [docs/s4r/MCP-TOOLS.md](docs/s4r/MCP-TOOLS.md).

| MCP tool | R/W | Use when |
| -------- | --- | -------- |
| `SA-S4R_query_nk_demo_state` | read | Infrastructure vs threat (Eventgen NK stanza) |
| `SA-S4R_apply_nk_demo_state` | **write** | Start/stop NK storyline (`mode`: `infrastructure` \| `threat`) — reloads Eventgen; no `make restart` |
| `SA-S4R_validate_nk_attack_traffic` | read | NK / `175.45.*` failed purchases (**last 15m**) |
| `SA-S4R_summarize_purchase_health` | read | Lost revenue, checkout outcomes, top products (**24h**) |
| `SA-S4R_geo_failed_purchases` | read | Failed-purchase geo hotspots + top cities (**24h**) |

**Built-in MCP** (same endpoint): `splunk_run_query`, `splunk_get_*`, `saia_*` — catalog SPL in [docs/s4r/SPL-CATALOG.md](docs/s4r/SPL-CATALOG.md) for IT Ops / DevOps when no `SA-S4R_*` tool fits.

**Agent tip:** `SA-S4R_query_nk_demo_state` → governed `SA-S4R_*` tools → `splunk_run_query` for catalog gaps only. One write tool: **`SA-S4R_apply_nk_demo_state`** (explicit user request only).

**Docs:** [docs/s4r/README.md](docs/s4r/README.md) · [docs/s4r/SPL-CATALOG.md](docs/s4r/SPL-CATALOG.md) · [docs/s4r/AGENTS.md](docs/s4r/AGENTS.md) · [docs/s4r/SA-S4R-APP.md](docs/s4r/SA-S4R-APP.md)

### Cursor skills (this repo)
| Invoke | Purpose |
| ------ | ------- |
| `/usage` | This cheat sheet |
| `/demo-prep` | Go/no-go: status, MCP verify, S4R mode, auth-failure SPL |

### Secrets (pick one)
- **Path A:** copy `tpl.env.example` → `tpl.env` (gitignored) + `op run` — no plaintext `.env`
- **Path B:** copy `.env.example` → `.env` (plain values; Compose auto-loads)

### Key docs
| Topic | File |
| ----- | ---- |
| Agent rules | [AGENTS.md](AGENTS.md) |
| Config / setup | [docs/poc/CONFIGURATION.md](docs/poc/CONFIGURATION.md) |
| Troubleshooting | [docs/poc/TROUBLESHOOTING.md](docs/poc/TROUBLESHOOTING.md) |
| Presales | [docs/poc/PRESALES.md](docs/poc/PRESALES.md) |
```

## Keep it short

- One screen of output; no full Makefile dump (`make help` for all targets).
- List all five `SA-S4R_*` tools; do not omit `geo_failed_purchases` or `summarize_purchase_health`.
- Distinguish **MCP mode toggle** (no `make restart`) from **shell** `s4r-attack-nk-*` (needs `make restart`).
- If status checks fail, add one-line fix pointer (e.g. `docker logs splunk-init`, [TROUBLESHOOTING.md](docs/poc/TROUBLESHOOTING.md)).
