# Workshop local assets (tracked template)

Copy to **`../local/`** (gitignored) for the Buttercup Enterprises nav tab, **`platform`** field extraction (Lab 4), and Dashboard Studio view:

```bash
make s4r-dashboard-local
# or: ./scripts/install-s4r-local-dashboard.sh
```

Then **`make restart`** if Splunk is already running.

## Splunk best practice: `local/` only

**All direct Splunk interaction** for this app — Splunk Web saves, field extractor, Dashboard Studio, nav editor, saved searches — must land under **`SA-S4R/local/`**. **Never** customize **`SA-S4R/default/`** at runtime; shipped **`default/`** is overwritten on app upgrade/reinstall.

| Put here | Not here |
| -------- | -------- |
| **`local/`** (this install target) | **`default/`** |
| Workshop dashboard, nav tab, **`platform`** extraction | PoC baseline (Eventgen, core props, barebones nav) |

Maintainers: update this **`local.example/`** tree in git; users run **`make s4r-dashboard-local`**. Do not commit personal **`local/`** content.

Shipped **`default/`** stays on Splunk’s barebones nav only; workshop UI is not included in public **`SA-S4R.spl`** builds (see `.github/workflows/package-s4r.yml`).

Layout spec: [docs/S4R-DASHBOARD.md](../../docs/S4R-DASHBOARD.md). Full policy: [docs/SA-S4R-APP.md](../../docs/SA-S4R-APP.md).
