# Graduation: from local SE PoC to unattended boot

Impact study for moving **splunk-mcp** beyond a **presales / workshop laptop PoC** toward something **others can clone and boot without the author in the room**.

This document does **not** change product behavior. It lists gaps, costs, and decision points so you can judge whether graduation is worth the investment.

**Related:** [SPECS.md](SPECS.md) (requirements today) · [PRESALES.md](PRESALES.md) (demo runbook) · [INSTALLATION.md](INSTALLATION.md) · [CI_CD.md](CI_CD.md) · [SECURITY.md](SECURITY.md)

---

## Definitions

| Term | Meaning |
| ---- | ------- |
| **Current state (PoC)** | SE runs the stack on their machine; warm-up, secrets, and MCP reload are operator habits. CI checks **lint only** (no Splunk in GitHub Actions). |
| **Graduated** | A new user follows **only** published docs + `make verify` and reaches a working Splunk + MCP + SA-S4R stack **without DMs to the maintainer**. |
| **Mature** | Graduated **plus** automated regression signal when boot/MCP breaks (e.g. optional CI smoke), release tags, and a named support path. |

**Graduation is not** “add a smoke test.” Smoke test is a **later safety net** once unattended boot is real and PRs can break compose/init without anyone noticing.

---

## Why graduate (benefits)

| Benefit | Who gains |
| ------- | --------- |
| Repeatable demos across SEs / regions | Presales, workshops |
| Fewer “works on my machine” surprises before customer calls | SE, customer-facing teams |
| Safer contributions (external or internal) to `compose.yml`, scripts, SA-S4R | Engineering |
| Clear **supported / unsupported** matrix | Security, IT, legal |
| Optional CI boot check before workshop season | Maintainer |

---

## Costs and risks (impact)

