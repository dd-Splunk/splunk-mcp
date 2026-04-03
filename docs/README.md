# Documentation index

Use this page to choose the right document. The root [README.md](../README.md) stays short on purpose; detail lives here.

## Source of truth

When docs disagree with the repo, trust **in order**:

1. [`Makefile`](../Makefile) — how Compose is invoked (`op run` vs `.env`), targets, env file names  
2. [`compose.yml`](../compose.yml) — services, ports, `SPLUNK_APPS_URL`, mounts  
3. [`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh) — Splunk REST bootstrap, user `dd`, token file  
4. [`AGENTS.md`](../AGENTS.md) — contributor rules and verification commands  

Splunk **version** is not hard-coded in git beyond the Docker **image tag** (default `latest`) and Splunkbase **app URLs**—confirm the running build in Splunk or via `services/server/info`.

## Getting started

| Document | Use when |
| -------- | -------- |
| [QUICK_START.md](QUICK_START.md) | You want a minimal checklist and commands only |
| [INSTALLATION.md](INSTALLATION.md) | You need step-by-step setup, tool versions, and verification |
| [OVERVIEW.md](OVERVIEW.md) | You want a full picture: purpose, components, flows, Splunkbase apps |

## Design and operations

| Document | Use when |
| -------- | -------- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | You need containers, volumes, networks, and init order |
| [CONFIGURATION.md](CONFIGURATION.md) | You are editing `compose.yml`, `tpl.env`, MCP client JSON, or paths |
| [SECURITY.md](SECURITY.md) | You are assessing risk, tokens, TLS, or production gaps |
| [SA-S4R-APP.md](SA-S4R-APP.md) | You are working with the bundled sample app / Eventgen data |

## API and development

| Document | Use when |
| -------- | -------- |
| [API_REFERENCE.md](API_REFERENCE.md) | You are calling Splunk REST or debugging MCP auth |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | You are changing scripts, Makefile, or testing locally |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Something failed: ports, health, token, MCP connection |

## Meta

| Document | Notes |
| -------- | ----- |
| [DOCUMENTATION_IMPROVEMENTS.md](DOCUMENTATION_IMPROVEMENTS.md) | Historical changelog of doc edits |

Claude log ingestion: see **Claude logs** in [CONFIGURATION.md](CONFIGURATION.md) and [QUICK_START.md](QUICK_START.md) (optional bind mount).

## Suggested reading order

1. Root README → `QUICK_START.md` or `INSTALLATION.md`
2. `OVERVIEW.md` for context
3. `CONFIGURATION.md` before changing ports or secrets
4. `SECURITY.md` before any non-local use
5. `TROUBLESHOOTING.md` when stuck
