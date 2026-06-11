## What is SA-S4R?

**SA-S4R** is a Splunk **app** mounted from the repository into the container at:

```text
/opt/splunk/etc/apps/SA-S4R
```

It is labeled in `default/app.conf` and is visible in Splunk Web as **Splunk4Rookies** (install folder name and **`[package] id`** must remain **`SA-S4R`** — Eventgen sample paths are hard-coded to that folder). **`[launcher] version`** is set in `app.conf` (bump when shipping a new `.spl`). The main purpose in this repo is to ship **Eventgen** sample data and supporting **lookups** so you can run searches against synthetic **`access_combined`** traffic without manual onboarding. **`appserver/static/Buttercup_Background.jpg`** is a static asset for a dashboard to be added later (not app-wide chrome).

Generated events match the **Splunk4Rookies** workshop **`noise_apache.log`** shape: `/product.screen` and `/cart.do?action=…` URIs, Buttercup referers, workshop-era user agents, and `HTTP 1.1` request lines.

## Layout

```text
SA-S4R/                         # tracked in git
├── appserver/static/
│   └── Buttercup_Background.jpg  # Dashboard background (future)
├── default/
│   ├── app.conf                # id, label, version, launcher metadata
│   ├── data/ui/nav/default.xml   # barebones nav (Search, Dashboards, Alerts, …)
│   ├── eventgen.conf           # Eventgen definitions (baseline + optional attack stanza)
│   ├── props.conf              # action, product_id, uid, JSESSIONID extractions
│   └── transforms.conf         # product_codes.csv lookup definition
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

# Created at runtime in the container (gitignored: **/local/, **/metadata/local.meta)
# e.g. local/inputs.conf, local/app.conf
```

### Dashboard background (hint)

**`Buttercup_Background.jpg`** is for a **dashboard** you add later—not Splunk Web app chrome. Do not use **`application.css`** for this; reference the file from the dashboard’s own HTML or CSS.

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

**`default/data/ui/nav/default.xml`** follows Splunk’s **barebones** app template (`share/splunk/app_templates/barebones/`): **Search** (default), **Analytics**, **Datasets**, **Reports**, **Alerts**, **Dashboards**, and **Modules**. Custom workshop dashboards (when added under `default/data/ui/views/`) appear under **Dashboards**.

## Field extractions and lookup

**`default/props.conf`** extracts `action`, `product_id`, `uid`, and `JSESSIONID` from the request line so workshop SPL such as `action=purchase` works without manual field extraction.

**`default/transforms.conf`** defines the **`product_codes.csv`** file lookup used in Lab 5:

```spl
| lookup product_codes.csv product_id
```

## Lookup table

**`lookups/product_codes.csv`** maps product IDs to names and prices for the lost-revenue exercise.

## Customizing

- Edit **`samples/action.txt`**, **`status.txt`**, or **`useragent.txt`** to change categorical choices.
- Tune **`interval`**, **`count`**, and **`randomizeCount`** per stanza in `eventgen.conf`.
- Adjust the **`product.screen`** / **`cart.do`** ratio via each stanza’s **`count`**.

### Workshop modes: infrastructure vs NK attack

Two storylines share the same baseline traffic; the NK stanza is toggled without editing Eventgen by hand.

| Mode | Enable / disable | After toggle |
| ---- | ---------------- | ------------ |
| **Infrastructure** (default) | `make s4r-attack-nk-disable` | `make restart` (recommended) |
| **Active threat** | `make s4r-attack-nk-enable` | `make restart` (required) |

Check current mode: **`make s4r-attack-nk-status`**. Script: **`scripts/toggle-s4r-attack-nk.sh`** (`enable` \| `disable` \| `status`). Sets **`disabled = false`** or **`disabled = true`** on **`[attack.nk.purchase.sample]`** in **`eventgen.conf`**.

Wait **1–2 minutes** after restart before validating in Search (narrow time range to **last 15m** so old uniform traffic does not mask the attack).

#### What each S4R agent should see

| Agent | Infrastructure (default) | Active threat (NK enabled) |
| ----- | ------------------------ | --------------------------- |
| **IT Ops** | ~40% errors site-wide; **503** / **404** lead | Same baseline errors; NK adds **401** / **403** on purchases |
| **DevOps** | ~40% failure rate on **all** platforms (server-wide) | Scripted UAs (`python-requests`, `curl`) fail more than browsers; still not a single-OS mobile regression |
| **Business Analytics** | Lost revenue spread across products | NK skew on **`CM-1`** (ManHawk); Pyongyang tops failed-purchase geo |
| **Security & Fraud** | No geo concentration; ~1 event per IP | **North Korea** / **Pyongyang** dominates failed purchases; same few **175.45.*** IPs repeat |

Power User synthesis: **infrastructure** → “fix the web tier”; **active threat** → “geo + scripted UA concentration warrants Security review, but IT Ops may still see 503/404 from baseline.”

#### Validation SPL

Canonical queries for both workshop modes: **[S4R-SPL-CATALOG.md § Workshop modes](S4R-SPL-CATALOG.md#-workshop-modes-infrastructure-vs-threat)** (and per-team § in the same file). Agents and dashboards should use that catalog — not duplicate SPL here.

NK attack token sources: **`samples/nk_clientip.txt`**, **`nk_status.txt`**, **`nk_useragent.txt`**, **`nk_product_id.txt`**.

#### Troubleshooting

| Symptom | Likely cause | Fix |
| ------- | ------------ | --- |
| `make s4r-attack-nk-enable` but no NK events | Splunk not restarted | `make restart`, wait ~2 min |
| Still no NK UAs / IPs | Missing sample template | Confirm **`samples/attack.nk.purchase.sample`** exists (basename must match stanza) |
| NK mode “stuck” on after disable | Container still running old config | `make s4r-attack-nk-disable` then **`make restart`** |
| Geo shows NK but agents say “infrastructure” | Time range too wide | Use **last 15m** after enable; baseline traffic dilutes the signal |

See [S4R-AGENTS.md](S4R-AGENTS.md) for Power User delegation and [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) for all workshop SPL.

## App metadata (compliance)

| File | Purpose |
| ---- | ------- |
| `default/app.conf` | **`[package] id`**, **`[launcher] version`**, UI label/description |
| `metadata/default.meta` | Export/ACL for shipped objects (`props`, `transforms`, lookup CSV, `eventgen.conf`) |
| `metadata/meta.conf` | Default ACL for new objects created in-app |

**Do not package** runtime paths: `local/`, `metadata/local.meta`, `.DS_Store` (excluded in **`package-s4r.yml`**). **`local/`** may contain HEC inputs or tokens from a live container — keep gitignored.

**Not yet in repo (workshop follow-ups):** Dashboard Studio view under `default/data/ui/views/`, **`platform`** field extraction (Lab 4), app icon under `appserver/static/`.

## See also

- [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) — canonical SPL for Labs 3–7 (agents + dashboards)
- [S4R-DASHBOARD.md](S4R-DASHBOARD.md) — dashboard layout (Labs 3–7)
- [ARCHITECTURE.md](ARCHITECTURE.md) — where SA-S4R fits in the stack
- [ARCHITECTURE.md](ARCHITECTURE.md) — volumes and persistence
