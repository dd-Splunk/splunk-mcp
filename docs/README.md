# Documentation

Local PoC: **Splunk Enterprise** + **Splunk MCP Server** in Docker, optional **Splunk4Rookies** workshop (**SA-S4R**).

## Start here

| I want to… | Read |
| ---------- | ---- |
| Run or demo the stack (SE / presales) | [PRESALES.md](PRESALES.md) |
| Install from scratch (long form) | [INSTALLATION.md](INSTALLATION.md) |
| Splunk4Rookies workshop (SPL, dashboard, agents) | [s4r/README.md](s4r/README.md) |
| Change the repo or use AI agents | [AGENTS.md](../AGENTS.md) |
| Present the agentic demo (Marp) | [demo-slides/README.md](../demo-slides/README.md) |

## Source of truth (code wins)

1. [`Makefile`](../Makefile)
2. [`compose.yml`](../compose.yml)
3. [`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh) — narrative in [CONFIGURATION.md § Appendix](CONFIGURATION.md#appendix-setup-splunksh)
4. [AGENTS.md](../AGENTS.md)

## Stack and operations

| Document | Purpose |
| -------- | ------- |
| [PRESALES.md](PRESALES.md) | Demo runbook, secrets paths, checklist |
| [INSTALLATION.md](INSTALLATION.md) | Hardware, 1Password, verification |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, boot flow, MCP clients |
| [CONFIGURATION.md](CONFIGURATION.md) | Compose, env, client configs, setup script |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Ports, init, Splunkbase, MCP errors |
| [SECURITY.md](SECURITY.md) | Secrets, TLS, vulnerability reporting |
| [API_REFERENCE.md](API_REFERENCE.md) | Splunk REST and MCP endpoints |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | What to edit when, test loop, lint |
| [CI_CD.md](CI_CD.md) | GitHub Actions, SA-S4R package release |
| [SPECS.md](SPECS.md) | Requirements and acceptance criteria |

## Splunk4Rookies (S4R)

| Document | Purpose |
| -------- | ------- |
| [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) | **Canonical SPL** (Labs 3–7; agents) |
| [S4R-DASHBOARD.md](S4R-DASHBOARD.md) | Dashboard Studio build spec (workshop **`local/`**) |
| [SA-S4R-APP.md](SA-S4R-APP.md) | Eventgen, NK toggle, **`default/` vs `local/`** |
| [S4R-AGENTS.md](S4R-AGENTS.md) | Multi-agent demo architecture |

## Suggested order

1. [PRESALES.md](PRESALES.md) (demos) **or** [INSTALLATION.md](INSTALLATION.md) (full setup)
2. [CONFIGURATION.md](CONFIGURATION.md) before changing env or clients
3. [SECURITY.md](SECURITY.md) before any non-local use
4. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when stuck
