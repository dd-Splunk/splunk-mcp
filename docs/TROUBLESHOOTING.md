# Troubleshooting Guide

## Common Issues & Solutions

### Container Issues

#### Issue: Docker daemon is not running

**Error**: `Cannot connect to Docker daemon`

**Solution**:

1. Start Docker Desktop application
2. Wait for it to fully load
3. Verify: `docker ps`

---

#### Issue: Port already in use

**Error**: `Address already in use` or `Bind for 0.0.0.0:8000 failed`

**Symptoms**: Cannot start Splunk container

**Solution**:

```bash
# Find process using port 8000
lsof -i :8000

# Find process using port 8089
lsof -i :8089

# Kill the process
kill -9 <PID>

# Or stop the conflicting service
# Example: Stop another Docker container
docker ps
docker stop <container_id>

# Retry
make up
```

**Alternative**: Use different ports by modifying `compose.yml`:

```yaml
ports:
  - "9000:8000"  # Changed from 8000
  - "9089:8089"  # Changed from 8089
```

---

#### Issue: Container exits immediately

**Error**: Container starts then stops

**Solution**:

```bash
make logs  # Check for errors

# Common causes:
# 1. License acceptance - verify SPLUNK_GENERAL_TERMS in compose.yml
# 2. Insufficient memory - increase Docker resources
# 3. Disk space - ensure 10GB free

make down && make clean && make up
```

---

#### Issue: Splunk container stuck in starting state

**Error**: Takes more than 5 minutes to start

**Solution**:

1. Increase Docker resource limits:
   - Open Docker Desktop preferences
   - Resources tab
   - Increase CPU and Memory

2. Check logs for stuck processes:

   ```bash
   make logs
   ```

3. Force restart:

   ```bash
   make down
   docker volume rm so1-var so1-etc
   make up
   ```

---

### Environment & Configuration Issues

#### Issue: `make up` fails with 1Password authentication error

**Error**: `Not currently authenticated` or `Account not found`

**Solution**:

```bash
# Authenticate with 1Password
op account add

# Follow the prompts:
# 1. Enter your 1Password account domain (e.g., my.1password.com)
# 2. Enter your email
# 3. Enter your master password
# 4. Enter your secret key

# Verify authentication
op account list

# Retry
make up
```

---

#### Issue: `op` command not found

**Error**: `op: command not found`

**Solution**:

```bash
# Install 1Password CLI
# macOS
brew install 1password-cli

# Verify
op --version

# Retry
make up
```

---

#### Issue: `tpl.env` not found (fresh clone)

**Error** (from `make up`): `tpl.env missing` / `copy the example…`

**Solution**: Create a local file from the tracked template (once per clone):

```bash
cp tpl.env.example tpl.env
```

Edit **`tpl.env`** with your `op://` paths. **`tpl.env`** is gitignored—do not commit it.

---

#### Issue: `make up` fails even though `op read "op://…"` works

**Common causes**:

1. **Extra quotes in `tpl.env`** — Use `VAR=op://vault/item/field` (no surrounding `"`…`"`). If the value is `"op://…"`, `op run` may leave quotes in the value and Compose will see invalid credentials.
2. **Spaces in item titles** — **`make up`** resolves secrets with **`op run --env-file=tpl.env`** (not **`op inject`**), which handles spaces in `op://` paths when unquoted.

---

#### Issue: Missing secrets in 1Password

**Error**: `ERROR: item "op://Private/Splunk-MCP-PoC/password" not found`

**Solution**:

1. Verify items in 1Password:

   ```bash
   op read "op://Private/Splunk-MCP-PoC/password"
   ```

2. If not found, create items:
   - See INSTALLATION.md for 1Password setup steps

3. Update `tpl.env` if paths are different:

   ```bash
   cat tpl.env
   ```

---

#### Issue: `.env` file not created / `SPLUNK_PASSWORD` not set

**Context**: `make up` uses **`op run --env-file=tpl.env`** when `.env` is missing. If `op` cannot resolve secrets, Compose will not get passwords.

**Error**: `Error: SPLUNK_PASSWORD not set` (or similar from Compose)

**Solution**:

