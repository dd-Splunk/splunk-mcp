# Splunk4Rookies agentic setup (Buttercup Enterprises)

Agent roles for the **Splunk4Rookies** attendee workshop (Apr 2026 deck) and this repo’s **`SA-S4R`** dataset. One **Splunk Power User** orchestrator delegates to four specialist agents; each maps to a dashboard panel in Labs 3–7.

**Related docs:** [What Does the Business Want to See.md](What%20Does%20the%20Business%20Want%20to%20See.md) (dashboard build spec), [SA-S4R-APP.md](SA-S4R-APP.md) (data and lookups), [`.cursor/agents/`](../.cursor/agents/) (copy-paste prompts for Cursor Task subagents).

## Scenario

**Buttercup Enterprises** is a US online retailer (books, clothing, gifts). You are the internal **Splunk power user** who provides insights to:

- IT Operations
- DevOps
- Business Analytics
- Security and Fraud

**Data scope (all agents):**

```spl
index=main sourcetype=access_combined
```

Eventgen in **`SA-S4R`** emits workshop-shaped Apache access logs (`/product.screen`, `/cart.do`). Lookup **`product_codes.csv`** maps `product_id` → `product_price`. Dashboards use a persistent **`platform`** field (Lab 4); **agents** may extract it **inline in SPL** with `rex` when the field is not indexed.

## Architecture

```text
Stakeholder question
        │
        ▼
┌───────────────────────┐
│  Splunk Power User    │  route · synthesize · executive narrative
└───────────┬───────────┘
            │ delegate (parallel when needed)
    ┌───────┼───────┬───────────┐
    ▼       ▼       ▼           ▼
 IT Ops  DevOps  Business    Security
         Analytics   & Fraud
            │       │           │
            └───────┴───────────┘
                    ▼
         Splunk MCP (splunk_run_query, saia_*)
         Vellem (workshop memory, no secrets)
```

## Splunk Power User (orchestrator)

**Mission:** Understand the ask, delegate to the right specialist(s), run searches via Splunk MCP, synthesize one business-facing insight.

**Delegate when:**

| Topic | Agent |
| ----- | ----- |
| HTTP errors, success vs failure, server health | IT Ops |
| OS, browsers, mobile testing, UA failures | DevOps |
| Revenue, purchases, lookups, lost sales | Business Analytics |
| Geography, fraud indicators, IP patterns | Security & Fraud |
| Full dashboard / executive summary | All four |

**Synthesis template:**

```markdown
## Buttercup insight — [time range]

**Question:** …
**Business impact:** …

| Team | Finding | Severity |
|------|---------|----------|
| IT Ops | … | … |
| DevOps | … | … |
| Business Analytics | … | … |
| Security & Fraud | … | … |

**Root-cause hypothesis:** …
**Recommended actions:** …
```

**Guardrails:** Read-only SPL in demos; no secrets in output; use MCP user `splunker` scope; escalate config tasks (field extract, lookup) explicitly.

**Prompt file:** [`.cursor/agents/s4r-power-user.md`](../.cursor/agents/s4r-power-user.md)

---

## IT Ops agent

**Ask (Lab 3):** Successful vs unsuccessful web server requests over time.

| Panel | Visualization | Canonical SPL |
| ----- | ------------- | ------------- |
| Success vs failure | Stacked column | `index=main sourcetype=access_combined \| timechart count by status limit=10` |

**Drill-down:**

```spl
index=main sourcetype=access_combined status>=400
| stats count by uri
| sort - count
| head 20
```

**Escalate:** UA-specific failures → DevOps; purchase-only failures → Business Analytics; geo clusters → Security.

**Prompt file:** [`.cursor/agents/s4r-it-ops.md`](../.cursor/agents/s4r-it-ops.md)

---

## DevOps agent

**Ask (Lab 4):** Most common operating systems; browsers with the most failures; **client-specific vs server-wide** failure pattern.

**`platform` field:** If not indexed, report it and prepend inline `rex` (do not stop). Full workflow and queries: [`.cursor/agents/s4r-devops.md`](../.cursor/agents/s4r-devops.md).

