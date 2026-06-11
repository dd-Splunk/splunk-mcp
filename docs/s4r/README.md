# Splunk4Rookies (S4R) — workshop docs

Buttercup Enterprises PoC: **SA-S4R** sample app, Labs 3–7 SPL, dashboard build, and agentic demo.

## Start here

| I want to… | Document |
| ---------- | -------- |
| Run canonical SPL (agents + dashboards) | [S4R-SPL-CATALOG.md](../S4R-SPL-CATALOG.md) |
| Build the Lab 3–7 dashboard | [S4R-DASHBOARD.md](../S4R-DASHBOARD.md) |
| Understand Eventgen, NK toggle, data | [SA-S4R-APP.md](../SA-S4R-APP.md) |
| Agent roles, delegation, demo beats | [S4R-AGENTS.md](../S4R-AGENTS.md) |
| Present the agentic demo (slides + script) | [demo-slides/](../../demo-slides/) — `s4r-demo-slides.md`, [S4R-DEMO.md](../../demo-slides/S4R-DEMO.md) |
| Cursor agent prompts | [`.cursor/agents/`](../../.cursor/agents/) |

## Cursor subagent configuration

Power User and specialists set **`model`** and **`is_background`** in YAML frontmatter (see [`.cursor/agents/README.md` § Model configuration](../../.cursor/agents/README.md#model-configuration) and [§ Foreground / background](../../.cursor/agents/README.md#foreground--background-configuration)):

| Agent | Model | Background |
| ----- | ----- | ---------- |
| `s4r-power-user` | `claude-4.6-sonnet-medium-thinking` | No (foreground orchestrator) |
| Four specialists | `composer-2.5-fast` | Yes (parallel workers) |

Orchestration detail: [S4R-AGENTS.md § Using agents in Cursor](../S4R-AGENTS.md#using-agents-in-cursor).

## Three layers (teaching model)

| Layer | Location |
| ----- | -------- |
| **Runbook** | `docs/S4R-SPL-CATALOG.md` — SPL; agents **always** use inline `rex` for `platform` (not Lab 4 UI extraction) |
| **Roles** | `.cursor/agents/s4r-*.md` |
| **Platform** | Splunk MCP via `.cursor/mcp.json` |

## Workshop data modes

```bash
make s4r-attack-nk-status    # disabled = infrastructure (default)
make s4r-attack-nk-enable && make restart   # active threat storyline
```

Detail: [SA-S4R-APP.md](../SA-S4R-APP.md) · discriminating SPL: [S4R-SPL-CATALOG.md § Workshop modes](../S4R-SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat).

## External reference

- Splunk4Rookies Lab Guide (Apr 2026 PDF): [`Splunk4Rookies - Lab Guide - Apr 2026.pdf`](../Splunk4Rookies%20-%20Lab%20Guide%20-%20Apr%202026.pdf) (if present in `docs/`)

## Stack context

Splunk + MCP bootstrap: [PRESALES.md](../PRESALES.md) · [ARCHITECTURE.md](../ARCHITECTURE.md) · [CONFIGURATION.md](../CONFIGURATION.md).
