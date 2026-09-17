# splunk-mcp

Local **proof-of-concept**: **Splunk Enterprise** in Docker, **Splunk MCP Server**, and optional **Splunk4Rookies** sample data (**`SA-S4R`**). Clients (**Cursor**, **Claude Desktop**, **Goose**) connect via **`npx mcp-remote`** to **`https://localhost:8089/services/mcp`**.

**Scope:** on-prem **local Enterprise only**. **Splunk Cloud** MCP (OAuth, `*.splunkcloud.com`, staging stacks) is **out of scope** — not tested or supported in this repo. See [docs/poc/README.md](docs/poc/README.md#scope).

```bash
cp tpl.env.example tpl.env   # or .env.example → .env
make up
make verify-mcp-remote
```

`make up` registers workshop tools **`SA-S4R_*`** on the MCP endpoint (prefer those over ad-hoc SPL). In Cursor: **`/usage`** (tool routing) · **`/demo-prep`** (go/no-go, including S4R smoke). Details: [AGENTS.md](AGENTS.md) · [docs/s4r/MCP-TOOLS.md](docs/s4r/MCP-TOOLS.md).

| URL | Use |
| --- | --- |
| `https://localhost:8000` | Splunk Web |
| `https://localhost:8089/services/mcp` | MCP (bearer token in client config only) |

**Documentation:** [docs/README.md](docs/README.md) · **PoC stack:** [docs/poc/README.md](docs/poc/README.md) · **Workshop:** [docs/s4r/README.md](docs/s4r/README.md) · **Contributors / AI:** [AGENTS.md](AGENTS.md)

Community PoC—not an official Splunk product. MIT [LICENSE](LICENSE).
