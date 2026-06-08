# CI/CD (GitHub Actions)

Automation in this repo is intentionally small: it supports a **local PoC** stack, not a full product pipeline. Treat workflows as **convenience checks and a throwaway `.spl` build**, not as release engineering.

## Workflows overview

| Workflow file | Purpose |
| ------------- | ------- |
| [.github/workflows/ci.yml](../.github/workflows/ci.yml) | Lint shell scripts and Markdown |
| [.github/workflows/package-s4r.yml](../.github/workflows/package-s4r.yml) | Build **SA-S4R** as `SA-S4R.spl`, upload a CI artifact, publish a **moving `latest` GitHub Release** |

---

## `ci.yml` (CI)

**Triggers**

- **Push** and **pull_request** to **`main`** or **`master`**.

**What it runs**

- **pre-commit** (**.pre-commit-config.yaml**): **shellcheck** on **`scripts/*.sh`**, **markdownlint-cli2** on project Markdown (via **`.markdownlint-cli2.jsonc`**)

**Permissions**

- **`contents: read`** only.

**PoC limitations**

- Does **not** build Docker images, start Splunk, run integration tests, or validate MCP connectivity.
- Does **not** package Splunk apps or publish releases.
- Match CI locally: `pip install pre-commit && pre-commit install`, then **`pre-commit run --all-files`** before pushing (requires **shellcheck** on PATH and **Node/npx** for markdownlint). CI installs **shellcheck** via **apt**; on macOS use **`brew install shellcheck`**.

---

## `package-s4r.yml` (Package SA-S4R app)

**Triggers**

- **`workflow_dispatch`** (manual run from the Actions tab).
- **Push** when paths change under **`SA-S4R/**`** or when **`.github/workflows/package-s4r.yml`** itself changes.

**What it runs**

1. Builds **`SA-S4R.spl`** using **`COPYFILE_DISABLE=1`** and **`tar --format ustar`** (aligned with Splunk packaging guidance).
2. Uploads **`SA-S4R.spl`** as a **workflow artifact** (short retention; see below).
3. **Deletes** any existing **`latest`** release and tag, **recreates** tag **`latest`** on the **current commit**, **force-pushes** the tag, and **creates** a GitHub Release titled **SA-S4R (latest)** with the `.spl` attached (marked as the repository’s **latest** release).

**Permissions**

- **`contents: write`** (required to push the **`latest`** tag and manage releases).

**Concurrency**

- **`package-s4r-latest-release`**: only one run at a time updates the **`latest`** release; additional runs **wait** (they are not canceled).

**PoC limitations**

- **No versioning**: the **`latest`** tag and release **move on every successful run**. There is **no semver**, change log, or compatibility promise.
- **`workflow_dispatch`** can run from **any branch**; that still **moves `latest`** to that branch’s HEAD. Release notes include the short SHA and ref name—check them before trusting the artifact.
- **GitHub workflow `paths` filters are literals**; they cannot reference `env`. If you rename **`SA-S4R/`**, update **`env.SPLUNK_APP_DIR`** and the **`on.push.paths`** entries together.
- **Workflow artifacts** use **limited retention** (currently **7 days**). For a durable download link, use the **Release** asset, not the Actions artifact (after retention expires, the artifact disappears).
- **No** Splunk AppInspect, signing, staging deploy, or promotion gates—appropriate for demos only.
- **Forks / tokens**: contributors forking the repo may have restricted **`GITHUB_TOKEN`** capabilities for releases; maintainers run this on the canonical repo.

---

## Related

- Contributor rules and local verification: [**`AGENTS.md`**](../AGENTS.md)
- Bundled app behavior: [**`docs/SA-S4R-APP.md`**](SA-S4R-APP.md)
