# Splunk4Rookies (SA-S4R)

PoC Splunk app: Buttercup Enterprises **Eventgen** traffic (`access_combined`), field extractions, **`product_codes.csv`** lookup, and dashboard static assets.

Install folder name must remain **`SA-S4R`** (Eventgen token paths and static URLs use this id).

**Splunk best practice:** direct Splunk UI changes (nav, dashboards, field extractions, saved searches) go in **`local/`** only — **never** in **`default/`**. Workshop pack: **`local.example/`** → **`make s4r-dashboard-local`**. Details: [docs/SA-S4R-APP.md](../docs/SA-S4R-APP.md) § **`default/` vs `local/`**.

Full stack and layout: [docs/SA-S4R-APP.md](../docs/SA-S4R-APP.md). SPL runbook: [docs/S4R-SPL-CATALOG.md](../docs/S4R-SPL-CATALOG.md). Workshop agents: [docs/S4R-AGENTS.md](../docs/S4R-AGENTS.md) and [`.cursor/agents/`](../.cursor/agents/).

**Workshop modes** (`scripts/toggle-s4r-attack-nk.sh`):

| Command | Mode |
| ------- | ---- |
| `make s4r-attack-nk-status` | Show enabled / disabled |
| `make s4r-attack-nk-enable` | Active threat (NK geo on failed purchases) |
| `make s4r-attack-nk-disable` | Infrastructure failure (default) |

After enable or disable, run **`make restart`** and wait ~2 minutes. Validation SPL and per-agent expectations: [docs/SA-S4R-APP.md](../docs/SA-S4R-APP.md).

**Buttercup dashboard (workshop):** install local-only nav, **`platform`** extraction, and Dashboard Studio view (not shipped in **`default/`**):

```bash
make s4r-dashboard-local   # copies local.example/ → local/ (gitignored)
make restart               # if Splunk is already up
```

Template: **`local.example/`**. Spec: [docs/S4R-DASHBOARD.md](../docs/S4R-DASHBOARD.md).