1. Sign in: `op signin` (or use desktop integration) and confirm `op read` works for every path in **`tpl.env`**, then **`make up`**.
2. Or create **`.env` manually** from **`.env.example`** (Path B; dev only; do not commit):

   ```bash
   cat > .env << 'EOF'
   SPLUNK_IMAGE=splunk/splunk:latest
   SPLUNK_PASSWORD=your_password_here
   SPLUNKBASE_USER=your_username
   SPLUNKBASE_PASS=your_password
   TZ=Europe/Brussels
   EOF

   make up
   ```

---

#### Issue: Splunk logs show `Invalid Splunkbase credentials` / ansible inventory errors

**Cause**: The **`so1`** container was created with **empty** `SPLUNKBASE_USER` / `SPLUNKBASE_PASS` (and often `SPLUNK_PASSWORD`). That happens if you run **`docker compose up -d`** without a **`.env`** file and without **`op run --env-file=tpl.env`**—Compose substitutes blank strings, and Splunk’s entrypoint refuses Splunkbase downloads.

**Fix**:

1. Prefer **`make up`**, which injects secrets via **`op run`** (or uses **`.env`**). Do not rely on plain **`docker compose up`** unless **`.env`** exists and is populated.
2. Verify 1Password paths in **`tpl.env`** (item titles with **spaces** must match exactly). Test:

   ```bash
   op read "op://YourVault/YourItem/password"
   ```

3. After changing secrets, reset volumes so the container is **recreated** with new env:

   ```bash
   make clean   # or: make down && docker volume rm so1-var so1-etc
   make up
   ```

**Note**: **`make logs`** uses **`docker logs so1`** (not `docker compose logs`) so you do not see misleading host-side warnings about unset variables when **`.env`** is absent; those warnings do not fix a container that was already started without credentials.

---

### Splunk Initialization Issues

#### Issue: splunk-init container fails

**Error**: `splunk-init exited with code 1`

**Symptoms**: Splunk running but user/role/token not created

**Solution**:

```bash
docker logs splunk-init  # Check error
make logs | tail -50     # Check Splunk readiness

# Wait 2-3 minutes for Splunk initialization, then retry:
make down && make up

# If still failing, run manually:
./scripts/setup-splunk.sh
```

---

#### Issue: Splunk MCP app not installed

**Error**: MCP endpoint returns 404

**Symptoms**: Cannot connect Claude Desktop to Splunk

**Solution**:

```bash
# Check installed apps
curl -k -u admin:password https://localhost:8089/services/appserver/apps \
  | grep -i "mcp\|model"

# If not found, check download URL in compose.yml:
cat compose.yml | grep SPLUNK_APPS_URL

# Expected Splunkbase apps (IDs and names) are listed in CONFIGURATION.md under compose.yml.
# If a 404 on download, update the /release/VERSION/ segment in SPLUNK_APPS_URL for that app.

# Verify Splunkbase credentials:
op read "op://Private/Splunkbase/username"
op read "op://Private/Splunkbase/password"

# If credentials wrong, update 1Password (or .env) and recycle the stack:
make down
docker volume rm so1-var so1-etc
make up
```

---

#### Issue: Splunk AI Toolkit — "Failed to fetch config metadata" / Empty response (Connection Management)

**Symptoms**: In Splunk Web, as user `splunker` (or any user with MLTK roles), adding an external LLM connection shows: `Failed to fetch config metadata: Empty response.`

**Root cause (typical)**: The UI calls `GET /servicesNS/<user>/Splunk_ML_Toolkit/mltk/aicommander_metadata`, which can return HTTP **500** with a **non-JSON** body. That often means the **Python for Scientific Computing** add-on is missing: MLTK’s REST handler imports `Splunk_SA_Scientific_Python_linux_x86_64`. If that app is not installed, `splunkd.log` will show: `Failed to find Python for Scientific Computing Add-on (Splunk_SA_Scientific_Python_linux_x86_64)`.

**Fix**:

