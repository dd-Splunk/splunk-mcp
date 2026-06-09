# Quick start

**Presales or first-time demo?** Use **[PRESALES.md](PRESALES.md)** as the runbook (secrets, timing, Cursor, verification). This page is a short technical checklist for engineers who already know the repo.

## Prerequisites

```bash
docker --version
# Path A: op --version && op signin ...
make --version
jq --version
curl --version
node --version   # for npx mcp-remote (all MCP clients)
```

Note: **Claude**, **Cursor**, and **Goose** use **`npx mcp-remote`** per [Splunk MCP Server 1.2](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/1.2/connecting-to-the-mcp-server-and-settings).

## 1. Secrets

- **1Password:** `cp tpl.env.example tpl.env` and set `op://` paths that resolve in your vault. Test: `op read "op://YourVault/Item/field"`.
- **No 1Password:** `cp .env.example .env` and set `SPLUNK_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, `SPLUNK_MCP_PASSWORD` (and optional `SPLUNK_IMAGE`, `TZ`).

## 2. Start

```bash
make up
```

Starts the stack, then runs **`make update-mcp-clients`**. First run can take **several minutes**.

With **`tpl.env`** and no **`.env`**, **`make up`** injects secrets via **`op run`** (nothing written to disk). For a plain **`.env`** file instead, see [PRESALES.md](PRESALES.md#secrets-path-a-1password-vs-path-b-plain-env) and [CONFIGURATION.md](CONFIGURATION.md#plain-env-path-b).

## 3. Verify

```bash
make demo-prep    # status + MCP verify + presales reminder
# or:
make verify       # status then verify-mcp-remote only
```

- Splunk Web: `https://localhost:8000` (admin + password from your secret source).
- **Cursor:** **`make up`** updates **`.cursor/mcp.json`**; restart Cursor.
- **Claude / Goose:** see [PRESALES.md](PRESALES.md#llm-client-configuration).

## Next

- [CONFIGURATION.md](CONFIGURATION.md) — ports, env, clients  
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when something fails  
- [INSTALLATION.md](INSTALLATION.md) — long-form install

## Do not commit

- **`tpl.env`**, **`.env`**, **`.secrets/`**, or client files with secrets (see [AGENTS.md](../AGENTS.md)).
