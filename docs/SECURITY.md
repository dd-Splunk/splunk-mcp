# Security

This repository is a **local Splunk MCP development PoC**. It is not hardened for production or internet-facing deployment.

## Reporting a vulnerability

If you believe you have found a security issue in this project:

1. **Do not** open a public GitHub issue for undisclosed vulnerabilities.
2. Use **GitHub private security advisories**: repository **Security** tab → **Report a vulnerability**.
3. Include steps to reproduce, affected paths or commands, and impact.

We will acknowledge reports as quickly as practicable for a community PoC.

**Supported versions:** only the latest commit on **`main`** is maintained (see [CI_CD.md](CI_CD.md)).

**Secret scanning:** CI and pre-commit run **gitleaks**. Do not commit credentials, vault paths, or bearer tokens—even in “temporary” examples.

## Scope

This document applies to the workspace **development PoC** context: single host, Docker, localhost URLs, and AI clients using **`npx mcp-remote`** to Splunk’s MCP endpoint with bearer tokens in client config only.

## Credential handling

- **`tpl.env.example`** (tracked): Placeholder `op://` paths only—safe to publish.
- **`tpl.env`** (gitignored): Your local file from **`cp tpl.env.example tpl.env`**; may contain real `op://` paths—**never commit**.
- **`.env`**: Optional; hand-written from **`.env.example`** (Path B) and **git-ignored** when present. With **`tpl.env`** only, **`make up`** passes secrets via **`op run`** without creating `.env`.
- **Do not** commit `.env`, token files, or private keys. See [AGENTS.md](../AGENTS.md).

### Secret scanning

Local pre-commit and CI both run **gitleaks** using [`.gitleaks.toml`](../.gitleaks.toml). GitHub Actions also runs a full-history gitleaks scan before the pre-commit job. Run the same checks locally before pushing:

```bash
pre-commit run --all-files
```

If gitleaks reports a real secret, rotate it outside git and remove it from history before publishing. Do not suppress findings for live credentials, bearer tokens, private keys, or machine-specific vault paths.

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

## Token lifecycle

- Re-run **`make update-mcp-client`** to rotate tokens in client configs.

## Logging and privacy

- Optional **Claude log** ingestion (if enabled) is sensitive—restrict Splunk access and disk permissions.
- Avoid logging full bearer tokens in Splunk searches or shell history.

## Checklist before any “production-like” use

- [ ] Replace self-signed localhost TLS with validated certificates; remove `NODE_TLS_REJECT_UNAUTHORIZED=0`.
- [ ] Restrict bind addresses and firewall rules.
- [ ] Scope Splunk user roles to least privilege.
- [ ] Store secrets in a managed vault, not only flat `.env` on disk.
- [ ] Enable Splunk audit and authentication logging.
