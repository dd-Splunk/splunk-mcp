# Requirements and acceptance criteria

Design requirements for the **splunk-mcp** PoC. When this document disagrees with the running stack, **code wins**—see [docs/README.md](../README.md#source-of-truth-code-wins).

## Purpose

Provide a self-contained local Splunk environment that demonstrates:

- Splunk MCP Server access from MCP clients
- A non-admin MCP execution identity on a Splunk4Rookies-like dataset (**SA-S4R** + Eventgen)

## Target platform

- Splunk Enterprise as a **linux/amd64** container (Apple Silicon via emulation)
- Image via **`SPLUNK_IMAGE`** in **`compose.yml`** (default **`splunk/splunk:latest`**); pin a tag in **`tpl.env`** / **`.env`** for reproducible demos. Cursor Cloud bootstrap defaults to **`splunk/splunk:10.4.1`** — see [CONFIGURATION.md](CONFIGURATION.md#cursor-cloud-bootstrap).
- Other services must not hardcode **`platform:`** unless required

## Identity and authorization

| User | Role | Use |
| ---- | ---- | --- |
| `admin` | `admin` | Bootstrap REST only |
| `splunker` (default) | `user` + `mcp_user` | MCP execution; **`mcp_user`** must include **`mcp_tool_execute`** |

MCP user must **not** be `admin`. The **`ai`** SPL command is available to all users and must not require special role/capability.

## Secrets

- No secrets in git; no secrets written to repo files during normal operation
- Support **Path A** (`op run` + **`tpl.env`**) and **Path B** (plain **`.env`**)
- Secrets must not be echoed to logs

## Splunkbase apps (pinned in `compose.yml`)

- Splunk MCP Server (7931)
- SA-Eventgen (1924)
- Config Explorer (4353)
- Splunk AI Assistant for SPL (7245)

Splunk AI Toolkit (2890) and Python for Scientific Computing (2882) are **out of scope** unless installed manually.

## SA-S4R

- Eventgen **`access_combined`** traffic into **`main`**
- **`product_codes`** lookup CSV under **`lookups/`**
- Workshop UI assets under **`local/`** only (see **`SA-S4R/local/README`**)

## MCP clients

Supported: **Cursor**, **Claude Desktop**, **Goose** (via **`npx mcp-remote`** → **`/services/mcp`**). **Mistral (Vibe)** uses the same pattern when configured.

- Tokens minted by **`scripts/mint-mcp-token.sh`** after **`splunk-init`**; written only to client configs
- Dev TLS: optional **`NODE_TLS_REJECT_UNAUTHORIZED=0`** when **`SPLUNK_MCP_TLS_INSECURE=1`**
- **Goose:** client config uses **`envs`** (not `env`) for TLS-related env vars

Details: [CONFIGURATION.md](CONFIGURATION.md), [ARCHITECTURE.md](ARCHITECTURE.md).

## Tooling

- Docker Compose orchestration
- **`make`** targets: start/stop/status/logs, bootstrap, MCP client update/verify, health checks

## Upgrades

- Pin **`SPLUNK_IMAGE`** and Splunkbase **`/release/VERSION/`** segments in **`compose.yml`** (see [CONFIGURATION.md](CONFIGURATION.md#composeyml)); bump from [Splunkbase](https://splunkbase.splunk.com) when releases change

## Acceptance criteria (minimum)

The environment is “working” when all of the following pass:

- Splunk MCP at `https://localhost:8089/services/mcp` answers **`tools/list`** with a minted token
- At least one MCP tool call succeeds (e.g. a search)
- Eventgen produces **`access_combined`** events in **`main`**
- As **`splunker`**, SPL `index=main | stats values(sourcetype) AS "Sourcetype"` includes **`access_combined`**
- Via MCP **`splunk_run_query`**, the same SPL includes **`access_combined`**
- **Cursor:** prompt “using Splunk MCP, list all non internal sourcetypes” succeeds and includes **`access_combined`**

Quick checks: **`make status`**, **`make verify-mcp-remote`**.
