# Splunk4Rookies — troubleshooting

Workshop-specific issues (Buttercup dashboard, NK threat mode, parallel agents). Stack bootstrap, MCP, and Docker: [../TROUBLESHOOTING.md](../poc/TROUBLESHOOTING.md).

## Dashboard or `platform` field missing

**Symptoms**: The Buttercup Enterprises dashboard tab is absent, dashboard edits disappear after rebuild, or panels that use **`platform`** return empty results.

**Cause**: Workshop UI and field-extraction assets must live under **`SA-S4R/local/`**. Fresh clones contain only the tracked **`SA-S4R/local/README`** guide; Dashboard Studio exports, nav overrides, **`local/props.conf`**, and **`metadata/local.meta`** are created locally and are not packaged into **`SA-S4R.spl`**.

**Solution**:

1. Follow **`SA-S4R/local/README`** to create the local dashboard, nav tab, metadata, and Lab 4 **`platform`** extraction.
2. If Splunk is already running, restart it after editing files under **`local/`**:

   ```bash
   make restart
   ```

3. If you saved workshop objects under **`default/`**, move or re-export them under **`local/`** and remove the duplicate default copy.

See [SA-S4R-APP.md § `default/` vs `local/`](SA-S4R-APP.md#default-vs-local-splunk-best-practice) and [DASHBOARD.md](DASHBOARD.md).

## NK attack workshop mode not visible in Search

**Symptoms**: Threat mode enabled (via **`SA-S4R_apply_nk_demo_state`** or `make s4r-attack-nk-enable`) but no `175.45.*` IPs, `python-requests`, or North Korea in `iplocation` results.

**Solution**:

1. **MCP path:** **`SA-S4R_query_nk_demo_state`** — expect `enabled: true` for threat mode. **`SA-S4R_validate_nk_attack_traffic`** (last 15m) after 1–2 min.
2. **Shell path:**

```bash
make s4r-attack-nk-status          # should print "enabled"
docker exec so1 grep -A1 'attack.nk.purchase' \
  /opt/splunk/etc/apps/SA-S4R/local/eventgen.conf 2>/dev/null \
  || docker exec so1 grep -A1 'attack.nk.purchase' \
  /opt/splunk/etc/apps/SA-S4R/default/eventgen.conf
# expect: disabled = false (threat) or true (infrastructure)

ls SA-S4R/samples/attack.nk.purchase.sample   # must exist (basename = stanza name)

make restart                       # required for shell toggle only
# wait ~2 minutes; search last 15m only
```

```spl
index=main sourcetype=access_combined action=purchase
  (useragent="*python-requests*" OR clientip=175.45.*)
| head 20
```

If still empty, confirm **SA-Eventgen** modinput is enabled (`make status`, [CONFIGURATION.md § Appendix: setup-splunk.sh](../poc/CONFIGURATION.md#appendix-setup-splunksh)). Full mode table: [SA-S4R-APP.md](SA-S4R-APP.md).

## Parallel agent searches hit `splunker` concurrency limit

**Symptoms**: Cursor launches four S4R specialist subagents; some `splunk_run_query` calls fail with:

```text
Search not executed: ... role-based concurrency limit of historical searches for user "splunker"
has been reached (usage=3, quota=3)
```

**Cause**: All specialists run SPL as **`splunker`**. The PoC sets **`srchJobsQuota=5`** on **`mcp_user`**, but the built-in **`user`** role may still cap concurrent historical searches lower on some builds — four parallel background workers can exceed the effective quota.

**Solution**:

1. Wait 5–10 seconds — in-flight searches finish; retry failed teams.
2. **Stagger** delegation (IT Ops + Business first, then DevOps + Security) or run one team at a time for screen-share clarity.
3. Power User: **wait for all** teams; report which summaries are missing — do not invent numbers.
4. Optional (advanced): confirm **`mcp_user`** has **`srchJobsQuota=5`** in Splunk (**Settings → Roles**).

See [AGENTS.md § Parallel delegation](AGENTS.md#parallel-delegation-and-search-concurrency) · [`.cursor/agents/README.md` § Parallel delegation](../../.cursor/agents/README.md#parallel-delegation-four-teams) · [S4R-DEMO.md § Backup & troubleshooting](../../demo-slides/S4R-DEMO.md#backup--troubleshooting).
