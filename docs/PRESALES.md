# Presales & demo use

This repo is a **local proof-of-concept** for showing Splunk Enterprise with the **Splunk MCP Server** app and LLM clients (Claude Desktop, Cursor, Goose). Use this page to run a repeatable demo and set expectations with customers or internal stakeholders.

## New SE takeover (start here)

1. **Secrets:** Edit **`tpl.env`** so every `op://` path resolves in **your** vault, **or** use **Path B** (no 1Password) below.
2. **Network:** Host must reach **Splunkbase** (`splunkbase.splunk.com`) and Docker Hub (or your mirror) for pulls—corporate VPN/firewall/proxy can block installs.
3. **Time:** First cold start can take **many minutes** (pull, Splunk, three Splunkbase downloads, init). For a live meeting, run **`make up`** well in advance or warm volumes the day before.
4. **Artifacts:** Read **`compose.yml`** comments for **`SPLUNK_APPS_URL`** (which app each ID is). Optional port overrides: **`docker-compose.override.yml.example`**.
5. **When stuck:** [TROUBLESHOOTING.md](TROUBLESHOOTING.md) → especially Splunkbase auth, ports, and init.

## Secrets: Path A (1Password CLI) vs Path B (plain `.env`)

| Path | When to use | What to do |
| ---- | ----------- | ---------- |
| **A — `op`** | You use 1Password and `op` is signed in | Edit **`tpl.env`** with valid `op://vault/item/field` paths. Run **`make up`** (no `.env` file needed; Makefile uses `op run`). |
| **B — no `op`** | No 1Password, CI, or air-gapped-style workflow | Create **`.env`** in the repo root (git-ignored) with **plain** values for `SPLUNK_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, `SPLUNK_IMAGE`, `TZ`. Same variable names as **`tpl.env`**. Then run **`make up`**. **Never commit `.env`.** |

Optional: **`make init`** runs `op inject` from **`tpl.env`** → **`.env`** if you prefer `op` but want a file on disk.

## Splunkbase and network (hard dependencies)

- **Valid Splunkbase credentials** are required: Compose passes them so Splunk can download **`SPLUNK_APPS_URL`** at start. Wrong password or account without download permission → apps (including **Splunk MCP Server**) never install → MCP setup fails.
- **Egress:** The machine running Docker needs HTTPS access to **splunkbase.splunk.com** (and image registry for **`SPLUNK_IMAGE`**). Offline/air-gapped installs are out of scope for this PoC.
- **URLs:** See comments on **`SPLUNK_APPS_URL`** in **`compose.yml`** (apps **1924** Eventgen, **4353** Config Explorer, **7931** Splunk MCP Server). If a URL returns **404**, update the `/release/<version>/` segment from the app’s current Splunkbase download link.

## Platform notes

- **Apple Silicon (M1/M2/M3):** **`compose.yml`** sets **`platform: linux/amd64`**. Splunk’s image runs via emulation—first pull and CPU use can be higher; allow extra time.
- **Windows:** Prefer **WSL2** + Docker Desktop; **`make`** and paths match Linux docs best. **Claude Desktop** config scripts in this repo target **macOS** paths (`~/Library/Application Support/Claude/...`). On Windows, configure the MCP client manually or adjust paths to your environment.
- **TLS:** Browser and `curl` use **`-k`** / accept self-signed certs for **localhost** only.

## Identity cheat sheet (who uses what)

| Actor | Purpose | Where it comes from |
| ----- | ------- | ------------------- |
| **`admin`** | Splunk Web login; REST in **`setup-splunk.sh`** | Password = **`SPLUNK_PASSWORD`** (secret store or `.env`) |
| **`dd`** | Least-privilege Splunk user for MCP (`mcp_tool_execute`) | Created by init; password in **`.secrets/dd-password`** if not set via env |
| **Bearer token** | MCP HTTP clients (`mcp-remote`) | File **`.secrets/splunk-token`** (encrypted token from Splunk MCP Server app) |

Do **not** use the **`admin`** password as the MCP Bearer token—the assistant uses the **token file** content.

## Sample Splunk search (bundled data)

After **SA-S4R** + **Eventgen** are running and data is flowing into **`main`** (may take a few minutes post-start), try in **Search & Reporting**:

```splunk
index=main sourcetype=access_combined
| head 20
```

If nothing returns yet, confirm apps in **Manage apps**, Eventgen enabled, and see [SA-S4R-APP.md](SA-S4R-APP.md).

## LLM demo (~60 seconds)

1. Open **Claude / Cursor / Goose** with MCP configured (see below).
2. Confirm **Splunk** / **MCP** tools appear in the tool list (exact names depend on **Splunk MCP Server** version—see [Splunk MCP Server on Splunkbase](https://splunkbase.splunk.com/app/7931)).
3. Run a **read-only** action (e.g. a small search or metadata) rather than destructive operations.
4. **`make verify-mcp-remote`** from a shell confirms **`mcp-remote`** can proxy to **`https://localhost:8089/services/mcp`** with the token (without printing the token).

