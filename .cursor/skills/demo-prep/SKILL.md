---
name: demo-prep
description: >-
  Pre-demo health check for splunk-mcp — stack status, MCP verify, S4R workshop
  mode, and MCP auth-failure monitoring. Use when the user invokes /demo-prep,
  asks to prepare for a demo/presentation, or wants a go/no-go before a meeting.
disable-model-invocation: true
---

# /demo-prep — Splunk MCP + S4R demo readiness

Run checks before a live demo or workshop. Produce a short **go / fix-first** report. Do not paste secrets, tokens, or `.env` values.

## Workflow

1. **Warm-stack reminder** — Cold `make up` after `make clean` can take several minutes. If stack is down, say so and offer `make up` (do not start unless the user asked).

2. **Run checks** (in order):
   ```bash
   make status
   make verify-mcp-remote MCP_VERIFY_CLIENT=cursor
   ```
   **S4R mode:** call **`SA-S4R_query_nk_demo_state`** (Splunk MCP) when connected; else `make s4r-attack-nk-status`.
   If `make verify-mcp-remote` fails, try `make update-mcp-client MCP_CLIENT=cursor` then re-verify. Remind user to **reload MCP** in Cursor (Settings → MCP → splunk-mcp-server).

3. **MCP auth monitoring** (only when Splunk API is ready — `make status` shows ready ✓):
   - Run as **admin** via Splunk REST (`op run --env-file=tpl.env` + admin password), **not** via `splunk_run_query` as `splunker` (`_internal` is not visible to the MCP user).
   - Use this SPL (last 30 minutes):
     ```spl
     index=_internal sourcetype=*mcp_monitoring_dashboard*
     ((event_type IN (tool_call_complete, tool_call_error))
      OR event_type IN (auth_failure, auth_invalid_audience, auth_token_decode_error))
     source_ip=*
     | eval is_tool_call=if(match(event_type, "^tool_call_"), 1, 0), is_auth_fail=1-is_tool_call
     | stats sum(is_tool_call) AS tool_calls sum(is_auth_fail) AS failed_auths
             values(auth_method) AS auth_methods dc(username) AS authenticated_users
             dc(tool_name) AS tools BY source_ip
     | eval _activity=tool_calls+failed_auths
     | sort 20 -_activity
     | fields source_ip auth_methods tool_calls failed_auths authenticated_users tools
     ```
   - **Go:** `failed_auths=0` (empty table is fine — means no failures and no tool calls yet).
   - **Cosmetic noise:** a few `auth_failure` rows right after boot usually mean stale token before MCP reload; after park-on-`make down` + early mint on `make up`, expect **zero** on a clean boot.

4. **Optional raw failures** (if `failed_auths` > 0):
   ```spl
   index=_internal sourcetype=mcp_monitoring_dashboard
   event_type IN (auth_failure, auth_invalid_audience, auth_token_decode_error) earliest=-30m
   | table _time source_ip error_message username
   | sort _time
   ```

5. **Output** using the template below. One screen; link to docs for deep fixes.

## Output template

```markdown
## Demo prep — splunk-mcp

**Verdict:** [GO / FIX FIRST]

| Check | Result |
| ----- | ------ |
| Stack (`make status`) | [ready ✓ / init failed / down] |
| S4R mode | [infrastructure / threat — `SA-S4R_query_nk_demo_state` or `make s4r-attack-nk-status`] |
| MCP verify (cursor) | [OK / failed] |
| MCP auth failures (30m) | [0 / N — from monitoring SPL] |

### If not GO
- [One-line fix per failure — e.g. `docker logs splunk-init`, `make update-mcp-client MCP_CLIENT=cursor`, reload MCP in Cursor]

### Demo entry points
- Splunk Web: https://localhost:8000
- MCP: https://localhost:8089/services/mcp
- Slides: `make marp-preview`
- Agentic workshop: "As Buttercup Power User: … delegate to all four teams" — [.cursor/agents/](.cursor/agents/)

**Docs:** [docs/poc/PRESALES.md](docs/poc/PRESALES.md) · [docs/s4r/README.md](docs/s4r/README.md)
```

## Boot hygiene (for SEs)

| Command | What it does |
| ------- | ------------ |
| `make down` | Parks MCP clients (removes `splunk-mcp-server` from configs), then stops stack |
| `make up` | Boots → mints token (`MCP_UPDATE_ON_BOOT`, default `cursor`) → registers S4R tools |
| `make up MCP_UPDATE_ON_BOOT="cursor goose claude"` | Mint once, update all three clients on boot |

After `make up`, reload MCP in Cursor before opening the MCP monitoring dashboard.

## Keep it short

- Do not run `make clean` or destructive commands unless the user explicitly asks.
- Failures in step 2 → [docs/poc/TROUBLESHOOTING.md](docs/poc/TROUBLESHOOTING.md).
