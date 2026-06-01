## Scope

This document applies the workspace **development PoC** context: single host, Docker, localhost URLs, and AI clients using a local MCP proxy with a stdio bridge.

## How this rule was applied

Security guidance for **credentials**, **certificates**, and **transport** was applied as follows: we document where secrets live, forbid committing them, describe TLS weaknesses explicitly, and avoid recommending this layout for production or internet exposure. This matches the **no hardcoded credentials** and **digital certificate** workspace rules by steering users toward `.env` / vault references and explicit verification steps for any real certificates.

## Credential handling

- **`tpl.env.example`** (tracked): Placeholder `op://` paths only—safe to publish.
- **`tpl.env`** (gitignored): Your local file from **`cp tpl.env.example tpl.env`**; may contain real `op://` paths—**never commit**.
- **`.env`**: Optional; hand-written from **`.env.example`** (Path B) and **git-ignored** when present. With **`tpl.env`** only, **`make up`** passes secrets via **`op run`** without creating `.env` (fewer secrets on disk).
- **Do not** commit `.env`, token files, or private keys. The repo should remain safe if published.

## TLS and trust

- Splunk uses **HTTPS** on 8089 with a **self-signed** (or container-default) certificate.
- The local proxy talks to Splunk over HTTPS and may disable TLS verification for localhost in development. That is acceptable only on **loopback** in a trusted dev machine context.
- **Production-style** deployments should use proper CA-issued certificates (or organizational PKI), **enable** verification, and avoid disabling TLS checks in client env vars.

### Certificate verification (operational)

For any non-default certificate files you mount or trust, inspect with:

```bash
openssl x509 -text -noout -in <file>
```

Confirm validity dates, key size (for RSA, at least 2048 bits; prefer modern curves for EC), and signature algorithm (SHA-256 family, not MD5/SHA-1).

## MCP and network exposure

- **Binding**: Compose publishes **8000** and **8089** to the host. Any process on the machine—or on the LAN if the host firewall allows—could reach those ports.
- **Do not** port-forward these services to the public Internet without authentication hardening, reverse proxy, and network ACLs.
- MCP over HTTP(S) should be treated as **privileged**: the token grants access consistent with Splunk roles assigned to the MCP user (default **`splunker`**).

## Splunk roles and least privilege

**`scripts/setup-splunk.sh`** does **not** grant **`admin`** to **`splunker`**. Do not add **`admin`** to MCP-capable accounts outside tightly controlled dev scenarios.

For stricter experiments:

- Reduce **`splunker`** (or your MCP user) to the minimum roles/capabilities required by the Splunk MCP Server app documentation.
- Use a dedicated service account per environment.

## Token lifecycle

- Tokens may be **time-limited** (see Splunk MCP app behavior and Splunk auth settings). In this repo, tokens are minted by `mcp-proxy` and held in memory; rotation is handled by restarting the proxy (or waiting for it to mint a new token).

## Logging and privacy

- **Claude log** monitoring (if enabled) ingests files from the host path into Splunk. Treat that index as **sensitive**; restrict Splunk access and disk permissions.
- Avoid logging full bearer tokens in Splunk searches or shell history.

## Checklist before any “production-like” use

- [ ] Replace self-signed localhost TLS with validated certificates and remove `NODE_TLS_REJECT_UNAUTHORIZED=0`.
- [ ] Restrict bind addresses and firewall rules; use VPN or private network where applicable.
- [ ] Scope Splunk user roles to least privilege; avoid admin on MCP-only users.
- [ ] Store secrets in a managed vault or secret store, not only flat `.env` on disk.
- [ ] Enable Splunk audit and authentication logging; monitor for failed MCP/API auth.

For broader MCP hardening patterns, see also Splunk and MCP security guidance relevant to your organization.