1. Ensure **app/2882** (Python for Scientific Computing, Linux 64-bit) is in **`SPLUNK_APPS_URL`** in **`compose.yml`**, *before* or with MLTK (see **CONFIGURATION.md** table), and that Splunkbase credentials allow the download.
2. Restart / reinstall apps as needed, then re-open the Connection Management UI. (On existing volumes, you may need to install 2882 from Splunkbase under **Manage apps** or recreate the stack after updating **`SPLUNK_APPS_URL`**.)

**Verify** (as admin, after the add-on is present and Splunk is healthy):

```bash
curl -k -u admin:password "https://localhost:8089/servicesNS/admin/Splunk_ML_Toolkit/mltk/aicommander_metadata?output_mode=json" | head -c 400
```

A healthy response is JSON with a `metadata` object; a missing Scientific Python add-on returns **500** with a short non-JSON error.

If apps still do not install, use the same Splunkbase credential and volume reinit steps as in **Issue: Splunk MCP app not installed** above.

---

### API & Connectivity Issues

#### Issue: Cannot reach Splunk API

**Error**: `Connection refused` or `Failed to connect`

**Symptoms**: `curl` commands fail

**Solution**:

```bash
# Check if container is running
make status

# Check network connectivity
docker exec so1 curl -k https://localhost:8089/services/server/info

# Check from host machine
curl -k https://localhost:8089/services/server/info

# If still failing:
# 1. Verify ports are mapped: docker port so1
# 2. Check firewall: disable temporarily
# 3. Restart container: make restart
```

---

#### Issue: Authentication failed

**Error**: `401 Unauthorized` or `Invalid credentials`

**Symptoms**: API calls fail with auth error

**Solution**:

```bash
# Verify credentials in .env
cat .env | grep SPLUNK

# Test with correct credentials
curl -k -u admin:$SPLUNK_PASSWORD https://localhost:8089/services/server/info

# If credentials wrong:
# 1. Update .env manually
# 2. Restart container: make restart
# 3. Or regenerate: make clean && make up
```

---

#### Issue: SSL certificate error

**Error**: `SSL_ERROR_SELF_SIGNED_CERT` or `certificate verify failed`

**Solution**:

```bash
# For curl: use -k flag (already in scripts)
curl -k https://localhost:8089/...

# For Python: disable verification
import urllib3
urllib3.disable_warnings()

# For Node.js: set NODE_TLS_REJECT_UNAUTHORIZED
NODE_TLS_REJECT_UNAUTHORIZED=0 node app.js

# Note: Only do this for localhost/development!
```

---

### Token Issues

#### Issue: Token generation fails

**Error**: `Failed to create token` or splunk-init exits non-zero

**Solution**:

```bash
# Check Splunk is ready
make status

# Verify user exists
curl -k -u admin:password https://localhost:8089/services/authentication/users/splunker

# Try manual encrypted MCP token (matches setup-splunk.sh)
curl -skS -u admin:$SPLUNK_PASSWORD \
  "https://localhost:8089/servicesNS/admin/Splunk_MCP_Server/mcp_token?username=splunker&output_mode=json" | jq .

# If error about permissions, verify admin user still exists:
curl -k -u admin:password https://localhost:8089/services/server/info
```

---

#### Issue: Token expired

**Error**: Claude Desktop disconnects after 15 days

**Solution**:

```bash
# Generate new token
make up
# or re-run token generation manually:
# curl -skS -u admin:$SPLUNK_PASSWORD \
#   "https://localhost:8089/servicesNS/admin/Splunk_MCP_Server/mcp_token?username=splunker&output_mode=json" | jq -r .token > .secrets/splunk-token

# Update Claude Desktop config
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Restart Claude Desktop
# (Fully quit and reopen)
```

---

#### Issue: Cannot parse token from response

**Error**: Token shows empty or malformed

**Solution**:

```bash
# Check token response
curl -k -s -X POST https://localhost:8089/services/authorization/tokens \
  -u admin:password \
  -d "status=enabled" \
  -d "name=test" \
  -d "audience=mcp" | grep -A 5 "token"

# Token should be in CDATA section:
# <s:key name="token"><![CDATA[eyJ...]]></s:key>

# If CDATA format changed, update sed expression in setup script:
# Current: sed -n 's/.*<!\[CDATA\[\(.*\)\]\].*/\1/p'
```

