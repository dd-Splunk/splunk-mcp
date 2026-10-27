# Security

This repository is a **local Splunk MCP development PoC**. It is not hardened for production or internet-facing deployment.

## Reporting a vulnerability

If you believe you have found a security issue in this project:

1. **Do not** open a public GitHub issue for undisclosed vulnerabilities.
2. Use **GitHub private security advisories**: repository **Security** tab → **Report a vulnerability**.
3. Include steps to reproduce, affected paths or commands, and impact.

We will acknowledge reports as quickly as practicable for a community PoC.

**Supported versions:** only the latest commit on **`main`** is maintained (see [CI_CD.md](CI_CD.md)).

**Secret scanning:** CI and pre-commit run **gitleaks**. Do not commit credentials or bearer tokens—even in “temporary” examples.

## Scope

This document applies to the workspace **development PoC** context: single host, Docker, localhost URLs, and AI clients using **`npx mcp-remote`** to Splunk’s MCP endpoint with the bearer token in a mode-600 header file.

## Credential handling

- **`.env.example`** (tracked): Empty placeholders only.
- **`.env`**: Gitignored. Create it with `cp .env.example .env`, fill the four required values, and `chmod 600`, or on macOS with `make env` (keychain, see [CONFIGURATION.md](CONFIGURATION.md#env-from-the-macos-keychain)). CI may export the same variables instead of writing the file.
- **Do not** commit `.env`, token files, or private keys. See [AGENTS.md](../../AGENTS.md).

### Secret scanning

Local pre-commit and CI both run **gitleaks** using [`.gitleaks.toml`](../../.gitleaks.toml). GitHub Actions also runs a full-history gitleaks scan before the pre-commit job. Run the same checks locally before pushing:

```bash
pre-commit run --all-files
```

If gitleaks reports a real secret, rotate it outside git and remove it from history before publishing. Do not suppress findings for live credentials, bearer tokens, or private keys.

## TLS and trust

- Splunk uses **HTTPS** on 8089 with a **self-signed** (or container-default) certificate.
- Clients may set **`NODE_TLS_REJECT_UNAUTHORIZED=0`** for self-signed localhost certs—acceptable only on **loopback** in a trusted dev machine context.
- **Production-style** deployments should use proper CA-issued certificates, **enable** verification, and avoid disabling TLS checks in client env vars.

For any non-default certificate files you mount or trust:

```bash
openssl x509 -text -noout -in <file>
```

Confirm validity dates, key size (RSA ≥2048 or modern EC curves), and signature algorithm (SHA-256 family, not MD5/SHA-1).

## MCP and network exposure

- Compose publishes **8000** and **8089** on **`127.0.0.1` only** (see **`compose.yml`**).
- **Do not** bind to **`0.0.0.0`** or port-forward these services to the public Internet without authentication hardening, reverse proxy, and network ACLs.
- MCP over HTTP(S) is **privileged**: the token grants access consistent with Splunk roles assigned to the MCP user (default **`splunker`**).

## Splunk roles and least privilege

**`scripts/setup-splunk.sh`** does **not** grant **`admin`** to **`splunker`**. Do not add **`admin`** to MCP-capable accounts outside tightly controlled dev scenarios.

## Bind mounts

- **`scripts/setup-splunk.sh`**, **`scripts/splunk-api-env.sh`**, **`scripts/with-splunk-env.sh`**, **`scripts/register-s4r-mcp-tools.sh`**, and **`SA-S4R/default/s4r_mcp_tools.json`** are bind-mounted **read-only** into **`splunk-init`**.
- **`SA-S4R`** is installed from GitHub **`latest` `SA-S4R.spl`** into **`so1-etc`**, not bind-mounted from the git tree. A compromised container can change the installed app inside the volume; it cannot rewrite the checkout’s **`default/`** or **`bin/`**. Do not add a **`:ro`** bind of the app tree — the image **chowns** that path and fails with **`Errno 30`** ([SA-S4R-APP.md](../s4r/SA-S4R-APP.md)).

## Token lifecycle

- Splunk MCP Server 2.1 encrypts every token with one administrator-managed key pair (created by **`scripts/mint-mcp-token.sh`** on first mint). Tokens expire no later than the key (default 180 days). Deleting the key invalidates every token; it is refused while any token is still active.
- Each mint creates a token that stays valid for months. **`update-all`** (**`make up`**, **`make update-mcp-clients`**) rewrites every configured client with the new token, then **`scripts/prune-mcp-tokens.sh`** revokes all older **`mcp`** tokens of the MCP user. A single-client **`make update-mcp-client`** does the same: all clients share the header file, so every configured client moves to the new token before older ones are revoked. **`make verify-mcp-remote`** checks the token already in each config and mints none.
- Re-run **`make update-mcp-clients`** to rotate. The token is written only to the header file (**`SPLUNK_MCP_HEADER_FILE`**, default **`~/.config/splunk-mcp/headers`**): directory 700, file 600, replaced atomically. **`make down`** (**`park all`**) deletes it. Client configs hold only its path and are still **`chmod 600`** after each update or park.
- **`.cursor/mcp.json` and `.mcp.json` are gitignored** but this clone often lives under **OneDrive** (or similar). They no longer contain the token, and the header file sits outside the repo so sync does not copy it off-box. Configs written before **`--header-file`** still carry the token inline: run **`make update-mcp-clients`** to migrate them (**`verify-config`** rejects them). Do not paste the token into chat or issues.
- Clients start **`mcp-remote --header-file <path>`**, so the token is not in any process’s arguments (on macOS, any local user can read those with **`ps`**). **`make verify-mcp-remote`** reads the same file (**`curl -H @file`**). Splunk’s 2.0 sample passes the token with **`--header`**; this repo deliberately does not.

## Logging and privacy

- Optional **Claude log** ingestion (if enabled) is sensitive—restrict Splunk access and disk permissions.
- Avoid logging full bearer tokens in Splunk searches or shell history.

## Checklist before any “production-like” use

- [ ] Replace self-signed localhost TLS with validated certificates; remove `NODE_TLS_REJECT_UNAUTHORIZED=0`.
- [ ] Restrict bind addresses and firewall rules.
- [ ] Scope Splunk user roles to least privilege.
- [ ] Store secrets in a managed vault, not only flat `.env` on disk.
- [ ] Enable Splunk audit and authentication logging.
