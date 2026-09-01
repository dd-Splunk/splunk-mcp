# splunk-mcp

Local **proof-of-concept**: **Splunk Enterprise** in Docker, **Splunk MCP Server**, and optional **Splunk4Rookies** sample data (**`SA-S4R`**). Clients (**Cursor**, **Claude Desktop**, **Goose**) connect via **`npx mcp-remote`**.

```bash
cp tpl.env.example tpl.env   # or .env.example → .env
make up
make verify-mcp-remote
```

| URL | Use |
| --- | --- |
| `https://localhost:8000` | Splunk Web |
| `https://localhost:8089/services/mcp` | MCP (bearer token in client config only) |

**Documentation:** [docs/README.md](docs/README.md) · **Workshop:** [docs/s4r/README.md](docs/s4r/README.md) · **Contributors / AI:** [AGENTS.md](AGENTS.md)

Community PoC—not an official Splunk product. MIT [LICENSE](LICENSE).
