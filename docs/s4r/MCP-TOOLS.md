# S4R MCP tools — architecture and implementation

How **SA-S4R** (Splunk4Rookies) registers governed tools with **Splunk MCP Server**, without a standalone MCP server.

**Product contract:** [About MCP Server for Splunk platform](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/about-mcp-server-for-splunk-platform) · [Managing custom tools](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/managing-custom-tools-in-splunk-mcp-server)

**Related:** [ARCHITECTURE.md](../poc/ARCHITECTURE.md) · [SA-S4R-APP.md](SA-S4R-APP.md) · [AGENTS.md](AGENTS.md) · [SPL-CATALOG.md](SPL-CATALOG.md) · [CONFIGURATION.md](../poc/CONFIGURATION.md)

## Why apps expose MCP tools

[MCP Server for Splunk platform 2.0](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/about-mcp-server-for-splunk-platform) is the interface between AI clients and Splunk. Built-in tools use the `splunk_` and `saia_` prefixes. An external app adds its own tools by registering them on `POST /services/mcp_tools`. A registered tool stays hidden until it is enabled.

You do not build and operate a separate MCP server per app. **Splunk MCP Server** supplies authentication, RBAC, discovery (`tools/list`), collision checks, rate limiting, monitoring, and admin dashboards.

Execution is either an **SPL** template or an **API** call to a Splunk REST endpoint the app already owns. Clients still talk to one surface: `https://localhost:8089/services/mcp`.

This PoC registers Buttercup workshop tools (`SA-S4R_*`) that way. Built-in MCP tools (`splunk_*`, `saia_*`) remain available for ad-hoc catalog SPL. This repo uses Cursor/Claude agents calling Splunk MCP.

## Definitions

Terms match [Managing custom tools in Splunk MCP Server](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/managing-custom-tools-in-splunk-mcp-server).

| Term | Meaning in this repo |
| ---- | -------------------- |
| **Tool name** | Short id in the JSON payload (`query_nk_demo_state`). Letters, digits, underscores; must start with a letter. |
| **MCP tool name** | What clients see after the app prefix: **`SA-S4R_<tool_name>`** (for example `SA-S4R_summarize_purchase_health`). |
| **Tool ID** | Used to enable, update, or delete a tool. This stack enables **`SA-S4R:SA-S4R_<tool_name>`** (the prefixed name clients see). |
| **External App ID** | Owning Splunk app. Always **`SA-S4R`** here (same as `[package] id` in `app.conf`). Namespaces tools and batch replace. |
| **Built-in tools** | Shipped with the MCP Server app (`splunk_run_query`, `saia_*`, …). Not created, modified, or deleted via `/services/mcp_tools`. |
| **Custom / app tools** | Registered by an external app. Must be **enabled** before they appear on `tools/list`. Enabling also runs collision detection against other active tools. |
| **Execution type `spl`** | MCP substitutes `$param$` placeholders into an SPL **template** and runs a search. S4R SPL tools use `\| savedsearch "…"` so the query lives in `savedsearches.conf`. |
| **Execution type `api`** | MCP issues HTTP against a Splunk REST path (`method`, `endpoint`, optional `headers` / `params` / `body`). S4R workshop-mode tools call `/servicesNS/nobody/SA-S4R/s4r_workshop_mode`. |
| **inputSchema** | JSON Schema (`type: object`) for tool arguments, inside `s4r_mcp_tools.json`. Good `description` text improves model tool selection. |
| **`_meta`** | Execution config, tags, examples, and `external_app_id`. SPL vs API fields must not be mixed. |
| **Batch replace** | `POST /services/mcp_tools` with `{ "external_app_id", "tools": [ … ] }` atomically replaces **all** tools for that app (insert / update / delete missing, rollback on failure). |

Distinct read/write names (`query_nk_demo_state` vs `apply_nk_demo_state`) avoid MCP collision detection treating the pair as ambiguous.

## Architecture

MCP Server 2.0 exposes three layers behind one **Splunk MCP Server**:

```text
AI chat or Agent  (Cursor, Claude, Cisco AI Canvas, …)
        │
        ▼
Splunk MCP Server     collision detection · rate limiting
        │
        ├─ Native tools          splunk_run_query, splunk_get_indexes, saia_*
        ├─ Splunkbase app tools  e.g. ES notables, ITSI alerts
        └─ Customer private app  SA-S4R_*  (this PoC — Buttercup workshop)
```

**How registration works** ([Managing custom tools](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/managing-custom-tools-in-splunk-mcp-server)):

