# Documentation

Local PoC: **Splunk Enterprise** + **Splunk MCP Server** in Docker, optional **Splunk4Rookies** workshop (**SA-S4R**).

**Scope:** this documentation cluster covers **local on-prem Enterprise** only. **Splunk Cloud** MCP is **out of scope** for this repo (see [poc/README.md § Scope](poc/README.md#scope)).

## Two clusters

| Cluster | Hub | For |
| ------- | --- | --- |
| **PoC (stack)** | [poc/README.md](poc/README.md) | Install, run, configure, and debug the platform |
| **Workshop (S4R)** | [s4r/README.md](s4r/README.md) | Buttercup Labs 3–7, SPL, dashboard, agents, demo |

## Start here

| I want to… | Read |
| ---------- | ---- |
| Run or demo the stack (SE / presales) | [poc/PRESALES.md](poc/PRESALES.md) |
| Install from scratch (long form) | [poc/INSTALLATION.md](poc/INSTALLATION.md) |
| PoC graduation / wider rollout impact | [poc/GRADUATION.md](poc/GRADUATION.md) |
| Splunk4Rookies workshop | [s4r/README.md](s4r/README.md) |
| Change the repo or use AI agents | [AGENTS.md](../AGENTS.md) — Cursor **`/usage`** (`SA-S4R_*` routing) · **`/demo-prep`** (S4R MCP smoke + stack checks) |
| Present the agentic demo (Marp) | [demo-slides/README.md](../demo-slides/README.md) |

## Source of truth (code wins)

1. [`Makefile`](../Makefile)
2. [`compose.yml`](../compose.yml)
3. [`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh) — narrative in [poc/CONFIGURATION.md § Appendix](poc/CONFIGURATION.md#appendix-setup-splunksh)
4. [AGENTS.md](../AGENTS.md)

## Suggested order

1. [poc/PRESALES.md](poc/PRESALES.md) (demos) **or** [poc/INSTALLATION.md](poc/INSTALLATION.md) (full setup)
2. [poc/CONFIGURATION.md](poc/CONFIGURATION.md) before changing env or clients
3. [poc/SECURITY.md](poc/SECURITY.md) before any non-local use
4. [poc/TROUBLESHOOTING.md](poc/TROUBLESHOOTING.md) or [s4r/TROUBLESHOOTING.md](s4r/TROUBLESHOOTING.md) when stuck
