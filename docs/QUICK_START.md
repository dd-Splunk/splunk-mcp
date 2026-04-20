# Quick Start

Minimal steps to run the stack. For full detail see [INSTALLATION.md](INSTALLATION.md) and [CONFIGURATION.md](CONFIGURATION.md).

## Prerequisites

```bash
docker --version
op --version              # 1Password CLI (signed in)
make --version
jq --version
curl --version
```

## 1. Clone

```bash
git clone <repository-url>
cd splunk-mcp
```

## 2. Configure secrets (`tpl.env`)

1. **`cp tpl.env.example tpl.env`** (local file; gitignored).
2. Set **`SPLUNK_IMAGE`** if you need a pinned Splunk tag (default `splunk/splunk:latest`).
3. Replace every **`op://…`** path with references that exist **in your** 1Password vault (vault name, item title, field labels).

Documentation often uses item names like `Splunk-MCP-PoC` or vault `Private`; **those are illustrative**. **`tpl.env.example`** uses placeholders—**your `tpl.env` must match your vault**.

Verify reads work:

```bash
op read "op://YourVault/YourItem/password"
```

## 3. Start

```bash
make up
```

- **`make up`** does **not** require `make init` first. If `.env` is missing, the Makefile runs Compose with `op run --env-file=tpl.env` (requires **`tpl.env`** from the step above).
- Wait **2–3 minutes** for Splunk and `splunk-init` to finish; the Makefile waits for `.secrets/splunk-token` then runs `update-claude-config`.

**Optional:** materialize a `.env` file:

```bash
make init    # tpl.env → .env (op run + scripts/materialize-env.sh)
make up
```

## 4. Verify

```bash
make status          # Expect "Splunk is ready ✓" when healthy
ls -la .secrets/splunk-token
```

**Splunk Web:** `https://localhost:8000` — `admin` / password from your `SPLUNK_PASSWORD` source.

**REST smoke test:**

```bash
curl -k -u "admin:${SPLUNK_PASSWORD}" https://localhost:8089/services/server/info
```

(Or paste your admin password; do not commit it.)

## 5. Claude Desktop

1. Quit Claude completely (e.g. **Cmd+Q** on macOS).
2. Relaunch. The repo runs **`make update-claude-config`** after the token exists; that merges the Splunk MCP entry into  
   `~/Library/Application Support/Claude/claude_desktop_config.json`.

## 6. Cursor

After `.secrets/splunk-token` exists:

```bash
make update-cursor-config
```

Restart Cursor or reload MCP servers.

## Claude logs in Splunk (optional)

Indexing Claude Desktop logs into **`claude_logs`** is **not** enabled unless:

1. You **uncomment** the Claude logs bind mount in **`compose.yml`** (macOS path shown in comments), **and**
2. The path exists on the host so `/var/log/claude_logs` appears inside `so1`.

Then create the **`claude_logs`** index and a **monitor** input on `/var/log/claude_logs` in Splunk. Search: `index=claude_logs`.

## Common commands

```bash
make help
make status
make logs
make restart
make down
make verify-mcp-remote
make clean            # destructive; prompts for confirmation
```

## Next steps

- [CONFIGURATION.md](CONFIGURATION.md) — ports, env vars, clients  
- [OVERVIEW.md](OVERVIEW.md) — architecture  
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — failures  

## Notes

- **`tpl.env`**: git-ignored (copy from **`tpl.env.example`**); never commit.
- **`.env`**: git-ignored; never commit. Prefer `op run` / `make up` without a file if you want fewer secrets on disk.
- **MCP token lifetime**: depends on Splunk MCP Server app and Splunk settings; regenerate by re-running setup or documented flows if clients fail with 401.
- **Self-signed TLS**: local dev only; see [SECURITY.md](SECURITY.md).
