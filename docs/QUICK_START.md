# Quick start

**Presales or first-time demo?** Use **[PRESALES.md](PRESALES.md)** as the runbook (secrets, timing, Cursor, verification). This page is a short technical checklist for engineers who already know the repo.

## Prerequisites

```bash
docker --version
# Path A: op --version && op signin ...
make --version
jq --version
curl --version
node --version   # for npx mcp-remote
```

## 1. Secrets

- **1Password:** `cp tpl.env.example tpl.env` and set `op://` paths that resolve in your vault. Test: `op read "op://YourVault/Item/field"`.
- **No 1Password:** `cp .env.example .env` and set `SPLUNK_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS` (and optional `SPLUNK_IMAGE`, `TZ`).

## 2. Start

```bash
make up
```

Waits for **`.secrets/splunk-token`**, then runs **`make update-claude-config`** (macOS). First run can take **several minutes**.

Optional: `make init` then `make up` if you want a materialized **`.env`**.

## 3. Verify

```bash
make status
make verify-mcp-remote
```

- Splunk Web: `https://localhost:8000` (admin + password from your secret source).
- **Cursor:** `make update-cursor-config` → restart Cursor.
- **Claude / Goose:** see [PRESALES.md](PRESALES.md#llm-client-configuration).

## Next

- [CONFIGURATION.md](CONFIGURATION.md) — ports, env, clients  
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — when something fails  
- [INSTALLATION.md](INSTALLATION.md) — long-form install

## Do not commit

- **`tpl.env`**, **`.env`**, **`.secrets/`**, or client files with live bearer tokens (see [AGENTS.md](../AGENTS.md)).
