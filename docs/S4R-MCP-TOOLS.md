# S4R-specific MCP tools

**Status:** workshop mode tools implemented (`SA-S4R_query_nk_demo_state`, `SA-S4R_apply_nk_demo_state`, `SA-S4R_validate_nk_attack_traffic`, `SA-S4R_summarize_purchase_health`, `SA-S4R_geo_failed_purchases`).  
**Related:** [S4R-AGENTS.md](S4R-AGENTS.md) · [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) · [SA-S4R-APP.md](SA-S4R-APP.md) · [Splunk MCP 1.3 custom tools](https://help.splunk.com/en/splunk-enterprise/mcp-server-for-splunk-platform/1.3/managing-custom-tools-in-splunk-mcp-server)

## Problem

Workshop agents today use **generic** Splunk MCP tools (`splunk_run_query`, `saia_*`) and a large **SPL catalog** in `docs/S4R-SPL-CATALOG.md`. That works but:

- Models must read the catalog and compose SPL (higher token cost, more drift).
- Workshop guardrails (time range, `platform` rex, lookup joins, NK threat mode) are repeated in every agent prompt.
- Demo operators toggled NK attack mode via Makefile only (now also via MCP).

## Implemented: workshop mode via MCP

Natural-language prompts such as *“start the North Korean attack simulation”* map to MCP tools that call a **custom REST handler** in **SA-S4R** (not raw Splunk REST from the agent).

| Tool | Type | Purpose |
| ---- | ---- | ------- |
| `SA-S4R_query_nk_demo_state` | API `GET` | READ-ONLY: returns `infrastructure` or `threat` |
| `SA-S4R_apply_nk_demo_state` | API `POST` | WRITE: sets `mode` to `infrastructure` or `threat` |
| `SA-S4R_validate_nk_attack_traffic` | SPL (saved search) | READ-ONLY: runs **`S4R Validate NK Attack Traffic`** — confirms NK / `175.45.*` failed purchases in **last 15m** |
| `SA-S4R_summarize_purchase_health` | SPL (saved search) | READ-ONLY: runs **`S4R Summarize Purchase Health`** — lost revenue, checkout outcomes, top products (**last 24h**) |
| `SA-S4R_geo_failed_purchases` | SPL (saved search) | READ-ONLY: runs **`S4R Geo Failed Purchase Hotspots`** — failed-purchase geo hotspots + top cities (**last 24h**) |

### App files (`SA-S4R/default/`)

| File | Role |
| ---- | ---- |
| `bin/s4r_workshop_mode.py` | REST handler — edits `[attack.nk.purchase.sample]` in `eventgen.conf`, reloads Eventgen modinput |
| `restmap.conf` | Exposes `/servicesNS/nobody/SA-S4R/s4r_workshop_mode` |
| `authorize.conf` | Capability `s4r_workshop_control` (granted to `mcp_user`) |
| `s4r_mcp_tools.json` | MCP tool definitions (batch replace payload) |
| `tool_input_payload_signatures.json` | Input schemas for app-packaged tool registration |
| `tools.conf` | App-packaged tool metadata; saved-search tools reference `savedsearches.conf` |
| `savedsearches.conf` | Governed SPL (e.g. **`S4R Validate NK Attack Traffic`**, **`S4R Summarize Purchase Health`**, **`S4R Geo Failed Purchase Hotspots`**) |

`make` targets (`s4r-attack-nk-enable` / `disable` / `status`) remain as operator fallbacks; they edit the same `default/eventgen.conf` stanza.

### Bootstrap

`make up` after **`splunk-init`** exits:

1. **`scripts/setup-splunk.sh`** (inside `splunk-init`) grants **`s4r_workshop_control`** to role **`mcp_user`** (with `mcp_tool_execute`). `splunk-init` only mounts this script — it cannot run the host registrar.
2. Host **`scripts/register-s4r-mcp-tools.sh`** — `POST /services/mcp_tools` batch replace for app **`SA-S4R`** (needs **`jq`** on the host; see [INSTALLATION.md](INSTALLATION.md)).

Re-register after editing tool JSON (uses `.env` or `op run --env-file=tpl.env`, same as `make up`):

```bash
make register-s4r-mcp-tools   # or: ./scripts/register-s4r-mcp-tools.sh
```

Tool names are intentionally distinct (`query_*` vs `apply_*`) so Splunk MCP collision detection does not flag the read/write pair as ambiguous.

### Security

- **`splunker`** invokes MCP tools only; it does not get `admin` or broad `edit_local_apps`.
- **`SA-S4R_apply_nk_demo_state`** is a configuration write — agents should call it only on explicit user request.
- Handler allowlists `mode` to `infrastructure` \| `threat` only.

### Agent usage

1. **Read mode** before infrastructure-vs-threat synthesis: `SA-S4R_query_nk_demo_state`.
2. **Set mode** when the user asks to start/stop the NK storyline: `SA-S4R_apply_nk_demo_state({ "mode": "threat" })`.
3. **Validate NK data** after enabling threat mode (~1–2 min): `SA-S4R_validate_nk_attack_traffic` (or saved search **`S4R Validate NK Attack Traffic`** in Splunk UI).
4. **Business KPIs** (lost revenue, checkout failure): `SA-S4R_summarize_purchase_health` — prefer over hand-written SPL for catalog § Business Analytics totals.
5. **Security geo** (failed-purchase hotspots, top cities): `SA-S4R_geo_failed_purchases` — prefer for catalog § Security & Fraud geo panels (**last 24h**). Pair with **`SA-S4R_validate_nk_attack_traffic`** when confirming NK threat signal (**last 15m**).

## M2: saved-search MCP tools

**M2** is catalog-backed **saved search → MCP tool** wiring: SPL lives in **`savedsearches.conf`**; the MCP tool runs that search (via `| savedsearch` in `s4r_mcp_tools.json` + matching `tools.conf` stanza). Shipped: **`validate_nk_attack_traffic`**, **`summarize_purchase_health`**, **`geo_failed_purchases`**. Additional catalog queries (IT Ops, DevOps) can follow the same pattern.

## Candidate tools (not yet implemented)

| Tool | Purpose | Backing |
| ---- | ------- | ------- |
| `s4r_list_catalog_sections` | List team sections and one-line intent | `S4R-SPL-CATALOG.md` structure |
| `s4r_run_team_query` | Run a **pre-approved** catalog query by team + query id | Catalog snippets + `splunk_run_query` |

## Milestones

- [x] **M0** — Design doc + branch
- [x] **M1** — REST handler + MCP registration for workshop mode
- [x] **M2** — Saved-search MCP tools (`validate_nk_attack_traffic`, `summarize_purchase_health`, `geo_failed_purchases`); more catalog queries optional
- [ ] **M3** — Update all specialist agents; `make verify` path for S4R tools
- [x] **M4** — Demo slides / S4R-DEMO.md mention governed tools + in-chat NK toggle

## References

- Splunk MCP custom tools: [Managing custom tools (1.3)](https://help.splunk.com/en/splunk-enterprise/mcp-server-for-splunk-platform/1.3/managing-custom-tools-in-splunk-mcp-server)
- Workshop SPL: [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md)
- Eventgen / NK toggle: [SA-S4R-APP.md](SA-S4R-APP.md)
- MCP client wiring: [CONFIGURATION.md](CONFIGURATION.md)
