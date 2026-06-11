# Splunk4Rookies agentic setup (Buttercup Enterprises)

Agent roles for the **Splunk4Rookies** attendee workshop (Apr 2026 deck) and this repo’s **`SA-S4R`** dataset. One **Splunk Power User** orchestrator delegates to four specialist agents; each maps to a dashboard panel in Labs 3–7.

**Related docs:** [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) (**SPL runbook**), [S4R-DASHBOARD.md](S4R-DASHBOARD.md) (dashboard layout), [SA-S4R-APP.md](SA-S4R-APP.md) (Eventgen data), [s4r/README.md](s4r/README.md) (workshop hub), [`.cursor/agents/`](../.cursor/agents/) (role prompts for Cursor).

## Educational model

Show attendees a pattern they can reuse: **Splunk** holds truth → **MCP** exposes governed tools → **SPL catalog** is the runbook → **agents** are stakeholder roles → **Power User** synthesizes.

```text
Stakeholder question
        │
        ▼
┌───────────────────────┐
│  Splunk Power User    │  route · delegate · synthesize
│  s4r-power-user.md    │
└───────────┬───────────┘
            │ delegate (parallel when needed)
    ┌───────┼───────┬───────────┐
    ▼       ▼       ▼           ▼
 IT Ops  DevOps  Business    Security
         Analytics   & Fraud
    │       │       │           │
    │  role prompts (.cursor/agents/s4r-*.md)
    │       │       │           │
    └───────┴───────┴───────────┘
                    │
                    ▼
         docs/S4R-SPL-CATALOG.md  ← canonical SPL (Labs 3–7)
                    │
                    ▼
         Splunk MCP (splunk_run_query, saia_*)
                    │
                    ▼
         index=main sourcetype=access_combined  (SA-S4R Eventgen)
```

| Layer | Teaches | File |
| ----- | ------- | ---- |
| Data | Synthetic workshop traffic | [SA-S4R-APP.md](SA-S4R-APP.md) |
| Runbook | SPL, fields, lookups | **[S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md)** |
| Roles | How each team thinks and reports | [`.cursor/agents/`](../.cursor/agents/) |
| Tools | LLM calls Splunk, not chat memory | Splunk MCP · [API_REFERENCE.md](API_REFERENCE.md) |
| Orchestration | One answer from many teams | `s4r-power-user.md` · this doc |

## Scenario

