# Splunk4Rookies dashboard prompt

Use this document as the **dashboard layout spec** (visualization, layout, acceptance) for the Buttercup Enterprises workshop in **Splunk4Rookies** (`SA-S4R`). **Canonical SPL** lives in [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md). Data and Eventgen: [SA-S4R-APP.md](SA-S4R-APP.md). Agentic setup: [S4R-AGENTS.md](S4R-AGENTS.md) and [`.cursor/agents/`](../.cursor/agents/). Workshop hub: [s4r/README.md](s4r/README.md).

## Scenario

You are a Splunk power user for **Buttercup Enterprises**, a US online retailer (books, clothing, gifts). Teams need one **Dashboard Studio** dashboard ( **Absolute** layout ) that answers four stakeholder questions and uses the marketing background image.

**Goal:** Go from messy machine data to a single, story-telling dashboard—all panels on one canvas, linked to the **global time picker**.

## Data scope

| Item | Value |
| ---- | ----- |
| Index / sourcetype | `index=main sourcetype=access_combined` |
| Event shape | Apache-style access logs: `/product.screen?uid=…&product_id=…` and `/cart.do?action=…&product_id=…` |
| Fields in repo | `action`, `product_id`, `uid`, `JSESSIONID` (`SA-S4R/default/props.conf`) |
| Field to add (Lab 4) | **`platform`** — install with **`make s4r-dashboard-local`** (`local/props.conf` from **`local.example/`**) for saved dashboard panels; **agents/MCP** use inline `rex` in [S4R-SPL-CATALOG.md § Platform prefix](S4R-SPL-CATALOG.md#platform-prefix-lab-4--required-for-agents--mcp) |
| Lookup | `product_codes.csv` → `product_id`, `product_name`, `product_price` (`SA-S4R/lookups/`) |
| Background asset | `/static/app/SA-S4R/Buttercup_Background.jpg` (repo: `SA-S4R/appserver/static/Buttercup_Background.jpg`) |

Base search and field conventions: [S4R-SPL-CATALOG.md § Data contract](S4R-SPL-CATALOG.md#data-contract).

## Dashboard platform

- **Product:** Dashboard Studio (not Classic Simple XML).
- **Layout:** **Absolute** — allows placing panels over the background image.
- **Deliverable:** One dashboard in the **Splunk4Rookies** app with **five** visual areas (four team panels + branded layout).
- **Do not** use app-wide `application.css`; background is a **dashboard** image only.
- **Install path:** **`make s4r-dashboard-local`** → **`SA-S4R/local/`** only. **Do not** build or save this dashboard under **`SA-S4R/default/`** (Splunk best practice).

## Panels (build in lab order)

### 1. IT Operations — success vs failure over time (Lab 3)

**Ask:** Investigate successful versus unsuccessful web server requests over time.

| | |
| --- | --- |
| Visualization | Stacked column chart |
| SPL | [S4R-SPL-CATALOG.md § IT Ops — Panel](S4R-SPL-CATALOG.md#-it-ops-lab-3) |

Add this panel to a **new** dashboard; choose Dashboard Studio and Absolute layout.

### 2. DevOps — OS mix and failing browsers (Lab 4)

**Ask:** Show the most common customer operating systems and which web browsers experience the most failures.

**Prerequisite (dashboard):** Run **`make s4r-dashboard-local`** so **`platform`** is extracted in **`local/props.conf`** for saved panels (Lab 4). **Agent/ad-hoc SPL:** always use [platform prefix](S4R-SPL-CATALOG.md#platform-prefix-lab-4--required-for-agents--mcp) — do not assume the saved extraction applies to MCP searches.

| Panel | Visualization | SPL |
| ----- | ------------- | --- |
| Top operating systems | Bar chart | [§ DevOps — top OS](S4R-SPL-CATALOG.md#-devops-lab-4) |
| Top 5 failing browsers over time | Area chart | [§ DevOps — failing browsers](S4R-SPL-CATALOG.md#-devops-lab-4) |

Add both charts to the **same** dashboard as panel 1.

### 3. Business Analytics — lost revenue (Lab 5)

**Ask:** Show lost revenue from the Buttercup Enterprises website.

Failed purchases have `action=purchase` and HTTP error status. Enrich with lookup prices, then aggregate:

| | |
| --- | --- |
| Visualization | Single value (or time series — workshop uses timechart) |
| SPL | [§ Business Analytics — lost revenue over time](S4R-SPL-CATALOG.md#-business-analytics-lab-5) |

Lookup: `SA-S4R/lookups/product_codes.csv` (see catalog **Data contract**).

### 4. Security and Fraud — activity by geography (Lab 6)

**Ask:** Show website activity by geographic location.

| | |
| --- | --- |
| Visualization | World map (city-level activity) |
| SPL | [§ Security & Fraud — activity by city](S4R-SPL-CATALOG.md#-security--fraud-lab-6) |

Requires Splunk **`iplocation`** (GeoLite etc.).

### 5. Buttercup Enterprises — branded layout (Lab 7)

**Ask:** Combine all panels on one dashboard with the custom background.

Tasks:

1. Set dashboard background to **`Buttercup_Background.jpg`** (workshop URL: `https://splk.it/ButtercupBackground`; in this repo use `/static/app/SA-S4R/Buttercup_Background.jpg`).
2. **Resize and position** panels to fit the placeholder regions on the background image.
3. **Link every panel** to the **global time picker**.

## Acceptance checklist

- [ ] Single Dashboard Studio dashboard in app **Splunk4Rookies** (`SA-S4R`)
- [ ] Absolute layout with background image (not app-level CSS)
- [ ] IT Ops: stacked column — `timechart count by status`
- [ ] DevOps: bar — top `platform`; area — top 5 `useragent` where `status>=400`
- [ ] Business: lost revenue — `action=purchase status>=400` + `lookup product_codes.csv` + `sum(product_price)`
- [ ] Security: map — `iplocation clientip` + `geostats count by City`
- [ ] All panels respect global time range
- [ ] Panel layout matches background “boxes” (workshop slide: finished dashboard mockup)

## Notes for implementers

- Workshop sample log uses **`clientip`** in SPL for geo; access_combined may expose **`clientip`** after parsing—confirm field name in Search (`clientip` vs `CLIENTIP` in raw events).
- **`status>=400`** defines “unsuccessful” / failure for DevOps and lost-revenue panels.
- Eventgen in this repo emits workshop-shaped traffic (~67% `/product.screen`, ~33% `/cart.do`) so panel ratios and errors should look plausible after a few minutes of ingestion.
- **Workshop modes:** default data supports **infrastructure failure** (Lab 3–5). Optional **`make s4r-attack-nk-enable`** + **`make restart`** adds NK geo concentration for Lab 6 / “threat vs infrastructure” agent demos — see [SA-S4R-APP.md](SA-S4R-APP.md).
- Prefer **`make s4r-dashboard-local`** to install the Dashboard Studio view under **`SA-S4R/local/data/ui/views/`** (gitignored; template in **`local.example/`**). Keep the background reference as a dashboard asset path above.

## References

- [s4r/README.md](s4r/README.md) — Splunk4Rookies doc hub
- [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) — canonical SPL for all panels
- [SA-S4R-APP.md](SA-S4R-APP.md) — Eventgen, extractions, lookup, background hint
- [S4R-AGENTS.md](S4R-AGENTS.md) — agentic demo script
- Splunk docs: [Dashboard Studio tutorial](https://splk.it/SplunkDashStudioTutorial)
