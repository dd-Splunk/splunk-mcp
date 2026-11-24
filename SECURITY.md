# Security Policy

This repository is a **local Splunk MCP development PoC**. It is not hardened for production or internet-facing deployment.

## Scope

In scope: the Docker stack on one laptop (**Splunk Enterprise** on `localhost:8089`), the scripts and Makefile targets that configure it and the MCP clients, and the **SA-S4R** sample app.

Out of scope: **Splunk Cloud** MCP and Splunk products themselves. Report Splunk product issues to Splunk.

Only the latest commit on **`main`** is maintained.

## Reporting a vulnerability

1. **Do not** open a public GitHub issue for undisclosed vulnerabilities.
2. Report privately: repository **Security** tab → **Advisories** → **Report a vulnerability**.
3. Include steps to reproduce, affected paths or commands, and impact.

**Never** paste tokens, passwords, or `.env` contents into reports, issues, pull requests, or logs. Redact them first.

## Response

This is a PoC maintained on a best-effort basis. Reports are acknowledged as quickly as practicable; there is no guaranteed fix timeline.

**Full guidance** (secrets, TLS, MCP exposure, checklist): [docs/poc/SECURITY.md](docs/poc/SECURITY.md).
