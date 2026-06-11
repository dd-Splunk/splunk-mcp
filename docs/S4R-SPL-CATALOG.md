# S4R SPL catalog — Buttercup Enterprises runbook

**Single source of truth** for workshop SPL (Labs 3–7). Aligned with the **Splunk4Rookies Lab Guide (Apr 2026)** cheat-sheet searches; agents run these via **Splunk MCP** (`splunk_run_query`). Dashboards use the same queries — see [S4R-DASHBOARD.md](S4R-DASHBOARD.md) for layout and visualization only. Workshop hub: [s4r/README.md](s4r/README.md).

**Lab guide:** [Splunk4Rookies - Lab Guide - Apr 2026.pdf](Splunk4Rookies%20-%20Lab%20Guide%20-%20Apr%202026.pdf)

**Educational model:** Splunk holds data → **this file** is the runbook → **agents** are stakeholder roles → **MCP** executes searches under `splunker` guardrails.

| Layer | File |
| ----- | ---- |
| Data / Eventgen | [SA-S4R-APP.md](SA-S4R-APP.md) |
| **SPL (this doc)** | `docs/S4R-SPL-CATALOG.md` |
| Agent roles | [`.cursor/agents/`](../.cursor/agents/) |
| Orchestration | [S4R-AGENTS.md](S4R-AGENTS.md) · `s4r-power-user.md` |

---

## Data contract

**Base search** (prefix every panel unless noted):

```spl
index=main sourcetype=access_combined
```

| Item | Value |
| ---- | ----- |
| Index / sourcetype | `main` / `access_combined` |
| URIs | `/product.screen`, `/cart.do?action=…` |
| Cart `action` values | `view`, `addtocart`, `purchase`, `remove`, `changequantity` |
| Extracted fields | `action`, `product_id`, `uid`, `JSESSIONID` (`SA-S4R/default/props.conf`) |
| Geo IP field | `clientip` (confirm casing in Search) |
| Success | `status` 2xx |
| Failure (workshop) | `status>=400` |
| Failed purchase | `action=purchase` AND `status>=400` |
| Lookup | `\| lookup product_codes.csv product_id` → `product_price`, `product_name`, `category` |
| Currency | USD (Buttercup US retailer) |

**Rules:** Never invent prices — always use the lookup. Distinguish `view` / `addtocart` / `remove` / `changequantity` from `purchase` failures.

---

## Shared snippets

### Explore lookup file (Lab 5)

```spl
| inputlookup product_codes.csv
```

### Lab guide — introductory challenge SPL

```spl
index=main sourcetype=access_combined status=200 action!=purchase
```

```spl
index=main sourcetype=access_combined status>=400 (action=addtocart OR action=remove)
```

### Platform prefix (Lab 4 — **required for agents / MCP**)

Workshop attendees create a **`platform`** field extraction in Splunk Web (field extractor wizard) for **saved dashboard panels**. **`splunk_run_query` does not use those saved extractions** — agents must **always** prepend this inline `rex` on any search that uses `platform`:

```spl
| rex field=useragent "\((?<platform>Linux; Android [0-9.]+|Macintosh; Intel Mac OS X [0-9_]+|Windows|iPhone; CPU iPhone OS [0-9_]+)"
| eval platform=if(isnull(platform),"Other",platform)
```

### Quick data check

```spl
index=main sourcetype=access_combined
| stats count
```

---

## § IT Ops (Lab 3)

**Ask:** Successful vs unsuccessful web server requests over time.

**Expected finding (infrastructure mode):** ~40% failure rate; **503** and **404** lead; errors on all URI types.

### Panel — stacked column (Lab 3)

Lab guide auto-populated search:

```spl
index=main sourcetype=access_combined
| timechart count by status limit=10
```

### Drill-down — top error URIs

```spl
index=main sourcetype=access_combined status>=400
| stats count by uri
| sort - count
| head 20
```

### Drill-down — success rate

```spl
index=main sourcetype=access_combined
| eval outcome=if(status<400,"success","failure")
| stats count by outcome
```

### Drill-down — purchase-specific outcomes

```spl
index=main sourcetype=access_combined action=purchase
| eval outcome=if(status<400,"success","failure")
| stats count by outcome, status
```

---

## § DevOps (Lab 4)

**Ask:** Top operating systems; browsers with most failures; **client-specific vs server-wide** failure pattern.