**Buttercup Enterprises** is a US online retailer (books, clothing, gifts). Base search and field conventions: **[S4R-SPL-CATALOG.md § Data contract](S4R-SPL-CATALOG.md#data-contract)**.

Eventgen in **`SA-S4R`** emits workshop-shaped Apache access logs. Lookup **`product_codes.csv`** maps `product_id` → `product_price`. **Dashboard panels** may use a Lab 4 **`platform`** field extraction; **agents always use inline `rex`** from the catalog (MCP does not rely on saved extractions).

## Splunk Power User (orchestrator)

**Mission:** Understand the ask, delegate to specialist(s), run searches via Splunk MCP using the **SPL catalog**, synthesize one business-facing insight.

**Prompt file:** [`.cursor/agents/s4r-power-user.md`](../.cursor/agents/s4r-power-user.md)

| Topic | Delegate to | Catalog § |
| ----- | ----------- | --------- |
| HTTP errors, success vs failure | IT Ops | [§ IT Ops](S4R-SPL-CATALOG.md#-it-ops-lab-3) |
| OS, browsers, client vs server | DevOps | [§ DevOps](S4R-SPL-CATALOG.md#-devops-lab-4) |
| Revenue, purchases, lost sales | Business Analytics | [§ Business Analytics](S4R-SPL-CATALOG.md#-business-analytics-lab-5) |
| Geography, fraud indicators | Security & Fraud | [§ Security & Fraud](S4R-SPL-CATALOG.md#-security--fraud-lab-6) |
| Infrastructure vs threat | All four | [§ Workshop modes](S4R-SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat) |
| Full dashboard / Labs 3–7 | All four | [§ Power User](S4R-SPL-CATALOG.md#-power-user-lab-7) |

**Synthesis template:** see `s4r-power-user.md`.

**Guardrails:** Read-only SPL in demos; no secrets in output; MCP user `splunker`; **MCP-only execution** (no Splunk REST/curl from agents); config tasks (field extract, lookup) escalated explicitly.

---

## Specialist agents

| Agent | Lab | Ask | Prompt | Catalog § |
| ----- | --- | --- | ------ | --------- |
| IT Ops | 3 | Success vs failure over time | [s4r-it-ops.md](../.cursor/agents/s4r-it-ops.md) | [§ IT Ops](S4R-SPL-CATALOG.md#-it-ops-lab-3) |
| DevOps | 4 | OS mix, failing browsers, client vs server | [s4r-devops.md](../.cursor/agents/s4r-devops.md) | [§ DevOps](S4R-SPL-CATALOG.md#-devops-lab-4) |
| Business Analytics | 5 | Lost revenue from failed purchases | [s4r-business-analytics.md](../.cursor/agents/s4r-business-analytics.md) | [§ Business Analytics](S4R-SPL-CATALOG.md#-business-analytics-lab-5) |
| Security & Fraud | 6 | Activity by geography | [s4r-security-fraud.md](../.cursor/agents/s4r-security-fraud.md) | [§ Security & Fraud](S4R-SPL-CATALOG.md#-security--fraud-lab-6) |
| Power User | 7 | Unified insight + dashboard | [s4r-power-user.md](../.cursor/agents/s4r-power-user.md) | [§ Power User](S4R-SPL-CATALOG.md#-power-user-lab-7) |

Escalation rules live in each agent file (not duplicated here).

---

## Workshop ↔ agent ↔ panel matrix

| Lab | Team | Catalog § |
| --- | ---- | --------- |
| 3 | IT Ops | `timechart count by status` |
| 4 | DevOps | `top platform`; `timechart by useragent` where `status>=400` |
| 5 | Business Analytics | `lookup product_codes.csv` + `sum(product_price)` |
| 6 | Security & Fraud | `iplocation clientip` + `geostats count by City` |
| 7 | Power User | All panels + synthesis |

Full SPL: [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md).

## Using agents in Cursor

1. Enable **splunk-mcp-server** in `.cursor/mcp.json` (`make up` / `make update-cursor-config`).
2. Buttercup / S4R questions: act as **Power User** ([`.cursor/rules/s4r-buttercup-agents.mdc`](../.cursor/rules/s4r-buttercup-agents.mdc)).
3. **Read `docs/S4R-SPL-CATALOG.md`** for SPL; agents for roles and output format.
4. Heavy parallel work: **Task** subagents — prompt must include *“Read catalog § [team] before `splunk_run_query`; MCP only — no REST/curl.”* See [`.cursor/agents/README.md`](../.cursor/agents/README.md).
5. Confirm data: `make status`, then catalog **Quick data check**.
6. Presales: `make demo-prep`.

### Model configuration

**Power User** uses **`claude-4.6-sonnet-medium-thinking`**; specialists use **`composer-2.5-fast`** (not `inherit`) so parallel workers stay fast and cheap while the orchestrator handles synthesis. Table, upgrade paths, and Cursor caveats: [`.cursor/agents/README.md` § Model configuration](../.cursor/agents/README.md#model-configuration).

### Foreground / background (`is_background`)

Specialists run as **background** subagents (`is_background: true`); **Power User** stays **foreground**. The Power User **waits for all** team summaries before synthesizing. Details: [`.cursor/agents/README.md` § Foreground / background](../.cursor/agents/README.md#foreground--background-configuration).

### Parallel delegation and search concurrency

When all four specialists run at once, each calls `splunk_run_query` as **`splunker`**. The default PoC user is limited to **3 concurrent historical searches** — expect occasional dispatch failures on the fourth query. Mitigations: retry after a few seconds, stagger teams, or run sequentially for live demos. See [`.cursor/agents/README.md` § Parallel delegation](../.cursor/agents/README.md#parallel-delegation-four-teams) and [TROUBLESHOOTING.md § Parallel agent searches](TROUBLESHOOTING.md#issue-parallel-agent-searches-hit-splunker-concurrency-limit).

**Copy-paste prompt (Demo 1):**

```text
As Buttercup Power User: is the shop losing money? Delegate to all four teams.
Read docs/S4R-SPL-CATALOG.md per team. Splunk MCP only — splunk_run_query; never Splunk REST or curl for searches. Last 24 hours.
Wait for all four summaries; synthesize one executive answer (Power User template).
```

## Synthetic data modes

Before “infrastructure vs threat” questions: **`make s4r-attack-nk-status`**. Toggle and Eventgen detail: [SA-S4R-APP.md](SA-S4R-APP.md). Discriminating SPL: [S4R-SPL-CATALOG.md § Workshop modes](S4R-SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat).

| Mode | How to set | Power User headline |
| ---- | ---------- | ------------------- |
| **Infrastructure** (default) | `make s4r-attack-nk-disable` (+ `make restart`) | 503/404 everywhere; flat ~40% geo/platform |
| **Active threat** | `make s4r-attack-nk-enable` then `make restart` | NK / Pyongyang on failed purchases; scripted UAs |

Use **last 15m** after enabling threat mode.

## Demo script: agentic Buttercup + Splunk MCP

**Full presenter guide** (17-slide Marp deck, mermaid diagrams, 20- and 10-minute tracks, copy-paste prompts): **[S4R-DEMO.md](../demo-slides/S4R-DEMO.md)** · **[demo-slides/README.md](../demo-slides/README.md)** (Marp build/preview).

Quick beats:

| Beat | Show | Say |
| ---- | ---- | --- |
| 1. Layers | `S4R-SPL-CATALOG.md`, one `s4r-*.md`, `s4r-power-user.md`, `.cursor/mcp.json` | Runbook, roles, orchestrator, MCP bridge |
| 2. Live ask | *“Is Buttercup losing money?”* | Delegate; `splunk_run_query` in tool trace |
| 3. Synthesis | Power User table | One executive answer |
| 4. Flip mode | `make s4r-attack-nk-enable` + `make restart` | Data mode changes verdict |
| 5. Threat ask | *“Infrastructure or active threat?”* (last 15m) | Security § + Workshop modes |
| 6. Dashboard | [S4R-DASHBOARD.md](S4R-DASHBOARD.md) | Panels = catalog sections |

Also: [PRESALES.md](PRESALES.md#optional-agentic-buttercup-demo-splunk4rookies).

## Example delegation

**User:** *“As Buttercup Power User: is the shop losing money? Delegate to all four teams.”*

1. **Power User** — last 24h; launch **four parallel** specialist subagents (IT Ops, DevOps, Business Analytics, Security & Fraud); **wait for all** before synthesizing.
2. Each specialist — catalog § for their team; **`splunk_run_query` via MCP only** (no REST/curl) in specialist context.
3. **Power User** — synthesize: lost revenue (Business), server-wide vs client (DevOps), status/URI errors (IT Ops), geo anomalies (Security).

**Typical verdict (infrastructure):** Yes, losing money — checkout/web tier failure (~40% server-wide), not a single mobile OS.

**Typical verdict (threat or residual NK in window):** Mixed — infrastructure still broken; Security leads on NK / **175.45.\*** failed-purchase concentration and **Costume-ManHawk** skew.

**User:** *“Is the shop losing money today — servers or mobile users?”*

1. **Power User** — time range; catalog quick check.
2. **IT Ops** — catalog § IT Ops.
3. **Business Analytics** — catalog § Business Analytics.
4. **DevOps** — catalog § DevOps (verdict query).
5. **Security** — catalog § Security (optional geo context).
6. **Power User** — synthesize.

**User:** *“Is the money loss bad infrastructure or an active threat?”*

1. **Power User** — `make s4r-attack-nk-status`; last 15m if threat mode.
2. **IT Ops** — purchase errors by status (catalog § Workshop modes).
3. **DevOps** — failure rate by platform + scripted UAs.
4. **Security** — failed purchases by Country/City/IP.
5. **Business Analytics** — lost revenue by product (`CM-1` skew in threat mode).
6. **Power User** — verdict per catalog **Expected finding** rows.

## References

- [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) — **canonical SPL**
- Splunk4Rookies attendee deck (Apr 2026) — Labs 3–7
- [SA-S4R-APP.md](SA-S4R-APP.md)
- [API_REFERENCE.md](API_REFERENCE.md)
