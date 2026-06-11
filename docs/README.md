# Documentation index

The root [README.md](../README.md) stays short. **Pick one door:**

| Role | Start here |
| ---- | ---------- |
| **SE / presales demo** | [PRESALES.md](PRESALES.md) |
| **Splunk4Rookies workshop** | [s4r/README.md](s4r/README.md) |
| **Install / operate stack** | [INSTALLATION.md](INSTALLATION.md) → [CONFIGURATION.md](CONFIGURATION.md) |
| **Change the repo** | [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) |

## Source of truth (when docs disagree with code)

1. [`Makefile`](../Makefile) — `make up` uses `op run` or `.env`; lifecycle targets use plain `docker compose`
2. [`compose.yml`](../compose.yml) — services, ports, `SPLUNK_APPS_URL`, mounts
3. [`scripts/setup-splunk.sh`](../scripts/setup-splunk.sh) — REST bootstrap ([CONFIGURATION.md § Appendix](CONFIGURATION.md#appendix-setup-splunksh))
4. [`AGENTS.md`](../AGENTS.md) — contributor rules and verification commands

## Getting started

| Document | Use when |
| -------- | -------- |
| **[PRESALES.md](PRESALES.md)** | **SE demo runbook** (includes [technical quick reference](PRESALES.md#technical-quick-reference)) |
| [INSTALLATION.md](INSTALLATION.md) | Hardware, 1Password layout, long-form setup |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Purpose, components, init flow, MCP clients |
| [demo-slides/S4R-DEMO.md](../demo-slides/S4R-DEMO.md) | Agentic demo presenter script |
| [demo-slides/README.md](../demo-slides/README.md) | Marp deck build/preview |

**Moved (redirect stubs):** [QUICK_START.md](QUICK_START.md) → PRESALES · [OVERVIEW.md](OVERVIEW.md) → ARCHITECTURE · [SETUP_SPLUNK_SCRIPT.md](SETUP_SPLUNK_SCRIPT.md) → CONFIGURATION appendix

## Splunk4Rookies (S4R)

Hub: **[s4r/README.md](s4r/README.md)**

| Document | Use when |
| -------- | -------- |
| [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) | **Canonical SPL** (Labs 3–7; agent runbook) |
| [S4R-DASHBOARD.md](S4R-DASHBOARD.md) | Dashboard Studio layout (Labs 3–7) |
| [SA-S4R-APP.md](SA-S4R-APP.md) | Eventgen, NK toggle, app assets |
| [S4R-AGENTS.md](S4R-AGENTS.md) | Agent architecture and demo beats |

**Moved:** [What Does the Business Want to See.md](What%20Does%20the%20Business%20Want%20to%20See.md) → [S4R-DASHBOARD.md](S4R-DASHBOARD.md)

## Design and operations

| Document | Use when |
| -------- | -------- |
| [CONFIGURATION.md](CONFIGURATION.md) | Compose, env, clients, **`setup-splunk.sh` appendix** |
| [SECURITY.md](SECURITY.md) | Dev-only risks, tokens, TLS |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Ports, health, token, Splunkbase, MCP errors |
| [CI_CD.md](CI_CD.md) | GitHub Actions, SA-S4R package release |

## API and development

| Document | Use when |
| -------- | -------- |
| [API_REFERENCE.md](API_REFERENCE.md) | Splunk REST and MCP |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | What to edit when, test loop, lint |

## Suggested reading order

1. [PRESALES.md](PRESALES.md) (demos) **or** [INSTALLATION.md](INSTALLATION.md) (full setup)
2. [CONFIGURATION.md](CONFIGURATION.md) before changing env or clients
3. [SECURITY.md](SECURITY.md) before any non-local use
4. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when stuck
