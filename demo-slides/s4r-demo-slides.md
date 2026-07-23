---
marp: true
theme: splunk
paginate: true
html: true
footer: '![w:46](https://www.splunk.com/content/dam/splunk2/en_us/images/icon-library/footer/logo-splunk-corp-rgb-w-web.svg)'
---

<script type="module">
  import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs';
  mermaid.initialize({
    startOnLoad: false,
    theme: 'dark',
    securityLevel: 'loose',
    flowchart: { htmlLabels: true, wrap: true, padding: 14, nodeSpacing: 45, rankSpacing: 55 },
    sequence: { diagramMarginX: 12, diagramMarginY: 12, boxMargin: 8 },
    themeVariables: {
      fontSize: '14px',
      fontFamily: "'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
    },
  });
  const renderMermaid = async () => {
    const nodes = document.querySelectorAll('.mermaid:not([data-processed])');
    if (nodes.length) await mermaid.run({ nodes });
  };
  document.addEventListener('DOMContentLoaded', renderMermaid);
  window.addEventListener('load', renderMermaid);
</script>

<!-- _class: lead lead-hero -->

# Splunk4Rookies<br>From dashboards to agentic analysis

<br>

Buttercup Enterprises workshop PoC · one dataset · three ways to use Splunk MCP

Live data via **Splunk MCP** — not pasted into the model

---

# Three ways this repo helps

| Step | Who | What you do |
| ---- | --- | ----------- |
| **1 — Workshop** | Builder / analyst | Describe dashboards in **plain natural language** — Labs 3–7 in the S4R Workshop |
| **2 — Business user** | Stakeholder | Ask **business questions** in chat — no SPL knowledge required |
| **3 — Agentic** | Platform / SOC lead | An **orchestrator** delegates to specialists and synthesizes an executive answer |

```text
Build (Step 1)  →  Ask (Step 2)  →  Orchestrate (Step 3)
```

Same Buttercup data, same SPL catalog — increasing structure as you go deeper.

<!--
This deck follows that sequence. Step 1 = dashboard build. Step 2 = single natural-language question via MCP. Step 3 = Power User + four specialists + executive synthesis.
-->

---

# Scenario — Buttercup Enterprises

**US online retailer** (books, clothing, gifts)

| Stakeholder | Cares about |
| ----------- | ----------- |
| IT Operations | Uptime, HTTP errors |
| DevOps | Browsers, OS, releases |
| Business Analytics | Lost revenue |
| Security and Fraud | Who, from where |

**Data:** `index=main sourcetype=access_combined` (SA-S4R Eventgen)

<!--
Pattern demo, not a product pitch. Splunk stays source of truth; the assistant calls governed tools. Same logs as Labs 3–7 dashboard build.
-->

---

<!-- _class: lead -->

# Step 1 — Build dashboards<br>with natural language

S4R Workshop · Labs 3–7 · Dashboard Studio

---

# Step 1 — Workshop dashboard build

Use an LLM in Cursor (or Claude Desktop) to create the **Splunk4Rookies** dashboard from the workshop spec — **no manual SPL hunting**.

**Example prompt:**

> *Build the Buttercup Enterprises dashboard per `docs/S4R-DASHBOARD.md` — four team panels on one Absolute-layout canvas with the marketing background.*

| Lab | Panel | Catalog section |
| --- | ----- | ----------------- |
| 3 | Stacked column — status | IT Ops |
| 4 | Bar + area — platform / UA | DevOps |
| 5 | Lost revenue | Business Analytics |
| 6 | Geo map | Security and Fraud |
| 7 | One canvas + background | Power User |

Build spec: `docs/S4R-DASHBOARD.md` · canonical SPL: `docs/S4R-SPL-CATALOG.md`

<!--
The catalog is the runbook — the LLM reads layout from S4R-DASHBOARD.md and SPL from the catalog, not from memory. Same panels the agentic demo narrates later.
-->

---

# Step 1 — What you get