## What this demo proves

- Splunk MCP exposes tools over **`https://localhost:8089/services/mcp`** (after apps and setup complete).
- A least-privilege Splunk user (`dd`) with **`mcp_tool_execute`** can drive MCP without admin.
- Standard MCP clients connect via **`mcp-remote`** and a bearer token generated at init.

It does **not** replace production architecture, security review, or Splunk Cloud / customer-specific networking.

## Before the demo (checklist)

| Prerequisite | Why |
| -------------- | --- |
| Docker Desktop (or equivalent) with enough RAM (see [INSTALLATION.md](INSTALLATION.md#prerequisites)) | Splunk container + app downloads |
| **Splunkbase account** + credentials in **`tpl.env`** or **`.env`** | Required for **`SPLUNK_APPS_URL`** downloads |
| **`op`** signed in **or** a working **`.env`** | Injects `SPLUNK_PASSWORD` and Splunkbase vars |
| Node/npm for **`npx mcp-remote`** | Claude / Cursor / Goose configs |
| Accept self-signed TLS in the browser for `https://localhost:8000` | Default Splunk dev cert |

**Time budget:** first cold start is often **several minutes** (image pull, Splunk start, Splunkbase app downloads, init). For a live meeting, start **`make up`** early or run once the day before so volumes are warm.

## Demo flow (suggested)

1. **Show the value prop in one sentence:** e.g. “Splunk operations exposed as MCP tools so an assistant can search and act with guardrails.”
2. Run **`make status`** until “Splunk is ready”.
3. Open **Splunk Web** at `https://localhost:8000`, log in as **admin** (password from your secret store—not from the repo).
4. **Optional:** run the sample SPL above if your narrative includes data.
5. In the LLM client, confirm **Splunk MCP** tools appear and run one low-risk tool (e.g. a small search), not destructive actions.
6. Point to **docs/SECURITY.md** if asked about TLS, tokens, or production gaps.

## Greenfield vs iterating

- **Iterate locally:** `make down` / `make up` as needed; token and volumes usually persist (named volumes **`so1-var`**, **`so1-etc`**).
- **Clean slate before an important demo:** see **`make clean`** (destructive; prompts) and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for volume reset—expect full reinstall time afterward.

## Client-specific notes

| Client | After `make up` |
| ------ | ---------------- |
| **Claude Desktop** | `make up` runs **`make claude-update`** automatically; user must **restart Claude** (e.g. Cmd+Q on macOS). |
| **Cursor** | Run **`make cursor-mcp`** after `.secrets/splunk-token` exists; restart Cursor or reload MCP. |
| **Goose** | Run **`make goose-update`**; restart Goose. |

Smoke-test from the shell: **`make verify-mcp-remote`**.

## Talking points / boundaries

- **Secrets:** Admin password and Splunkbase credentials never belong in git; use **`tpl.env`** + `op` or a local `.env` (git-ignored). See [AGENTS.md](../AGENTS.md).
- **Not for untrusted networks:** Default setup uses self-signed TLS and dev-oriented MCP SSL settings; see [SECURITY.md](SECURITY.md).
- **Splunk version:** Image tag is controlled by **`SPLUNK_IMAGE`** (see `tpl.env`). Pin a version for reproducible demos.
- **Licensing:** This stack uses Splunk’s Docker image defaults for dev/PoC; enterprise licensing and air-gapped installs are out of scope for this repo—position accordingly.

## Handoff to another presales engineer

1. Clone the repo; do **not** reuse someone else’s **`tpl.env`** if it contains their `op://` paths—use the committed template and map to your vault (or use **Path B** `.env`).
2. Ensure Splunkbase credentials work: without them, app downloads from **`SPLUNK_APPS_URL`** fail and MCP setup will not complete.
3. Read [QUICK_START.md](QUICK_START.md) → [CONFIGURATION.md](CONFIGURATION.md) → [TROUBLESHOOTING.md](TROUBLESHOOTING.md) in that order when something breaks.

## Publishing this repository

Before making the repo public or wide-internal:

- Keep **`tpl.env`** free of real **`op://`** vault/item IDs and passwords (template-only).
- Confirm **`.gitignore`** excludes `.env`, `.secrets/`, and client configs with tokens ([AGENTS.md](../AGENTS.md)).
- This repo includes **[LICENSE](../LICENSE)** (MIT); confirm it matches your org’s policy before wide distribution.
- Optionally set GitHub **Topics** from [.github/TOPICS.md](../.github/TOPICS.md).