| Area | Cost / risk if you graduate |
| ---- | --------------------------- |
| **Secrets** | Every user needs Splunkbase credentials; org may need a **shared lab account** policy. CI smoke needs **GitHub Actions secrets** (never in git). |
| **Time** | Cold `make up` is often **20–45 minutes** (image, Splunkbase downloads, init). Unattended users need explicit expectations. |
| **Support** | More clones → more `splunk-init` / MCP / Splunkbase tickets unless runbooks and ownership are clear. |
| **Platform** | Today **Cursor-first** on boot (`MCP_UPDATE_ON_BOOT=cursor`). Claude/Goose need extra steps unless defaults change. |
| **Workshop assets** | Dashboard and Lab 4 `platform` extraction still live in **`SA-S4R/local/`** (mostly gitignored). Unattended workshop may require a **packaged `.spl`** or more tracked `local/` assets. |
| **CI** | Full stack smoke in GitHub is **slow, flaky, and secret-heavy**. Deferred by choice; see [CI smoke (deferred)](#ci-smoke-deferred). |
| **Licensing** | Splunk Enterprise trial/license and Splunkbase terms remain **operator responsibility**; graduation does not remove legal review for wider distribution. |

---

## Graduation checklist

Use this as a scorecard. **Internal graduation** can be declared when every **required** row is checked; **mature** adds the optional rows.

### A. Onboarding (required)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| A1 | Single canonical path in docs (no “ask maintainer for `tpl.env`”) | Path A + B documented | Publish org-standard: e.g. “Path B for first clone” in [INSTALLATION.md](INSTALLATION.md) |
| A2 | Prerequisites with pass/fail commands (Docker RAM, Splunkbase reachability, Node/`npx`) | Partial in [PRESALES.md](PRESALES.md) | Add a **preflight** section or script (`docker info`, `curl` Splunkbase, `npx --version`) |
| A3 | First-run duration documented | Mentioned in presales | Put **cold vs warm** times in INSTALLATION + PRESALES |
| A4 | Acceptance command documented | `make verify` / `make demo-prep` | State explicitly: **`make verify` exit 0 = graduated acceptance** (align with [SPECS.md](SPECS.md)) |

### B. Secrets and credentials (required)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| B1 | Four required vars documented | Yes (`.env.example`, `tpl.env.example`) | None for doc-only graduation |
| B2 | Splunkbase account called out as mandatory | Yes | Org policy for **shared vs personal** Splunkbase creds |
| B3 | No personal `op://` paths in shared templates | `tpl.env.example` only | Contributors use gitignored `tpl.env` locally |
| B4 | CI secrets story (if smoke ever added) | Not implemented | Document which secrets go in GitHub org settings |

### C. Supported platform matrix (required)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| C1 | OS list (e.g. macOS + Docker Desktop = supported) | Implicit | Write **Supported / best effort / unsupported** table |
| C2 | MCP client matrix | Cursor primary; others manual | Either expand `MCP_UPDATE_ON_BOOT` default or document “Cursor-only supported” |
| C3 | Cloud / Cursor Cloud | [cloud-bootstrap.sh](../../scripts/cloud-bootstrap.sh) | Link from INSTALLATION; state VM ephemeral disk behavior |

### D. Reliability and versions (required)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| D1 | Pinned Splunk image | `splunk/splunk:10.4.1` default | Document bump process in CONFIGURATION |
| D2 | Pinned Splunkbase app URLs | `compose.yml` | Document bump + Splunk major migration (`make clean-y`) |
| D3 | Pinned `mcp-remote` | `MCP_REMOTE_PACKAGE` default `mcp-remote@0.8.3` | Document override |
| D4 | Top failures runbook | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Ensure init / MCP 401 / Splunkbase / no data are one-hop fixes |

### E. Workshop consumability (required for S4R graduation)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| E1 | NK mode does not dirty git | Writes `local/eventgen.conf` | Document in [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) |
| E2 | Dashboard / `platform` field | Manual `local/` per `SA-S4R/local/README` | Ship **SA-S4R.spl** with workshop assets **or** document “Search-only workshop” without dashboard |
| E3 | MCP workshop tools registered on boot | `make up` → `register-s4r-mcp-tools` | None |
| E4 | Agent + SPL runbook | [s4r/README.md](../s4r/README.md) | None for technical graduation |

### F. Proof of unattended boot (required)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| F1 | Someone **other than maintainer** completes fresh clone → `make up` → `make verify` | Not formally recorded | Run **one** dry run; capture blockers in issues |
| F2 | No maintainer-only secrets in the path | Depends on org | Use only `.env.example` + org Splunkbase creds for the dry run |

### G. Governance (required for org-wide rollout)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| G1 | Named owner / channel | Community PoC | Slack, wiki, or GitHub Discussions |
| G2 | Issue template with `make status`, init logs | Optional | Add `.github/ISSUE_TEMPLATE` |
| G3 | Release or tag for workshops | `package-s4r.yml` → `latest` PoC release | Tag e.g. `workshop-2026-04` for reproducible classes |

### H. CI smoke (optional — deferred)

| # | Criterion | Today | Gap / action |
| - | --------- | ----- | ------------ |
| H1 | Lint CI green | Yes (`ci.yml`) | Maintain |
| H2 | Boot + MCP in GitHub Actions | **Not planned** | Revisit when F1 passes and PRs risk breaking boot without local test |
| H3 | Trigger policy | — | Prefer `workflow_dispatch` or nightly, not every push |

---

## What already supports graduation

These reduce the gap versus a greenfield PoC:

- **Pinned** Splunk **10.4.1**, Splunkbase app URLs, **`mcp-remote@0.8.3`**
- **Park on down** / early MCP mint on up (fewer stale-token failures)
- **`make clean-y && make up`** for full reset
- **`make verify`** / **`/demo-prep`** acceptance path
- **MCP-first** workshop mode (`SA-S4R_*` tools); NK toggle in **`local/eventgen.conf`**
- Tracked **`.cursor/skills/`** (`/usage`, `/demo-prep`)
- **SA-S4R** package workflow ([CI_CD.md](CI_CD.md))
- **Cursor Cloud** bootstrap for ephemeral VMs

---

## What still blocks unattended use (highest impact)

1. **Splunkbase credentials** — every operator needs a valid account; downloads fail without it.
2. **Cold start time** — unattended users may assume `make up` is “a few minutes.”
3. **Cursor-first boot** — Claude/Goose need explicit `make update-mcp-client` or `MCP_UPDATE_ON_BOOT="cursor goose claude"`.
4. **Workshop dashboard** — still built in **`SA-S4R/local/`**; not in git except README.
5. **No formal “supported matrix”** — Windows/WSL/Linux ambiguity creates support load.
6. **No recorded external dry run** — graduation is a claim until F1 is done.

---

## CI smoke (deferred)

**Decision (current):** No stack smoke test in CI — **added value is low** for a laptop SE PoC while lint catches script/doc regressions.

**Revisit when:**

- Checklist sections **A–F** are largely complete, and
- Multiple contributors merge changes to `compose.yml`, `setup-splunk.sh`, or `SA-S4R/` without always running `make up` locally.

**What smoke would assert (same as `make verify` contract):**

1. `splunk-init` exit 0  
2. Splunk REST ready on 8089  
3. MCP token mint  
4. MCP `tools/list` (direct + optional `mcp-remote` stdio)  
5. Optional: `SA-S4R_*` tools present after `register-s4r-mcp-tools`

**Prerequisites:** GitHub Actions secrets for `SPLUNK_PASSWORD`, `SPLUNKBASE_USER`, `SPLUNKBASE_PASS`, `SPLUNK_MCP_PASSWORD`; **~30–45 min** job timeout; tolerate Splunkbase/network flakes.

---

## Suggested phases (impact vs effort)

| Phase | Scope | Effort | Outcome |
| ----- | ----- | ------ | ------- |
| **0 — Now** | Lint CI, local `make verify`, presales runbook | Done / low | SE-led demos |
| **1 — Doc graduation** | Supported matrix, preflight, F1 dry run by another SE | Low–medium | “Clone and boot” without maintainer |
| **2 — Workshop package** | SA-S4R.spl or tracked `local/` for dashboard | Medium | Full Buttercup UI without hand-build |
| **3 — Org secrets** | Shared Splunkbase lab account, template `.env` policy | Medium (process) | Fewer credential failures |
| **4 — CI smoke** | `workflow_dispatch` boot job | High (time, secrets, flakes) | Regression signal on `main` |

You can stop at **Phase 1** and still call the repo “graduated” for internal SE use. Phases 2–4 are for **wider** or **hands-off** distribution.

---

## Decision questions (for your impact study)

1. **Audience:** Internal SE only, or customers/partners cloning the repo?
2. **Workshop:** Search + MCP agents only, or **dashboard-required**?
3. **Clients:** Cursor-only supported, or must Claude/Goose work out of the box on `make up`?
4. **Secrets:** Personal Splunkbase OK, or require org lab account?
5. **Support:** Who owns tickets when `splunk-init` fails on someone else’s laptop?
6. **CI:** Is lint enough until workshop season, or is broken `main` unacceptable for a week?

---

## Quick reference: acceptance today

From [SPECS.md](SPECS.md) — unchanged by this document:

```bash
make status              # splunk-init OK + Splunk ready (when stack is up)
make verify-mcp-remote   # client config + MCP tools/list + mcp-remote stdio
make verify              # status then verify-mcp-remote
make demo-prep           # status + verify + warm-stack reminder
```

**Graduated acceptance** = same commands, run by a **non-maintainer** on a **fresh clone** with **only** documented secrets paths.

---

## Document maintenance

Update this file when:

- Supported platform or client matrix changes  
- CI smoke is adopted or explicitly rejected again  
- Workshop packaging strategy changes (`local/` vs `.spl`)  
- A formal external dry run (F1) completes — note date and outcome in a short “Evidence” subsection below

### Evidence log

| Date | Event | Outcome |
| ---- | ----- | ------- |
| — | — | Add rows when dry runs or rollout decisions happen |
