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

## Model configuration

Each agent sets **`model`** in YAML frontmatter ([Subagents → Model configuration](https://cursor.com/docs/subagents)). Prefer explicit models over **`inherit`** for specialists so four parallel workers do not all run the orchestrator’s thinking model.

| Agent | `model` | Rationale |
| ----- | ------- | --------- |
| `s4r-power-user` | `claude-4.6-sonnet-medium-thinking` | Routing, wait-for-all, cross-team synthesis, infrastructure vs threat verdict |
| `s4r-it-ops`, `s4r-devops`, `s4r-business-analytics`, `s4r-security-fraud` | `composer-2.5-fast` | Catalog § → MCP → template; runbook-driven, cost/latency friendly in parallel |

**Upgrades:** Flagship demos — Power User → `claude-opus-4-8-thinking-high`. Weak DevOps/Security verdicts in rehearsal — bump only those two to `claude-4.6-sonnet-medium-thinking`.

**Caveats:** Cursor may override models (plan, Max Mode, org policy). Rehearse with your subscription before a live workshop.

## Foreground / background configuration

Cursor subagents support **`is_background`** ([Subagents](https://cursor.com/docs/subagents)):

| Agent | `is_background` | Mode | Why |
| ----- | ------------- | ---- | --- |
| `s4r-power-user` | `false` (default) | **Foreground** | User-facing orchestrator — blocks until synthesis is ready |
| Specialists (four teams) | `true` | **Background** | Parallel workers; MCP/SPL noise stays out of the main thread |

**Background** specialists write progress under `~/.cursor/subagents/`. The Power User prompt requires **wait for all** delegated specialists before synthesizing — note missing/failed teams instead of inventing findings.

**Demo tip:** Background keeps the executive answer clean; set `is_background: false` on a specialist if you want live MCP tool traces visible for that team.

Example specialist frontmatter:

```yaml
---
name: s4r-it-ops
model: composer-2.5-fast
is_background: true
description: IT Operations analyst for Buttercup web tier — HTTP success vs failure.
---
```

## Task subagent example

```text
You are the S4R IT Ops agent. Read .cursor/agents/s4r-it-ops.md for your role.
Before splunk_run_query: read docs/S4R-SPL-CATALOG.md § IT Ops and run every query there.
Time range: last 24 hours.
Return IT Ops summary only; do not synthesize other teams.
```

Launch with Splunk MCP enabled (`subagent_type: generalPurpose` or `s4r-power-user`).

## Parallel delegation (four teams)

**Copy-paste (Demo 1):**

```text
As Buttercup Power User: is the shop losing money? Delegate to all four teams.
Read docs/S4R-SPL-CATALOG.md per team. Use Splunk MCP splunk_run_query. Last 24 hours.
Wait for all four summaries; synthesize one executive answer (Power User template).
```

**Expected synthesis (infrastructure mode, last 24h):** Yes — non-zero lost revenue; ~40% failure **server-wide** (DevOps); 403/401/402 on **`/cart.do`** (IT Ops); geo mostly baseline unless NK stanza was recently enabled.

**Expected synthesis (mixed / residual NK in 24h):** Infrastructure still broken **and** Pyongyang / **175.45.\*** may dominate failed-purchase geo (Security) even when `make s4r-attack-nk-status` shows **disabled** — use **last 15m** after toggling modes, or narrow time range.

### Splunk search concurrency

Four parallel specialists each call `splunk_run_query` as **`splunker`**. Default PoC role limits **historical search concurrency to 3** per user — a fourth simultaneous search may fail with:

`role-based concurrency limit of historical searches for user "splunker" has been reached (usage=3, quota=3)`

**Presenter mitigations:** wait a few seconds and retry; stagger one team; or run teams sequentially (`is_background: false` on specialists for visible one-at-a-time demos). Power User should **wait for all** teams and note any that failed dispatch — do not invent findings.

Detail: [TROUBLESHOOTING.md § Parallel agent searches](../../docs/TROUBLESHOOTING.md#issue-parallel-agent-searches-hit-splunker-concurrency-limit).

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
