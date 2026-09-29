# CI/CD (GitHub Actions)

Automation in this repo is intentionally small: it supports a **local PoC** stack, not a full product pipeline. Treat workflows as **convenience checks and a throwaway `.spl` build**, not as release engineering.

## Workflows overview

| Workflow file | Purpose |
| ------------- | ------- |
| [.github/workflows/ci.yml](../../.github/workflows/ci.yml) | Secret scanning, shell/Markdown lint, Docker-free `make test` |
| [.github/workflows/package-s4r.yml](../../.github/workflows/package-s4r.yml) | Build **SA-S4R** as `SA-S4R.spl`, upload a CI artifact, publish a **moving `latest` GitHub Release** |

---

## `ci.yml` (CI)

**Triggers**

- **Push** to **`main`** or **`master`**.
- **pull_request** events (no branch filter in the workflow).

**What it runs**

- **gitleaks** on the full git history (**.gitleaks.toml** allowlists PoC placeholders)
- **pre-commit** (**.pre-commit-config.yaml**): **gitleaks** on tracked files, **shellcheck** on **`scripts/*.sh`** and **`tests/*.sh`**, **markdownlint-cli2** on project Markdown (via **`.markdownlint-cli2.jsonc`**)
- **`make test`**: MCP client JSON/YAML shape (no Splunk) and SA-S4R mode/payload unit tests (**PyYAML** + **jq** + **npx**)

**Permissions**

- **`contents: read`** only.

**PoC limitations**

- Does **not** build Docker images, start Splunk, run integration tests, or validate MCP connectivity.
- **Does** run Docker-free unit tests (`make test`).
- Does **not** package Splunk apps or publish releases.
- Match CI locally: `pip install pre-commit && pre-commit install`, then **`pre-commit run --all-files`** and **`make test`** before pushing (requires **shellcheck** on PATH, **Node/npx**, **jq**, and **PyYAML**). CI installs **shellcheck** and **jq** via **apt**; on macOS use **`brew install shellcheck`**. Optional full-history scan: **`brew install gitleaks && gitleaks detect --source . --config .gitleaks.toml`**.

---

## `package-s4r.yml` (Package SA-S4R app)

**Triggers**

- **`workflow_dispatch`** (manual run from the Actions tab).
- **Push** when paths change under **`SA-S4R/**`** or when **`.github/workflows/package-s4r.yml`** itself changes.
- **`pull_request`** for the same paths (build + artifact only).

**What it runs**

1. Builds **`SA-S4R.spl`** using **`COPYFILE_DISABLE=1`** and **`tar --format ustar`** (aligned with Splunk packaging guidance).
2. Uploads **`SA-S4R.spl`** as a **workflow artifact** (short retention; see below).
3. **Publish `latest` only from `main` / `master`:** on **push** or **`workflow_dispatch`** when **`github.ref`** is **`refs/heads/main`** or **`refs/heads/master`**, the job **deletes** any existing **`latest`** release and tag, **recreates** tag **`latest`** on the **current commit**, **force-pushes** the tag, and **creates** a GitHub Release titled **SA-S4R (latest)** with the `.spl` attached (marked as the repository’s **latest** release). Feature-branch pushes and pull requests **do not** move **`latest`**.

The package excludes **`local/`** and **`metadata/local.meta`**. Workshop dashboard/nav/field-extraction overrides stay in the running app’s **`local/`** (inside **`so1-etc`**). Git ignores **`SA-S4R/local/**`**.

Compose installs this `.spl` from the **`latest`** release URL in **`SPLUNK_APPS_URL`**. The image downloads it on the first start of an empty **`so1-etc`**. See [SA-S4R-APP.md](../s4r/SA-S4R-APP.md) § Install from GitHub `.spl`.

**Permissions**

- **`contents: write`** (required to push the **`latest`** tag and manage releases).

**Concurrency**

- **`package-s4r-latest-release`**: only one run at a time updates the **`latest`** release; additional runs **wait** (they are not canceled).

**PoC limitations**

- **No versioning**: the **`latest`** tag and release **move on every successful publish from `main`/`master`**. There is **no semver**, change log, or compatibility promise.
- **`workflow_dispatch`** from a **non-main** branch builds the artifact but **does not** move **`latest`**.
- **GitHub workflow `paths` filters are literals**; they cannot reference `env`. If you rename **`SA-S4R/`**, update **`env.SPLUNK_APP_DIR`** and the **`on.push.paths`** / **`on.pull_request.paths`** entries together.
- **Workflow artifacts** use **limited retention** (currently **7 days**). For a durable download link, use the **Release** asset, not the Actions artifact (after retention expires, the artifact disappears).
- **No** Splunk AppInspect, signing, staging deploy, or promotion gates—appropriate for demos only.
- **Forks / tokens**: contributors forking the repo may have restricted **`GITHUB_TOKEN`** capabilities for releases; maintainers run this on the canonical repo.

---

## Related

- Contributor rules and local verification: [**`AGENTS.md`**](../../AGENTS.md)
- Bundled app behavior: [**`docs/s4r/SA-S4R-APP.md`**](../s4r/SA-S4R-APP.md)