**Lab vs agents:** In the workshop, attendees save a **`platform`** field extraction for dashboard panels (`| top limit=20 platform`). **Agents and MCP must not rely on that extraction** — always use the **platform prefix** (`rex` + `eval`) from Shared snippets on every query that references `platform`.

**Expected finding (infrastructure mode):** ~40% failure on **all** platforms (flat spread ⇒ server-side). **Expected (threat mode):** scripted UAs (`python-requests`, `curl`) may outlier; platforms still flat.

### Panel — top operating systems (**agents — inline rex**)

**Canonical for MCP** (prepend platform prefix after base search):

```spl
index=main sourcetype=access_combined
| rex field=useragent "\((?<platform>Linux; Android [0-9.]+|Macintosh; Intel Mac OS X [0-9_]+|Windows|iPhone; CPU iPhone OS [0-9_]+)"
| eval platform=if(isnull(platform),"Other",platform)
| top limit=20 platform showperc=f
```

### Lab reference — top operating systems (saved field extraction)

Workshop dashboard panel only (after Lab 4 field extractor wizard). **Do not use for agent searches.**

```spl
index=main sourcetype=access_combined
| top limit=20 platform showperc=f
```

### Panel — top failing browsers over time (Lab 4)

Lab guide final search (area chart; limit 5, hide OTHER):

```spl
index=main sourcetype=access_combined status>=400
| timechart count by useragent limit=5 useother=f
```

### Verdict — failure rate by platform

```spl
index=main sourcetype=access_combined
| rex field=useragent "\((?<platform>Linux; Android [0-9.]+|Macintosh; Intel Mac OS X [0-9_]+|Windows|iPhone; CPU iPhone OS [0-9_]+)"
| eval platform=if(isnull(platform),"Other",platform)
| eval outcome=if(status<400,"success","failure")
| stats count by platform, outcome
| eventstats sum(count) as platform_total by platform
| eval pct=round(100*count/platform_total,1)
| chart values(pct) over platform by outcome
```

**Read:** one platform with much higher failure % ⇒ client cohort; all platforms ~40/60 ⇒ **server-side** (escalate IT Ops).

### Optional — release test matrix

```spl
index=main sourcetype=access_combined status>=400
| rex field=useragent "\((?<platform>Linux; Android [0-9.]+|Macintosh; Intel Mac OS X [0-9_]+|Windows|iPhone; CPU iPhone OS [0-9_]+)"
| eval platform=if(isnull(platform),"Other",platform)
| rex field=useragent "(?<handset>Pixel[^;]*|Nexus[^;]*|SM-[^;]+|iPhone[^;]*)"
| stats count by platform, handset
| sort - count
| head 15
```

---

## § Business Analytics (Lab 5)

**Ask:** Lost revenue from failed purchases.

**Expected finding:** Non-zero `lost_revenue` from lookup; failed purchases track site-wide error rate unless threat mode skews **`CM-1`**.

### Lab step — enrich purchases with lookup (before failure filter)

```spl
index=main sourcetype=access_combined action=purchase
| lookup product_codes.csv product_id
```

### Panel — lost revenue over time (Lab 5)

Lab guide final search (Single Value or time series):

```spl
index=main sourcetype=access_combined action=purchase status>=400
| lookup product_codes.csv product_id
| timechart sum(product_price)
```

### Drill-down — single-value total

```spl
index=main sourcetype=access_combined action=purchase status>=400
| lookup product_codes.csv product_id
| stats sum(product_price) as lost_revenue, count as failed_purchases
```

### Drill-down — by product

```spl
index=main sourcetype=access_combined action=purchase status>=400
| lookup product_codes.csv product_id
| stats sum(product_price) as lost_revenue, count by product_name, category
| sort - lost_revenue
```

### Drill-down — purchase success vs failure

```spl
index=main sourcetype=access_combined action=purchase
| eval outcome=if(status<400,"success","failure")
| stats count by outcome
```

---

## § Security & Fraud (Lab 6)

**Ask:** Website activity by geographic location; failure concentration.

**Expected finding (infrastructure mode):** Cities fail at ~same rate; ~1 event per IP. **Expected (threat mode):** **North Korea** / **Pyongyang** and **175.45.*** IPs dominate failed purchases.

### Panel — activity by city (Lab 6 — map)

