# Documentation index

The root [README.md](../README.md) stays short. **For a presales or SE demo, start with [PRESALES.md](PRESALES.md)**—then use the sections below if you need more depth.

## Source of truth (when docs disagree with code)

1. [`Makefile`](../Makefile) — `make up` uses `op run` or `.env`; lifecycle targets use plain `docker compose` (no `op` required)  
2. [`compose.yml`](../compose.yml) — services, ports, `SPLUNK_APPS_URL`, mounts  
3. [`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh) — REST bootstrap, `splunker`, token file  
4. [`AGENTS.md`](../AGENTS.md) — contributor rules and verification commands  

## Getting started

| Document | Use when |
| -------- | -------- |
| **[PRESALES.md](PRESALES.md)** | **SE / presales: first-time demo, checklist, handoff** |
| [QUICK_START.md](QUICK_START.md) | Minimal command list (points to PRESALES for demos) |
| [INSTALLATION.md](INSTALLATION.md) | Full install: hardware, 1Password items, step-by-step |
| [OVERVIEW.md](OVERVIEW.md) | Architecture and Splunkbase app flow |

## Design and operations

| Document | Use when |
| -------- | -------- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Containers, volumes, init order |
| [CONFIGURATION.md](CONFIGURATION.md) | `compose.yml`, `tpl.env` / `.env`, client JSON, optional local overrides |
| [SETUP_SPLUNK_SCRIPT.md](SETUP_SPLUNK_SCRIPT.md) | Details for `scripts/setup-splunk.sh` |
| [SECURITY.md](SECURITY.md) | Dev-only risks, tokens, TLS |
| [CI_CD.md](CI_CD.md) | GitHub Actions, artifacts |
| [SA-S4R-APP.md](SA-S4R-APP.md) | Bundled sample app and Eventgen |
| [What Does the Business Want to See.md](What%20Does%20the%20Business%20Want%20to%20See.md) | **Splunk4Rookies** dashboard build prompt (Labs 3–7) |

## API and development

| Document | Use when |
| -------- | -------- |
| [API_REFERENCE.md](API_REFERENCE.md) | Splunk REST and MCP |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | Changing scripts, Makefile, local test |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Ports, health, token, Splunkbase, MCP errors |

## Suggested reading order

1. [PRESALES.md](PRESALES.md) (demos) **or** [QUICK_START.md](QUICK_START.md) (technical minimum)  
2. [CONFIGURATION.md](CONFIGURATION.md) before changing env or clients  
3. [SECURITY.md](SECURITY.md) before any non-local use  
4. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when stuck  