| Panel | Visualization | Canonical SPL |
| ----- | ------------- | ------------- |
| Top OS | Bar chart | `index=main sourcetype=access_combined` + platform prefix + `\| top limit=20 platform showperc=f` |
| Failing browsers | Area chart | `index=main sourcetype=access_combined status>=400 \| timechart count by useragent limit=5 useother=f` |
| Failure rate by OS | Table / verdict | platform prefix + `stats` by `platform`, `outcome` — see DevOps agent query 3 |

**Escalate:** Flat failure rate across platforms → IT Ops; purchase-only failures → Business Analytics.

**Prompt file:** [`.cursor/agents/s4r-devops.md`](../.cursor/agents/s4r-devops.md)

---

## Business Analytics agent

**Ask (Lab 5):** Lost revenue from failed purchases on the website.

| Panel | Visualization | Canonical SPL |
| ----- | ------------- | ------------- |
| Lost revenue | Single value / timechart | `index=main sourcetype=access_combined action=purchase status>=400 \| lookup product_codes.csv product_id \| timechart sum(product_price)` |

**Total headline:**

```spl
index=main sourcetype=access_combined action=purchase status>=400
| lookup product_codes.csv product_id
| stats sum(product_price) as lost_revenue
```

**Escalate:** Missing lookup → config; global 503 → IT Ops.

**Prompt file:** [`.cursor/agents/s4r-business-analytics.md`](../.cursor/agents/s4r-business-analytics.md)

---

## Security & Fraud agent

**Ask (Lab 6):** Website activity by geographic location.

| Panel | Visualization | Canonical SPL |
| ----- | ------------- | ------------- |
| Activity by city | Cluster map | `index=main sourcetype=access_combined \| iplocation clientip \| geostats count by City` |

**Drill-down (failed purchases by geo):**

```spl
index=main sourcetype=access_combined action=purchase status>=400
| iplocation clientip
| geostats count by City
```

**Escalate:** Product-specific fraud pattern → Business Analytics; UA bot pattern → DevOps.

**Prompt file:** [`.cursor/agents/s4r-security-fraud.md`](../.cursor/agents/s4r-security-fraud.md)

---

## Workshop ↔ agent ↔ panel matrix

| Lab | Team | Agent | Canonical SPL (short) |
| --- | ---- | ----- | --------------------- |
| 3 | IT Ops | IT Ops | `timechart count by status` |
| 4 | DevOps | DevOps | `top platform`; `timechart by useragent` where `status>=400` |
| 5 | Business Analytics | Business Analytics | `lookup product_codes.csv` + `sum(product_price)` |
| 6 | Security & Fraud | Security & Fraud | `iplocation clientip` + `geostats count by City` |
| 7 | Power User | Power User | Unified dashboard + synthesis |

## Using agents in Cursor

1. Enable **splunk-mcp-server** and optionally **vellem** in `.cursor/mcp.json` (`make up` / `make update-cursor-config`).
2. For a Buttercup / S4R question, the main agent acts as **Power User** (see [`.cursor/rules/s4r-buttercup-agents.mdc`](../.cursor/rules/s4r-buttercup-agents.mdc)).
3. For heavy parallel work, launch **Task** subagents with prompts from [`.cursor/agents/`](../.cursor/agents/README.md).
4. Confirm data: `make status`, then `index=main | stats count by sourcetype`.
5. Presales check: `make demo-prep`.

## Example delegation

**User:** *“Is the shop losing money today — servers or mobile users?”*

1. **Power User** — set time range; confirm `main` has events.
2. **IT Ops** — `timechart count by status`.
3. **Business Analytics** — `lookup` + `sum(product_price)` on `action=purchase status>=400`.
4. **DevOps** — failures by `useragent` / `platform`.
5. **Security** — `geostats` on error events by city.
6. **Power User** — synthesize: capacity vs client vs geo narrative.

## References

- Splunk4Rookies attendee deck (Apr 2026) — Labs 3–7, slide 28–29 scenario
- [What Does the Business Want to See.md](What%20Does%20the%20Business%20Want%20to%20See.md)
- [SA-S4R-APP.md](SA-S4R-APP.md)
- [API_REFERENCE.md](API_REFERENCE.md) — Splunk MCP tools
