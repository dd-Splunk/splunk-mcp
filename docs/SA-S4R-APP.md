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
│   ├── data/ui/nav/default.xml
│   ├── eventgen.conf           # Eventgen definitions (dual templates)
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
    ├── action.txt
    ├── jsessionid.txt
    ├── method.txt
    ├── product_id.txt
    ├── referer.txt
    ├── status.txt
    └── useragent.txt

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

Configuration lives in **`default/eventgen.conf`**. Two stanzas emit Buttercup-shaped traffic into **`main`** / **`access_combined`**:

- **`product.screen.sample`** (~67%) — `GET|POST /product.screen?uid=…&product_id=…&JSESSIONID=…`
- **`cart.do.sample`** (~33%) — `GET|POST /cart.do?action=…&product_id=…&JSESSIONID=…`

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

Both use workshop-style `HTTP 1.1`, Buttercup referers, and a trailing response-time integer.

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

## App metadata (compliance)

| File | Purpose |
| ---- | ------- |
| `default/app.conf` | **`[package] id`**, **`[launcher] version`**, UI label/description |
| `metadata/default.meta` | Export/ACL for shipped objects (`props`, `transforms`, lookup CSV, `eventgen.conf`) |
| `metadata/meta.conf` | Default ACL for new objects created in-app |

**Do not package** runtime paths: `local/`, `metadata/local.meta`, `.DS_Store` (excluded in **`package-s4r.yml`**). **`local/`** may contain HEC inputs or tokens from a live container — keep gitignored.

**Not yet in repo (workshop follow-ups):** Dashboard Studio view under `default/data/ui/views/`, **`platform`** field extraction (Lab 4), app icon under `appserver/static/`.

## See also

- [What Does the Business Want to See.md](What%20Does%20the%20Business%20Want%20to%20See.md) — dashboard build prompt (Labs 3–7)
- [OVERVIEW.md](OVERVIEW.md) — where SA-S4R fits in the stack
- [ARCHITECTURE.md](ARCHITECTURE.md) — volumes and persistence
