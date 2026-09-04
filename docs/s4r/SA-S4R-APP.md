## What is SA-S4R?

**SA-S4R** is a Splunk **app** mounted from the repository into the container at:

```text
/opt/splunk/etc/apps/SA-S4R
```

It is labeled in `default/app.conf` and is visible in Splunk Web as **Splunk4Rookies** (install folder name and **`[package] id`** must remain **`SA-S4R`** — Eventgen sample paths are hard-coded to that folder). **`[launcher] version`** is set in `app.conf` (bump when shipping a new `.spl`). The main purpose in this repo is to ship **Eventgen** sample data and supporting **lookups** so you can run searches against synthetic **`access_combined`** traffic without manual onboarding. **`appserver/static/Buttercup_Background.jpg`** is the dashboard background asset used by the workshop dashboard you create under **`local/`** (not app-wide chrome).

Generated events match the **Splunk4Rookies** workshop **`noise_apache.log`** shape: `/product.screen` and `/cart.do?action=…` URIs, Buttercup referers, workshop-era user agents, and `HTTP 1.1` request lines.

## Layout

```text
SA-S4R/                         # tracked in git
├── appserver/static/
│   └── Buttercup_Background.jpg  # Dashboard background for the local/ workshop view
├── bin/
│   └── s4r_workshop_mode.py    # REST handler: infrastructure vs NK threat mode
├── default/
│   ├── app.conf                # id, label, version, launcher metadata
│   ├── authorize.conf          # capability s4r_workshop_control
│   ├── data/ui/nav/default.xml   # barebones nav (Search, Dashboards, Alerts, …)
│   ├── eventgen.conf           # Eventgen definitions (baseline + optional attack stanza)
│   ├── props.conf              # action, product_id, uid, JSESSIONID (platform → local/props.conf)
│   ├── restmap.conf            # /s4r_workshop_mode for API MCP tools
│   ├── savedsearches.conf      # Governed SPL backing SPL MCP tools
│   ├── s4r_mcp_tools.json      # Batch-replace payload for POST /services/mcp_tools
│   ├── tool_input_payload_signatures.json  # JSON Schema per tool name
│   ├── tools.conf              # App-packaged SPL tool stanzas (Developer Day)
│   └── transforms.conf         # product_codes lookup (file: lookups/product_codes.csv)
├── lookups/
│   └── product_codes.csv       # Demo lookup for Lab 5
├── metadata/
│   ├── default.meta
│   └── meta.conf
└── samples/                    # Token sources for Eventgen
    ├── product.screen.sample
    ├── cart.do.sample
    ├── attack.nk.purchase.sample
    ├── action.txt
    ├── jsessionid.txt
    ├── method.txt
    ├── product_id.txt
    ├── referer.txt
    ├── status.txt
    ├── useragent.txt
    ├── nk_clientip.txt      # NK attack mode (175.45.176.0/22 pool)
    ├── nk_status.txt
    ├── nk_useragent.txt
    └── nk_product_id.txt
local/                          # gitignored overrides; README tracked (workshop guide)
```

## `default/` vs `local/` (Splunk best practice)

Splunk apps split **shipped baseline** (`default/`) from **instance-specific overrides** (`local/`). **`local/` wins at runtime** when both define the same object.

| Directory | Purpose in this repo | Who edits it |
| --------- | -------------------- | ------------ |
| **`default/`** | PoC baseline shipped in git and **`SA-S4R.spl`**: Eventgen, core props, barebones nav, lookups | **Maintainers only** — intentional product changes in git, not ad hoc Splunk UI saves |
| **`local/`** | Workshop dashboard, nav tab, Lab 4 **`platform`** extraction, and anything you customize in Splunk Web | **You / attendees** — all direct Splunk interaction |
| **`local/README`** | Tracked workshop guide (props, nav, metadata snippets; links to dashboard spec) | Maintainers when updating workshop instructions |

**Rules (Splunk and this repo):**