---

### Claude Desktop Integration Issues

#### Issue: Claude Desktop cannot connect to Splunk

**Error**: "MCP server connection failed" or timeout

**Symptoms**: No Splunk tools available in Claude

**Solution**:

1. **Verify config file**:

   ```bash
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
   
   # Should contain:
   # - "splunk-mcp-server"
   # - "https://localhost:8089/services/mcp"
   # - Valid Bearer token
   ```

2. **Restart Claude Desktop**:
   - Force quit: Cmd+Q
   - Wait 2 seconds
   - Reopen from Applications

3. **Check token validity**:

   ```bash
   # Token should be recent
   curl -k -u admin:password https://localhost:8089/services/authorization/tokens
   ```

4. **Test connection manually**:

   ```bash
   TOKEN="your_token_here"
   curl -k -H "Authorization: Bearer $TOKEN" \
     https://localhost:8089/services/mcp
   ```

5. **Check Claude logs**:

   ```bash
   log stream --predicate 'process == "Claude"' --level debug
   ```

---

#### Issue: mcp-remote fails with `405`, `SseError`, or `Using custom headers: {"Authorization":""}`

**Cause**: The shell split your `--header` value into multiple words. `mcp-remote` only reads the **next** argument after `--header`. If you run:

```bash
npx -y mcp-remote https://localhost:8089/services/mcp --header Authorization: Bearer YOUR_TOKEN
```

then the first header argument is the word `Authorization:` (with nothing after the colon), so the parsed header is `Authorization` with an **empty** value. Logs will show `Using custom headers: {"Authorization":""}`. Without a Bearer token, the client then mis-handles errors (often HTML) and you may see `405`, OAuth parse errors, or SSE failures.

**Fix**: Pass the header as **one** argument (quoted):

```bash
TOKEN=$(tr -d '\n' < .secrets/splunk-token)
export NODE_TLS_REJECT_UNAUTHORIZED=0   # dev only; matches .cursor/mcp.json
npx -y mcp-remote "https://localhost:8089/services/mcp" \
  --header "Authorization: Bearer ${TOKEN}"
```

**Cursor / Claude** configs use JSON `args` with two strings (`--header` and `Authorization: Bearer …`) — that is already correct. This mistake mainly happens when you copy-paste a manual `npx` command into a terminal.

**Verify**: From the repo root, with Splunk up:

```bash
make verify-mcp-remote
```

You should see `OK: mcp-remote connected to Splunk (Streamable HTTP).`

---

#### Issue: npx not found

**Error**: `Error: command not found: npx` (in Claude Desktop logs)

**Symptoms**: Claude cannot spawn mcp-remote

**Solution**:

```bash
# Install Node.js and npm
# macOS
brew install node

# Verify
node --version
npm --version
npx --version

# Restart Claude Desktop
```

---

#### Issue: mcp-remote not found

**Error**: `Module not found: mcp-remote`

**Solution**:

```bash
# Install mcp-remote globally
npm install -g mcp-remote

# Or npx will auto-download with -y flag (already in config)

# Restart Claude Desktop
```

---

### Data & Volume Issues

#### Issue: Data lost after container restart

**Error**: Splunk has no data/configs after restarting

**Symptoms**: Volumes not persisting

**Solution**:

```bash
# Check volume exists
docker volume ls | grep so1

# If missing, volumes weren't created properly:
docker volume create so1-var
docker volume create so1-etc

# Inspect volume
docker volume inspect so1-var

# Check mount points in container
docker exec so1 df -h | grep opt/splunk

# Backup data before cleanup:
docker run --rm -v so1-var:/data -v ~/backup:/backup \
  alpine tar czf /backup/backup-$(date +%s).tar.gz -C /data .
```

---

#### Issue: Disk space error

**Error**: `No space left on device` or volume full

**Solution**:

```bash
# Check disk usage
docker volume inspect so1-var
du -sh /var/lib/docker/volumes/so1-*

# Check container logs
make logs | grep -i "space\|disk"

# Solutions:
# 1. Delete old indexes
# 2. Increase disk space
# 3. Clean up Docker: docker system prune -a
# 4. Move volumes to larger disk
```

