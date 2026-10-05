# Developer guide

Contributing and changing this PoC. Stack design: [ARCHITECTURE.md](ARCHITECTURE.md). Env and clients: [CONFIGURATION.md](CONFIGURATION.md). CI: [CI_CD.md](CI_CD.md).

## What to edit when

| Change | Update |
| ------ | ------ |
| `Makefile`, `compose.yml`, `scripts/setup-splunk.sh` | [CONFIGURATION.md](CONFIGURATION.md), [ARCHITECTURE.md](ARCHITECTURE.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md) as needed |
| `scripts/cloud-bootstrap.sh` or Cursor Cloud bootstrap behavior | [CONFIGURATION.md § Cursor Cloud bootstrap](CONFIGURATION.md#cursor-cloud-bootstrap), [INSTALLATION.md](INSTALLATION.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md) as needed |
| MCP client paths / token flow | [CONFIGURATION.md](CONFIGURATION.md), [API_REFERENCE.md](API_REFERENCE.md) |
| SA-S4R Eventgen / NK toggle | [SA-S4R-APP.md](../s4r/SA-S4R-APP.md), [s4r/README.md](../s4r/README.md) |
| SA-S4R MCP tools (`s4r_mcp_tools.json`, saved searches, REST handler) | [MCP-TOOLS.md](../s4r/MCP-TOOLS.md); re-run **`make up`** (restarts **`splunk-init`**) |
| SA-S4R app UI / knowledge objects | Installed app **`local/`** only (never **`default/`**) — [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) § Workshop objects in `local/` |
| `SA-S4R` packaging / `.github/workflows/package-s4r.yml` | [CI_CD.md](CI_CD.md) and [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) |
| Workshop SPL | [S4R-SPL-CATALOG.md](../s4r/SPL-CATALOG.md) only (agents reference this path) |
| Agent prompts | `.cursor/agents/s4r-*.md`, [S4R-AGENTS.md](../s4r/AGENTS.md) |
| Cursor project skills (`/usage`, `/demo-prep`, `/splunk-enterprise-administration-advisor`) | `.cursor/skills/*/SKILL.md`, root [AGENTS.md](../../AGENTS.md#cursor-skills-project), and [CONFIGURATION.md § Makefile targets](CONFIGURATION.md#makefile-targets) if command behavior changes |
| Marp slides, theme, or `make marp-*` targets | [demo-slides/README.md](../../demo-slides/README.md), [demo-slides/S4R-DEMO.md](../../demo-slides/S4R-DEMO.md), and [CONFIGURATION.md § Makefile targets](CONFIGURATION.md#makefile-targets) |
| Secret scanning or pre-commit hooks (`.gitleaks.toml`, `.pre-commit-config.yaml`, CI lint) | [CI_CD.md](CI_CD.md), [SECURITY.md](SECURITY.md), and root [SECURITY.md](../../SECURITY.md) |

Source of truth when docs disagree with code: [docs/README.md](../README.md#source-of-truth-code-wins) and [AGENTS.md](../../AGENTS.md).

## Local test loop

Docker-free (MCP config shape + SA-S4R mode parse):

```bash
make test
```

Needs **jq**, **npx**, **Python 3**, and **PyYAML**. Full stack:

```bash
make down
make clean          # destructive — removes volumes
make up
make verify         # status + MCP client verify
```

Logs: `make logs` · shell in Splunk: `docker exec -it so1 bash`

Never recover a broken `so1` with bare **`docker compose up -d`** unless a populated **`.env`** exists. That recreates the container with empty Splunkbase env (ansible “No inventory was parsed”). Use **`./scripts/compose-up.sh`** or **`make up`**. Do not bind **`SA-S4R` `:ro`** — [TROUBLESHOOTING.md](TROUBLESHOOTING.md) · [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) § Install from GitHub `.spl`.

## Lint before push

```bash
pre-commit run --all-files
make test
```

Requires **shellcheck** and **Node/npx** (markdownlint); pre-commit also runs **gitleaks**. See [CI_CD.md](CI_CD.md).

## Extending the stack

- **Optional log ingest:** uncomment Claude bind mount in `compose.yml`; create index + monitor in Splunk ([CONFIGURATION.md](CONFIGURATION.md) — not automated in `setup-splunk.sh`).
- **Additional Splunk users:** extend `scripts/setup-splunk.sh` via REST ([CONFIGURATION.md § Appendix](CONFIGURATION.md#appendix-setup-splunksh)).
- **Custom ports:** `docker-compose.override.yml` (gitignored); set `SPLUNK_MCP_ENDPOINT` and re-run `make update-mcp-clients`.

## Project Cursor skills

Tracked skills live under **`.cursor/skills/`** and are intentionally small, slash-invoked helpers:

| Skill | Intent | Boundary |
| ----- | ------ | -------- |
| `/usage` | Static repo cheat sheet for S4R MCP routing, make targets, and MCP park/boot flow | No live health checks unless the user asks. Keep it concise; point to docs instead of duplicating runbooks. |
| `/demo-prep` | Live-demo go/no-go: `make demo-prep` (Splunkbase pins + status + verify), S4R MCP smoke, and MCP auth stats | Do not start, clean, or change NK mode unless the user asked. Do not paste secrets. |
| `/splunk-enterprise-administration-advisor` | Read-only Splunk Enterprise administration guidance for local users, roles, capabilities, configuration precedence, `btool`, service ownership, and maintenance readiness | Advisory only: do not mutate users, roles, config files, app state, indexes, services, or cluster state. Keep source-file, `btool`, and runtime evidence distinct; cite current Splunk Enterprise docs for product behavior. |

All skill files set **`disable-model-invocation: true`** so their bodies are loaded only when invoked. The Splunk Enterprise administration advisor is vendored from **`splunk/splunk-agent-skills`** with its Apache-2.0 **`LICENSE`** beside the skill; preserve that license if refreshing it. Keep workshop role behavior in **`.cursor/agents/`** and the SPL in **`docs/s4r/SPL-CATALOG.md`**; skills should route users to those sources rather than becoming another runbook.

## Contributing

- Shell: ShellCheck-clean; use `set -eu` in new scripts.
- Docs: update the table above when behavior changes; keep secrets out of git.
- License: [LICENSE](../../LICENSE) (MIT).

## Resources

- Splunk REST: <https://docs.splunk.com/Documentation/Splunk/latest/RESTREF>
- Splunk MCP 2.0 clients: [API_REFERENCE.md](API_REFERENCE.md) · auth: [CONFIGURATION.md](CONFIGURATION.md#splunk-mcp-authentication-20)
- MCP Server 2.0: [About MCP Server](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/about-mcp-server-for-splunk-platform) · [Managing custom tools](https://help.splunk.com/en/splunk-cloud-platform/mcp-server-for-splunk-platform/2.0/managing-custom-tools-in-splunk-mcp-server)
- Custom / app MCP tools in this repo: [MCP-TOOLS.md](../s4r/MCP-TOOLS.md)
- MCP: <https://modelcontextprotocol.io/>
