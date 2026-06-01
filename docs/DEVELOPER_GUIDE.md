# Developer Guide

## Project Overview

This is a proof-of-concept environment that integrates:

- **Splunk Enterprise**: Search and indexing platform
- **Splunk MCP Server**: Model Context Protocol implementation for Splunk
- **Claude Desktop**: AI assistant with MCP integration
- **1Password**: Credential management
- **Docker Compose**: Container orchestration

See ARCHITECTURE.md for detailed system design.

## Tech stack (pinning)

| Component | Source of truth | Notes |
| --------- | ---------------- | ----- |
| Splunk Enterprise | `SPLUNK_IMAGE` in local `tpl.env` / `.env` (default `splunk/splunk:latest` in **`tpl.env.example`**) | **Build** is whatever that tag resolves to when pulled—verify at runtime (`services/server/info`). |
| Splunk MCP Server app | `SPLUNK_APPS_URL` in `compose.yml` (Splunkbase URLs, e.g. app `1924`) | Package **release** is in the URL path, not a separate semver in this repo. |
| Docker / Compose | Host installation | Use recent versions; see [INSTALLATION.md](INSTALLATION.md). |
| 1Password CLI | `op` | Used for `op run` with `make up` when `.env` is absent. |
| `make`, `jq`, `curl` | Host | Required by Makefile and scripts. |

## File Structure Explanation

### Configuration Files

#### `compose.yml`

- Defines Docker services (so1, splunk-init, mcp-proxy)
- Volume mounts for persistence
- Network configuration
- Port mappings
- Health checks

```yaml
services:
  so1:
    image: ${SPLUNK_IMAGE}
    ports:
      - "8000:8000"
      - "8089:8089"
    volumes:
      - so1-var:/opt/splunk/var
      - so1-etc:/opt/splunk/etc
    restart: always

  splunk-init:               # One-time initialization
    depends_on:
      so1:
        condition: service_healthy
    volumes:
      - ./scripts/setup-splunk.sh:/setup-splunk.sh
```

#### `tpl.env.example` and `tpl.env`

- **`tpl.env.example`**: Tracked placeholder template (copy to **`tpl.env`**; **`tpl.env`** is gitignored).
- Uses 1Password references: `op://vault/item/field` (must match **your** vault).
- Consumed by **`op run --env-file=tpl.env`** when `.env` is absent (`make up`)

#### `.env` (git-ignored, optional)

- Hand-written from **`.env.example`** (Path B); never commit
- If present, Compose loads it automatically; if absent, the Makefile uses `op run` with **`tpl.env`**
- Never commit to version control

### Scripts

#### `scripts/setup-splunk.sh`

Main initialization script (runs in `splunk-init`). Steps:

1. **SA-Eventgen** — Enables the default Eventgen modular input when the app is installed.

2. **MCP server dev settings** — POST `ssl_verify=false` on the Splunk MCP app config (local dev only).

3. **Role `mcp_user`** — Creates or updates `/services/authorization/roles/mcp_user` with capability **`mcp_tool_execute`**.

4. **User `splunker`** — Creates or updates via `/services/authentication/users` with Splunk roles **`user`** and **`mcp_user`** (override with **`SPLUNK_MCP_USER`**). Does **not** grant **`admin`**.

5. **MCP password** — Uses `SPLUNK_MCP_PASSWORD` (env) for the MCP execution user. This repo does not write passwords to disk.

**Not** in this minimal script: **`claude_logs`** index/monitor automation.

Host-side **Claude** / **Cursor** / **Goose** config is updated by `scripts/mcp-client.sh` (`make update-mcp-clients`), not by this script inside the container.

**Error Handling:**

- Checks for `jq` installation
- Validates JSON during updates
- Backs up corrupted configs
- Graceful handling of already-existing resources

### Build Automation

#### `Makefile`

Key targets:

```text
make help                 # Target list (default goal)
make up                   # scripts/compose-up.sh → update-*-config
make down / restart       # docker compose (no op)
make logs / status        # docker logs / health probe
make clean                # down -v + remove .env
make verify-mcp-remote    # scripts/mcp-client.sh verify (MCP_VERIFY_CLIENT=all)
```

Linting: **pre-commit** (shellcheck + markdownlint), not Makefile targets.

## Development Workflow

### Local Development

1. **Clone repository**

   ```bash
   git clone <url> splunk-mcp
   cd splunk-mcp
   ```

2. **Make changes**
   - Edit configuration files
   - Modify scripts
   - Update Makefile targets

3. **Test changes**

   ```bash
   make down
   make clean
   make up
   make status
   ```

4. **View logs**

   ```bash
   make logs
   ```

### Customize Configuration

**Change Splunk image tag** — set in local **`tpl.env`** / **`.env`** (variable `SPLUNK_IMAGE`), e.g.:

```bash
SPLUNK_IMAGE=splunk/splunk:9.4
```

`compose.yml` references `${SPLUNK_IMAGE:-splunk/splunk:latest}` on the `so1` service `image:` key—not under `environment:`.

**Change port mappings** - Edit `compose.yml`:

```yaml
ports:
  - "9000:8000"     # Web UI
  - "9089:8089"     # API
```

See ARCHITECTURE.md for all configuration options.

See TROUBLESHOOTING.md and ARCHITECTURE.md for details.

See API_REFERENCE.md for endpoint testing examples.

## Extending the System

### Add Custom Log Index

To monitor additional log sources (similar to Claude logs):

1. **Edit compose.yml** - Add new bind mount:

```yaml
volumes:
  - /path/to/logs:/var/log/custom_logs:rw
```

1. **Edit setup-splunk.sh** - Add monitor input:

```bash
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/data/inputs/monitor/" \
  -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
  -d "name=/var/log/custom_logs" \
  -d "index=custom_index"
```

### Add Additional Users

Edit `scripts/setup-splunk.sh`:

```bash
curl -X POST "${SPLUNK_URL}/services/authentication/users" \
  -u "${SPLUNK_REST_USER}:${SPLUNK_PASSWORD}" \
  -d "name=user2" -d "password=pass" -d "roles=user" -d "roles=mcp_user"
```

## CI/CD Integration

For CI/CD, use make targets: `make up`, `make status`, `make down`.

## Debugging

See TROUBLESHOOTING.md for common issues. Quick debugging:

```bash
make logs | tail -100         # View recent logs
bash -x script.sh             # Run with debug output
docker exec -it so1 /bin/bash # Interactive shell
curl -v -k https://...        # Verbose curl
```

See ARCHITECTURE.md for performance tuning and resource requirements.

## Best Practices

**Security**: Rotate tokens, strong passwords, restrict access.

**Maintenance**: Backup volumes, monitor disk, review logs.

**Development**: Use version control, test, document changes.

## Contributing

**Code Style**: ShellCheck, jq, 2-space YAML indentation.

**Testing**: Run `make up`, verify `make status`, test endpoints, review logs.

**Documentation**: Update relevant docs with changes.

## Useful Commands

```bash
make clean && make up && sleep 120 && make status  # Full test cycle
make logs | grep -i error                          # Filter errors
docker exec -it so1 bash                           # Container shell
docker stats                                        # Resource usage
```

## Resources

- Splunk API: <https://docs.splunk.com/Documentation/Splunk/latest/RESTREF>
- Docker: <https://docs.docker.com/>
- MCP: <https://modelcontextprotocol.io/>
- 1Password CLI: <https://developer.1password.com/docs/cli/>

See TROUBLESHOOTING.md for solutions to common issues.
