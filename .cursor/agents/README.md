# S4R Cursor agent prompts

Copy-paste **role prompts** for **Cursor Task** subagents (or main chat) on **Splunk4Rookies / Buttercup Enterprises** (`SA-S4R`).

**SPL runbook (canonical searches):** [docs/S4R-SPL-CATALOG.md](../../docs/S4R-SPL-CATALOG.md) — agents reference this; they do not duplicate full query blocks.

## Three layers

| Layer | File | Purpose |
| ----- | ---- | ------- |
| Runbook | `docs/S4R-SPL-CATALOG.md` | Labs 3–7 SPL + workshop-mode queries |
| Roles | `s4r-*.md` (this folder) | Persona, output format, escalation |
| Orchestrator | `s4r-power-user.md` | Delegate, synthesize, MCP workflow |

Design: [docs/S4R-AGENTS.md](../../docs/S4R-AGENTS.md). **Marp deck:** [demo-slides/s4r-demo-slides.md](../../demo-slides/s4r-demo-slides.md) (`make marp-preview`). **Presenter script:** [demo-slides/S4R-DEMO.md](../../demo-slides/S4R-DEMO.md).

| File | Role |
| ---- | ---- |
| [s4r-power-user.md](s4r-power-user.md) | Orchestrator — delegate and synthesize |
| [s4r-it-ops.md](s4r-it-ops.md) | IT Operations — HTTP success vs failure |
| [s4r-devops.md](s4r-devops.md) | DevOps — platform and browser failures |
| [s4r-business-analytics.md](s4r-business-analytics.md) | Business Analytics — lost revenue |
| [s4r-security-fraud.md](s4r-security-fraud.md) | Security & Fraud — geographic activity |

## Task subagent example

```text
You are the S4R IT Ops agent. Read .cursor/agents/s4r-it-ops.md for your role.
Before splunk_run_query: read docs/S4R-SPL-CATALOG.md § IT Ops and run every query there.
Time range: last 24 hours.
Return IT Ops summary only; do not synthesize other teams.
```

Launch with Splunk MCP enabled (`subagent_type: generalPurpose` or `s4r-power-user`).

## Prerequisites

- `make up` and `make demo-prep`
- Data in `main` / `access_combined` (SA-S4R Eventgen)
- Splunk MCP tools in the client

## Workshop data modes

| Mode | Command |
| ---- | ------- |
| Infrastructure (default) | `make s4r-attack-nk-disable` then `make restart` |
| Active threat (NK geo) | `make s4r-attack-nk-enable` then `make restart` |
| Check current mode | `make s4r-attack-nk-status` |

Discriminating SPL: [S4R-SPL-CATALOG.md § Workshop modes](../../docs/S4R-SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat). Eventgen detail: [SA-S4R-APP.md](../../docs/SA-S4R-APP.md).
