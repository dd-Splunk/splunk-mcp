# Troubleshooting Guide

| Cluster | Document |
| ------- | -------- |
| Stack (Docker, MCP, init) | This file |
| Splunk4Rookies workshop | [s4r/TROUBLESHOOTING.md](../s4r/TROUBLESHOOTING.md) |

Admin REST examples below use **`splunk_curl`** from **`scripts/splunk-api-env.sh`**. It passes the admin password to curl through a config on a file descriptor, so it does not show in **`ps`** the way **`curl -u admin:…`** does. Load it once per shell from the repo root:

```bash
set -a; . ./.env; set +a
. scripts/splunk-api-env.sh
```

Examples with plain **`curl -u <user>`** prompt for the password instead.

## Cursor Cloud (Docker-in-Docker)

### Bootstrap before `make up`

Fresh Cursor Cloud VMs do not auto-start Docker or Splunk storage. Run once per boot:

```bash
./scripts/cloud-bootstrap.sh
make up
```

Requires secrets when creating **`.env`** (first boot or after **`--force-env`**):

- Cursor Cloud secrets **`SPLUNKBASE_USER`** / **`SPLUNKBASE_PASS`**. Bootstrap writes gitignored **`.env`** and generates admin/splunker passwords when those variables are unset.

See [CONFIGURATION.md](CONFIGURATION.md#cursor-cloud-bootstrap) and [AGENTS.md](../../AGENTS.md).

### Cannot log in after Cloud bootstrap

**Symptom:** `make up` succeeded in Cursor Cloud, but you do not know the Splunk Web admin password.

**Cause:** **`scripts/cloud-bootstrap.sh`** creates **`SPLUNK_ADMIN_PASSWORD`** and **`SPLUNK_SPLUNKER_PASSWORD`** in the gitignored local **`.env`** when they were not already set. They are intentionally not printed in logs.

**Use locally without printing secrets:**

```bash
set -a
. ./.env
set +a
. scripts/splunk-api-env.sh
splunk_curl -sk \
  "https://localhost:8089/services/server/info?output_mode=json" >/dev/null
```

For Splunk Web, log in as **admin** with **`SPLUNK_ADMIN_PASSWORD`** from `.env`. To rotate generated passwords, run **`./scripts/cloud-bootstrap.sh --force-env --wipe`** before **`make up`**; do not commit or paste `.env`.

### KVStore status `failed` / MCP token mint fails

**Symptom:** `kvStoreStatus: failed`, `mcp_token` returns *KVStore is not ready*, or mongod exits with featureCompatibilityVersion errors after changing Splunk versions.

**Cause:** Persistent ext4 data under `/mnt/splunkdb` still contains KVStore from an older Splunk major version.

**Solution:**

```bash
./scripts/cloud-bootstrap.sh --wipe
make up
```

### Splunk crashes on startup (`available_memory_size_in_bytes`)

**Symptom:** Splunk 10.x SIGABRT during `setupIndexPipeline` on Cursor Cloud.

**Solution:** Use default bootstrap (fake cgroup mount) or pin `splunk/splunk:9.3.2` with `./scripts/cloud-bootstrap.sh --image splunk/splunk:9.3.2`.

### `homePath ... on unusable filesystem`

**Symptom:** Splunk refuses to create indexes on Docker overlay/tmpfs.

**Solution:** Run `./scripts/cloud-bootstrap.sh` — it mounts ext4 loopback at `/mnt/splunkdb` and binds it as `so1-var`.

---

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

#### Issue: `so1` unhealthy after read-only SA-S4R bind mounts

**Error**: `chown failed … Errno 30 Read-only file system` on `/opt/splunk/etc/apps/SA-S4R`; healthcheck `Permission denied` on `/opt/splunk/var/log/splunk`; Compose `dependency failed to start: container so1 is unhealthy`

**Cause**: The official Splunk image **chowns** `/opt/splunk/etc/apps/SA-S4R` recursively at start. A **read-only** bind of the app root **or** of shipped subdirs (`default/`, `bin/`, …) fails that step. A half-finished chown can leave `/opt/splunk` unwritable for the healthcheck.

**Solution**: Leave the app bind out of `compose.yml`. The default install is [GitHub `latest` `SA-S4R.spl`](https://github.com/dd-Splunk/splunk-mcp/releases/download/latest/SA-S4R.spl) via `SPLUNK_APPS_URL` (app lands in `so1-etc`). Recover a bad bind with **`./scripts/compose-up.sh`** (or **`make up`**) after removing the mount. Do **not** run bare **`docker compose up`** without secrets.

**Lesson**: Nested `:ro` binds of `default/`, `bin/`, lookups, or samples fail the **same** recursive chown. See [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) § Install from GitHub `.spl`.

---

#### Issue: `wait-splunk-init` sits on `created` after `so1` is unhealthy

**Error**: Compose prints `dependency failed to start: container so1 is unhealthy`, then `Waiting for splunk-init to finish… still running (6/180)…`

**Cause**: `splunk-init` never starts until `so1` is **healthy**. The wait script treats a **`created`** container as “still running” and can wait up to **15 minutes**.

**Solution**: Stop the wait, fix the mount or secrets, then **`./scripts/compose-up.sh`**. Do not leave a 180-attempt wait running against a container that `depends_on` blocked.

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

#### Issue: `.env` missing or `SPLUNK_ADMIN_PASSWORD` not set

**Error**: `need .env or SPLUNK_ADMIN_PASSWORD` or Compose reports an empty password.

**Solution**:

```bash
cp .env.example .env
chmod 600 .env
```

Fill `SPLUNK_ADMIN_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, and `SPLUNK_SPLUNKER_PASSWORD`. Do not commit `.env`. Then `make up`.

On macOS, `make env` builds `.env` from keychain items instead. If it reports `keychain item '…' not found`, create the item ([CONFIGURATION.md](CONFIGURATION.md#env-from-the-macos-keychain)). The first run may show a macOS prompt allowing `security` to read the item.

#### Issue: `SPLUNK_PASSWORD was renamed to SPLUNK_ADMIN_PASSWORD`

**Cause**: `.env` (or the environment) still uses the old names. `SPLUNK_PASSWORD` is now `SPLUNK_ADMIN_PASSWORD`, and `SPLUNK_MCP_PASSWORD` is now `SPLUNK_SPLUNKER_PASSWORD`.

**Solution**: rename the keys in place; values are unchanged:

```bash
sed -i '' -e 's/^SPLUNK_PASSWORD=/SPLUNK_ADMIN_PASSWORD=/' \
  -e 's/^SPLUNK_MCP_PASSWORD=/SPLUNK_SPLUNKER_PASSWORD=/' .env   # macOS; drop '' on Linux
```

`FORCE_SPLUNK_MCP_PASSWORD` is likewise now `FORCE_SPLUNK_SPLUNKER_PASSWORD`.

---

#### Issue: Splunk logs show `Invalid Splunkbase credentials` / ansible inventory errors

**Cause**: The **`so1`** container was created with **empty** `SPLUNKBASE_USER` / `SPLUNKBASE_PASS` (and often `SPLUNK_ADMIN_PASSWORD`). That happens if you run **`docker compose up -d`** without a populated **`.env`**—Compose substitutes blank strings, and Splunk’s entrypoint refuses Splunkbase downloads.

**Fix**:

1. Prefer **`make up`**, which loads **`.env`**. Do not rely on plain **`docker compose up`** unless **`.env`** exists and is populated.
2. Confirm the four required keys in **`.env`** are non-empty. Do not print the file.
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

**Symptoms**: Splunk running but user/role/token not created **or** Eventgen never enabled; **`make status`** prints **`splunk-init: FAILED (exit N)`** and exits non-zero. Look in **`docker logs splunk-init`** for `error: SA-Eventgen` / `still disabled`.

**Solution**:

```bash
make status                # confirms init failure vs still running
docker logs splunk-init  # Check error
make logs | tail -50     # Check Splunk readiness

# Wait 2-3 minutes for Splunk initialization, then retry:
make down && make up

# If still failing, run manually:
./scripts/setup-splunk.sh
```

---

#### Issue: `mcp_token` wait never finishes / `splunker` missing

**Also seen with**: `still waiting …: Unknown resource ''. Valid resources: key-pair, tokens` — the minting script predates Splunk MCP Server 2.1 (old endpoint `/servicesNS/…/mcp_token`). Update the repo; **`scripts/mint-mcp-token.sh`** must use `/services/mcp_token/key-pair` and `/services/mcp_token/tokens`.

**Error**: `make up` hangs on `Waiting for Splunk MCP Server mcp_token endpoint…`

**Cause**: `splunk-init` exited 0 but never created role **`mcp_user`** / user **`splunker`**. Classic log line: `This user doesn't have permissions to assign capability=s4r_workshop_control` — Splunk rejects the whole role POST when that capability is unknown (wrong `authorize.conf` stanza or app not loaded yet).

**Solution**: Confirm with `docker logs splunk-init`. Fixed path: **`[capability::s4r_workshop_control]`** (two colons) in **`SA-S4R/default/authorize.conf`**; init creates the role with **`mcp_tool_execute` first**, then grants the custom cap. If that grant fails, `splunk-init` now exits non-zero (without it, `SA-S4R_apply_nk_demo_state` returns HTTP 403). Recycle init or:

```bash
make down && make up
```

On a stack that already finished init without `splunker`, re-run **`docker start splunk-init`** after pulling the fix, or wait for the next **`make up`**.

---

#### Issue: MCP encryption key expired or needs rotation

**Symptom**: every MCP client gets HTTP 401 at once, or `make update-mcp-clients` fails with *encryption key has expired; rotate it before creating tokens*. The key pair that encrypts all MCP tokens is valid for 180 days by default and tokens cannot outlive it.

**Solution** (admin REST, local PoC; the app refuses to delete the key while any token is active):

```bash
# Load splunk_curl first (top of this page); check status first
splunk_curl -ks https://localhost:8089/services/mcp_token/key-pair
# Disable every token, then delete the key
for id in $(splunk_curl -ks "https://localhost:8089/services/mcp_token/tokens?scope=all&output_mode=json" | jq -r '.tokens[].token_id'); do
  splunk_curl -ks -X PUT -H 'Content-Type: application/json' -d '{"disabled": true}' \
    "https://localhost:8089/services/mcp_token/tokens/$id"
done
splunk_curl -ks -X DELETE https://localhost:8089/services/mcp_token/key-pair
# Recreate the key and mint fresh tokens for the clients
make update-mcp-clients
```

`scripts/mint-mcp-token.sh` recreates the key pair automatically when none exists.

---

#### Issue: Splunk MCP app not installed

**Error**: MCP endpoint returns 404

**Symptoms**: Cannot connect Claude Desktop to Splunk

**Solution**:

```bash
# Check installed apps
splunk_curl -k https://localhost:8089/services/appserver/apps \
  | grep -i "mcp\|model"

# If not found, check download URL in compose.yml:
cat compose.yml | grep SPLUNK_APPS_URL

# Expected Splunkbase apps (IDs and names) are listed in CONFIGURATION.md under compose.yml.
# If a 404 on download, update the /release/VERSION/ segment in SPLUNK_APPS_URL for that app.
make check-splunkbase-pins   # compose.yml pin vs Splunkbase default (no secrets)

# If Splunkbase credentials are wrong, update .env and recycle the stack:
make down
docker volume rm so1-var so1-etc
make up
```

---

#### Issue: SA-S4R MCP tools missing from `tools/list`

**Error**: Cursor/Claude show generic Splunk tools but not `SA-S4R_query_nk_demo_state` (or other `SA-S4R_*` tools)

**Cause**: **`splunk-init`** registers the tools and then exits. A stack that booted before that step, or an init that failed the `POST /services/mcp_tools` call, leaves them off `tools/list`.

**Cause 2: the user lacks role `s4r_user`.** The five tools are limited to that role (Tool Role Policies). A user without it sees no `SA-S4R_*` tools in `tools/list` and gets HTTP 403 `Role not permitted for this tool` on a call, while the generic Splunk tools still work. `admin` bypasses the policies. Check with `GET /services/authentication/users/<name>` and `GET /services/mcp_tool_roles`.

**Cause 3: `splunker` lost the tools after init.** `docker logs splunk-init` shows `Role s4r_user not found` when the installed SA-S4R is older than 2.0.0 (an existing `so1-etc` volume keeps the app it first installed). Init then leaves the role and the policies out, so the tools stay open. A `Restricted 5 SA-S4R MCP tools` line means the policies were applied.

**Solution**:

```bash
docker logs splunk-init
make up
```

For cause 2, add `s4r_user` to the user's roles. For cause 3, `make clean-y && make up` installs the current app.

`make up` starts the exited **`splunk-init`** container again. Init installs **`jq`** itself. See [MCP-TOOLS.md](../s4r/MCP-TOOLS.md).

On a fresh install the KV Store can take minutes to start. Registration waits up to 5 minutes for **`/services/kvstore/status`** to report `ready`. If **`docker logs splunk-init`** shows `KV Store not ready after 300s`, run **`make up`** again. If it shows status `failed`, see [KVStore status `failed`](#kvstore-status-failed--mcp-token-mint-fails).

---

#### Issue: Splunk AI Toolkit / Connection Management (out of scope)

**Splunk AI Toolkit** (2890) and **Python for Scientific Computing** (2882) are **not** installed by this stack. If you add them manually from Splunkbase, install **2882** before **2890** and assign any toolkit role in Splunk Web. `setup-splunk.sh` does not read a role name from the environment.

**Symptoms** (manual MLTK only): Connection Management shows `Failed to fetch config metadata: Empty response.` — often because app **2882** is missing; `splunkd.log` may reference `Splunk_SA_Scientific_Python_linux_x86_64`.

**Verify** (after manual install):

```bash
splunk_curl -k "https://localhost:8089/servicesNS/admin/Splunk_ML_Toolkit/mltk/aicommander_metadata?output_mode=json" | head -c 400
```

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
splunk_curl -k https://localhost:8089/services/server/info

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

# For Node.js talking to Splunk directly: set NODE_TLS_REJECT_UNAUTHORIZED
NODE_TLS_REJECT_UNAUTHORIZED=0 node some-script.js

# Note: Only do this for localhost/development!
```

---

### Claude Desktop Integration Issues

#### Issue: Claude Code does not show Splunk tools

**Cause**: `.mcp.json` missing or parked (`make down` parks it), the session started before it was written, or the project server was not approved.

**Solution**:

```bash
make update-mcp-client MCP_CLIENT=claude-code
make verify-mcp-remote MCP_VERIFY_CLIENT=claude-code
```

Start a new Claude Code session in the repo, approve **splunk-mcp-server**, and check **`/mcp`**.

#### Issue: MCP client stops working after `make up` or `make update-mcp-clients`

**Cause**: `update-all` revokes superseded tokens. A client session that was already running keeps the old (now revoked) token in its `mcp-remote` process, and `make verify-mcp-remote` reports `token revoked or expired`.

**Solution**: reload MCP servers in Cursor, run **`/mcp`** (or start a new session) in Claude Code, or restart Claude Desktop. If a config was edited by hand, run **`make update-mcp-clients`**.

#### Issue: Claude Desktop cannot connect to Splunk

**Error**: "MCP server connection failed" or timeout

**Symptoms**: No Splunk tools available in Claude

**Solution**:

1. **Verify config file**:

   ```bash
   cat ~/Library/Application\ Support/Claude/claude_desktop_config.json
   # Should contain npx mcp-remote → https://localhost:8089/services/mcp
   # and --header-file ~/.config/splunk-mcp/headers (mode 600, holds the token)
   ls -l ~/.config/splunk-mcp/headers
   ```

2. **Restart Claude Desktop**:
   - Force quit: Cmd+Q
   - Wait 2 seconds
   - Reopen from Applications

3. **Test Splunk MCP from the shell**:

   ```bash
   make verify-mcp-remote MCP_VERIFY_CLIENT=claude
   ```

4. **Check Claude logs**:

   ```bash
   log stream --predicate 'process == "Claude"' --level debug
   ```

---

#### Issue: npx not found

**Error**: `Error: command not found: npx` (in Claude Desktop logs)

**Symptoms**: The client cannot spawn `npx mcp-remote`

**Solution**:

```bash
# Install Node.js
# macOS
brew install node

# Verify
node --version
npm --version
# Restart Claude Desktop / Cursor (new Claude Code session)
```

---

---
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

### Splunk4Rookies (S4R) workshop

Dashboard, NK threat mode, and parallel agent issues: **[s4r/TROUBLESHOOTING.md](../s4r/TROUBLESHOOTING.md)**.

---

#### Issue: `splunker` account locked out

**Symptoms**:

- REST basic auth as `splunker` returns HTTP **500**: *"For security reasons, your account has been locked out"*
- `GET .../authentication/users/splunker?output_mode=json` shows **`"locked-out": true`**
- **`make verify-mcp-remote MCP_VERIFY_CLIENT=cursor`** may still pass while Splunk REST is locked (it reuses the bearer token in the header file, for both the direct `tools/list` and the stdio `mcp-remote` path)
- **MCP bearer token** (`tools/list`, `splunk_run_query`) may still work — it does not use the `splunker` password, and minting authenticates as **`admin`**

**Cause**: Splunk locks local accounts after repeated failed login attempts. Common PoC triggers:

1. **`SPLUNK_SPLUNKER_PASSWORD` drift** — password in `.env` no longer matches Splunk (setup only sets password on **create** or when **`FORCE_SPLUNK_SPLUNKER_PASSWORD=1`**).
2. **Parallel subagents using REST fallback** — several workers attempted `-u splunker:…` via Splunk REST when MCP was unavailable; wrong or stale password locks the account quickly. **Agents must use Splunk MCP only** — prefer **`SA-S4R_*`** when it matches, else **`splunk_run_query`** (see `.cursor/agents/s4r-*.md`).
3. **Manual REST probes** with an incorrect password.

**Fix (immediate — unlock)**:

```bash
# From repo root; requires SPLUNK_ADMIN_PASSWORD (admin) in .env
set -a
. ./.env
set +a
splunk_curl -sk -X POST \
  "https://localhost:8089/services/authentication/users/splunker" \
  -d "locked-out=false" \
  -H "Content-Type: application/x-www-form-urlencoded"
```

Or re-run init (clears lock idempotently after `setup-splunk.sh` unlock step):

```bash
docker compose run --rm splunk-init   # or: make up
```

**Fix (password out of sync)**:

```bash
FORCE_SPLUNK_SPLUNKER_PASSWORD=1 make up
```

**Verify**:

```bash
make verify-mcp-remote MCP_VERIFY_CLIENT=all   # config + tools/list
# Optional: confirm splunker basic auth
curl -sk -u splunker \
  "https://localhost:8089/services/authentication/current-context?output_mode=json"
```

**Prevention**: Workshop agents and subagents must use **Splunk MCP only** (prefer **`SA-S4R_*`**, else **`splunk_run_query`**) — never REST basic auth as `splunker`. Prefer **`make verify-mcp-remote MCP_VERIFY_CLIENT=all`** before delegating four teams. Keep **`SPLUNK_SPLUNKER_PASSWORD`** aligned with `.env`; use **`FORCE_SPLUNK_SPLUNKER_PASSWORD=1`** after rotating the password. Parallel agent limits: [s4r/TROUBLESHOOTING.md](../s4r/TROUBLESHOOTING.md).

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
splunk_curl -k https://localhost:8089/services/server/info
splunk_curl -k https://localhost:8089/services/authentication/users/splunker
splunk_curl -k https://localhost:8089/services/authorization/roles/mcp_user

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
splunk_curl -k \
  https://localhost:8089/services/data/indexes/claude_logs

# View Splunk monitor input config
splunk_curl -k \
  https://localhost:8089/services/data/indexes/claude_logs
#### Issue: Claude logs stopped being indexed

**Error**: Previously indexed logs, but nothing recent

**Solution**:

```bash
# Check monitor status
splunk_curl -k "https://localhost:8089/services/data/inputs/monitor"

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
