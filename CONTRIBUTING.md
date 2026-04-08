# Contributing

Thanks for helping improve this repo. It is a **local PoC** for Splunk Enterprise + Splunk MCP Server; changes should keep `make up`, `make status`, and `make verify-mcp-remote` working for a clean clone.

## Before you open a PR

1. Read **[AGENTS.md](AGENTS.md)** — secrets, idempotent setup, and which files must never contain live tokens.
2. Prefer **small, focused** changes (one concern per PR when possible).
3. If you change **`Makefile`**, **`compose.yml`**, or **`scripts/setup-splunk.sh`**, update the docs listed in AGENTS.md (typically `docs/CONFIGURATION.md`, `docs/OVERVIEW.md`, and/or `docs/TROUBLESHOOTING.md`).

## Secrets and config

- **Never commit** `.env`, `.secrets/*`, live Bearer tokens in `.cursor/mcp.json`, or similar.
- **`tpl.env`** in git must stay a **template** (placeholder `op://` paths only).
- Do not paste passwords or tokens into issues, PR descriptions, or logs.

## How to verify locally

```bash
make up          # or ensure stack already healthy
make status
make verify-mcp-remote
```

If your change touches client config scripts, spot-check the relevant target (`make claude-update`, `make cursor-mcp`, or `make goose-update`) in a safe environment.

### Markdown

Documentation under `docs/`, plus root `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, and `.github/**/*.md`, is linted with **[markdownlint-cli2](https://github.com/DavidAnson/markdownlint-cli2)** (config: `.markdownlint.json`, globs: `.markdownlint-cli2.jsonc`).

```bash
make lint-md       # check
make lint-md-fix   # apply safe auto-fixes
```

**MD013** (line length) is disabled so long URLs and tables stay readable; other default rules apply. Fragment docs may start with `##` (**MD041** off); **MD036** (bold as heading) is off for config-style sections.

## Documentation

- **README** stays short; deeper detail belongs under **`docs/`**.
- Cross-link to existing guides instead of duplicating long procedures.

## License

By contributing, you agree that your contributions are licensed under the **[LICENSE](LICENSE)** (MIT).
