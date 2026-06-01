# Repository description & topics

## GitHub short description (About)

Use this text (or a shortened variant) in **Repository → Settings → General → About**, or via CLI:

```bash
gh repo edit OWNER/splunk-mcp --description "Proof-of-concept: Splunk Enterprise with Splunk MCP Server in Docker. Connect Claude Desktop, Cursor, or Goose via npx mcp-remote; secrets with 1Password CLI or .env."
```

## Topics

Suggested topics for discoverability (Claude, **Cursor**, **Goose**, Splunk, MCP):

| Topic | Notes |
| ----- | ----- |
| **mcp** | Model Context Protocol |
| **model-context-protocol** | Long-form MCP label (optional) |
| **splunk** | Splunk Enterprise |
| **splunk-mcp-server** | Splunkbase app for `/services/mcp` |
| **claude** | Anthropic Claude Desktop |
| **cursor** | Cursor IDE MCP client |
| **goose** | Goose AI agent / MCP extension |
| **llm** | Large language models |
| **docker** | Container runtime |
| **docker-compose** | Compose orchestration |
| **local-development** | Local PoC workflows |
| **poc** / **proof-of-concept** | Demo / lab use |
| **ai-development** | AI tooling |
| **integration** | Splunk + LLM integration |
| **rest-api** | Splunk REST / MCP HTTP |
| **authentication** | Tokens / Splunk auth |
| **token-auth** | Bearer tokens for MCP |
| **ai** | AI / assistants |

### Add or refresh topics (CLI)

```bash
gh repo edit OWNER/splunk-mcp \
  --add-topic cursor \
  --add-topic goose \
  --add-topic docker-compose \
  --add-topic llm \
  --add-topic local-development \
  --add-topic splunk-mcp-server
```

Topics already on the repo (e.g. `claude`, `mcp`, `splunk`) can stay; `--add-topic` is idempotent for existing names.
