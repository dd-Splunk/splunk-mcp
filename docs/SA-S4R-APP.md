## What is SA-S4R?

**SA-S4R** is a Splunk **app** mounted from the repository into the container at:

```text
/opt/splunk/etc/apps/SA-S4R
```

It is labeled in `default/app.conf` and is visible in Splunk Web as an app named **SA-S4R**. The main purpose in this repo is to ship **Eventgen** sample data and supporting **lookups** so you can run searches against synthetic **`access_combined`** traffic without manual onboarding.

## Layout

```text
SA-S4R/
├── default/
│   ├── app.conf
│   └── eventgen.conf      # Eventgen definitions
├── lookups/
│   └── product_codes.csv  # Example lookup table
├── metadata/
│   ├── local.meta
│   └── meta.conf
├── samples/               # Token sources for Eventgen
│   ├── access_combined.sample
│   ├── action.txt
│   ├── jsessionid.txt
│   ├── method.txt
│   ├── path.txt
│   ├── product_id.txt
│   ├── referer.txt
│   ├── status.txt
│   └── useragent.txt
└── local/
    └── app.conf
```

## Eventgen

Configuration lives in **`default/eventgen.conf`**. The sample stanza **`access_combined.sample`**:

- Emits events on an interval with randomized count.
- Targets index **`main`** and sourcetype **`access_combined`**.
- Replaces tokens in the sample file with random IPs, timestamps, file-based tokens (paths, status codes, user agents, etc.).

Upstream documentation: [Splunk Eventgen](https://splunk.github.io/eventgen/).

### Enabling Eventgen

Eventgen is provided by a Splunkbase app (included in `SPLUNK_APPS_URL` in `compose.yml`). After Splunk is up:

1. Confirm the Eventgen app is installed and enabled.
2. Confirm **SA-S4R** is enabled under **Apps**.
3. If events do not appear, check Splunk’s internal logs and Eventgen app status; Eventgen may require enablement per app in your Splunk version.

## Sample event file

**`samples/access_combined.sample`** is a template line for Apache/NCSA combined-style access logs. Tokens like `CLIENTIP`, `METHOD`, `PATH`, `STATUS` are substituted per `eventgen.conf`.

## Lookup table

**`lookups/product_codes.csv`** is a small CSV for demonstrations (product code → description). You can extend it and reference it from searches or knowledge objects in Splunk Web.

## Customizing

- Add or edit **`samples/*.txt`** files to change categorical random choices.
- Tune **`interval`**, **`count`**, and **`randomizeCount`** in `eventgen.conf` for load characteristics.
- Add new stanzas and `.sample` files for additional sourcetypes.

## See also

- [OVERVIEW.md](OVERVIEW.md) — where SA-S4R fits in the stack
- [ARCHITECTURE.md](ARCHITECTURE.md) — volumes and persistence
