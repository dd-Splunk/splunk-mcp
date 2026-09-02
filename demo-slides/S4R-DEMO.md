# Splunk4Rookies demo — Agentic Buttercup + Splunk MCP

Presenter guide for **Splunk4Rookies** workshop follow-on or **SE presales**: show how **multi-agent orchestration** and **Splunk MCP** turn `access_combined` logs into stakeholder-ready answers.

**Audience:** Splunk users, SEs, workshop attendees who completed Labs 3–7 (or will build the dashboard).

**Duration:** 20 minutes (full) · 10 minutes (short — see [Short track](#short-track-10-minutes)).

**Related:** [S4R-SPL-CATALOG.md](../docs/S4R-SPL-CATALOG.md) · [S4R-MCP-TOOLS.md](../docs/S4R-MCP-TOOLS.md) · [S4R-AGENTS.md](../docs/S4R-AGENTS.md) · [PRESALES.md](../docs/PRESALES.md) · [SA-S4R-APP.md](../docs/SA-S4R-APP.md) · [demo-slides/README.md](README.md) (Marp)

---

## Before you start (5 minutes earlier)

On-screen checklist: **deck slide 30** (Appendix — before you start).

```bash
make demo-prep                    # status + MCP verify
make s4r-attack-nk-status         # expect: disabled (infrastructure mode)
```

| Check | Command / action |
| ----- | ---------------- |
| Splunk Web | `https://localhost:8000` (admin — password from vault) |
| MCP in Cursor | Restart Cursor; Splunk MCP tools visible |
| Data flowing | Search: `index=main sourcetype=access_combined \| head 5` |
| Tabs pre-open | `docs/S4R-SPL-CATALOG.md`, `.cursor/agents/s4r-power-user.md`, `.cursor/agents/s4r-it-ops.md`, `.cursor/mcp.json` |

**Warm stack:** Cold `make up` can take many minutes — start Splunk before the session.

**After threat segment:** `make s4r-attack-nk-disable && make restart` to restore default mode.

---

## Slide deck (Marp)

**Source:** [`demo-slides/s4r-demo-slides.md`](s4r-demo-slides.md) — **32 slides** with Splunk dark theme, client-side Mermaid, and HTML speaker notes.

```bash
make marp-preview    # Marp preview window
make marp-serve      # http://localhost:8080/
make marp-html       # export demo-slides/s4r-demo-slides.html
```

**Cursor:** open `demo-slides/s4r-demo-slides.md` with the [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode) extension; press **`P`** for presenter notes. Requires network for Mermaid (jsDelivr CDN) unless you use exported HTML.

**Maintainer details** (theme classes, diagram layout, troubleshooting): [`demo-slides/README.md`](README.md).

The sections below mirror slide content and **speaker script**; if the deck and this file diverge, **`s4r-demo-slides.md` wins** for on-screen text.

---

## Slide 1 — Title

**Splunk4Rookies** / **From dashboards to agentic analysis**

- Buttercup Enterprises workshop PoC · one dataset · **three ways** to use Splunk MCP
- Live data via **Splunk MCP** — not pasted into the model

*Speaker note:* Pattern demo, not a product pitch. Splunk stays source of truth; the assistant calls governed tools.

---

## Slide 2 — Three ways this repo helps

| Step | Who | What |
| ---- | --- | ---- |
| **1 — Workshop** | Builder | Natural language **dashboard build** (Labs 3–7) |
| **2 — Business user** | Stakeholder | **Business questions** — no SPL |
| **3 — Agentic** | Platform lead | **Orchestrator** + specialists + executive synthesis |

*Speaker note:* Deck follows this sequence. Same catalog throughout.

---

## Slide 3 — Scenario — Buttercup Enterprises

**US online retailer** (books, clothing, gifts)

| Stakeholder | Cares about |
| ----------- | ----------- |
| IT Operations | Uptime, HTTP errors |
| DevOps | Browsers, OS, releases |
| Business Analytics | Lost revenue |
| Security and Fraud | Who, from where |

**Data:** `index=main sourcetype=access_combined` (SA-S4R Eventgen)

*Speaker note:* Same logs as Labs 3–7 dashboard build.

---

## Slides 4–6 — Step 1: Workshop dashboard build

**Slide 4:** Section divider — build dashboards with natural language.

**Slide 5:** Labs 3–7 table; example prompt referencing `docs/S4R-DASHBOARD.md`.

**Slide 6:** Artifacts — `S4R-DASHBOARD.md`, `S4R-SPL-CATALOG.md`, `SA-S4R` app.

*Speaker note:* Optional live or screenshot — LLM reads layout spec + catalog SPL. Workshop hub: `docs/s4r/README.md`.

---

<a id="slides-7-12-splunk-mcp-architecture"></a>

## Slides 7–12 — Splunk MCP architecture and S4R tools

Developer Day 2026: apps expose tools through **Splunk MCP Server** — recordings in the [Developer Day 2026 playlist](https://www.youtube.com/playlist?list=PLxkFdMSHYh3T2mFyCdg8iz9ef068gLdfJ). Primary session: **[Apps with MCP Tools](https://www.youtube.com/watch?v=fjGCf0QiBJc)**. Implementation: [S4R-MCP-TOOLS.md](../docs/S4R-MCP-TOOLS.md).

**Slide 7:** Section divider — apps as tools.

**Slide 8 — Apps as MCP tools:** Session wording — existing Splunk apps into Cursor/Claude/AI Canvas; saved search vs REST; `tools.conf` + signatures; collision detection / rate limiting.

**Slide 9 — Architecture:** Native tools · Splunkbase app tools · private app (`SA-S4R_*`). Szebenyi deck three-layer diagram.

**Slide 10 — How it works:** App files → MCP Tool Registration → saved search / REST handler.

**Slide 11 — `tools.conf` and signatures:** Official `[savedsearches:]` / `[restmap:]` stanzas mapped to SA-S4R; Tool ID.

**Slide 12 — SA-S4R workshop tools:** five tools (two API for NK mode, three SPL for KPIs / geo / NK validate).

*Speaker note:* Technical / SE audiences: ~2 minutes. Workshop-only attendees can skip to Step 2. Agents call governed tools; they do not invent a second MCP server.

---

<a id="slides-13-16-step-2-business-questions-without-spl"></a>

## Slides 13–16 — Step 2: Business questions without SPL

**Slide 13:** Section divider — end-user mode.

**Slide 14:** Example business prompts (*Is my website losing money?*, checkout funnel, merchandising).

**Slide 15:** Splunk MCP sequence diagram + identity table (`splunker`, bearer token, `splunk_run_query`, **`SA-S4R_*`** workshop tools).

**Slide 16 — Live demo prompt** (two columns on-screen):

> *Using the Buttercup SPL catalog: is the website losing money? Summarize business impact from failed purchases.*

*Speaker note:* Single assistant — no delegation. Prefer **`SA-S4R_summarize_purchase_health`**; plain-language answer.

**Optional Step 2 (Security)** — right column:

> *Where are failed purchases concentrated geographically? Any anomalies worth review?*

*Watch for:* **`SA-S4R_geo_failed_purchases`**

---

## Slides 17–27 — Step 3: Agentic orchestration

**Slide 17:** Section divider — Power User + four teams + executive synthesis.

**Slide 18 — The challenge:** One log set → four questions → one executive answer.

**Slide 19 — Agentic Architecture:** User → Power User → IT Ops / DevOps / Business Analytics / Security → catalog → MCP → synthesis.

**Slide 20 — Agents Artifacts defined:** `S4R-SPL-CATALOG.md`, `.cursor/agents/s4r-*.md`, `.cursor/mcp.json`, `S4R-AGENTS.md`.

**Slide 21 — Two workshop data modes:** infrastructure vs NK threat; prefer **`SA-S4R_apply_nk_demo_state`** / **`SA-S4R_query_nk_demo_state`** in chat; `make s4r-attack-nk-*` as operator fallback.

**Slide 22 — Demo 1 (infrastructure):**

> *As Buttercup Power User: is the shop losing money? Delegate to all four teams.*

**Slide 23 — Delegation flow** + expected answer (bad web tier, not mobile/geo).

**Slide 24 — Buttercup Insights** synthesis table (live MCP numbers).

**Slides 25–26 — Additional Business questions:** checkout, merchandising, mobile, international, fraud vs reliability (Step 2 or Step 3).

**Slide 27 — Demo 2 (North Korea attack):** compact slide — enable threat via chat (`SA-S4R_apply_nk_demo_state`) or one-line `make` fallback; then Power User ask; **last 15 minutes**. Validate with **`SA-S4R_validate_nk_attack_traffic`**.

*Speaker notes:* See original Demo 1/2 detail below; cleanup **`SA-S4R_apply_nk_demo_state`** (`infrastructure`) or `make s4r-attack-nk-disable && make restart`.

---

## Slide 28 — Takeaways

1. **Step 1** — NL dashboard build from workshop spec + catalog.
2. **MCP architecture** — SA-S4R packages SPL and API tools in `tools.conf`; Splunk MCP Server exposes them ([Apps with MCP Tools](https://www.youtube.com/watch?v=fjGCf0QiBJc)).
3. **Step 2** — Business questions via MCP; no SPL for the user.
4. **Step 3** — Power User orchestrates four specialists → executive synthesis.
5. **Same data and catalog** — infrastructure vs threat without rewriting prompts.

**Repo:** `splunk-mcp` · `make up` · presenter guide: `demo-slides/S4R-DEMO.md` (this file)

---

## Slide 29 — Thank You

Closing slide (`lead-hero` styling). No additional script required.

---

## Slides 30–32 — Appendix

| Slide | Content |
| ----- | ------- |
| 30 | Before you start — `make demo-prep`, checks, warm-stack reminder |
| 31 | Copy-paste prompts — Steps 1, 2, and 3 (Demo 1 / Demo 2) |
| 32 | Troubleshooting table — MCP, events, NK mode, concurrency, token |

Expanded presenter detail for appendix topics: [Before you start](#before-you-start-5-minutes-earlier), [Backup & troubleshooting](#backup--troubleshooting), [Copy-paste prompts](#copy-paste-prompts-chat), [Business use cases (copy-paste)](#business-use-cases-copy-paste).

---

## Slide 25 — Additional Business questions (1 of 2)

| Use case | Ask the Power User |
| -------- | ------------------ |
| Checkout vs funnel | *Are we losing sales because checkout is failing, or because customers never get to purchase?* |
| Merchandising priority | *Which products and categories are costing us the most in failed checkout revenue?* |
| Mobile vs platform | *Should we invest in mobile app fixes, or is checkout failing every platform equally?* |

*Speaker note:* Same pattern for all use cases: Power User delegates to four teams, catalog SPL, MCP only.

---

## Slide 26 — Additional Business questions (2 of 2)

| Use case | Ask the Power User |
| -------- | ------------------ |
| International growth | *Is checkout failing more for international customers than for US shoppers?* |
| Fraud vs reliability | *Is the revenue impact from an active attack, or from a broken checkout service?* |

*Speaker note:* Show after Buttercup Insights — optional alternate questions. Attendees can swap questions without changing agents or runbook.

Expanded prompts: [Business use cases (copy-paste)](#business-use-cases-copy-paste).

---

## Presenter script (20 minutes)

Timings are approximate. Adjust for audience questions.

### 0:00 — Hook + three paths (2 min)

**Say:** *“This repo supports three journeys on the same Buttercup data: build the workshop dashboard in natural language, ask business questions without SPL, then — if you want structure — delegate to specialist agents.”*

**Show:** Slides 1–3.

---

### 0:02 — Step 1: Dashboard build (2 min)

**Do:** Open `docs/S4R-DASHBOARD.md` and `docs/S4R-SPL-CATALOG.md` — scroll Labs 3–7 sections.

**Say:** *“Workshop attendees describe the dashboard; the LLM reads the layout spec and catalog SPL — same runbook the agents use later.”*

**Show:** Slides 4–6. Optional: show existing dashboard in Splunk Web.

---

### 0:04 — Splunk MCP architecture (2 min)

**Say:** *“Developer Day — Apps with MCP Tools: native Splunk tools, Splunkbase app tools, and your private app. SA-S4R is that private column — saved searches and a REST handler, registered with tools.conf and signatures.”*

**Show:** Slides 7–12. Point at the architecture diagram, then the five `SA-S4R_*` tools.

**Skip** for workshop-only audiences who just want the live Q&A — go straight to Step 2.

---

### 0:06 — Step 2: Business question (3 min)

**Say:** *“Executives don’t write SPL. They ask: is my website losing money?”*

**Show:** Slides 13–15 (MCP guardrails).

**Do:** Cursor — [Step 2 prompt](#slides-13-16-step-2-business-questions-without-spl) (single assistant, no delegation).

**Narrate:** *“Governed workshop tool — `SA-S4R_summarize_purchase_health` — or catalog SPL via `splunk_run_query`; plain-language answer.”*

**Show:** Slide 16.

---

### 0:09 — Step 3: Agentic setup (2 min)

**Do:** Open `.cursor/agents/s4r-power-user.md` and one specialist file; `.cursor/mcp.json` (blur token).

**Say:** *“Same MCP bridge — now the Power User routes to IT Ops, DevOps, Business Analytics, Security and Fraud, then synthesizes.”*

**Show:** Slides 17–21 (challenge, architecture, artifacts, data modes).

Optional: `make verify-mcp-remote MCP_VERIFY_CLIENT=cursor` in terminal (fast).

---

### 0:11 — Step 3 Demo 1 live (4 min)

**Do:** Cursor chat — Step 3 Demo 1 prompt (delegate to all four teams).

**Narrate while it runs:**

- *“Power User is delegating…”*
- *“There’s `SA-S4R_summarize_purchase_health` or `splunk_run_query` — governed SPL from the catalog.”*
- *“IT Ops owns status codes; Business owns lookup revenue; Security may call `SA-S4R_geo_failed_purchases`.”*

**If delegation is slow:** Call out one team only first: *“IT Ops only — success vs failure from catalog § IT Ops.”*

**Show:** Slides 23–26 when synthesis appears (delegation flow, Buttercup Insights, optional business-question menu).

**Fallback if MCP fails:** Run one search in Splunk Web from catalog § IT Ops; explain MCP would return the same JSON.

---

### 0:14 — Bridge to threat storyline (1 min)

**Say:** *“Same agents, same catalog. We flip synthetic data mode to simulate an active threat — no prompt rewrite.”*

**Show:** Slide 21 again (or narrate from memory — enable NK mode). Slides 25–26 list alternate business questions if the audience asks.

---

### 0:15 — Step 3 Demo 2 live (4 min)

**Do:** Cursor chat — enable threat first:

> *Start the North Korean attack simulation for the Buttercup workshop.*

Wait ~2 min; optional **`SA-S4R_validate_nk_attack_traffic`**. Then Step 3 Demo 2 prompt (**last 15 minutes**).

**Terminal fallback:** `make s4r-attack-nk-enable && make restart` (see Slide 27).

**Narrate:** *“Security should surface North Korea on failed purchases (`SA-S4R_geo_failed_purchases` / validate NK tool); DevOps should see scripted user agents; IT Ops still sees 503 from baseline traffic.”*

**Say:** *“Verdict: mixed — infrastructure still broken, but Security has a lead for investigation.”*

---

### 0:19 — Close (1 min)

**Show:** Slides 28–29 (takeaways, thank you).

**Say:** *“Build, ask, orchestrate — one catalog in git, live answers from Splunk MCP.”*

**Cleanup:** **`SA-S4R_apply_nk_demo_state`** (`infrastructure`) or `make s4r-attack-nk-disable && make restart`

---

## Short track (10 minutes)

| Time | Action |
| ---- | ------ |
| 0:00 | Slides 1–3 (three paths + scenario) |
| 0:02 | Slides 4–6 (Step 1 dashboard) — brief or skip if audience did workshop |
| 0:04 | Slide 16 — Step 2 business question live (skip architecture 7–12) |
| 0:07 | Slides 17–21 + Step 3 Demo 1 prompt |
| 0:14 | Slide 21 + Step 3 Demo 2 **or** skip Demo 2 if low on time |
| 0:19 | Slides 28–29 takeaways + thank you |

Skip: `make verify-mcp-remote` live, Step 1 live build, second terminal restart.

---

## Backup & troubleshooting

On-screen table: **deck slide 32**. Expanded detail below for presenters.

| Problem | Presenter action |
| ------- | ---------------- |
| MCP tools missing | `make update-cursor-config`; restart Cursor |
| No events | `make status`; `docker logs splunk-init` |
| NK mode no signal | **`SA-S4R_query_nk_demo_state`**; **`SA-S4R_validate_nk_attack_traffic`**; `make restart`; search **last 15m** |
| Concurrency limit | Wait; run one team at a time |
| Token / 401 | `make up` or `make update-mcp-client MCP_CLIENT=cursor` |

Details: [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) · [SA-S4R-APP.md](../docs/SA-S4R-APP.md) (NK troubleshooting table)

---

## Optional: Splunk Web validation (audience double-check)

Run in Search & Reporting (same SPL as agents):

```spl
index=main sourcetype=access_combined action=purchase status>=400
| lookup product_codes product_id
| stats sum(product_price) as lost_revenue
```

Threat mode geo:

```spl
index=main sourcetype=access_combined action=purchase status>=400 earliest=-15m
| iplocation clientip
| stats count by Country, City, clientip
| sort - count
| head 5
```

Full catalog: [S4R-SPL-CATALOG.md](../docs/S4R-SPL-CATALOG.md)

---

## Copy-paste prompts (chat)

Short on-slide versions: **deck slide 31**. Long-form prompts for live demos:

**Demo 1:**

```text
As Buttercup Power User for Splunk4Rookies: is the shop losing money?
Delegate to IT Ops, DevOps, Business Analytics, and Security & Fraud.
Read docs/S4R-SPL-CATALOG.md for SPL. Splunk MCP only — splunk_run_query and SA-S4R_* workshop tools; never Splunk REST or curl for searches.
Synthesize one executive answer with the Power User template.
```

**Demo 2:**

```text
As Buttercup Power User: is the money loss bad infrastructure or an active threat?
Check SA-S4R_query_nk_demo_state (fallback: make s4r-attack-nk-status). Delegate to all four teams.
Use docs/S4R-SPL-CATALOG.md including § Workshop modes. Splunk MCP only — SA-S4R_* tools and splunk_run_query; no REST/curl for searches. Time range: last 15 minutes.
Synthesize with clear verdict and recommended actions.
```

**Single-team deep dive (fill-in):**

```text
You are the S4R [IT Ops|DevOps|Business Analytics|Security & Fraud] agent.
Read .cursor/agents/s4r-[team].md and docs/S4R-SPL-CATALOG.md § [section].
Run searches via splunk_run_query or SA-S4R_* workshop tools (MCP only — no REST/curl). Return only that team's summary.
```

---

## Business use cases (copy-paste)

Same delegation pattern as Demo 1 unless noted. Infrastructure mode, **last 24 hours**, unless Demo 2 / fraud ask.

**Checkout vs funnel:**

```text
As Buttercup Power User: are we losing sales because checkout is failing, or because customers never get to purchase?
Delegate to all four teams. Read docs/S4R-SPL-CATALOG.md per team. Splunk MCP only — SA-S4R_* tools and splunk_run_query; never REST or curl.
Synthesize one executive answer with the Power User template.
```

**Merchandising priority:**

```text
As Buttercup Power User: which products and categories are costing us the most in failed checkout revenue?
Delegate to all four teams. Read docs/S4R-SPL-CATALOG.md (Business Analytics § + supporting teams). MCP only. Last 24 hours.
Synthesize with recommended merchandising and engineering priorities.
```

**Mobile vs platform:**

```text
As Buttercup Power User: should we invest in mobile app fixes, or is checkout failing every platform equally?
Delegate to all four teams. Read docs/S4R-SPL-CATALOG.md (DevOps § platform prefix + IT Ops + Business). MCP only. Last 24 hours.
Synthesize with a clear build-vs-fix recommendation.
```

**International growth:**

```text
As Buttercup Power User: is checkout failing more for international customers than for US shoppers?
Delegate to all four teams. Read docs/S4R-SPL-CATALOG.md (Security § iplocation + Business + IT Ops). MCP only. Last 24 hours.
Synthesize with a go/no-go on international marketing spend.
```

**Fraud vs reliability** (same storyline as Demo 2 — enable NK mode, **last 15 minutes**):

```text
As Buttercup Power User: is the revenue impact from an active attack, or from a broken checkout service?
Check make s4r-attack-nk-status. Delegate to all four teams. Read docs/S4R-SPL-CATALOG.md including § Workshop modes. MCP only. Last 15 minutes.
Synthesize who to mobilize first — Security vs Engineering.
```

---

## See also

- [S4R-AGENTS.md](../docs/S4R-AGENTS.md) — agent architecture
- [PRESALES.md](../docs/PRESALES.md) — stack bootstrap
- [`.cursor/agents/README.md`](../.cursor/agents/README.md) — Task subagent examples
