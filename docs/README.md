# Documentation index

Use this page to choose the right document. The root [README.md](../README.md) stays short on purpose; detail lives here.

## Source of truth

When docs disagree with the repo, trust **in order**:

1. [`Makefile`](../Makefile) — `make up` uses `op run` or `.env`; lifecycle targets (`down`, `logs`, `status`, `clean`, …) use plain `docker compose` without secrets  
2. [`compose.yml`](../compose.yml) — services, ports, `SPLUNK_APPS_URL`, mounts  
3. [`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh) — Splunk REST bootstrap, user `splunker`, token file  
4. [`AGENTS.md`](../AGENTS.md) — contributor rules and verification commands  

Splunk **version** is not hard-coded in git beyond the Docker **image tag** (default `latest`) and Splunkbase **app URLs**—confirm the running build in Splunk or via `services/server/info`.

## Getting started

| Document | Use when |
| -------- | -------- |
| [QUICK_START.md](QUICK_START.md) | You want a minimal checklist and commands only |
| [INSTALLATION.md](INSTALLATION.md) | Full install: prerequisites, 1Password, start, clients, verification |
| [PRESALES.md](PRESALES.md) | You are doing a demo or handing the repo to another SE / presales |
| [OVERVIEW.md](OVERVIEW.md) | You want a full picture: purpose, components, flows, Splunkbase apps |

## Design and operations

| Document | Use when |
| -------- | -------- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | You need containers, volumes, networks, and init order |
| [CONFIGURATION.md](CONFIGURATION.md) | You are editing `compose.yml`, `tpl.env` / `tpl.env.example`, MCP client JSON, or paths |
| [SETUP_SPLUNK_SCRIPT.md](SETUP_SPLUNK_SCRIPT.md) | You need flowcharts and REST details for `scripts/setup-splunk.sh` |
| [../docker-compose.override.yml.example](../docker-compose.override.yml.example) | Optional local port/mount overrides (copy to `docker-compose.override.yml`) |
| [SECURITY.md](SECURITY.md) | You are assessing risk, tokens, TLS, or production gaps |
| [SA-S4R-APP.md](SA-S4R-APP.md) | You are working with the bundled sample app / Eventgen data |

## API and development

| Document | Use when |
| -------- | -------- |
| [API_REFERENCE.md](API_REFERENCE.md) | You are calling Splunk REST or debugging MCP auth |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | You are changing scripts, Makefile, or testing locally |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Something failed: ports, health, token, MCP connection |

Optional **Claude log** ingestion: see [CONFIGURATION.md](CONFIGURATION.md) and [QUICK_START.md](QUICK_START.md) (bind mount + index/monitor in Splunk).

## Suggested reading order

1. Root README → `QUICK_START.md` or `INSTALLATION.md` (presales: add `PRESALES.md`)
2. `OVERVIEW.md` for context
3. `CONFIGURATION.md` before changing ports or secrets
4. `SECURITY.md` before any non-local use
5. `TROUBLESHOOTING.md` when stuck