**One Dashboard Studio canvas** — four stakeholder panels + branded background, all on the **global time picker**.

| Artifact | Role |
| -------- | ---- |
| `docs/S4R-DASHBOARD.md` | Layout, viz types, acceptance criteria |
| `docs/S4R-SPL-CATALOG.md` | Versioned SPL — single source of truth |
| `SA-S4R` app | Eventgen data, lookups, static assets |

Workshop hub: `docs/s4r/README.md`

<!--
After the workshop, attendees have a pinned dashboard. Steps 2 and 3 show how the same questions move into chat — with and without multi-agent structure.
-->

---

<!-- _class: lead -->

# Step 2 — Ask business questions<br>without SPL

End-user mode · Splunk MCP · no query language

---

# Step 2 — Business questions in plain English

Stakeholders ask **outcome questions** — the assistant runs governed searches and returns a narrative answer.

**Examples:**

> *Is my website losing money?*

> *Are we losing sales because checkout is failing, or because customers never reach purchase?*

> *Which product categories cost us the most in failed checkout revenue?*

No SPL in the prompt. The model reads `docs/S4R-SPL-CATALOG.md` and calls **`splunk_run_query`** via Splunk MCP.

<!--
Step 2 can be a single assistant — no delegation required. Good for executives and workshop attendees who finished the dashboard and want answers, not panels.
-->

---

# Splunk MCP guardrails

<!-- _class: diagram diagram-split -->

<div class="diagram-table-row">

<pre class="mermaid">
sequenceDiagram
  participant U as User
  participant A as Assistant
  participant MCP as Splunk MCP
  participant S as splunker
  U->>A: Natural language question
  A->>A: Read SPL catalog section
  A->>MCP: splunk_run_query
  MCP->>S: REST search
  S-->>MCP: JSON results
  MCP-->>A: Rows and aggregates
  A-->>U: Business answer
</pre>

<div class="diagram-table-col">

| Identity | Purpose |
| -------- | ------- |
| `splunker` | MCP searches (`mcp_tool_execute`) |
| Bearer token | Client auth — not in git |
| `splunk_run_query` | Primary demo tool |

</div>
</div>

<!--
Read-only demo discipline; token minted at make up. Cursor spawns npx mcp-remote over HTTPS as splunker, not admin. Steps 2 and 3 both use this bridge — Step 3 adds agent roles on top.
-->

---

# Step 2 — Live demo prompt

**Ask Cursor (no agent delegation):**

> *Using the Buttercup SPL catalog: is the website losing money? Summarize business impact from failed purchases.*

**Watch for:**

1. Catalog-backed SPL — not invented field names or prices
2. Tool call: `splunk_run_query`
3. Plain-language answer — revenue and failure rate, not a query dump

**Expected (infrastructure mode):** Yes — high purchase failure; lost revenue from failed checkouts.

<!--
Default data mode = infrastructure (~40% 503/404 everywhere). This is the lightweight path before introducing the orchestrator in Step 3.
-->

---

<!-- _class: lead -->

# Step 3 — Agentic orchestration<br>for specialists

Power User · four teams · executive synthesis

---

# The challenge

```text
One set of web logs  →  four different questions  →  one executive answer
```

Without agent structure you get:

- Four disconnected SPL walls in chat
- No routing to the right expertise
- Hallucinated field names or prices

With agent structure you get: dedicated <span class="splunk-orange">runbook</span>, <span class="splunk-orange">roles</span>, and <span class="splunk-orange">platform</span>

<!--
Step 3 is for builders who want teachable, git-owned personas — mirrors how real platform teams delegate.
-->

---

<!-- _class: diagram -->

# Agentic Architecture

