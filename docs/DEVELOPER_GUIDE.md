# Developer Guide

## Project Overview

This is a proof-of-concept environment that integrates:

- **Splunk Enterprise**: Search and indexing platform
- **Splunk MCP Server**: Model Context Protocol implementation for Splunk
- **Claude Desktop**: AI assistant with MCP integration
- **1Password**: Credential management
- **Docker Compose**: Container orchestration

## Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│            Claude Desktop                        │
│  (via npx mcp-remote with Bearer token)         │
└──────────────────┬──────────────────────────────┘
                   │ HTTPS + JWT Bearer Token
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│    Splunk Enterprise (Docker Container)          │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  Splunk MCP Server App (v0.2.4)           │ │
│  │  /services/mcp endpoint                   │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  User: dd                                  │ │
│  │  Role: mcp_user                           │ │
│  │  Auth: Bearer token (15-day expiry)       │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  Volumes:                                        │
│  - so1-var (indexes, logs)                     │
│  - so1-etc (configurations)                    │
└─────────────────────────────────────────────────┘
```

## Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| Container Runtime | Docker | Latest | Isolate Splunk |
| Orchestration | Docker Compose | Latest | Define services |
| Splunk | splunk/splunk | 10.0 | Search platform |
| MCP App | Splunk MCP Server | 0.2.4 | Protocol integration |
| Init Container | curlimages/curl | Latest | Lightweight HTTP client |
| Auth | 1Password CLI | Latest | Secret management |
| Build | Make | Latest | Task automation |
| JSON | jq | Latest | Configuration management |

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

### Modifying Configuration

#### Change Splunk Image

Edit `compose.yml`:

```yaml
environment:
  SPLUNK_IMAGE: splunk/splunk:9.1  # Change version
```

Or override with environment variable:

```bash
SPLUNK_IMAGE=splunk/splunk:9.1 make up
```

#### Add Splunk Configuration

Edit `default.yml`:

```
# Add custom settings
[general]
serverName = my_splunk_instance
site_name = site1
```

#### Modify User Permissions

Edit `scripts/setup-splunk-user.sh`:

```bash
# Add capabilities to role
curl ... -d "capability=accelerate_datamodel" \
         -d "capability=admin_all_objects"
```

#### Change Port Mappings

Edit `compose.yml`:

```yaml
ports:
  - "9000:8000"     # Changed from 8000
  - "9089:8089"     # Changed from 8089
```

### Adding Dependencies

#### Add Python Library

1. Create `requirements.txt`
2. Modify `scripts/setup-splunk-user.sh` to install
3. Test with `docker exec so1 python -m pip install -r requirements.txt`

#### Add Node.js Package

1. Install globally: `npm install -g package-name`
2. Or modify container startup to install

### Testing

#### Unit Tests

Test individual components:

```bash
# Test API connectivity
curl -k -u admin:password https://localhost:8089/services/server/info

# Test user creation
curl -k -u admin:password https://localhost:8089/services/authentication/users/dd

# Test token generation
curl -k -H "Authorization: Bearer $TOKEN" https://localhost:8089/services/mcp
```

#### Integration Tests

Test full workflow:

```bash
#!/bin/bash
set -e

# Start fresh
make clean
make up

# Wait for readiness
sleep 120

# Check all components
make status

