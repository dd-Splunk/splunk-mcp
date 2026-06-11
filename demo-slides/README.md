# S4R Marp slide deck

Presenter slides for the **Splunk4Rookies agentic Buttercup demo**, built with [Marp](https://marp.app/).

| File | Role |
| ---- | ---- |
| **`s4r-demo-slides.md`** | Source deck (17 slides + speaker notes) |
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

**Cursor / VS Code (optional):** install the [Marp for VS Code](https://marketplace.visualstudio.com/items?itemName=marp-team.marp-vscode) extension. Register the theme in workspace settings if preview looks unstyled:

```json
"markdown.marp.themes": ["./demo-slides/splunk.css"],
"markdown.marp.enableHtml": true
```

Open `demo-slides/s4r-demo-slides.md` and use the Marp preview pane. Press **`P`** for presenter view (speaker notes). CLI targets (`make marp-*`) use `.marprc.yml` in this folder and do not require VS Code settings.

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
- **`footer`** — Splunk “a Cisco company” white logo (lower center via CSS); confidential line appended in `splunk.css`.

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
| `lead-hero` | With `lead` — large hero title (S1, S14 Thank You) |
| `diagram` | Smaller body text; full-width Mermaid |
| `diagram-split` | Diagram + table side by side (~62% / ~34%) |
| `diagram-split-equal` | With `diagram-split` — 50/50 columns (S7) |

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

## Slide map (17)

| # | Title | Notes |
| - | ----- | ----- |
| 1 | Splunk4Rookies / Agentic analysis… | `lead lead-hero` |
| 2 | Scenario — Buttercup Enterprises | |
| 3 | The challenge | |
| 4 | Agentic Architecture | `diagram`; User / Agentic / Splunk platform subgraphs |
| 5 | Agents Artifacts defined | |
| 6 | Splunk MCP guardrails | `diagram-split` |
| 7 | Two workshop data modes | `diagram-split-equal`; shell-styled `make` nodes |
| 8 | Demo 1 - Infrastructure story | |
| 9 | Demo 1 — delegation flow | `diagram`; expected answer under chart |
| 10 | Buttercup Insights | |
| 11 | Demo 2 - NK attack | |
| 12 | Dashboard tie-in — Lab 7 | |
| 13 | Takeaways | |
| 14 | Thank You | `lead lead-hero` |
| 15–17 | Appendix (before you start, prompts, troubleshooting) | Same style as content slides |

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
| Mermaid shows as text | `html: true` in front matter and `.marprc.yml`; use `<pre class="mermaid">`; hard-refresh browser |
| `marp -s` fails | Pass a **directory** (`make marp-serve`), not a file |
| Diagram clipped on S4 | Full-width diagram slides cap SVG at 520px height; only grows when diagram is the last element |
| VS Code preview ≠ browser | Prefer `make marp-html` + browser for Mermaid; or `make marp-serve` |

## Related docs

- [S4R-DEMO.md](S4R-DEMO.md) — presenter script and demo flow
- [s4r/README.md](../docs/s4r/README.md) — Splunk4Rookies workshop hub
- [PRESALES.md](../docs/PRESALES.md) — SE checklist
- [S4R-AGENTS.md](../docs/S4R-AGENTS.md) — agent architecture
