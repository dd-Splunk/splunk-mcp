---
name: demo-prep
description: >-
  Pre-demo go/no-go for local splunk-mcp. Splunkbase app pins, make status/verify,
  SA-S4R_* MCP smoke, admin auth stats. Use only when the user invokes /demo-prep
  or explicitly asks to prepare for a live demo.
disable-model-invocation: true
---

# /demo-prep

Do not paste secrets. Do not `make up` / `make clean` / change NK mode unless the user asked.

## Run (in order)

1. `make demo-prep` — Splunkbase pins first (so a 404 pin is visible even if the stack is down), then status + `verify-mcp-remote`.
   - Pins **MISSING**: next `make up` can 404 (so1 unhealthy; ansible `Error downloading … Not Found`). FIX: bump only `/release/VERSION/` in `compose.yml` to Splunkbase default ([CONFIGURATION.md](docs/poc/CONFIGURATION.md) § Version bump). Then `make down && make up` if the user asked to recover boot.
   - Pins **STALE**: GO for today if Splunk is ready; note an optional bump before the next reboot.
   - Pins **OK** / **SKIP** (offline): continue.
   - If status is init failed / so1 not healthy: `docker logs so1 --tail 80` and look for that download 404. Do not wait out `splunk-init` “still running” while so1 is restart-looping.
2. **S4R MCP smoke** (if Splunk MCP tools are connected):
   - Call **`SA-S4R_query_nk_demo_state`**. Missing tool → FIX: `make register-s4r-mcp-tools`, reload **splunk-mcp-server**.
   - If mode is **threat**: **`SA-S4R_validate_nk_attack_traffic`**. Empty rows → wait ~1–2 min or FIX Eventgen; do not apply threat yourself.
   - If mode is **infrastructure**: skip validate (empty NK is expected). Optional one-shot **`SA-S4R_summarize_purchase_health`** only if you need proof Eventgen purchases exist.
   - Else (no MCP): `make s4r-attack-nk-status`.
3. If Splunk is ready: `make mcp-auth-failures` (admin `_internal`; not MCP). On `failed_auths>0`, `make mcp-auth-failures DETAIL=1`. If secrets missing, skip and say so.
4. If MCP verify failed: `make update-mcp-client MCP_CLIENT=cursor`, reload **splunk-mcp-server**. Verify must accept pinned `mcp-remote@x.y.z` in client args.

Cold `make up` after `make clean` takes several minutes.

## Report

```markdown
## Demo prep — splunk-mcp
**Verdict:** GO | FIX FIRST

| Check | Result |
| ----- | ------ |
| Splunkbase pins | OK / STALE / MISSING / SKIP |
| Stack | ready ✓ / init failed / down |
| MCP verify | OK / failed |
| S4R tools | `SA-S4R_query_nk_demo_state` OK / missing |
| S4R mode | infrastructure / threat |
| S4R data | skip (infra) / NK rows (threat) / empty wait |
| MCP auth 30m | failed_auths=N (0 or empty = GO) |

### If not GO
- pins MISSING → bump `compose.yml` `/release/VERSION/` (do not invent URLs; use Splunkbase default)
- so1 404 in logs → same bump, then `make down && make up` only if the user asked
- MCP / S4R → `make register-s4r-mcp-tools`, reload MCP, `docker logs splunk-init`
```

**Entry points:** `https://localhost:8000` · `https://localhost:8089/services/mcp` · `make marp-preview`

**Docs:** [docs/s4r/MCP-TOOLS.md](docs/s4r/MCP-TOOLS.md) · [docs/poc/TROUBLESHOOTING.md](docs/poc/TROUBLESHOOTING.md) · [docs/poc/CONFIGURATION.md](docs/poc/CONFIGURATION.md)
