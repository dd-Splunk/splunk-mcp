---
name: usage
description: >-
  Static cheat sheet for local splunk-mcp: SA-S4R_* MCP routing, make targets,
  MCP park/boot. Use only when the user invokes /usage or asks for the repo
  command cheat sheet. Do not run live health checks unless asked.
disable-model-invocation: true
---

# /usage

Print the cheat sheet. No live checks unless asked. No secrets. `make help` for all targets.

Prefer **`SA-S4R_*`** (Splunk MCP) over `splunk_run_query` when the ask matches. Names are prefixed `SA-S4R_`. One write tool — explicit user ask only.

```markdown
## splunk-mcp
Endpoints: https://localhost:8000 · https://localhost:8089/services/mcp

### S4R MCP (prefer these)
| User ask | Tool | Notes |
| -------- | ---- | ----- |
| What workshop mode? | `SA-S4R_query_nk_demo_state` | read |
| Start / stop NK storyline | `SA-S4R_apply_nk_demo_state` | **write** `mode=threat` \| `infrastructure`; no `make restart` |
| NK / 175.45.* traffic yet? | `SA-S4R_validate_nk_attack_traffic` | read, last **15m**; empty → wait 1–2 min or still infrastructure |
| Losing money / checkout KPIs? | `SA-S4R_summarize_purchase_health` | read, **24h** |
| Where are failed purchases? | `SA-S4R_geo_failed_purchases` | read, **24h**; pair with validate for NK |

Else: `splunk_run_query` + [docs/s4r/SPL-CATALOG.md](docs/s4r/SPL-CATALOG.md). Shell fallback: `make s4r-attack-nk-*` then **`make restart`**. Missing tools: `make register-s4r-mcp-tools`, reload MCP.

### Stack
| Command | Notes |
| ------- | ----- |
| `make up` | Boot → mint (default cursor) → register S4R tools |
| `make down` | Park `splunk-mcp-server`, then stop |
| `make status` / `make verify` | Health; MCP `tools/list` |
| `make demo-prep` | Shell status+verify. Go/no-go: **/demo-prep** |
| `make clean-y` | Destructive reset |

After `make up`: reload **splunk-mcp-server** in Cursor Settings → MCP.
Agents: `.cursor/agents/s4r-*.md` · slides: `make marp-preview`
Secrets: Path A `tpl.env`+`op` · Path B `.env`
Docs: [docs/s4r/MCP-TOOLS.md](docs/s4r/MCP-TOOLS.md) · [AGENTS.md](AGENTS.md)
```
