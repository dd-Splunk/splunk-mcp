# Splunk4Rookies (SA-S4R)

PoC Splunk app: Buttercup Enterprises **Eventgen** traffic (`access_combined`), field extractions, **`product_codes`** lookup, and dashboard static assets.

Install folder name must remain **`SA-S4R`** (Eventgen token paths and static URLs use this id).

**Splunk best practice:** direct Splunk UI changes (nav, dashboards, field extractions, saved searches) go in **`local/`** only — **never** in **`default/`**. Workshop setup: **`SA-S4R/local/README`** (tracked). Details: [docs/s4r/SA-S4R-APP.md](../docs/s4r/SA-S4R-APP.md) § **`default/` vs `local/`**.

Full stack and layout: [docs/s4r/SA-S4R-APP.md](../docs/s4r/SA-S4R-APP.md). MCP tools (architecture and config files): [docs/s4r/MCP-TOOLS.md](../docs/s4r/MCP-TOOLS.md). SPL runbook: [docs/s4r/SPL-CATALOG.md](../docs/s4r/SPL-CATALOG.md). Workshop agents: [docs/s4r/AGENTS.md](../docs/s4r/AGENTS.md) and [`.cursor/agents/`](../.cursor/agents/).

**Workshop modes** (`scripts/toggle-s4r-attack-nk.sh`):

| Command | Mode |
| ------- | ---- |
| `make s4r-attack-nk-status` | Show enabled / disabled |
| `make s4r-attack-nk-enable` | Active threat (NK geo on failed purchases) |
| `make s4r-attack-nk-disable` | Infrastructure failure (default) |

After enable or disable, run **`make restart`** and wait ~2 minutes. Validation SPL and per-agent expectations: [docs/s4r/SA-S4R-APP.md](../docs/s4r/SA-S4R-APP.md).

**Buttercup dashboard (workshop):** create nav, **`platform`** extraction, and Dashboard Studio view under **`local/`** (not **`default/`**). Follow **`local/README`** and [docs/s4r/DASHBOARD.md](../docs/s4r/DASHBOARD.md). Run **`make restart`** after changes if Splunk is already up.
