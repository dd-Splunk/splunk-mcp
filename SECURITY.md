# Security Policy

This repository is a **local Splunk MCP development PoC**. It is not hardened for production or internet-facing deployment.

## Supported versions

Only the latest commit on **`main`** is maintained. There is no long-term support or semver guarantee for releases tagged **`latest`** (see [docs/CI_CD.md](docs/CI_CD.md)).

## Reporting a vulnerability

If you believe you have found a security issue in this project:

1. **Do not** open a public GitHub issue for undisclosed vulnerabilities.
2. Use **GitHub private security advisories**: repository **Security** tab → **Report a vulnerability**.
3. Include steps to reproduce, affected paths or commands, and impact.

We will acknowledge reports as quickly as practicable for a community PoC.

## Scope and known limitations

Read [docs/SECURITY.md](docs/SECURITY.md) for:

- Where secrets must live (never commit `.env`, `tpl.env`, `.cursor/mcp.json`, or tokens)
- Dev-only TLS settings (`curl -k`, `ssl_verify=false`, `NODE_TLS_REJECT_UNAUTHORIZED=0`)
- Localhost port binding and MCP token handling
- Checklist before any production-like use

## Secret scanning

CI and pre-commit run **gitleaks** on this repository. Do not commit real credentials, vault paths, or bearer tokens—even in example files meant to be “temporary.”
