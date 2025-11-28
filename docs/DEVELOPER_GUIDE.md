# Developer Guide

## Project Overview

This is a proof-of-concept environment that integrates:

- **Splunk Enterprise**: Search and indexing platform
- **Splunk MCP Server**: Model Context Protocol implementation for Splunk
- **Claude Desktop**: AI assistant with MCP integration
- **1Password**: Credential management
- **Docker Compose**: Container orchestration

See ARCHITECTURE.md for detailed system design.

## Tech Stack

| Component | Version | Purpose |
|-----------|---------|---------|
| Docker | Latest | Container runtime |
| Docker Compose | Latest | Orchestration |
| Splunk | 10.0 | Search platform |
| MCP App | 0.2.4 | Protocol integration |
| 1Password CLI | Latest | Secrets |
| Make | Latest | Automation |
| jq | Latest | JSON processing |

## File Structure Explanation

### Configuration Files

#### `compose.yml`

- Defines Docker services (so1, splunk-init)
- Volume mounts for persistence
- Network configuration
- Port mappings
- Health checks

```yaml
services:
  so1:                        # Main Splunk service
    image: ${SPLUNK_IMAGE}   # From .env
    ports:
      - "8000:8000"          # Web UI
      - "8089:8089"          # API / MCP
    volumes:
      - so1-var:/opt/splunk/var     # Indexes
      - so1-etc:/opt/splunk/etc     # Configs
    restart: always

  splunk-init:               # One-time initialization
    depends_on:
      so1:
        condition: service_healthy
    volumes:
      - ./scripts/setup-splunk-user.sh:/setup-splunk-user.sh
```

#### `default.yml`

- Splunk configuration defaults
- Mounted at `/tmp/defaults/default.yml`
- Gets merged with Splunk defaults during startup
- Can be customized for specific requirements

#### `tpl.env`

- Template for environment variables
- Uses 1Password references: `op://vault/item/field`
- Processed by `make init` to create `.env`

#### `.env` (git-ignored)

- Runtime environment variables
- Contains secrets from 1Password
- Never committed to version control
- Generated during `make init`

### Scripts

#### `scripts/setup-splunk-user.sh`

Main initialization script. Steps:

1. **Creates role `mcp_user`**
   - Makes REST API call to `/services/authorization/roles`
   - Minimal capabilities for MCP operations

2. **Creates user `dd`**
   - Makes REST API call to `/services/authentication/users`
   - Assigns `mcp_user` role
   - Uses password from environment

3. **Generates authentication token**
   - Makes REST API call to `/services/authorization/tokens`
   - Status: enabled
   - Audience: mcp
   - Extracts token from CDATA response

4. **Configures Claude Desktop**
   - Reads existing Claude config (if any)
   - Uses `jq` to safely update JSON
   - Inserts token into MCP server configuration
   - Creates directory if needed

**Error Handling:**

- Checks for `jq` installation
- Validates JSON during updates
- Backs up corrupted configs
- Graceful handling of already-existing resources

### Build Automation

#### `Makefile`

Key targets:

```makefile
init:            # 1Password injection → .env
up:              # Start containers and wait
down:            # Stop containers
restart:         # Restart containers
clean:           # Remove everything (destructive)
logs:            # Follow container logs
status:          # Check health
token:           # Generate new token
claude-config:   # Show Claude config
```

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

**Change Splunk version** - Edit `compose.yml`:

```yaml
environment:
  SPLUNK_IMAGE: splunk/splunk:9.1
```

**Add Splunk config** - Edit `default.yml`:

```
[general]
serverName = my_splunk_instance
site_name = site1
```

**Change port mappings** - Edit `compose.yml`:

```yaml
ports:
  - "9000:8000"     # Web UI
  - "9089:8089"     # API
```

See ARCHITECTURE.md for all configuration options.

See TROUBLESHOOTING.md for common issues and ARCHITECTURE.md for extending the system.

See API_REFERENCE.md for endpoint testing examples.

## Extending the System

### Add Custom Log Index

To monitor additional log sources (similar to Claude logs):

1. **Edit compose.yml** - Add new bind mount:

```yaml
volumes:
  - /path/to/logs:/var/log/custom_logs:rw
```

2. **Edit setup-splunk-user.sh** - Add monitor input:

```bash
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/data/inputs/monitor/" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=/var/log/custom_logs" \
  -d "index=custom_index"
```

### Add Additional Users

Edit `scripts/setup-splunk-user.sh`:

```bash
curl -X POST "${SPLUNK_URL}/services/authentication/users" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=user2" -d "password=pass" -d "roles=mcp_user"
```

## CI/CD Integration

For GitHub Actions, use `make up`, `make status`, and `make down` targets. See Makefile for available commands.

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

**Security**: Rotate tokens before expiry, use strong passwords, restrict network access, keep software updated.

**Maintenance**: Backup volumes regularly, monitor disk space, review logs for errors, document changes.

**Development**: Use version control, test changes, keep documentation current, maintain consistent style.

## Contributing

**Code Style**: Use ShellCheck for bash, jq for JSON, 2-space indentation for YAML.

**Testing**: Run `make up`, verify `make status`, test endpoints, review logs.

**Documentation**: Update relevant docs (README, ARCHITECTURE, API_REFERENCE) with changes.

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