```text
SA-S4R/default/s4r_mcp_tools.json
        │
        ▼
POST /services/mcp_tools    batch replace for external_app_id=SA-S4R
        │
        ▼
POST /services/mcp_tools    enable each tool (create leaves tools disabled)
        │
        ▼
tools/list at https://localhost:8089/services/mcp
```

Backing objects the registry calls when a tool runs:

```text
type=spl  →  | savedsearch "S4R …"     →  savedsearches.conf
type=api  →  GET/POST /s4r_workshop_mode
                   →  restmap.conf + bin/s4r_workshop_mode.py
                   →  eventgen.conf  [attack.nk.purchase.sample]
```

This repo (Cursor / Claude / Goose):

```text
npx mcp-remote  +  encrypted bearer token (splunker)
        │
        ▼
https://localhost:8089/services/mcp
        │
        ├─ Built-in  splunk_* / saia_*
        └─ SA-S4R_*
```

**What the platform owns:** TLS endpoint, token auth, capability **`mcp_tool_execute`**, tool registry, collision checks, search execution as **`splunker`**.

**What SA-S4R owns:** the registration payload, governed SPL, the workshop-mode REST handler, the Eventgen stanza it toggles, and the **`s4r_workshop_control`** capability stanza.

Agents should prefer **`SA-S4R_*`** when the question matches a workshop tool; otherwise they read [SPL-CATALOG.md](SPL-CATALOG.md) and call **`splunk_run_query`**.

## App files that augment Splunk MCP

All paths are under **`SA-S4R/`** unless noted. MCP/tool packaging lives in **`default/`** (shipped with the app). Do not move these to **`local/`** — `local/` is for workshop UI (nav, dashboard, Lab 4 `platform` extraction). See [SA-S4R-APP.md](SA-S4R-APP.md) § **`default/` vs `local/`**.

| File | Required for | Role |
| ---- | ------------ | ---- |
| **`default/s4r_mcp_tools.json`** | Registration | Batch-replace payload: `external_app_id`, full tool objects (`name`, `title`, `description`, `inputSchema`, `_meta`). Source of truth for what **`scripts/register-s4r-mcp-tools.sh`** POSTs. |
| **`default/savedsearches.conf`** | SPL tools | Governed searches: **`S4R Summarize Purchase Health`**, **`S4R Geo Failed Purchase Hotspots`**, **`S4R Validate NK Attack Traffic`**. SPL should match [SPL-CATALOG.md](SPL-CATALOG.md). |
| **`default/restmap.conf`** | API tools | Exposes **`/servicesNS/nobody/SA-S4R/s4r_workshop_mode`**. Script: `s4r_workshop_mode.py`. Requires authentication; `capability = mcp_tool_execute`. |
| **`bin/s4r_workshop_mode.py`** | API tools | REST handler: reads/writes `disabled` on `[attack.nk.purchase.sample]` via Splunk config REST (`configs/conf-eventgen` and `properties/eventgen`); allowlists `mode` to `infrastructure` \| `threat`; reloads the Eventgen modinput. POST returns **200** when reload succeeds, **503** (`eventgen_reload_failed`) when the stanza was updated but Eventgen did not reload — then **`make restart`**. |
| **`default/authorize.conf`** | Workshop write path | Declares capability **`[capability::s4r_workshop_control]`** (two colons). `scripts/setup-splunk.sh` grants it to role **`mcp_user`** after the app loads (best-effort; the REST map still gates on `mcp_tool_execute`). |
| **`default/eventgen.conf`** | Baseline Eventgen | Ships NK stanza with **`disabled = true`** (infrastructure default). |
| **`local/eventgen.conf`** | Workshop mode | Gitignored override Splunk writes when MCP or `make s4r-attack-nk-*` POSTs `disabled`. Scripts do not edit this file. |
| **`scripts/register-s4r-mcp-tools.sh`** | **`splunk-init`** | Called at the end of **`setup-splunk.sh`**. `POST /services/mcp_tools` batch replace, enable each tool, reload `conf-savedsearches`. Enable or reload non-2xx **fails init**. |

`tools/list` reads the registry written by that POST. It does not read app conf files. Edit `s4r_mcp_tools.json` (and the saved search or REST handler the tool calls), then run `make up` so **`splunk-init`** registers again.

## Tool catalog

