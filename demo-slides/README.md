# S4R Marp slide deck

Presenter slides for the **Splunk4Rookies agentic Buttercup demo**, built with [Marp](https://marp.app/).

| File | Role |
| ---- | ---- |
| **`s4r-demo-slides.md`** | Source deck (32 slides + speaker notes) |
| **`index.md`** | Symlink → `s4r-demo-slides.md` (for `marp -s` server mode) |
| **`splunk.css`** | Custom theme (`/* @theme splunk */`) — dark background, orange titles |
| **`.marprc.yml`** | CLI defaults: `themeSet`, `html: true` |
| **`s4r-demo-slides.html`** | Exported HTML (regenerate with `make marp-html`) |
| **`S4R-DEMO.md`** | Full presenter script, timings, copy-paste prompts |

## Quick start

From the repo root (requires [Marp CLI](https://github.com/marp-team/marp-cli) on `PATH`):

```bash
make marp-preview    # open preview window (single file)
make marp-serve      # http://localhost:8080/ (directory mode)
make marp-html       # write demo-slides/s4r-demo-slides.html
```

**Cursor / VS Code (optional):** install the [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode) extension. Workspace settings in **`.vscode/settings.json`** register `demo-slides/splunk.css` as theme `splunk` and set `markdown.marp.html` to **`all`** (needed for Mermaid `<script>`). Reload the window if you still see *The specified theme "splunk" is not recognized by Marp for VS Code* — the extension does **not** read `.marprc.yml` (that file is CLI-only).

Open `demo-slides/s4r-demo-slides.md` and use the Marp preview pane. Press **`P`** for presenter view (speaker notes). CLI targets (`make marp-*`) use `.marprc.yml` in this folder.

## Front matter

```yaml
---
marp: true
theme: splunk
paginate: true
html: true
footer: '![w:46](https://www.splunk.com/.../logo-splunk-corp-rgb-w-web.svg)'
---
```

- **`theme: splunk`** — must match `/* @theme splunk */` in `splunk.css`.
- **`html: true`** — required for Mermaid client-side rendering, `<br>`, `<span class="splunk-orange">`, and layout `<div>`s.
- **`footer`** — Splunk “a Cisco company” white logo (lower center via CSS); PoC disclaimer appended in `splunk.css`.

## Mermaid diagrams

Marp does **not** render ` ```mermaid ` fenced blocks. This deck uses:

1. A **Mermaid 10 ESM script** in the deck front matter (jsDelivr CDN).
2. Diagrams in **`<pre class="mermaid">`** — no blank lines inside the block (Marp parses inner content as Markdown).

```html
<pre class="mermaid">
flowchart TB
  A --> B
</pre>
```

**Offline / air-gapped:** export with `make marp-html` on a machine with network first, or open the generated HTML after export. Live preview needs CDN access for Mermaid.

**Label clipping:** theme sets isolated `14px` font on `.mermaid` (12px on split slides) so node boxes match label size.

## Slide classes

Apply at the **top** of a slide (before the `#` title):

| Class | Use |
| ----- | --- |
| `lead` | Gradient title slide (centered) |
| `lead-hero` | With `lead` — large hero title (S1, S29 Thank You) |
| `diagram` | Smaller body text; full-width Mermaid |
| `diagram-split` | Diagram + table side by side (~62% / ~34%) |
| `diagram-split-equal` | With `diagram-split` — 50/50 columns (S21 data modes) |
| `compact` | Smaller body, tables, and blockquotes for dense slides (S8, S11–12, S16, S27, S31–32) |
| *(HTML)* `.two-col` | Two equal columns inside a compact slide (S16 prompts) |

Example:

```markdown
---

<!-- _class: diagram diagram-split -->

# Splunk MCP guardrails

<div class="diagram-table-row">
<pre class="mermaid">...</pre>
<div class="diagram-table-col">| table |</div>
</div>
```

## Speaker notes

Use **HTML comments** only — not `note:` (that can leak onto slides):

```markdown
<!--
Numbers come from live MCP — do not read fixed amounts from slides.
-->
```

Visible in Marp **presenter view** (`P`).

## Slide map (32)

Deck follows **three steps** plus a **MCP architecture** primer (Developer Day 2026) between Step 1 and Step 2.

| # | Title | Notes |
| - | ----- | ----- |
| 1 | From dashboards to agentic analysis | `lead lead-hero` |
| 2 | Three ways this repo helps | Steps 1–3 overview table |
| 3 | Scenario — Buttercup Enterprises | |
| 4 | Step 1 — Build dashboards with natural language | `lead` section divider |
| 5 | Step 1 — Workshop dashboard build | Labs 3–7 table |
| 6 | Step 1 — What you get | Artifacts |
| 7 | Splunk MCP architecture — Apps as tools | `lead` section divider |
| 8 | Apps as MCP tools | Existing apps → AI tools; saved search vs REST; `tools.conf` + signatures |
| 9 | Splunk MCP architecture | `diagram-split`; native / Splunkbase / private `SA-S4R_*` |
| 10 | How it works | `diagram`; app files → MCP registration |
| 11 | `tools.conf` and signatures | `compact`; `[savedsearches:]` / `[restmap:]` |
| 12 | SA-S4R workshop tools | `compact`; five `SA-S4R_*` tools |
| 13 | Step 2 — Ask business questions without SPL | `lead` section divider |
| 14 | Step 2 — Business questions in plain English | Example prompts |
| 15 | Splunk MCP guardrails | `diagram-split`; `SA-S4R_*` workshop tools |
| 16 | Step 2 — Live demo prompt | `compact`; two-column Business + Security asks |
| 17 | Step 3 — Agentic orchestration for specialists | `lead` section divider |
| 18 | The challenge | |
| 19 | Agentic Architecture | `diagram`; User / Agentic / Splunk platform subgraphs |
| 20 | Agents Artifacts defined | |
| 21 | Two workshop data modes | MCP NK toggle (`mode=infrastructure` / `threat`); caption has tool names |
| 22 | Step 3 — Demo 1: Infrastructure story | |
| 23 | Step 3 — delegation flow | `diagram`; executive synthesis |
| 24 | Buttercup Insights | |
| 25 | Additional Business questions (1 of 2) | Checkout, merchandising, mobile vs platform |
| 26 | Additional Business questions (2 of 2) | International, fraud vs reliability |
| 27 | Step 3 — Demo 2: North Korea attack | `compact`; chat enable + Power User ask |
| 28 | Takeaways | All three steps + MCP architecture |
| 29 | Thank You | `lead lead-hero` |
| 30 | Appendix — before you start | |
| 31 | Appendix — copy-paste prompts | `compact` — Steps 1–3 prompts |
| 32 | Appendix — troubleshooting | `compact` table |

## Theme highlights (`splunk.css`)

- **Slide size:** 1280×720; black background; fixed **43.2px** orange `h1` on content slides.
- **Content slides (S2+):** top-aligned titles (`justify-content: flex-start`) — same vertical title position on every slide.
- **Tables:** dark rows, centered; orange header text.
- **Code:** Splunk blue `#00B3F0` on dark `#111` blocks; `pre:not(.mermaid)` only.
- **Logo:** footer, lower center, ~46px wide (71% smaller than initial header size).

## Troubleshooting

| Issue | Fix |
| ----- | --- |
| Theme not applied / wrong colors | Theme name must be `splunk` in front matter **and** `/* @theme splunk */` in CSS; restart Marp preview |
| *Theme "splunk" is not recognized by Marp for VS Code* | Register `./demo-slides/splunk.css` via `markdown.marp.themes` (see `.vscode/settings.json`); reload the window. Marp CLI does not need this. |
| Mermaid shows as text | `html: true` in front matter and `.marprc.yml`; use `<pre class="mermaid">`; hard-refresh browser |
| `marp -s` fails | Pass a **directory** (`make marp-serve`), not a file |
| Diagram clipped on S4 | Full-width diagram slides cap SVG at 520px height; only grows when diagram is the last element |
| VS Code preview ≠ browser | Prefer `make marp-html` + browser for Mermaid; or `make marp-serve` |

## Related docs

- [S4R-DEMO.md](S4R-DEMO.md) — presenter script and demo flow
- [S4R-MCP-TOOLS.md](../docs/S4R-MCP-TOOLS.md) — MCP architecture, definitions, app config files; [Developer Day 2026 recordings](https://www.youtube.com/playlist?list=PLxkFdMSHYh3T2mFyCdg8iz9ef068gLdfJ)
- [s4r/README.md](../docs/s4r/README.md) — Splunk4Rookies workshop hub
- [PRESALES.md](../docs/PRESALES.md) — SE checklist
- [S4R-AGENTS.md](../docs/S4R-AGENTS.md) — agent architecture