---

### Log Analysis

#### Viewing Logs

```bash
# Real-time logs
make logs

# Last 100 lines
docker logs --tail 100 so1

# Logs with timestamps
docker logs --timestamps so1

# Follow specific search
docker logs so1 | grep -i "error\|warning\|MCP"

# Save to file
docker logs so1 > splunk_logs.txt
```

#### Common Log Messages

| Message | Meaning | Action |
| --------- | --------- | --------- |
| `All pipelines have been started` | Splunk initialized | OK - ready to use |
| `REST handler 'mcp' not found` | MCP app not installed | Reinstall app |
| `Authentication failed` | Bad credentials | Check .env |
| `role="mcp_user" does not exist` (or missing `mcp_tool_execute` capability) | Role creation/update failed | Run `setup-splunk.sh` / `make up` again |
| `License not found` | License issue | Accept license again |

---

## Verification Checklist

```bash
make status                  # Check containers
make logs | tail -20         # Check for errors

# Manual verification:
curl -k -u admin:password https://localhost:8089/services/server/info
curl -k -u admin:password https://localhost:8089/services/authentication/users/splunker
curl -k -u admin:password https://localhost:8089/services/authorization/roles/mcp_user

# Verify Claude config:
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json | jq '.mcpServers'
```

## Getting Help

### Collect Diagnostic Information

```bash
#!/bin/bash
# Save this as diagnose.sh and run: bash diagnose.sh

echo "=== System Info ===" > diagnosis.txt
uname -a >> diagnosis.txt

echo -e "\n=== Docker Info ===" >> diagnosis.txt
docker --version >> diagnosis.txt
docker compose version >> diagnosis.txt

echo -e "\n=== Container Status ===" >> diagnosis.txt
docker compose ps >> diagnosis.txt

echo -e "\n=== Container Logs ===" >> diagnosis.txt
docker logs so1 >> diagnosis.txt

echo -e "\n=== Environment ===" >> diagnosis.txt
cat .env | grep -v "PASSWORD\|PASS" >> diagnosis.txt

echo -e "\n=== Network ===" >> diagnosis.txt
docker network inspect splunk >> diagnosis.txt

echo "Diagnostics saved to diagnosis.txt"
```

### Claude Logs Debugging

#### Issue: No Claude logs in Splunk

**Error**: `index=claude_logs` returns no results

**Solution**:

```bash
# Check if Claude logs directory exists
ls -la ~/Library/Logs/Claude/

# Verify directory is mounted
docker exec so1 ls -la /var/log/claude_logs

# Check if index was created
curl -k -u admin:password \
  https://localhost:8089/services/data/indexes/claude_logs

# View Splunk monitor input config
curl -k -u admin:password \
  https://localhost:8089/services/data/indexes/claude_logs
#### Issue: Claude logs stopped being indexed

**Error**: Previously indexed logs, but nothing recent

**Solution**:

```bash
# Check monitor status
curl -k -u admin:password "https://localhost:8089/services/data/inputs/monitor"

# Verify Claude app is running
log stream --predicate 'process == "Claude"' --level debug | head -20

# Restart Splunk
make restart

# Wait 2-3 minutes and retry query:
# index=claude_logs | stats count
```

### Resources

- Splunk API: <https://docs.splunk.com/Documentation/Splunk/latest/RESTREF>
- MCP Protocol: <https://modelcontextprotocol.io/>
- Docker: <https://docs.docker.com/>
- 1Password CLI: <https://developer.1password.com/docs/cli/>

## Debug Mode

### Enable Verbose Output

```bash
# In make commands
set -x
make up

# In Docker
docker compose up --verbose

# In curl
curl -v -k https://localhost:8089/services/server/info

# In shell scripts
bash -x scripts/setup-splunk.sh
```

### Interactive Debugging

```bash
# Enter container shell
docker exec -it so1 /bin/bash

# Test commands inside container
curl -k https://localhost:8089/services/server/info
ps aux | grep splunk
tail -f /opt/splunk/var/log/splunk/splunkd.log
```
