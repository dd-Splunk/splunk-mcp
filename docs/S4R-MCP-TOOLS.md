# S4R-specific MCP tools (prep)

**Status:** design / branch prep — not implemented.  
**Branch:** `feature/s4r-mcp-tools`  
**Related:** [S4R-AGENTS.md](S4R-AGENTS.md) · [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) · [Splunk MCP 1.3 tool namespacing](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/connecting-to-the-mcp-server-and-settings)

## Problem

Workshop agents today use **generic** Splunk MCP tools (`splunk_run_query`, `saia_*`) and a large **SPL catalog** in `docs/S4R-SPL-CATALOG.md`. That works but:

- Models must read the catalog and compose SPL (higher token cost, more drift).
- Workshop guardrails (time range, `platform` rex, lookup joins, NK threat mode) are repeated in every agent prompt.
- Demo operators toggle NK attack mode via Makefile, not via MCP.

## Goal

Expose a small, **namespaced** set of workshop tools (proposed prefix **`s4r_`**) so agents can call governed, catalog-backed operations without hand-writing SPL each time.

## Non-goals (initial)

- Replacing Splunk MCP Server or forking the Splunkbase app (7931).
- Customer Splunk Cloud OAuth flows (see [PRESALES.md § Splunk Cloud](PRESALES.md#splunk-cloud-stacks-oauth-vs-this-poc)).
- Writing arbitrary SPL from a single mega-tool (keep least privilege).

## Current stack (unchanged for now)

| Layer | Today |
| ----- | ----- |
| MCP transport | `npx mcp-remote` → `https://localhost:8089/services/mcp` |
| Auth | Encrypted bearer token (`make update-mcp-clients`) |
| Execution user | `splunker` / `mcp_user` / `mcp_tool_execute` |
| Agent data path | `splunk_run_query` + catalog § per team |

## Candidate tools (draft)

| Tool | Purpose | Backing |
| ---- | ------- | ------- |
| `s4r_get_workshop_mode` | Return infrastructure vs NK threat mode | `make s4r-attack-nk-status` logic / Eventgen stanza |
| `s4r_list_catalog_sections` | List team sections and one-line intent | `S4R-SPL-CATALOG.md` structure |
| `s4r_run_team_query` | Run a **pre-approved** catalog query by team + query id | Catalog snippets + `splunk_run_query` |
| `s4r_summarize_purchase_health` | High-level Buttercup KPIs (failure %, lost revenue) | Catalog § Business + lookups |
| `s4r_geo_failed_purchases` | Security storyline helper | Catalog § Security & Fraud |

Exact names and parameters TBD after Splunk MCP **tool management** / allowlist review (1.3 Guardrails).

## Implementation options (to decide)

1. **Sidecar MCP server (stdio)** — small Node/Python MCP in this repo; proxies to Splunk REST or calls `splunk_run_query` internally; registered as a second MCP server in Cursor/Goose.
2. **Splunk app extension** — if/when Splunk MCP supports custom tools in `SA-S4R` (investigate app hooks; may be out of scope for PoC).
3. **Thin wrapper over catalog** — generate tool schemas from `S4R-SPL-CATALOG.md` at build time (single source of truth).

**Recommendation for PoC:** option **1** — sidecar stdio server, versioned in-repo, no Splunkbase publish required for v0.

## Security / guardrails

- Read-only searches only; no `| delete`, `| collect`, or index mutation.
- Enforce catalog allowlist (query ids), not free-form SPL parameters except bounded time range.
- Same MCP user (`splunker`); no elevation to `admin`.
- Do not embed secrets in tool definitions; reuse existing client token flow.

## Agent impact

| File | Change (later) |
| ---- | -------------- |
| `.cursor/agents/s4r-*.md` | Prefer `s4r_*` tools where available; fallback to catalog + `splunk_run_query` |
| `docs/S4R-AGENTS.md` | Document tool layer in educational model diagram |
| `scripts/mcp-client.sh` | Optional second MCP server entry (`s4r-mcp` or merged config) |
| `Makefile` | `verify-s4r-mcp` target |

## Milestones

- [ ] **M0** — This doc + branch (`feature/s4r-mcp-tools`)
- [ ] **M1** — Spike: sidecar MCP lists `s4r_get_workshop_mode` + one `s4r_run_team_query`
- [ ] **M2** — Wire into `make update-mcp-clients` / `.cursor/mcp.json.example`
- [ ] **M3** — Update Power User + one specialist agent to use tools; `make verify` path
- [ ] **M4** — Demo slides / S4R-DEMO.md mention tool layer

## Open questions

1. Does Splunk MCP Server 1.3 allow **custom** tools from a companion app, or only `splunk_*` / `saia_*`?
2. One MCP server vs two in client config (Splunk + S4R sidecar)?
3. Should `s4r_*` tools call Splunk REST directly or delegate to `splunk_run_query` via loopback MCP?

## References

- Splunk MCP tool namespacing: `splunk_`, `saia_` — [Connecting (1.3)](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.3/connecting-to-the-mcp-server-and-settings)
- Workshop SPL: [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md)
- MCP client wiring: [CONFIGURATION.md](CONFIGURATION.md)
