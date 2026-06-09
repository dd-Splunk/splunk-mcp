# Splunk4Rookies dashboard prompt

Use this document as the **build spec** when creating the Buttercup Enterprises workshop dashboard in the **Splunk4Rookies** app (`SA-S4R`). It reflects **Splunk4Rookies** workshop Labs 3–7. Data and lookups are described in [SA-S4R-APP.md](SA-S4R-APP.md). For **agentic** analysis (Power User delegating to IT Ops, DevOps, Business Analytics, Security), see [S4R-AGENTS.md](S4R-AGENTS.md) and [`.cursor/agents/`](../.cursor/agents/).

## Scenario

You are a Splunk power user for **Buttercup Enterprises**, a US online retailer (books, clothing, gifts). Teams need one **Dashboard Studio** dashboard ( **Absolute** layout ) that answers four stakeholder questions and uses the marketing background image.

**Goal:** Go from messy machine data to a single, story-telling dashboard—all panels on one canvas, linked to the **global time picker**.

## Data scope

| Item | Value |
| ---- | ----- |
| Index / sourcetype | `index=main sourcetype=access_combined` |
| Event shape | Apache-style access logs: `/product.screen?uid=…&product_id=…` and `/cart.do?action=…&product_id=…` |
| Fields in repo | `action`, `product_id`, `uid`, `JSESSIONID` (`SA-S4R/default/props.conf`) |
| Field to add (Lab 4) | **`platform`** — extract from `useragent` (OS/platform); required before DevOps panels |
| Lookup | `product_codes.csv` → `product_id`, `product_name`, `product_price` (`SA-S4R/lookups/`) |
| Background asset | `/static/app/SA-S4R/Buttercup_Background.jpg` (repo: `SA-S4R/appserver/static/Buttercup_Background.jpg`) |

Base search prefix for every panel:

```spl
index=main sourcetype=access_combined
```

## Dashboard platform

- **Product:** Dashboard Studio (not Classic Simple XML).
- **Layout:** **Absolute** — allows placing panels over the background image.
- **Deliverable:** One dashboard in the **Splunk4Rookies** app with **five** visual areas (four team panels + branded layout).
- **Do not** use app-wide `application.css`; background is a **dashboard** image only.

## Panels (build in lab order)

### 1. IT Operations — success vs failure over time (Lab 3)

**Ask:** Investigate successful versus unsuccessful web server requests over time.

| | |
| --- | --- |
| Visualization | Stacked column chart |
| Reference SPL | `index=main sourcetype=access_combined \| timechart count by status limit=10` |

Add this panel to a **new** dashboard; choose Dashboard Studio and Absolute layout.

### 2. DevOps — OS mix and failing browsers (Lab 4)

**Ask:** Show the most common customer operating systems and which web browsers experience the most failures.

**Prerequisite:** Extract **`platform`** from `useragent` (workshop field extraction). Then:

| Panel | Visualization | Reference SPL |
| ----- | ------------- | ------------- |
| Top operating systems | Bar chart | `index=main sourcetype=access_combined \| top limit=20 platform showperc=f` |
| Top 5 failing browsers over time | Area chart | `index=main sourcetype=access_combined status>=400 \| timechart count by useragent limit=5 useother=f` |

Add both charts to the **same** dashboard as panel 1.

### 3. Business Analytics — lost revenue (Lab 5)

**Ask:** Show lost revenue from the Buttercup Enterprises website.

Failed purchases have `action=purchase` and HTTP error status. Enrich with lookup prices, then aggregate:

| | |
| --- | --- |
| Visualization | Single value (or time series of lost revenue—workshop uses timechart for the exercise) |
| Reference SPL | `index=main sourcetype=access_combined action=purchase status>=400 \| lookup product_codes.csv product_id \| timechart sum(product_price)` |

Lookup maps `product_id` → `product_price` (and name/category) in `SA-S4R/lookups/product_codes.csv`.

### 4. Security and Fraud — activity by geography (Lab 6)

**Ask:** Show website activity by geographic location.

| | |
| --- | --- |
| Visualization | World map (city-level activity) |
| Reference SPL | `index=main sourcetype=access_combined \| iplocation clientip \| geostats count by City` |

Requires Splunk **`iplocation`** (GeoLite etc. as in your Splunk deployment).

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
- Prefer shipping dashboard JSON/XML under `SA-S4R/default/data/ui/views/` when automating; keep background reference as a dashboard asset path above.

## References

- [SA-S4R-APP.md](SA-S4R-APP.md) — Eventgen, extractions, lookup, background hint
- Splunk docs: [Dashboard Studio tutorial](https://splk.it/SplunkDashStudioTutorial)