1. **Splunk Web, Settings → Knowledge, nav editor, field extractor, Dashboard Studio saves** — must land under **`SA-S4R/local/`** only. **Never** save customizations into **`default/`** (Splunk will overwrite shipped objects on upgrade/reinstall).
2. **Agents and contributors** — do not add workshop dashboards, nav tabs, or Lab 4 field extractions under **`SA-S4R/default/`** in git. **Exception:** MCP packaging (`savedsearches.conf` for tool backing, `tools.conf`, `s4r_mcp_tools.json`, REST handler) is maintainer-owned in **`default/`** — [MCP-TOOLS.md](MCP-TOOLS.md). Document workshop UI setup in **`local/README`**.
3. **Packaging** — **`package-s4r.yml`** excludes **`local/`** (entire directory) so instance-specific content is not published in **`SA-S4R.spl`**. In git, **`SA-S4R/local/**`** is ignored except **`local/README`** (see **`.gitignore`**).

If you already saved something to **`default/`** inside a running container, move it to **`local/`** (or re-export from Splunk into **`local/`**), then remove the duplicate from **`default/`**.

### Dashboard background (hint)

**`Buttercup_Background.jpg`** is for the **Buttercup Enterprises** workshop dashboard—not Splunk Web app chrome. Do not use **`application.css`** for this; create the dashboard under **`SA-S4R/local/`** per **`SA-S4R/local/README`** and [DASHBOARD.md](DASHBOARD.md), then reference the file from the dashboard’s own HTML or CSS.

- **Repo path:** `SA-S4R/appserver/static/Buttercup_Background.jpg`
- **Splunk Web URL:** `/static/app/SA-S4R/Buttercup_Background.jpg`
- **App folder name:** **`SA-S4R`** (unchanged; the UI label **Splunk4Rookies** is display-only)

Example when you define the dashboard (adjust selector to your panel layout):

```css
.dashboard-body {
  background: url("/static/app/SA-S4R/Buttercup_Background.jpg") center center / cover no-repeat;
}
```

## Eventgen

Configuration lives in **`default/eventgen.conf`**. Two **baseline** stanzas emit Buttercup-shaped traffic into **`main`** / **`access_combined`**:

- **`product.screen.sample`** (~67%) — `GET|POST /product.screen?uid=…&product_id=…&JSESSIONID=…`
- **`cart.do.sample`** (~33%) — `GET|POST /cart.do?action=…&product_id=…&JSESSIONID=…`

Optional third stanza for the **active threat** workshop storyline ( **`disabled = true`** by default):

- **`attack.nk.purchase.sample`** — purchase-only cart events from a small **North Korea** IP pool (`175.45.176.0/22`), auth/denial status codes (`401`/`403`), suspicious user agents (`python-requests`, `curl`, `NK-Scanner`), skewed to **`CM-1`** (ManHawk costume). Requires matching template **`samples/attack.nk.purchase.sample`** (same basename as the stanza). Higher **`count`** (25 vs 16) so NK traffic dominates failed-purchase geo panels when enabled.

Cart **`action`** values (`action.txt`): `view`, `addtocart`, `purchase`, `remove`, `changequantity`.

