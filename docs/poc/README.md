# PoC stack documentation

Splunk Enterprise + Splunk MCP Server in Docker: install, configure, operate, and debug.

Workshop (Buttercup / SA-S4R): **[../s4r/README.md](../s4r/README.md)**.

## Docs in this cluster

| Document | Purpose |
| -------- | ------- |
| [PRESALES.md](PRESALES.md) | Demo runbook, secrets paths, checklist |
| [INSTALLATION.md](INSTALLATION.md) | Hardware, 1Password, verification |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Components, boot flow, MCP clients |
| [CONFIGURATION.md](CONFIGURATION.md) | Compose, env, MCP auth, client configs |
| [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Docker, init, MCP, connectivity |
| [SECURITY.md](SECURITY.md) | Secrets, TLS, vulnerability reporting |
| [API_REFERENCE.md](API_REFERENCE.md) | Splunk REST and MCP endpoints |
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) | What to edit when, test loop, lint |
| [CI_CD.md](CI_CD.md) | GitHub Actions, SA-S4R package release |
| [SPECS.md](SPECS.md) | Requirements and acceptance criteria |
| [GRADUATION.md](GRADUATION.md) | PoC → unattended boot: impact study and checklist |

## Suggested order

1. [PRESALES.md](PRESALES.md) (demos) **or** [INSTALLATION.md](INSTALLATION.md) (full setup)
2. [CONFIGURATION.md](CONFIGURATION.md) before changing env or clients
3. [SECURITY.md](SECURITY.md) before any non-local use
4. [TROUBLESHOOTING.md](TROUBLESHOOTING.md) when stuck