<pre class="mermaid">
flowchart TB
  subgraph USER["User layer"]
    Q["User prompt: Is the shop losing money?"]
  end
  subgraph AGENTIC["Agentic layer"]
    PU["Splunk Power User"]
    IT["IT Ops"]
    DO["DevOps"]
    BA["Business Analytics"]
    SF["Security and Fraud"]
    CAT["SPL catalog"]
    EXEC["Executive synthesis"]
  end
  subgraph SPLUNK["Splunk platform"]
    MCP["Splunk MCP"]
    SPL["Splunk Enterprise"]
  end
  Q --> PU
  PU --> IT
  PU --> DO
  PU --> BA
  PU --> SF
  IT --> CAT
  DO --> CAT
  BA --> CAT
  SF --> CAT
  IT --> MCP
  DO --> MCP
  BA --> MCP
  SF --> MCP
  MCP --> SPL
  IT --> PU
  DO --> PU
  BA --> PU
  SF --> PU
  PU --> EXEC
</pre>

<!--
Point at each box in the repo — nothing is hidden inside one mega-prompt. Power User = orchestrator; Executive synthesis = final stakeholder table.
-->

---

# Agents Artifacts defined

| Layer | File | Teaches |
| ----- | ---- | ------- |
| Runbook | `docs/S4R-SPL-CATALOG.md` | Canonical SPL — versioned like a playbook |
| Roles | `.cursor/agents/s4r-*.md` | Persona, output format, escalation |
| Bridge | `.cursor/mcp.json` | `npx mcp-remote` to Splunk MCP endpoint |

Orchestration design: `docs/S4R-AGENTS.md`

<!--
SPL is not duplicated in every agent file — agents reference the catalog. Same catalog Steps 1 and 2 already used.
-->

---

# Two workshop data modes

<!-- _class: diagram diagram-split diagram-split-equal -->

<div class="diagram-table-row">

<pre class="mermaid">
flowchart TB
  BASE["Baseline traffic"]
  NK["NK attack sample"]
  M1["Infrastructure story"]
  M2["Active threat story"]
  C1["make s4r-attack-nk-disable"]
  C2["make s4r-attack-nk-enable"]
  BASE --> M1
  BASE --> NK
  NK --> M2
  M1 --- C1
  M2 --- C2
  classDef shell fill:#0d0d0d,stroke:#333,color:#00B3F0
  class C1,C2 shell
</pre>

<div class="diagram-table-col">

| Mode | Command | Security sees |
| ---- | ------- | ------------- |
| Infrastructure | `make s4r-attack-nk-disable` | Flat geo |
| Active threat | `make s4r-attack-nk-enable` + `make restart` | Pyongyang tops failed purchases |

</div>
</div>

<br>

Search **last 15m** after enabling threat mode.

---

# Step 3 — Demo 1: Infrastructure story

**Ask Cursor (act as Power User):**

> *As Buttercup Power User: is the shop losing money? Delegate to all four teams.*

**Watch for:**

1. Delegation to four specialists (parallel or sequential)
2. Tool calls: `splunk_run_query`
3. SPL from catalog sections — not invented
4. One synthesis table — not four SPL dumps

<!--
Default data mode = infrastructure (~40% 503/404 everywhere). If slow, call one team first: IT Ops only from catalog IT Ops section.
-->

---

<!-- _class: diagram -->

# Step 3 — delegation flow

<pre class="mermaid">
flowchart TB
  P1["Power User"]
  T1["IT Ops"]
  T2["DevOps"]
  T3["Business Analytics"]
  T4["Security"]
  SYN1["Executive synthesis"]
  P1 --> T1
  P1 --> T2
  P1 --> T3
  P1 --> T4
  T1 --> SYN1
  T2 --> SYN1
  T3 --> SYN1
  T4 --> SYN1
</pre>

**Expected answer (default mode):**

> Yes, losing money — bad web tier, not mobile or one geo.

---

# Buttercup Insights

**Business impact:** ~40% purchase failure; $ lost from failed checkouts

<br>

| Team | Finding | Severity |
|------|---------|----------|
| IT Ops | 503/404 dominate | Critical |
| DevOps | Flat ~40% all platforms | High, escalate IT Ops |
| Business Analytics | Revenue lost via lookup | Critical |
| Security | No geo concentration | Low |