Upstream documentation: [Splunk Eventgen](https://splunk.github.io/eventgen/).

### Enabling Eventgen

Eventgen is provided by a Splunkbase app (included in `SPLUNK_APPS_URL` in `compose.yml`). After Splunk is up:

1. Confirm the Eventgen app is installed and enabled.
2. Confirm **Splunk4Rookies** (**`SA-S4R`**) is enabled under **Apps**.
3. If events do not appear, check Splunk’s internal logs and Eventgen app status; Eventgen may require enablement per app in your Splunk version.

## Sample event files

- **`product.screen.sample`** — product page views with `uid` (no `action`).
- **`cart.do.sample`** — cart actions with `action=` (no `uid`).
- **`attack.nk.purchase.sample`** — same cart line shape as **`cart.do.sample`**; used only when the NK attack stanza is enabled.

All use workshop-style `HTTP 1.1`, Buttercup referers, and a trailing response-time integer.

## Navigation

**`default/data/ui/nav/default.xml`** follows Splunk’s **barebones** app template (`share/splunk/app_templates/barebones/`): **Search** (default), **Analytics**, **Datasets**, **Reports**, **Alerts**, **Dashboards**, and **Modules**.

The **Buttercup Enterprises** workshop tab and Dashboard Studio view live under **`local/`** only (gitignored except **`local/README`**). Create them per **`local/README`** and [DASHBOARD.md](DASHBOARD.md), then **`make restart`** if Splunk is already running.

## Field extractions and lookup

**`default/props.conf`** extracts `action`, `product_id`, `uid`, and `JSESSIONID` from the request line so workshop SPL such as `action=purchase` works without manual field extraction.

**`platform`** (Lab 4) belongs in **`local/props.conf`** — see **`SA-S4R/local/README`**. Agents/MCP still use inline `rex` per [SPL-CATALOG.md](SPL-CATALOG.md).

**`default/transforms.conf`** registers lookup **`product_codes`** (backed by **`lookups/product_codes.csv`**) for Lab 5:

```spl
| lookup product_codes product_id
```

## Lookup table

Use the transforms stanza name in SPL and saved searches:

```spl
| inputlookup product_codes
| lookup product_codes product_id
```

The stanza **`[product_codes]`** in **`default/transforms.conf`** points at the backing file **`lookups/product_codes.csv`**. The CSV columns are **`product_id`**, **`product_name`**, **`product_price`**, and **`category`**. Keep the stanza name stable so catalog SPL, agents, and dashboards can use **`product_codes`** even if maintainers reorganize files later.

## Customizing

**Splunk Web:** save all knowledge objects, nav changes, field extractions, and dashboards under **`local/`** only — never **`default/`** (see **`default/` vs `local/`** above).

- Edit **`samples/action.txt`**, **`status.txt`**, or **`useragent.txt`** to change categorical choices.
- Tune **`interval`**, **`count`**, and **`randomizeCount`** per stanza in `eventgen.conf`.
- Adjust the **`product.screen`** / **`cart.do`** ratio via each stanza’s **`count`**.

### Workshop modes: infrastructure vs NK attack

Two storylines share the same baseline traffic; the NK stanza is toggled without editing Eventgen by hand.

| Mode | Enable / disable (preferred) | After toggle |
| ---- | -------------------------- | ------------ |
| **Infrastructure** (default) | MCP **`SA-S4R_apply_nk_demo_state`** (`mode=infrastructure`) | Reloads Eventgen modinput — **no `make restart`** |
| **Active threat** | MCP **`SA-S4R_apply_nk_demo_state`** (`mode=threat`) | Same; wait 1–2 min, then **`SA-S4R_validate_nk_attack_traffic`** |

**Shell fallback:** `make s4r-attack-nk-disable` / `make s4r-attack-nk-enable` then **`make restart`** if MCP is unavailable or signal is slow.

Check current mode: **`SA-S4R_query_nk_demo_state`** (MCP), **`make s4r-attack-nk-status`** (shell), or read **`local/eventgen.conf`** (override) then **`default/eventgen.conf`**. Toggles write **`SA-S4R/local/eventgen.conf`** only (gitignored) so **`default/`** stays pristine. Script: **`scripts/toggle-s4r-attack-nk.sh`** (`enable` \| `disable` \| `status`). MCP tools register on **`make up`**; re-register with **`make register-s4r-mcp-tools`** — see [MCP-TOOLS.md](MCP-TOOLS.md).

Wait **1–2 minutes** after enabling threat mode before validating in Search (narrow time range to **last 15m** so old uniform traffic does not mask the attack).

#### What each S4R agent should see

| Agent | Infrastructure (default) | Active threat (NK enabled) |
| ----- | ------------------------ | --------------------------- |
| **IT Ops** | ~40% errors site-wide; **503** / **404** lead | Same baseline errors; NK adds **401** / **403** on purchases |
| **DevOps** | ~40% failure rate on **all** platforms (server-wide) | Scripted UAs (`python-requests`, `curl`) fail more than browsers; still not a single-OS mobile regression |
| **Business Analytics** | Lost revenue spread across products | NK skew on **`CM-1`** (ManHawk); Pyongyang tops failed-purchase geo |
| **Security & Fraud** | No geo concentration; ~1 event per IP | **North Korea** / **Pyongyang** dominates failed purchases; same few **175.45.*** IPs repeat |

Power User synthesis: **infrastructure** → “fix the web tier”; **active threat** → “geo + scripted UA concentration warrants Security review, but IT Ops may still see 503/404 from baseline.”

#### Validation SPL

Canonical queries for both workshop modes: **[SPL-CATALOG.md § Workshop modes](SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat)** (and per-team § in the same file). Agents and dashboards should use that catalog — not duplicate SPL here.

**Saved searches (Splunk4Rookies app):**

- **`S4R Summarize Purchase Health`** — Business KPIs over **last 24h**: total lost revenue (`product_codes` lookup), success vs failure purchase counts, top 5 products by lost revenue. MCP tool: **`SA-S4R_summarize_purchase_health`**.
- **`S4R Geo Failed Purchase Hotspots`** — Security geo over **last 24h**: top failed-purchase country/city/IP hotspots plus top cities by overall activity (`iplocation`). MCP tool: **`SA-S4R_geo_failed_purchases`**.
- **`S4R Validate NK Attack Traffic`** — NK geo check over **last 15m**; rows appear when threat mode is producing **North Korea** or **175.45.*** failed purchases. Empty results mean no NK signal yet (wait 1–2 min after enable, or confirm mode with **`SA-S4R_query_nk_demo_state`**). MCP tool: **`SA-S4R_validate_nk_attack_traffic`**.

`make up` registers the MCP tools after init. **`make register-s4r-mcp-tools`** re-runs that step and reloads **`conf-savedsearches`** so new stanzas are visible without **`make restart`**.

NK attack token sources: **`samples/nk_clientip.txt`**, **`nk_status.txt`**, **`nk_useragent.txt`**, **`nk_product_id.txt`**.

#### Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| NK enabled via MCP but no events yet | Eventgen warming up | Wait 1–2 min; **`SA-S4R_validate_nk_attack_traffic`** |
| `make s4r-attack-nk-enable` but no NK events | Splunk not restarted (shell path) | `make restart`, wait ~2 min |
| Still no NK UAs / IPs | Missing sample template | Confirm **`samples/attack.nk.purchase.sample`** exists (basename must match stanza) |
| NK mode “stuck” on after disable | Container still running old config | `make s4r-attack-nk-disable` then **`make restart`** |
| Geo shows NK but agents say “infrastructure” | Time range too wide | Use **last 15m** after enable; baseline traffic dilutes the signal |

See [AGENTS.md](AGENTS.md) for Power User delegation and [SPL-CATALOG.md](SPL-CATALOG.md) for all workshop SPL.

## App metadata (compliance)

| File | Purpose |
| ---- | ------- |
| `default/app.conf` | **`[package] id`**, **`[launcher] version`**, UI label/description |
| `default/tools.conf` | App-packaged MCP SPL tool stanzas (see [MCP-TOOLS.md](MCP-TOOLS.md)) |
| `default/s4r_mcp_tools.json` | Batch-replace payload for Splunk MCP Server |
| `metadata/default.meta` | Export/ACL for shipped objects (`props`, `transforms`, lookup CSV, `eventgen.conf`) |
| `metadata/meta.conf` | Default ACL for new objects created in-app |

**Do not package** runtime paths: `local/`, `metadata/local.meta`, `.DS_Store` (excluded in **`package-s4r.yml`**). **`local/`** holds workshop dashboard/nav overrides and may contain HEC inputs or tokens from a live container — keep gitignored.

**Workshop assets:** Dashboard Studio view, nav tab, and **`platform`** extraction — create under **`local/`** per **`local/README`**. Optional follow-up: app icon under `appserver/static/`.

## See also

- [SPL-CATALOG.md](SPL-CATALOG.md) — canonical SPL for Labs 3–7 (agents + dashboards)
- [MCP-TOOLS.md](MCP-TOOLS.md) — MCP architecture, definitions, config files
- [DASHBOARD.md](DASHBOARD.md) — dashboard layout (Labs 3–7)
- [ARCHITECTURE.md](../poc/ARCHITECTURE.md) — where SA-S4R fits in the stack