# Test endpoints
TOKEN=$(curl -k -s -u admin:password https://localhost:8089/services/authorization/tokens | grep -o 'token.*' | sed 's/.*<!\[CDATA\[\(.*\)\]\].*/\1/' | head -1)

curl -k -H "Authorization: Bearer $TOKEN" https://localhost:8089/services/mcp | jq .

echo "✓ All tests passed"
```

#### Manual Testing

```bash
# Start containers
make up

# In separate terminal, watch logs
make logs

# Test in another terminal
curl -k -u admin:password https://localhost:8089/services/server/info

# Test Claude Desktop connection
# Open Claude and verify Splunk MCP is available
```

## Extending the System

### Adding Custom MCP Tools

1. **Inside Splunk container**

   ```bash
   docker exec -it so1 /bin/bash
   ```

2. **Navigate to MCP app**

   ```bash
   cd /opt/splunk/etc/apps/splunk_mcp_server/
   ```

3. **Add custom tool definition**
   - Create new tool JSON
   - Register in MCP configuration

### Adding a Secondary User

Edit `scripts/setup-splunk-user.sh`:

```bash
# Create another user
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/authentication/users" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "name=user2" \
  -d "password=password2" \
  -d "roles=mcp_user"

# Generate token for user2
curl ${CURL_OPTS} -X POST "${SPLUNK_URL}/services/authorization/tokens" \
  -u "${SPLUNK_USER}:${SPLUNK_PASSWORD}" \
  -d "status=enabled" \
  -d "name=user2" \
  -d "audience=mcp"
```

### Integrating with CI/CD

#### GitHub Actions Example

```yaml
name: Test Splunk Setup

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Start Splunk
        run: make up
        
      - name: Wait for ready
        run: sleep 120
        
      - name: Check status
        run: make status
        
      - name: Run tests
        run: bash test.sh
        
      - name: Cleanup
        run: make down
```

## Debugging

### Enable Debug Logging

```bash
# In setup script
bash -x scripts/setup-splunk-user.sh

# In Docker Compose
docker compose up --verbose
```

### Inspect Container State

```bash
# Enter container
docker exec -it so1 /bin/bash

# Check Splunk logs
tail -f /opt/splunk/var/log/splunk/splunkd.log

# Check file permissions
ls -la /opt/splunk/etc/

# Test connectivity
curl -k https://localhost:8089/services/server/info
```

### Check Volume Contents

```bash
# List volume contents
docker run --rm -v so1-var:/data alpine ls -la /data/

# Extract config file
docker run --rm -v so1-etc:/data alpine cat /data/system/default/limits.conf
```

### Network Debugging

```bash
# Check bridge network
docker network inspect splunk

# Test DNS resolution
docker exec so1 nslookup so1

# Check routing
docker exec so1 route -n
```

## Performance Tuning

### Resource Allocation

Edit Docker Desktop preferences:

- CPU: Allocate 4+ cores
- Memory: Allocate 8GB+
- Disk: Ensure 20GB+ available

### Splunk Tuning

In `default.yml`:

```
[httpServer]
maxThreads = 256
maxSockets = 256

[scheduler]
max_searches_per_cpu = 4

[search]
dispatch_dir_warning_threshold = 75
```

## Best Practices

### Security

1. **Rotate tokens**: Generate new tokens before expiry
2. **Use strong passwords**: Don't use `changeme` in production
3. **Restrict network access**: Use firewall rules
4. **Update regularly**: Keep Splunk and Docker current
5. **Audit access**: Review logs and user permissions

### Maintenance

1. **Backup volumes**: Regularly backup `so1-var` and `so1-etc`
2. **Monitor disk space**: Splunk indexes grow over time
3. **Review logs**: Check `splunkd.log` for errors
4. **Clean old data**: Implement index retention policies
5. **Document changes**: Track configuration modifications

### Development

1. **Use version control**: Commit all code changes
2. **Test before deploying**: Verify in dev environment
3. **Document APIs**: Keep endpoint documentation updated
4. **Follow conventions**: Maintain consistent code style
5. **Comment code**: Add comments to complex logic

## Contributing

### Code Style

- **Bash scripts**: Use ShellCheck for validation
- **JSON**: Use `jq` for formatting
- **Markdown**: Follow standard conventions
- **YAML**: Use 2-space indentation

### Testing Requirements

Before submitting changes:

1. Run `make up` and verify startup
2. Run `make status` and verify health
3. Test API endpoints manually
4. Review logs for errors
5. Run `make down && make clean` to reset

### Documentation

Update documentation when making changes:

- Update README.md for user-facing changes
- Update ARCHITECTURE.md for system changes
- Update API_REFERENCE.md for API changes
- Add entries to CHANGELOG.md (if exists)

## Useful Development Commands

```bash
# Full test cycle
make clean && make up && sleep 120 && make status && make logs

# Watch logs in real-time
make logs | grep -i "error\|warning\|mcp"

# Test specific endpoint
curl -v -k -u admin:password https://localhost:8089/services/server/info

# Interactive container
docker exec -it so1 bash

# Check resource usage
docker stats

# View volume structure
docker volume inspect so1-var

# Save debug info
bash diagnose.sh > debug.txt
```

## Learning Resources

### Splunk

- [Official Splunk Documentation](https://docs.splunk.com/)
- [REST API Reference](https://docs.splunk.com/Documentation/Splunk/latest/RESTREF)
- [Admin Manual](https://docs.splunk.com/Documentation/Splunk/latest/Admin)

### Docker

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Best Practices](https://docs.docker.com/develop/dev-best-practices/)

### MCP Protocol

- [MCP Specification](https://modelcontextprotocol.io/)
- [Protocol Details](https://modelcontextprotocol.io/docs/concepts/architecture)

### 1Password

- [1Password CLI Documentation](https://developer.1password.com/docs/cli/)
- [Secret Injection](https://developer.1password.com/docs/cli/secret-template-syntax/)

## Troubleshooting Development Issues

See TROUBLESHOOTING.md for common issues and solutions.

## Getting Help

- Check existing issues in the repository
- Review documentation in this project
- Consult Splunk official documentation
- Test with minimal reproducible example
- Collect diagnostic information (see TROUBLESHOOTING.md)
