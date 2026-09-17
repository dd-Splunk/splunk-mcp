---
name: demo-prep
description: >-
  Pre-demo go/no-go for local splunk-mcp. Uses SA-S4R_* MCP tools for workshop
  mode and data smoke, plus make status/verify and admin auth stats. Use only
  when the user invokes /demo-prep or explicitly asks to prepare for a live demo.
disable-model-invocation: true
---

# /demo-prep

Do not paste secrets. Do not `make up` / `make clean` / change NK mode unless the user asked.

## Run (in order)

1. `make demo-prep` — status + `verify-mcp-remote` + warm-stack tip.
2. **S4R MCP smoke** (if Splunk MCP tools are connected):
   - Call **`SA-S4R_query_nk_demo_state`**. Missing tool → FIX: `make register-s4r-mcp-tools`, reload **splunk-mcp-server**.
   - If mode is **threat**: **`SA-S4R_validate_nk_attack_traffic`**. Empty rows → wait ~1–2 min or FIX Eventgen; do not apply threat yourself.
   - If mode is **infrastructure**: skip validate (empty NK is expected). Optional one-shot **`SA-S4R_summarize_purchase_health`** only if you need proof Eventgen purchases exist.
   - Else (no MCP): `make s4r-attack-nk-status`.
3. If Splunk is ready: `make mcp-auth-failures` (admin `_internal`; not MCP). On `failed_auths>0`, `make mcp-auth-failures DETAIL=1`. If secrets missing, skip and say so.
4. If MCP verify failed: `make update-mcp-client MCP_CLIENT=cursor`, reload **splunk-mcp-server**.

Cold `make up` after `make clean` takes several minutes.

## Report

```markdown
## Demo prep — splunk-mcp
**Verdict:** GO | FIX FIRST

| Check | Result |
| ----- | ------ |
| Stack | ready ✓ / init failed / down |
| MCP verify | OK / failed |
| S4R tools | `SA-S4R_query_nk_demo_state` OK / missing |
| S4R mode | infrastructure / threat |
| S4R data | skip (infra) / NK rows (threat) / empty wait |
| MCP auth 30m | failed_auths=N (0 or empty = GO) |

### If not GO
- one-line fix each (`docker logs splunk-init`, `make register-s4r-mcp-tools`, reload MCP)
```

**Entry points:** `https://localhost:8000` · `https://localhost:8089/services/mcp` · `make marp-preview`

**Docs:** [docs/s4r/MCP-TOOLS.md](docs/s4r/MCP-TOOLS.md) · [docs/poc/TROUBLESHOOTING.md](docs/poc/TROUBLESHOOTING.md)
