## What is SA-S4R?

**SA-S4R** is a Splunk **app** installed from the GitHub **`latest`** package into:

```text
/opt/splunk/etc/apps/SA-S4R
```

It is labeled in `default/app.conf` and is visible in Splunk Web as **Splunk4Rookies** (install folder name and **`[package] id`** must remain **`SA-S4R`** — Eventgen sample paths are hard-coded to that folder). Compose downloads [**`SA-S4R.spl`**](https://github.com/dd-Splunk/splunk-mcp/releases/download/latest/SA-S4R.spl) from the moving GitHub Release **`latest`** via **`SPLUNK_APPS_URL`**. The official image installs that list only on the first start of an empty **`so1-etc`** volume. Workshop mode sets the NK stanza through Splunk config REST; Splunk stores that override in **`local/eventgen.conf`** inside the installed app. Do not save Splunk UI customizations into **`default/`**. **`[launcher] version`** is set in `app.conf` (bump when shipping a new `.spl`). The main purpose in this repo is to ship **Eventgen** sample data and supporting **lookups** so you can run searches against synthetic **`access_combined`** traffic without manual onboarding. **`appserver/static/Buttercup_Background.jpg`** is the dashboard background asset used by the workshop dashboard you create under **`local/`** (not app-wide chrome).

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
local/                          # created in the running app (so1-etc); gitignored
```

## `default/` vs `local/` (Splunk best practice)

Splunk apps split **shipped baseline** (`default/`) from **instance-specific overrides** (`local/`). **`local/` wins at runtime** when both define the same object.

| Directory | Purpose in this repo | Who edits it |
| --------- | -------------------- | ------------ |
| **`default/`** | PoC baseline shipped in git and **`SA-S4R.spl`**: Eventgen, core props, barebones nav, lookups | **Maintainers only** — intentional product changes in git, not ad hoc Splunk UI saves |
| **`local/`** | Workshop dashboard, nav tab, Lab 4 **`platform`** extraction, and anything you customize in Splunk Web (lives in **`so1-etc`**, not git) | **You / attendees** — all direct Splunk interaction |

**Rules (Splunk and this repo):**

1. **Splunk Web, Settings → Knowledge, nav editor, field extractor, Dashboard Studio saves** — must land under **`SA-S4R/local/`** only. **Never** save customizations into **`default/`** (Splunk will overwrite shipped objects on upgrade/reinstall).
2. **Agents and contributors** — do not add workshop dashboards, nav tabs, or Lab 4 field extractions under **`SA-S4R/default/`** in git. **Exception:** MCP packaging (`savedsearches.conf` for tool backing, `s4r_mcp_tools.json`, REST handler) is maintainer-owned in **`default/`** — [MCP-TOOLS.md](MCP-TOOLS.md). Workshop UI setup is in [Workshop objects in `local/`](#workshop-objects-in-local) and [DASHBOARD.md](DASHBOARD.md).
3. **Packaging** — **`package-s4r.yml`** excludes **`local/`** (entire directory) so instance-specific content is not published in **`SA-S4R.spl`**. Git ignores **`SA-S4R/local/**`** (see **`.gitignore`**).
4. **Install** — Compose does not bind-mount the app tree. The package lands in **`so1-etc`**. Workshop UI and Eventgen overrides still belong in that installed app’s **`local/`**.

If you already saved something to **`default/`** inside a running container, move it to **`local/`** (or re-export from Splunk into **`local/`**), then remove the duplicate from **`default/`**.

### Install from GitHub `.spl`

Compose installs [**`SA-S4R.spl`**](https://github.com/dd-Splunk/splunk-mcp/releases/download/latest/SA-S4R.spl) from the moving **`latest`** release. **`package-s4r.yml`** rebuilds that asset when **`SA-S4R/**`** changes on **`main`**.

- **First start only:** the official image downloads **`SPLUNK_APPS_URL`** when **`so1-etc`** is empty. A volume created while the app was bind-mounted does not contain the package. Recreate it (`make down && make clean && make up`, or remove volume **`so1-etc`**) to install or to pick up a newer **`latest`**.
- **Which build you boot:** **`latest`** is the last package published from **`main`**, not this clone or a dirty working tree. The `.spl` **excludes `local/`**.
- **Source edits:** changes under **`default/`**, **`bin/`**, samples, and the tool JSON are invisible in Splunk until they are on **`main`**, **`package-s4r.yml`** moves **`latest`**, and **`so1-etc`** is recreated.
- **Host scripts:** **`make s4r-attack-nk-*`** POSTs the NK stanza to Splunk config REST. Splunk writes **`local/eventgen.conf`** inside the installed app. **`splunk-init`** still bind-mounts **`SA-S4R/default/s4r_mcp_tools.json`** from the checkout and POSTs it. MCP **`SA-S4R_apply_nk_demo_state`** calls the same configs endpoint from inside Splunk.
- **Egress:** boot needs **`github.com`** for this package and Splunkbase for the other **`SPLUNK_APPS_URL`** apps.
- **Do not bind-mount the app `:ro`.** The image **chowns** `/opt/splunk/etc/apps/SA-S4R` at start; a read-only bind fails with **`Errno 30`**. The package install avoids that bind.

### Dashboard background (hint)

**`Buttercup_Background.jpg`** is for the **Buttercup Enterprises** workshop dashboard—not Splunk Web app chrome. Do not use **`application.css`** for this; create the dashboard under the installed app’s **`local/`** per [Workshop objects in `local/`](#workshop-objects-in-local) and [DASHBOARD.md](DASHBOARD.md), then reference the file from the dashboard’s own HTML or CSS.

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

The **Buttercup Enterprises** workshop tab and Dashboard Studio view live under the installed app’s **`local/`** only. Create them per [Workshop objects in `local/`](#workshop-objects-in-local) and [DASHBOARD.md](DASHBOARD.md). They persist in **`so1-etc`**.

## Field extractions and lookup

**`default/props.conf`** extracts `action`, `product_id`, `uid`, and `JSESSIONID` from the request line so workshop SPL such as `action=purchase` works without manual field extraction.

**`platform`** (Lab 4) belongs in the installed app’s **`local/props.conf`** — see [Workshop objects in `local/`](#workshop-objects-in-local). Agents/MCP still use inline `rex` per [SPL-CATALOG.md](SPL-CATALOG.md).

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
| **Infrastructure** (default) | MCP **`SA-S4R_apply_nk_demo_state`** (`mode=infrastructure`) | Reloads Eventgen — **no `make restart`** on HTTP **200**. HTTP **503** means the stanza was updated but Eventgen did not reload → **`make restart`** |
| **Active threat** | MCP **`SA-S4R_apply_nk_demo_state`** (`mode=threat`) | Same; wait 1–2 min, then **`SA-S4R_validate_nk_attack_traffic`** |

**Shell fallback:** `make s4r-attack-nk-disable` / `make s4r-attack-nk-enable`. Same REST update and Eventgen reload as MCP. **`make restart`** only if the script reports that the reload failed.

Check current mode: **`SA-S4R_query_nk_demo_state`** (MCP) or **`make s4r-attack-nk-status`** (shell). Both read the effective `disabled` value from Splunk. Toggles `POST /servicesNS/nobody/SA-S4R/configs/conf-eventgen/attack.nk.purchase.sample` (`disabled=true` or `false`). Splunk writes the override to **`SA-S4R/local/eventgen.conf`** (gitignored) so **`default/`** stays pristine. Script: **`scripts/toggle-s4r-attack-nk.sh`** (`enable` \| `disable` \| `status`). MCP tools register inside **`splunk-init`** during **`make up`**. After a JSON edit, **`make up`** again — see [MCP-TOOLS.md](MCP-TOOLS.md).

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

**`splunk-init`** registers the MCP tools and reloads **`conf-savedsearches`** so new stanzas are visible without **`make restart`**. After an edit, **`make up`**.

NK attack token sources: **`samples/nk_clientip.txt`**, **`nk_status.txt`**, **`nk_useragent.txt`**, **`nk_product_id.txt`**.

#### Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| NK enabled via MCP but no events yet | Eventgen warming up | Wait 1–2 min; **`SA-S4R_validate_nk_attack_traffic`** |
| `make s4r-attack-nk-enable` but no NK events | Eventgen still warming up, or reload failed | Wait 1–2 min; if the script printed a reload error, `make restart` |
| Still no NK UAs / IPs | Missing sample template | Confirm **`samples/attack.nk.purchase.sample`** exists (basename must match stanza) |
| NK mode “stuck” on after disable | Eventgen did not reload | `make s4r-attack-nk-disable`; **`make restart`** if reload failed |
| Geo shows NK but agents say “infrastructure” | Time range too wide | Use **last 15m** after enable; baseline traffic dilutes the signal |

See [AGENTS.md](AGENTS.md) for Power User delegation and [SPL-CATALOG.md](SPL-CATALOG.md) for all workshop SPL.

## App metadata (compliance)

| File | Purpose |
| ---- | ------- |
| `default/app.conf` | **`[package] id`**, **`[launcher] version`**, UI label/description |
| `default/s4r_mcp_tools.json` | Batch-replace payload for Splunk MCP Server (`POST /services/mcp_tools`) |
| `metadata/default.meta` | Export/ACL for shipped objects (`props`, `transforms`, lookup CSV, `eventgen.conf`) |
| `metadata/meta.conf` | Default ACL for new objects created in-app |

**Do not package** runtime paths: `local/`, `metadata/local.meta`, `.DS_Store` (excluded in **`package-s4r.yml`**). **`local/`** holds workshop dashboard/nav overrides and may contain HEC inputs or tokens from a live container — keep gitignored.

**Workshop assets:** Dashboard Studio view, nav tab, and **`platform`** extraction — create under the installed app’s **`local/`** ([Workshop objects in `local/`](#workshop-objects-in-local)). Optional follow-up: app icon under `appserver/static/`.

### Workshop objects in `local/`

These are instance overrides. Create them in Splunk Web (they land under the installed app’s **`local/`** in **`so1-etc`**). Do not add them under **`default/`** in git. Layout and panels: [DASHBOARD.md](DASHBOARD.md).

Lab 4 — **`local/props.conf`**:

```conf
[access_combined]
EXTRACT-platform = \((?<platform>Linux; Android [0-9.]+|Macintosh; Intel Mac OS X [0-9_]+|Windows|iPhone; CPU iPhone OS [0-9_]+)
```

Workshop nav tab — **`local/data/ui/nav/local.xml`**:

```xml
<nav search_view="search" color="#791CF8">
  <view name="buttercup_enterprises_dashboard" />
</nav>
```

Dashboard permissions — **`local/metadata/local.meta`**:

```conf
[views/buttercup_enterprises_dashboard]
access = read : [ admin, sc_admin, power, user ], write : [ admin, sc_admin ]
export = none
```

Build the Dashboard Studio view in Splunk Web and save it under **`local/data/ui/views/`**. Background asset: `/static/app/SA-S4R/Buttercup_Background.jpg`.

## See also

- [SPL-CATALOG.md](SPL-CATALOG.md) — canonical SPL for Labs 3–7 (agents + dashboards)
- [MCP-TOOLS.md](MCP-TOOLS.md) — MCP architecture, definitions, config files
- [DASHBOARD.md](DASHBOARD.md) — dashboard layout (Labs 3–7)
- [ARCHITECTURE.md](../poc/ARCHITECTURE.md) — where SA-S4R fits in the stack