**Root-cause hypothesis:** Server-side failure, not fraud

<!--
Numbers come from live MCP — do not read fixed amounts from slides. Step 2 gave one answer; Step 3 shows how each team contributed.
-->

---

# Additional Business questions (1 of 2)

| Use case | Ask |
| -------- | --- |
| Checkout vs funnel | *Are we losing sales because checkout is failing, or because customers never get to purchase?* |
| Merchandising priority | *Which products and categories are costing us the most in failed checkout revenue?* |
| Mobile vs platform | *Should we invest in mobile app fixes, or is checkout failing every platform equally?* |

<!--
Step 2: ask directly. Step 3: prefix with As Buttercup Power User and delegate to all four teams.
-->

---

# Additional Business questions (2 of 2)

| Use case | Ask |
| -------- | --- |
| International growth | *Is checkout failing more for international customers than for US shoppers?* |
| Fraud vs reliability | *Is the revenue impact from an active attack, or from a broken checkout service?* |

<!--
Use case 5 / Demo 2: make s4r-attack-nk-enable before ask. Attendees can swap questions without changing agents or runbook.
-->

---

# Step 3 — Demo 2: North Korea attack

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

<!--
Verdict: mixed — infrastructure still broken, but Security has a lead. Cleanup after demo: make s4r-attack-nk-disable and make restart.
-->

---

# Takeaways

1. **Step 1 — Workshop:** Natural language builds the **S4R dashboard** from `S4R-DASHBOARD.md` + SPL catalog.
2. **Step 2 — Business user:** Ask **outcome questions**; Splunk MCP returns live answers — no SPL required.
3. **Step 3 — Agentic:** **Power User** orchestrates IT Ops, DevOps, Business Analytics, Security and Fraud → **executive synthesis**.
4. **Same data, same catalog** — infrastructure vs threat modes without rewriting prompts.

**Repo:** `splunk-mcp` · `make up` · presenter guide: `demo-slides/S4R-DEMO.md`

**Does not replace:** Production architecture, Splunk Cloud specifics, full security review.

---

<!-- _class: lead lead-hero -->

# Thank You

---

# Appendix — before you start

```bash
make demo-prep
make s4r-attack-nk-status    # expect: disabled
```

| Check | Action |
| ----- | ------ |
| Splunk Web | `https://localhost:8000` |
| MCP in Cursor | Restart Cursor; Splunk MCP tools visible |
| Data flowing | `index=main sourcetype=access_combined \| head 5` |

**Warm stack:** start Splunk before the session (`make up` can take many minutes).

---

<!-- _class: compact -->

# Appendix — copy-paste prompts

**Step 1 — Dashboard build:**

> *Build the Buttercup Enterprises dashboard per `docs/S4R-DASHBOARD.md` — four team panels on one Absolute-layout canvas.*

**Step 2 — Business question:**

> *Using the Buttercup SPL catalog: is the website losing money? Summarize business impact from failed purchases.*

**Step 3 — Demo 1 (orchestrator):**

> *As Buttercup Power User: is the shop losing money? Delegate to all four teams.*

**Step 3 — Demo 2 (threat):**

> *As Buttercup Power User: is the money loss due to bad infrastructure or an active threat? Delegate to all four teams. Use the last 15 minutes.*

---

# Appendix — troubleshooting

| Problem | Presenter action |
| ------- | ---------------- |
| MCP tools missing | `make update-cursor-config`; restart Cursor |
| No events | `make status`; `docker logs splunk-init` |
| NK mode no signal | `make s4r-attack-nk-status`; `make restart`; search **last 15m** |
| Concurrency limit | Wait; run one team at a time |
| Token / 401 | `make up` or `make update-mcp-client MCP_CLIENT=cursor` |

Details: `docs/TROUBLESHOOTING.md` · `docs/SA-S4R-APP.md`