| MCP name | Type | Purpose | Backing |
| -------- | ---- | ------- | ------- |
| `SA-S4R_query_nk_demo_state` | API `GET` | READ-ONLY: `infrastructure` or `threat` | `s4r_workshop_mode` |
| `SA-S4R_apply_nk_demo_state` | API `POST` | WRITE: set `mode` to `infrastructure` or `threat` | same handler; body `mode=$mode$` |
| `SA-S4R_validate_nk_attack_traffic` | SPL | READ-ONLY: NK / `175.45.*` failed purchases (**last 15m**) | saved search **`S4R Validate NK Attack Traffic`** |
| `SA-S4R_summarize_purchase_health` | SPL | READ-ONLY: lost revenue, checkout outcomes, top products (**last 24h**) | saved search **`S4R Summarize Purchase Health`** |
| `SA-S4R_geo_failed_purchases` | SPL | READ-ONLY: failed-purchase geo hotspots + top cities (**last 24h**) | saved search **`S4R Geo Failed Purchase Hotspots`** |

`make` targets (`s4r-attack-nk-enable` / `disable` / `status`) remain shell fallbacks. They call the same config REST endpoint as MCP (`POST …/configs/conf-eventgen/attack.nk.purchase.sample`) and reload the Eventgen modinput.

## Bootstrap

**`splunk-init`** runs **`scripts/setup-splunk.sh`** after **`so1`** is healthy:

1. Create role **`mcp_user`** with **`mcp_tool_execute`** and `srchJobsQuota=5`, then grant **`s4r_workshop_control`**. Create user **`splunker`**.
2. **`scripts/register-s4r-mcp-tools.sh`** (same container):
   - `POST https://so1:8089/services/mcp_tools` with `s4r_mcp_tools.json` (batch replace for `external_app_id=SA-S4R`)
   - For each tool: enable `tool_id=SA-S4R:SA-S4R_<name>` with `override: true` (non-2xx **fails init**)
   - `POST …/configs/conf-savedsearches/_reload` so new saved-search stanzas are visible without **`make restart`** (non-2xx **fails init**)
3. After init exits **0**, **`make update-mcp-clients`** mints a bearer token into client config (not the repo).

Re-register after editing tool JSON or saved searches:

```bash
make up
```

That starts the exited **`splunk-init`** container again. **`make down && make up`** is the full restart.

The product API authenticates with a bearer token for a user that has **`mcp_tool_admin`**. This local PoC posts as **`admin`** with basic auth (`SPLUNK_PASSWORD`) to `/services/mcp_tools`. Runtime tool **execution** uses the **`splunker`** bearer token on `/services/mcp`. Do not commit either secret.

## Security

- **`splunker`** invokes MCP tools only; it does not get `admin` or broad `edit_local_apps`.
- **`SA-S4R_apply_nk_demo_state`** is a configuration write — call it only on explicit user request.
- Handler allowlists `mode` to `infrastructure` \| `threat` only.
- Capability **`mcp_tool_execute`** is required to call tools; **`s4r_workshop_control`** documents workshop-mode intent on the role.

## Agent usage

1. **Read mode** before infrastructure-vs-threat synthesis: `SA-S4R_query_nk_demo_state`.
2. **Set mode** when the user asks to start/stop the NK storyline: `SA-S4R_apply_nk_demo_state({ "mode": "threat" })`.
3. **Validate NK data** after enabling threat mode (~1–2 min): `SA-S4R_validate_nk_attack_traffic`.
4. **Business KPIs:** `SA-S4R_summarize_purchase_health` — prefer over hand-written SPL for catalog § Business Analytics totals.
5. **Security geo:** `SA-S4R_geo_failed_purchases` (**last 24h**). Pair with **`SA-S4R_validate_nk_attack_traffic`** for NK signal (**last 15m**).

## Candidate tools (not yet implemented)

| Tool | Purpose | Backing |
| ---- | ------- | ------- |
| `s4r_list_catalog_sections` | List team sections and one-line intent | `SPL-CATALOG.md` structure |
| `s4r_run_team_query` | Run a **pre-approved** catalog query by team + query id | Catalog snippets + `splunk_run_query` |

Additional catalog queries (IT Ops, DevOps) can follow the M2 pattern: stanza in `savedsearches.conf`, SPL `template` in `s4r_mcp_tools.json`, then `make up`.

## Milestones

- [x] **M0** — Design doc + branch
- [x] **M1** — REST handler + MCP registration for workshop mode
- [x] **M2** — Saved-search MCP tools (`validate_nk_attack_traffic`, `summarize_purchase_health`, `geo_failed_purchases`); more catalog queries optional
- [ ] **M3** — Update all specialist agents; `make verify` path for S4R tools
- [x] **M4** — Demo slides / S4R-DEMO.md mention governed tools + in-chat NK toggle
- [x] **M5** — Deck + this doc follow MCP Server 2.0 custom-tool registration (`s4r_mcp_tools.json`, then enable)
