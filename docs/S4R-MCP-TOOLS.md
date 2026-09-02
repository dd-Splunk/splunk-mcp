# S4R MCP tools — architecture and implementation

How **SA-S4R** (Splunk4Rookies) registers governed tools with **Splunk MCP Server**, without a standalone MCP server.

**Related:** [ARCHITECTURE.md](ARCHITECTURE.md) · [SA-S4R-APP.md](SA-S4R-APP.md) · [S4R-AGENTS.md](S4R-AGENTS.md) · [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) · [CONFIGURATION.md](CONFIGURATION.md) · [Managing custom tools (MCP 1.3)](https://help.splunk.com/en/splunk-enterprise/mcp-server-for-splunk-platform/1.3/managing-custom-tools-in-splunk-mcp-server)

**Recordings:** [Developer Day 2026 playlist](https://www.youtube.com/playlist?list=PLxkFdMSHYh3T2mFyCdg8iz9ef068gLdfJ) · session **[Apps with MCP Tools](https://www.youtube.com/watch?v=fjGCf0QiBJc)** · recap [community announcement](https://community.splunk.com/t5/Product-News-Announcements/Splunk-Developer-Day-announcements-AI-agents-MCP-tools/ba-p/761316)

## Why apps expose MCP tools

[Splunk Developer Day 2026](https://www.youtube.com/playlist?list=PLxkFdMSHYh3T2mFyCdg8iz9ef068gLdfJ) framed apps as the way Splunk insights are packaged for the customer. **MCP** lets those insights reach LLMs for analysis and action.

The **[Apps with MCP Tools](https://www.youtube.com/watch?v=fjGCf0QiBJc)** session (official description):

> Apps are now able to create MCP tools from custom rest endpoints and saved searches. These are exposed to the Splunk MCP server via a new conf file. `tools.conf` has a stanza per tool shared over MCP specifying the name of the tool and the description to be shared with agents and LLMs.

You do **not** build and operate a separate MCP server per app. **Splunk MCP Server** supplies authentication, RBAC, discovery (`tools/list`), collision checks, rate limiting, monitoring, and admin dashboards.

Execution is either an **SPL** template (often a saved search) or an **API** call to a Splunk REST endpoint the app already owns. Clients still talk to one surface: `https://localhost:8089/services/mcp`.

This PoC follows that model for Buttercup workshop tools (`SA-S4R_*`). Built-in MCP tools (`splunk_*`, `saia_*`) remain available for ad-hoc catalog SPL. In-app SDK agents ([Splunk Apps with AI: Agents Deployed in Apps](https://www.youtube.com/watch?v=JEXpWDyeBiI)) are a different path — this repo uses Cursor/Claude agents calling Splunk MCP.

## Definitions

Terms match [Splunk MCP Server 1.3 custom tools](https://help.splunk.com/en/splunk-enterprise/mcp-server-for-splunk-platform/1.3/managing-custom-tools-in-splunk-mcp-server).

| Term | Meaning in this repo |
| ---- | -------------------- |
| **Tool name** | Short id in the JSON payload (`query_nk_demo_state`). Letters, digits, underscores; must start with a letter. |
| **MCP tool name** | What clients see after the app prefix: **`SA-S4R_<tool_name>`** (for example `SA-S4R_summarize_purchase_health`). |
| **Tool ID** | Globally unique `external_app_id:mcp_tool_name`. Example: `SA-S4R:SA-S4R_summarize_purchase_health`. Used to enable, update, or delete a tool. |
| **External App ID** | Owning Splunk app. Always **`SA-S4R`** here (same as `[package] id` in `app.conf`). Namespaces tools and batch replace. |
| **Built-in tools** | Shipped with the MCP Server app (`splunk_run_query`, `saia_*`, …). Not created, modified, or deleted via `/services/mcp_tools`. |
| **Custom / app tools** | Registered by an external app. Must be **enabled** before they appear on `tools/list`. Enabling also runs collision detection against other active tools. |
| **Execution type `spl`** | MCP substitutes `$param$` placeholders into an SPL **template** and runs a search. S4R SPL tools use `\| savedsearch "…"` so the query lives in `savedsearches.conf`. |
| **Execution type `api`** | MCP issues HTTP against a Splunk REST path (`method`, `endpoint`, optional `headers` / `params` / `body`). S4R workshop-mode tools call `/servicesNS/nobody/SA-S4R/s4r_workshop_mode`. |
| **inputSchema** | JSON Schema (`type: object`) for tool arguments. Good `description` text improves model tool selection. |
| **`_meta`** | Execution config, tags, examples, and `external_app_id`. SPL vs API fields must not be mixed. |
| **Batch replace** | `POST /services/mcp_tools` with `{ "external_app_id", "tools": [ … ] }` atomically replaces **all** tools for that app (insert / update / delete missing, rollback on failure). |

Distinct read/write names (`query_nk_demo_state` vs `apply_nk_demo_state`) avoid MCP collision detection treating the pair as ambiguous.

## Architecture

Developer Day **[Apps with MCP Tools](https://www.youtube.com/watch?v=fjGCf0QiBJc)** (Michael Szebenyi, 13 May 2026) shows three tool layers behind one **Splunk MCP Server**:

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

**How it works** (session “How Does It Work?”):

```text
SA-S4R app
  tools.conf  +  tool_input_payload_signatures.json
  savedsearches.conf  →  Saved Search
  restmap.conf        →  Custom REST handler
        │
        ▼
MCP Tool Registration API   (app install, or this PoC: POST /services/mcp_tools)
        │
        ▼
MCP tools callable at https://localhost:8089/services/mcp
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
               ├─ type=spl  →  | savedsearch "S4R …"     →  savedsearches.conf
               └─ type=api  →  GET/POST /s4r_workshop_mode
                                      →  restmap.conf + bin/s4r_workshop_mode.py
                                      →  eventgen.conf  [attack.nk.purchase.sample]
```

**What the platform owns:** TLS endpoint, token auth, capability **`mcp_tool_execute`**, tool registry, collision checks, search execution as **`splunker`**.

**What SA-S4R owns:** tool definitions, governed SPL, the workshop-mode REST handler, Eventgen stanza it toggles, and the **`s4r_workshop_control`** capability stanza.

Agents should prefer **`SA-S4R_*`** when the question matches a workshop tool; otherwise they read [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) and call **`splunk_run_query`**.

## App files that augment Splunk MCP

All paths are under **`SA-S4R/`** unless noted. MCP/tool packaging lives in **`default/`** (shipped with the app). Do not move these to **`local/`** — `local/` is for workshop UI (nav, dashboard, Lab 4 `platform` extraction). See [SA-S4R-APP.md](SA-S4R-APP.md) § **`default/` vs `local/`**.

| File | Required for | Role |
| ---- | ------------ | ---- |
| **`default/s4r_mcp_tools.json`** | This PoC’s registration | Batch-replace payload: `external_app_id`, full tool objects (`name`, `title`, `description`, `inputSchema`, `_meta`). Source of truth for what **`scripts/register-s4r-mcp-tools.sh`** POSTs. |
| **`default/tools.conf`** | Developer Day app packaging | One stanza per tool. Session examples: **`[savedsearches:<name>]`** (`search=` saved-search name, `description`, `tags`) and **`[restmap:<name>]`** (`endpoint_name`, `method`, `headers`, `tags`). This PoC currently lists the three SPL tools with short names + `savedsearch=`; API tools are in `restmap.conf` + `s4r_mcp_tools.json`. |
| **`default/tool_input_payload_signatures.json`** | LLM call schema | Per-tool JSON so the model knows arguments (session: “shared with LLMs so it knows how to call the tool”). Mirrors `inputSchema` in `s4r_mcp_tools.json`. |
| **`default/savedsearches.conf`** | SPL tools | Governed searches: **`S4R Summarize Purchase Health`**, **`S4R Geo Failed Purchase Hotspots`**, **`S4R Validate NK Attack Traffic`**. SPL should match [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md). |
| **`default/restmap.conf`** | API tools | Exposes **`/servicesNS/nobody/SA-S4R/s4r_workshop_mode`**. Script: `s4r_workshop_mode.py`. Requires authentication; `capability = mcp_tool_execute`. |
| **`bin/s4r_workshop_mode.py`** | API tools | REST handler: reads/writes `disabled` on `[attack.nk.purchase.sample]` in `eventgen.conf`; allowlists `mode` to `infrastructure` \| `threat`; reloads the Eventgen modinput. |
| **`default/authorize.conf`** | Workshop write path | Declares capability **`[capability::s4r_workshop_control]`** (two colons). `scripts/setup-splunk.sh` grants it to role **`mcp_user`** after the app loads (best-effort; the REST map still gates on `mcp_tool_execute`). |
| **`default/eventgen.conf`** | Data mode | Stanza the handler toggles. Same file as `make s4r-attack-nk-*`. |
| **`scripts/register-s4r-mcp-tools.sh`** | Host bootstrap | `POST /services/mcp_tools` batch replace, enable each tool, reload `conf-savedsearches`. Needs **`jq`** and admin credentials from `.env` or `op run --env-file=tpl.env`. |

Two complementary packaging paths:

1. **App files (Developer Day):** `tools.conf` + `tool_input_payload_signatures.json` + `savedsearches.conf` / `restmap.conf`. Session flow: app install → MCP Tool Registration API.
2. **REST registration (this PoC):** after **`splunk-init`**, the host script batch-replaces from **`s4r_mcp_tools.json`** so tools are registered **and enabled** on local Enterprise without relying on install-time discovery. Keep the JSON, `tools.conf` stanzas, and signatures in sync when you add or rename a tool.

### Official `tools.conf` shapes (session examples)

Saved search:

```ini
[savedsearches:broken_block_search]
search = broken_block_search
description = A search for the number of blocks broken by all players
tags = Blocks, broken, minecraft
```

Custom REST:

```ini
[restmap:myhello]
description = A simple hello world!
endpoint_name = myhello
method = get
headers = Accept:*/*
tags = Hello, hola, welcome
```

SA-S4R mapping: saved-search tools → `S4R Summarize Purchase Health`, `S4R Geo Failed Purchase Hotspots`, `S4R Validate NK Attack Traffic`; REST tools → `s4r_workshop_mode` (`query_nk_demo_state` / `apply_nk_demo_state`).

## Tool catalog

| MCP name | Type | Purpose | Backing |
| -------- | ---- | ------- | ------- |
| `SA-S4R_query_nk_demo_state` | API `GET` | READ-ONLY: `infrastructure` or `threat` | `s4r_workshop_mode` |
| `SA-S4R_apply_nk_demo_state` | API `POST` | WRITE: set `mode` to `infrastructure` or `threat` | same handler; body `mode=$mode$` |
| `SA-S4R_validate_nk_attack_traffic` | SPL | READ-ONLY: NK / `175.45.*` failed purchases (**last 15m**) | saved search **`S4R Validate NK Attack Traffic`** |
| `SA-S4R_summarize_purchase_health` | SPL | READ-ONLY: lost revenue, checkout outcomes, top products (**last 24h**) | saved search **`S4R Summarize Purchase Health`** |
| `SA-S4R_geo_failed_purchases` | SPL | READ-ONLY: failed-purchase geo hotspots + top cities (**last 24h**) | saved search **`S4R Geo Failed Purchase Hotspots`** |

`make` targets (`s4r-attack-nk-enable` / `disable` / `status`) remain operator fallbacks; they edit the same Eventgen stanza.

## Bootstrap

`make up` after **`splunk-init`** exits **0**:

1. **`scripts/setup-splunk.sh`** (inside `splunk-init`) creates role **`mcp_user`** with **`mcp_tool_execute`** and `srchJobsQuota=5`, then grants **`s4r_workshop_control`**. `splunk-init` only mounts this script — it cannot run the host registrar.
2. Host **`scripts/register-s4r-mcp-tools.sh`**:
   - `POST https://localhost:8089/services/mcp_tools` with `s4r_mcp_tools.json` (batch replace for `external_app_id=SA-S4R`)
   - For each tool: enable `tool_id=SA-S4R:SA-S4R_<name>` with `override: true`
   - `POST …/configs/conf-savedsearches/_reload` so new saved-search stanzas are visible without **`make restart`**
3. **`make update-mcp-clients`** mints a bearer token into client config (not the repo).

Re-register after editing tool JSON or saved searches:

```bash
make register-s4r-mcp-tools   # or: ./scripts/register-s4r-mcp-tools.sh
```

Admin registration uses **`SPLUNK_PASSWORD`** (basic auth to `/services/mcp_tools`). Runtime tool **execution** uses the **`splunker`** bearer token on `/services/mcp`. Do not commit either secret.

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
| `s4r_list_catalog_sections` | List team sections and one-line intent | `S4R-SPL-CATALOG.md` structure |
| `s4r_run_team_query` | Run a **pre-approved** catalog query by team + query id | Catalog snippets + `splunk_run_query` |

Additional catalog queries (IT Ops, DevOps) can follow the M2 pattern: stanza in `savedsearches.conf`, matching `tools.conf` + signature, SPL `template` in `s4r_mcp_tools.json`, then `make register-s4r-mcp-tools`.

## Milestones

- [x] **M0** — Design doc + branch
- [x] **M1** — REST handler + MCP registration for workshop mode
- [x] **M2** — Saved-search MCP tools (`validate_nk_attack_traffic`, `summarize_purchase_health`, `geo_failed_purchases`); more catalog queries optional
- [ ] **M3** — Update all specialist agents; `make verify` path for S4R tools
- [x] **M4** — Demo slides / S4R-DEMO.md mention governed tools + in-chat NK toggle
- [x] **M5** — Deck + this doc: Developer Day architecture (`tools.conf` / signatures / how it works)

## Developer Day 2026 recordings

Playlist: [Developer Day 2026](https://www.youtube.com/playlist?list=PLxkFdMSHYh3T2mFyCdg8iz9ef068gLdfJ)

| Session | Role for this PoC | Video |
| ------- | ----------------- | ----- |
| Apps with MCP Tools | **Primary** — `tools.conf`, signatures, saved searches, custom REST → Splunk MCP Server (Szebenyi, 13 May 2026) | [watch](https://www.youtube.com/watch?v=fjGCf0QiBJc) |
| Splunk Apps with AI: Agents Deployed in Apps | Related — agents *inside* a Splunk app (Python SDK). This repo uses Cursor agents instead. | [watch](https://www.youtube.com/watch?v=JEXpWDyeBiI) |
| Build Your First AI Agent (Agent Launchpad) | Related — Splunk AI Toolkit agents, not the S4R Cursor orchestrator | [watch](https://www.youtube.com/watch?v=W18A6q6BOA0) |
| Splunk Developer Day Kickoff | Agenda / MCP + agentic apps framing | [watch](https://www.youtube.com/watch?v=cHdAd-7ecfY) |
