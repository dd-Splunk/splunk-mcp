# Splunk4Rookies demo — Agentic Buttercup + Splunk MCP

Presenter guide for **Splunk4Rookies** workshop follow-on or **SE presales**: show how **multi-agent orchestration** and **Splunk MCP** turn `access_combined` logs into stakeholder-ready answers.

**Audience:** Splunk users, SEs, workshop attendees who completed Labs 3–7 (or will build the dashboard).

**Duration:** 20 minutes (full) · 10 minutes (short — see [Short track](#short-track-10-minutes)).

**Related:** [S4R-SPL-CATALOG.md](../docs/S4R-SPL-CATALOG.md) · [S4R-AGENTS.md](../docs/S4R-AGENTS.md) · [PRESALES.md](../docs/PRESALES.md) · [SA-S4R-APP.md](../docs/SA-S4R-APP.md) · [demo-slides/README.md](README.md) (Marp)

---

## Before you start (5 minutes earlier)

On-screen checklist: **deck slide 15** (Appendix — before you start).

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

**Source:** [`demo-slides/s4r-demo-slides.md`](s4r-demo-slides.md) — **19 slides** with Splunk dark theme, client-side Mermaid, and HTML speaker notes.

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

**Splunk4Rookies** / **Agentic analysis with Splunk MCP**

- Buttercup Enterprises workshop PoC · One dataset · four teams · one orchestrator
- Live data via **Splunk MCP** — not pasted into the model

*Speaker note:* Pattern demo, not a product pitch. Splunk stays source of truth; the assistant calls governed tools.

---

## Slide 2 — Scenario — Buttercup Enterprises

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

## Slide 3 — The challenge

```text
One set of web logs  →  four different questions  →  one executive answer
```

Without agent structure you get:

- Four disconnected SPL walls in chat
- No routing to the right expertise
- Hallucinated field names or prices

With agent structure you get: dedicated **runbook**, **roles**, and **platform**.

---

## Slide 4 — Agentic Architecture

Three layers on the diagram: **User layer** → **Agentic layer** (Power User, four specialists, SPL catalog, executive synthesis) → **Splunk platform** (MCP → Enterprise).

*Speaker note:* Point at each box in the repo — nothing is hidden inside one mega-prompt. Full Mermaid: [`s4r-demo-slides.md`](s4r-demo-slides.md) slide 4.

---

## Slide 5 — Agents Artifacts defined

| Layer | File | Teaches |
| ----- | ---- | ------- |
| Runbook | `docs/S4R-SPL-CATALOG.md` | Canonical SPL — versioned like a playbook |
| Roles | `.cursor/agents/s4r-*.md` | Persona, output format, escalation |
| Bridge | `.cursor/mcp.json` | `npx mcp-remote` to Splunk MCP endpoint |

Orchestration design: `docs/S4R-AGENTS.md`

*Speaker note:* SPL is not duplicated in every agent file — agents reference the catalog.

---

## Slide 6 — Splunk MCP guardrails

Sequence diagram (User → Power User → Splunk MCP → `splunker`) beside identity table.

| Identity | Purpose |
| -------- | ------- |
| `splunker` | MCP searches (`mcp_tool_execute`) |
| Bearer token | Client auth — not in git |
| `splunk_run_query` | Primary demo tool |

*Speaker note:* Read-only demo discipline; token minted at `make up`. Cursor spawns `npx mcp-remote` over HTTPS as `splunker`, not admin.

---

## Slide 7 — Two workshop data modes

Diagram: baseline traffic vs NK attack sample → infrastructure story vs active threat story; `make s4r-attack-nk-disable` / `make s4r-attack-nk-enable`.

| Mode | Command | Security sees |
| ---- | ------- | ------------- |
| Infrastructure | `make s4r-attack-nk-disable` | Flat geo |
| Active threat | `make s4r-attack-nk-enable` + `make restart` | Pyongyang tops failed purchases |

Search **last 15m** after enabling threat mode.

*Speaker note:* Show **before Demo 1** — default mode is infrastructure (~40% 503/404 everywhere).

---

## Slide 8 — Demo 1 - Infrastructure story

**Ask Cursor (act as Power User):**

> *As Buttercup Power User: is the shop losing money? Delegate to all four teams.*

**Watch for:**

1. Delegation to four specialists (parallel or sequential)
2. Tool calls: `splunk_run_query`
3. SPL from catalog sections — not invented
4. One synthesis table — not four SPL dumps

*Speaker note:* If slow, call one team first: IT Ops only from catalog § IT Ops.

---

## Slide 9 — Demo 1 — delegation flow

Power User → four teams → synthesis.

**Expected answer (default mode):**

> Yes, losing money — bad web tier, not mobile or one geo.

---

## Slide 10 — Buttercup Insights

**Business impact:** ~40% purchase failure; $ lost from failed checkouts

| Team | Finding | Severity |
|------|---------|----------|
| IT Ops | 503/404 dominate | Critical |
| DevOps | Flat ~40% all platforms | High, escalate IT Ops |
| Business Analytics | Revenue lost via lookup | Critical |
| Security | No geo concentration | Low |

**Root-cause hypothesis:** Server-side failure, not fraud

*Speaker note:* Numbers come from **live MCP** — do not read fixed amounts from slides.

---

## Slide 11 — Demo 2 - NK attack

**Ask Cursor:**

> *As Buttercup Power User: is the money loss due to bad infrastructure or an active threat? Delegate to all four teams. Use the last 15 minutes.*

**Terminal (before ask):**

```bash
make s4r-attack-nk-enable
make restart
# wait ~2 minutes
make s4r-attack-nk-status    # enabled
```

**Expected shift:** Security and Fraud leads — NK; IT Ops still sees 503/404 from baseline.

*Speaker note:* Verdict: mixed — infrastructure still broken, but Security has a lead. Cleanup: `make s4r-attack-nk-disable && make restart`.

---

## Slide 12 — Dashboard tie-in — Lab 7

| Lab | Panel | Catalog section |
| --- | ----- | ----------------- |
| 3 | Stacked column — status | IT Ops |
| 4 | Bar + area — platform / UA | DevOps |
| 5 | Lost revenue | Business Analytics |
| 6 | Geo map | Security and Fraud |
| 7 | One canvas + background | Power User |

Build spec: [S4R-DASHBOARD.md](../docs/S4R-DASHBOARD.md)

*Speaker note:* Agents narrate; dashboard pins the SPL for production.

---

## Slide 13 — Takeaways

1. **Splunk MCP** — LLM calls your instance with **roles and capabilities**, not admin password in chat.
2. **SPL catalog** — single runbook; agents stay thin and teachable.
3. **Power User** — routes, delegates, **synthesizes** — mirrors real SOC / platform team lead.
4. **Same orchestration, different data** — infrastructure vs threat without rewriting prompts.

**Repo:** `splunk-mcp` · `make up` · presenter guide: `demo-slides/S4R-DEMO.md` (this file)

**Does not replace:** Production architecture, Splunk Cloud specifics, full security review.

---

## Slide 14 — Thank You

Closing slide (`lead-hero` styling). No additional script required.

---

## Slides 15–19 — Appendix

| Slide | Content |
| ----- | ------- |
| 15 | Before you start — `make demo-prep`, checks, warm-stack reminder |
| 16 | Copy-paste prompts (short versions for Demo 1 and Demo 2) |
| 17 | Troubleshooting table — MCP, events, NK mode, concurrency, token |
| 18 | Business use cases (1 of 2) — checkout, merchandising, mobile vs platform |
| 19 | Business use cases (2 of 2) — international, fraud vs reliability; Demo 1 / 2 callout |

Expanded presenter detail for appendix topics: [Before you start](#before-you-start-5-minutes-earlier), [Backup & troubleshooting](#backup--troubleshooting), [Copy-paste prompts](#copy-paste-prompts-chat), [Business use cases (copy-paste)](#business-use-cases-copy-paste).

---

## Slide 18 — Appendix — Business use cases (1 of 2)

Executive questions on the same Buttercup web logs — stakeholder framing, not status-code trivia.

| Use case | Ask the Power User |
| -------- | ------------------ |
| Checkout vs funnel | *Are we losing sales because checkout is failing, or because customers never get to purchase?* |
| Merchandising priority | *Which products and categories are costing us the most in failed checkout revenue?* |
| Mobile vs platform | *Should we invest in mobile app fixes, or is checkout failing every platform equally?* |

*Speaker note:* Same pattern for all use cases: Power User delegates to four teams, catalog SPL, MCP only.

---

## Slide 19 — Appendix — Business use cases (2 of 2)

| Use case | Ask the Power User |
| -------- | ------------------ |
| International growth | *Is checkout failing more for international customers than for US shoppers?* |
| Fraud vs reliability | *Is the revenue impact from an active attack, or from a broken checkout service?* |

**Workshop demos:** [Demo 1](#slide-8--demo-1---infrastructure-story) uses the classic lost-revenue ask; [Demo 2](#slide-11--demo-2---nk-attack) maps to fraud vs infrastructure (NK mode, last 15m).

*Speaker note:* Optional reference — skip in the main 20-minute track. Attendees can swap questions without changing agents or runbook.

Expanded prompts: [Business use cases (copy-paste)](#business-use-cases-copy-paste).

---

## Presenter script (20 minutes)

Timings are approximate. Adjust for audience questions.

### 0:00 — Hook (1 min)

**Say:** *“You built four dashboard panels for four teams. Here’s how an AI assistant can mirror that workflow — using Splunk MCP so answers come from live data, not from the model’s memory.”*

**Show:** Slide 2–3.

---

### 0:01 — Show the files (3 min)

**Do:** Open four editor tabs:

1. `docs/S4R-SPL-CATALOG.md` — scroll to § IT Ops
2. `.cursor/agents/s4r-it-ops.md` — short role file
3. `.cursor/agents/s4r-power-user.md` — delegation table
4. `.cursor/mcp.json` — splunk server entry (blur token if screen-sharing)

**Say:** *“Runbook, role, orchestrator, MCP config — four artifacts your team can own in git.”*

**Show:** Slides 4–5.

---

### 0:04 — MCP in one sentence (1 min)

**Say:** *“Cursor spawns `npx mcp-remote`, which speaks HTTPS to Splunk’s MCP endpoint. Searches run as `splunker`, not as admin.”*

**Show:** Slide 6 (sequence diagram). Then **Slide 7** — infrastructure vs threat data modes (default = infrastructure).

Optional: `make verify-mcp-remote MCP_VERIFY_CLIENT=cursor` in terminal (fast).

---

### 0:05 — Demo 1 live (6 min)

**Do:** Cursor chat — paste [Demo 1 prompt](#slide-8--demo-1---infrastructure-story).

**Narrate while it runs:**

- *“Power User is delegating…”*
- *“There’s `splunk_run_query` — that’s SPL from the catalog.”*
- *“IT Ops owns status codes; Business owns lookup revenue.”*

**If delegation is slow:** Call out one team only first: *“IT Ops only — success vs failure from catalog § IT Ops.”*

**Show:** Slides 9–10 when synthesis appears (delegation flow + Buttercup Insights).

**Fallback if MCP fails:** Run one search in Splunk Web from catalog § IT Ops; explain MCP would return the same JSON.

---

### 0:11 — Bridge to threat storyline (1 min)

**Say:** *“Same agents, same catalog. We flip synthetic data mode to simulate an active threat — no prompt rewrite.”*

**Show:** Slide 7 again (or narrate from memory — enable NK mode). Optional: **Slides 18–19** (appendix) — alternate business questions if audience asks.

---

### 0:12 — Demo 2 live (5 min)

**Do:** Terminal — [Demo 2 commands](#slide-11--demo-2---nk-attack). Wait for events (~2 min can overlap with talking).

**Do:** Cursor — Demo 2 prompt (**last 15 minutes**).

**Narrate:** *“Security should surface North Korea on failed purchases; DevOps should see scripted user agents; IT Ops still sees 503 from baseline traffic.”*

**Say:** *“Verdict: mixed — infrastructure still broken, but Security has a lead for investigation.”*

---

### 0:17 — Dashboard + workshop (2 min)

**Show:** Slide 12. Optional: Splunk Web sample search or future dashboard.

**Say:** *“Labs 3–7 built the panels; this agent stack builds the **story** for executives.”*

---

### 0:19 — Close (1 min)

**Show:** Slides 13–14 (takeaways, thank you).

**Say:** *“Take the pattern: catalog + roles + MCP. Your SPL stays authoritative in Splunk and git.”*

**Cleanup:** `make s4r-attack-nk-disable && make restart`

---

## Short track (10 minutes)

| Time | Action |
| ---- | ------ |
| 0:00 | Slides 2, 4, 5, 7 (scenario + architecture + data modes) |
| 0:02 | Demo 1 prompt only — skip parallel narration detail |
| 0:07 | Slide 7 + Demo 2 **or** skip Demo 2 if low on time |
| 0:09 | Slides 13–14 takeaways + thank you |

Skip: `make verify-mcp-remote` live, dashboard slide detail, second terminal restart.

---

## Backup & troubleshooting

On-screen table: **deck slide 17**. Expanded detail below for presenters.

| Problem | Presenter action |
| ------- | ---------------- |
| MCP tools missing | `make update-cursor-config`; restart Cursor |
| No events | `make status`; `docker logs splunk-init` |
| NK mode no signal | `make s4r-attack-nk-status`; `make restart`; search **last 15m** |
| Concurrency limit | Wait; run one team at a time |
| Token / 401 | `make up` or `make update-mcp-client MCP_CLIENT=cursor` |

Details: [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) · [SA-S4R-APP.md](../docs/SA-S4R-APP.md) (NK troubleshooting table)

---

## Optional: Splunk Web validation (audience double-check)

Run in Search & Reporting (same SPL as agents):

```spl
index=main sourcetype=access_combined action=purchase status>=400
| lookup product_codes.csv product_id
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

Short on-slide versions: **deck slide 16**. Long-form prompts for live demos:

**Demo 1:**

```text
As Buttercup Power User for Splunk4Rookies: is the shop losing money?
Delegate to IT Ops, DevOps, Business Analytics, and Security & Fraud.
Read docs/S4R-SPL-CATALOG.md for SPL. Splunk MCP only — splunk_run_query; never Splunk REST or curl for searches.
Synthesize one executive answer with the Power User template.
```

**Demo 2:**

```text
As Buttercup Power User: is the money loss bad infrastructure or an active threat?
Check make s4r-attack-nk-status. Delegate to all four teams.
Use docs/S4R-SPL-CATALOG.md including § Workshop modes. Splunk MCP only — no REST/curl for searches. Time range: last 15 minutes.
Synthesize with clear verdict and recommended actions.
```

**Single-team deep dive (fill-in):**

```text
You are the S4R [IT Ops|DevOps|Business Analytics|Security & Fraud] agent.
Read .cursor/agents/s4r-[team].md and docs/S4R-SPL-CATALOG.md § [section].
Run searches via splunk_run_query (MCP only — no REST/curl). Return only that team's summary.
```

---

## Business use cases (copy-paste)

Same delegation pattern as Demo 1 unless noted. Infrastructure mode, **last 24 hours**, unless Demo 2 / fraud ask.

**Checkout vs funnel:**

```text
As Buttercup Power User: are we losing sales because checkout is failing, or because customers never get to purchase?
Delegate to all four teams. Read docs/S4R-SPL-CATALOG.md per team. Splunk MCP only — splunk_run_query; never REST or curl.
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
