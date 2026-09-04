# Splunk4Rookies (S4R) — workshop docs

Buttercup Enterprises PoC: **SA-S4R** sample app, Labs 3–7 SPL, dashboard build, and agentic demo.

Stack install and MCP bootstrap: [../poc/PRESALES.md](../poc/PRESALES.md) · [../poc/ARCHITECTURE.md](../poc/ARCHITECTURE.md) · [../poc/CONFIGURATION.md](../poc/CONFIGURATION.md).

## Docs in this cluster

| Document | Purpose |
| -------- | ------- |
| [SPL-CATALOG.md](SPL-CATALOG.md) | **Canonical SPL** (Labs 3–7; agents) |
| [DASHBOARD.md](DASHBOARD.md) | Dashboard Studio build spec (`SA-S4R/local/`) |
| [SA-S4R-APP.md](SA-S4R-APP.md) | Eventgen, NK toggle, `default/` vs `local/` |
| [AGENTS.md](AGENTS.md) | Multi-agent demo architecture |
| [MCP-TOOLS.md](MCP-TOOLS.md) | SA-S4R MCP tools (definitions, registration) |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Workshop-specific issues (dashboard, NK mode, parallel agents) |

## Start here

| I want to… | Document |
| ---------- | -------- |
| Run canonical SPL (agents + dashboards) | [SPL-CATALOG.md](SPL-CATALOG.md) |
| Build the Lab 3–7 dashboard | [DASHBOARD.md](DASHBOARD.md) |
| Workshop `local/` setup (props, nav, permissions) | [SA-S4R/local/README](../../SA-S4R/local/README) |
| Present the agentic demo (slides + script) | [demo-slides/](../../demo-slides/) — `s4r-demo-slides.md`, [S4R-DEMO.md](../../demo-slides/S4R-DEMO.md) |
| Cursor agent prompts | [`.cursor/agents/`](../../.cursor/agents/) |

## Cursor subagents

Power User and specialists set **`model`** and **`is_background`** in YAML frontmatter — see [`.cursor/agents/README.md`](../../.cursor/agents/README.md). Orchestration: [AGENTS.md § Using agents in Cursor](AGENTS.md#using-agents-in-cursor).

| Agent | Model | Background |
| ----- | ----- | ---------- |
| `s4r-power-user` | `claude-4.6-sonnet-medium-thinking` | No (foreground orchestrator) |
| Four specialists | `composer-2.5-fast` | Yes (parallel workers) |

**Parallel demos:** four specialists share **`splunker`** search concurrency (limit 3) — [TROUBLESHOOTING.md](TROUBLESHOOTING.md#parallel-agent-searches-hit-splunker-concurrency-limit).

## Workshop data modes

```bash
make s4r-attack-nk-status    # disabled = infrastructure (default)
make s4r-attack-nk-enable && make restart   # active threat storyline
```

Detail: [SA-S4R-APP.md](SA-S4R-APP.md) · discriminating SPL: [SPL-CATALOG.md § Workshop modes](SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat).

## Three layers (teaching model)

| Layer | Location |
| ----- | -------- |
| **Runbook** | [SPL-CATALOG.md](SPL-CATALOG.md) — agents **always** use inline `rex` for `platform` |
| **Roles** | `.cursor/agents/s4r-*.md` |
| **Platform** | Splunk MCP via `.cursor/mcp.json` |
