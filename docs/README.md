# Documentation index

Use this page to choose the right document. The root [README.md](../README.md) stays short on purpose; detail lives here.

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
| [CLAUDE_LOGS_SETUP.md](CLAUDE_LOGS_SETUP.md) | Claude log ingestion details (if present) |
| [DOCUMENTATION_IMPROVEMENTS.md](DOCUMENTATION_IMPROVEMENTS.md) | Changelog-style notes from doc cleanups |

## Suggested reading order

1. Root README → `QUICK_START.md` or `INSTALLATION.md`
2. `OVERVIEW.md` for context
3. `CONFIGURATION.md` before changing ports or secrets
4. `SECURITY.md` before any non-local use
5. `TROUBLESHOOTING.md` when stuck
