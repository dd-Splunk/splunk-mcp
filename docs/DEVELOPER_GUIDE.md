# Developer guide

Contributing and changing this PoC. Stack design: [ARCHITECTURE.md](ARCHITECTURE.md). Env and clients: [CONFIGURATION.md](CONFIGURATION.md). CI: [CI_CD.md](CI_CD.md).

## What to edit when

| Change | Update |
| ------ | ------ |
| `Makefile`, `compose.yml`, `scripts/setup-splunk.sh` | [CONFIGURATION.md](CONFIGURATION.md), [ARCHITECTURE.md](ARCHITECTURE.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md) as needed |
| MCP client paths / token flow | [CONFIGURATION.md](CONFIGURATION.md), [API_REFERENCE.md](API_REFERENCE.md) |
| SA-S4R Eventgen / NK toggle | [SA-S4R-APP.md](SA-S4R-APP.md), [s4r/README.md](s4r/README.md) |
| SA-S4R app UI / knowledge objects | **`SA-S4R/local/`** only (never **`default/`**); workshop guide **`local/README`** (only tracked file under **`local/`**) — [SA-S4R-APP.md](SA-S4R-APP.md) |
| Workshop SPL | [S4R-SPL-CATALOG.md](S4R-SPL-CATALOG.md) only (agents reference this path) |
| Agent prompts | `.cursor/agents/s4r-*.md`, [S4R-AGENTS.md](S4R-AGENTS.md) |

Source of truth when docs disagree with code: [docs/README.md](README.md#source-of-truth-when-docs-disagree-with-code) and [AGENTS.md](../AGENTS.md).

## Local test loop

```bash
make down
make clean          # destructive — removes volumes
make up
make status
make verify-mcp-remote
```

Logs: `make logs` · shell in Splunk: `docker exec -it so1 bash`

## Lint before push

```bash
pre-commit run --all-files
```

Requires **shellcheck** and **Node/npx** (markdownlint). See [CI_CD.md](CI_CD.md).

## Extending the stack

- **Optional log ingest:** uncomment Claude bind mount in `compose.yml`; create index + monitor in Splunk ([CONFIGURATION.md](CONFIGURATION.md) — not automated in `setup-splunk.sh`).
- **Additional Splunk users:** extend `scripts/setup-splunk.sh` via REST ([CONFIGURATION.md § Appendix](CONFIGURATION.md#appendix-setup-splunksh)).
- **Custom ports:** `docker-compose.override.yml` (gitignored); set `SPLUNK_MCP_ENDPOINT` and re-run `make update-mcp-clients`.

## Contributing

- Shell: ShellCheck-clean; use `set -eu` in new scripts.
- Docs: update the table above when behavior changes; keep secrets out of git.
- License: [LICENSE](../LICENSE) (MIT).

## Resources

- Splunk REST: <https://docs.splunk.com/Documentation/Splunk/latest/RESTREF>
- Splunk MCP 1.2 clients: [API_REFERENCE.md](API_REFERENCE.md)
- MCP: <https://modelcontextprotocol.io/>
