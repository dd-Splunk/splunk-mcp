# S4R Cursor agent prompts

Copy-paste system prompts for **Cursor Task** subagents (or the main chat) when working on **Splunk4Rookies / Buttercup Enterprises** (`SA-S4R`).

| File | Role |
| ---- | ---- |
| [s4r-power-user.md](s4r-power-user.md) | Orchestrator — delegate and synthesize |
| [s4r-it-ops.md](s4r-it-ops.md) | IT Operations — HTTP success vs failure |
| [s4r-devops.md](s4r-devops.md) | DevOps — platform and browser failures |
| [s4r-business-analytics.md](s4r-business-analytics.md) | Business Analytics — lost revenue |
| [s4r-security-fraud.md](s4r-security-fraud.md) | Security & Fraud — geographic activity |

**Full design:** [docs/S4R-AGENTS.md](../../docs/S4R-AGENTS.md)

## Task subagent example

```text
You are the S4R IT Ops agent. Read .cursor/agents/s4r-it-ops.md and follow it exactly.
Use Splunk MCP splunk_run_query for index=main sourcetype=access_combined.
Time range: last 24 hours. Report success rate and top failing status codes.
Return IT Ops summary only; do not synthesize other teams.
```

Launch with `subagent_type: generalPurpose` and Splunk MCP enabled.

## Prerequisites

- `make up` and `make demo-prep`
- Data in `main` / `access_combined` (SA-S4R Eventgen)
- Splunk MCP tools available in the client