Lab guide search:

```spl
index=main sourcetype=access_combined
| iplocation clientip
| geostats count by City
```

### Lab 6 challenge — activity outside the United States

Lab guide solution (filter after `iplocation` adds `Country`):

```spl
index=main sourcetype=access_combined
| iplocation clientip
| search Country!="United States"
| geostats count by City
```

### Drill-down — errors by city

```spl
index=main sourcetype=access_combined status>=400
| iplocation clientip
| geostats count by City
```

### Drill-down — failed purchases by geo

```spl
index=main sourcetype=access_combined action=purchase status>=400
| iplocation clientip
| geostats count by City
```

### Drill-down — failed purchases by country and IP (threat discrimination)

```spl
index=main sourcetype=access_combined action=purchase status>=400
| iplocation clientip
| stats count as failed_purchases by Country, City, clientip
| sort - failed_purchases
| head 10
```

### Drill-down — high-volume IPs

```spl
index=main sourcetype=access_combined
| stats count by clientip
| sort - count
| head 20
```

Requires Splunk **`iplocation`** (GeoLite or equivalent).

---

## § Workshop modes (infrastructure vs threat)

Toggle commands and Eventgen detail: [SA-S4R-APP.md](SA-S4R-APP.md). Check mode: **`make s4r-attack-nk-status`**. After enable/disable: **`make restart`**, wait ~2 min, search **last 15m**.

| Mode | Headline |
| ---- | -------- |
| Infrastructure (default) | 503/404 everywhere; flat ~40% geo and platform |
| Active threat (NK enabled) | Pyongyang tops failed purchases; scripted UAs; 401/403 on purchases |

### Threat — scripted user agents

```spl
index=main sourcetype=access_combined action=purchase
  (useragent="*python-requests*" OR useragent="*NK-Scanner*" OR useragent="curl/*")
| stats count by clientip, useragent, status
| sort - count
```

### Threat — purchase errors by status (IT Ops handoff)

```spl
index=main sourcetype=access_combined action=purchase status>=400
| stats count by status
| sort - count
```

### Threat — fail rate by city (geo baseline check)

```spl
index=main sourcetype=access_combined action=purchase
| iplocation clientip
| stats count as total, count(eval(status>=400)) as failed by City
| eval fail_rate=round(100*failed/total,1)
| sort - total
| head 15
```

---

## § Power User (Lab 7)

**Ask:** One executive answer across all four teams; map to dashboard panels.

**Workflow:**

1. Confirm data (`§ Data contract` quick check).
2. Check workshop mode if ask is infrastructure vs threat (`make s4r-attack-nk-status`).
3. Delegate — run § IT Ops, § DevOps, § Business Analytics, § Security in parallel when needed.
4. Synthesize (template in [S4R-AGENTS.md](S4R-AGENTS.md) and `s4r-power-user.md`).

**Panel SPL one-liners:**

| Team | Panel SPL tail |
| ---- | -------------- |
| IT Ops | `\| timechart count by status limit=10` |
| DevOps | platform prefix + `\| top limit=20 platform showperc=f`; `status>=400 \| timechart count by useragent limit=5 useother=f` |
| Business | `action=purchase status>=400 \| lookup product_codes.csv product_id \| timechart sum(product_price)` |
| Security | `\| iplocation clientip \| geostats count by City` |

---

## Agent → catalog index

| Agent file | Read this section |
| ---------- | ----------------- |
| `s4r-it-ops.md` | § IT Ops |
| `s4r-devops.md` | § DevOps · Shared snippets (**platform prefix — always rex for MCP**) |
| `s4r-business-analytics.md` | § Business Analytics |
| `s4r-security-fraud.md` | § Security & Fraud · § Workshop modes |
| `s4r-power-user.md` | All sections · § Power User |

---

## See also

- [Splunk4Rookies - Lab Guide - Apr 2026.pdf](Splunk4Rookies%20-%20Lab%20Guide%20-%20Apr%202026.pdf) — workshop cheat-sheet SPL (Exercises 3–7)
- [S4R-AGENTS.md](S4R-AGENTS.md) — architecture, delegation, demo script
- [SA-S4R-APP.md](SA-S4R-APP.md) — Eventgen, NK toggle, troubleshooting
- [API_REFERENCE.md](API_REFERENCE.md) — Splunk MCP tools
