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

# Splunk4Rookies<br>Agentic analysis with Splunk MCP

<br>

Buttercup Enterprises workshop PoC · One dataset · four teams · one orchestrator

Live data via **Splunk MCP** — not pasted into the model

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

# The challenge

```text
One set of web logs  →  four different questions  →  one executive answer
```

Without agent structure you get:

- Four disconnected SPL walls in chat
- No routing to the right expertise
- Hallucinated field names or prices

With agent structure you get: dedicated <span class="splunk-orange">runbook</span>, <span class="splunk-orange">roles</span>, and <span class="splunk-orange">platform</span>

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
Point at each box in the repo — nothing is hidden inside one mega-prompt.
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
SPL is not duplicated in every agent file — agents reference the catalog.
-->

---

# Splunk MCP guardrails

<!-- _class: diagram diagram-split -->

<div class="diagram-table-row">

<pre class="mermaid">
sequenceDiagram
  participant U as User
  participant PU as Power User
  participant MCP as Splunk MCP
  participant S as splunker
  U->>PU: Natural language question
  PU->>PU: Read SPL catalog section
  PU->>MCP: splunk_run_query
  MCP->>S: REST search
  S-->>MCP: JSON results
  MCP-->>PU: Rows and aggregates
  PU-->>U: Team summary
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
Read-only demo discipline; token minted at make up. Cursor spawns npx mcp-remote over HTTPS as splunker, not admin.
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

# Demo 1 - Infrastructure story

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

# Demo 1 — delegation flow

<pre class="mermaid">
flowchart TB
  P1["Power User"]
  T1["IT Ops"]
  T2["DevOps"]
  T3["Business Analytics"]
  T4["Security"]
  SYN1["Synthesis"]
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
Numbers come from live MCP — do not read fixed amounts from slides.
-->

---

# Demo 2 - NK attack

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

# Dashboard tie-in — Lab 7

| Lab | Panel | Catalog section |
| --- | ----- | ----------------- |
| 3 | Stacked column — status | IT Ops |
| 4 | Bar + area — platform / UA | DevOps |
| 5 | Lost revenue | Business Analytics |
| 6 | Geo map | Security and Fraud |
| 7 | One canvas + background | Power User |

Build spec: `docs/S4R-DASHBOARD.md`

<!--
Agents narrate; dashboard pins the SPL for production.
-->

---

# Takeaways

1. **Splunk MCP** — LLM calls your instance with **roles and capabilities**, not admin password in chat.
2. **SPL catalog** — single runbook; agents stay thin and teachable.
3. **Power User** — routes, delegates, **synthesizes** — mirrors real SOC / platform team lead.
4. **Same orchestration, different data** — infrastructure vs threat without rewriting prompts.

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

# Appendix — copy-paste prompts

**Demo 1:**

> *As Buttercup Power User: is the shop losing money? Delegate to all four teams.*

**Demo 2:**

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

---

# Appendix — Business use cases (1 of 2)

Executive questions on the same `access_combined` data — not basic HTTP troubleshooting.

| Use case | Ask the Power User |
| -------- | ------------------ |
| Checkout vs funnel | *Are we losing sales because checkout is failing, or because customers never get to purchase?* |
| Merchandising priority | *Which products and categories are costing us the most in failed checkout revenue?* |
| Mobile vs platform | *Should we invest in mobile app fixes, or is checkout failing every platform equally?* |

<!--
Same orchestration as Demo 1: delegate to four teams, read S4R-SPL-CATALOG.md, MCP splunk_run_query only. Infrastructure mode, last 24h. Full prompts: demo-slides/S4R-DEMO.md § Business use cases.
-->

---

# Appendix — Business use cases (2 of 2)

| Use case | Ask the Power User |
| -------- | ------------------ |
| International growth | *Is checkout failing more for international customers than for US shoppers?* |
| Fraud vs reliability | *Is the revenue impact from an active attack, or from a broken checkout service?* |

**Workshop demos:** *Demo 1* — lost revenue · *Demo 2* — fraud vs infrastructure (NK mode, **last 15m**)

<!--
Use case 5 / Demo 2: make s4r-attack-nk-enable before ask. Attendees can swap questions without changing agents or runbook.
-->
