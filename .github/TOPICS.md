# Repository description & topics

## GitHub short description (About)

Use this text (or a shortened variant) in **Repository → Settings → General → About**, or via CLI:

```bash
gh repo edit dd-Splunk/splunk-mcp --description "PoC: Splunk Enterprise + Splunk MCP Server in Docker. Splunk4Rookies (SA-S4R) sample data, multi-agent demo, Marp presenter deck. Cursor, Claude Desktop, or Goose via npx mcp-remote; secrets with 1Password or .env."
```

## Topics

Suggested topics for discoverability (Splunk, MCP, Splunk4Rookies, Marp):

| Topic | Notes |
| ----- | ----- |
| **mcp** | Model Context Protocol |
| **model-context-protocol** | Long-form MCP label |
| **splunk** | Splunk Enterprise |
| **splunk-mcp-server** | Splunkbase app for `/services/mcp` |
| **splunk4rookies** | Workshop / Buttercup Enterprises storyline |
| **marp** | Marp slide deck in `demo-slides/` |
| **claude** | Anthropic Claude Desktop |
| **cursor** | Cursor IDE MCP client |
| **goose** | Goose AI agent / MCP extension |
| **llm** | Large language models |
| **docker** | Container runtime |
| **docker-compose** | Compose orchestration |
| **local-development** | Local PoC workflows |
| **poc** / **proof-of-concept** | Demo / lab use |
| **eventgen** | SA-Eventgen sample traffic (SA-S4R) |
| **ai-development** | AI tooling |
| **integration** | Splunk + LLM integration |
| **rest-api** | Splunk REST / MCP HTTP |
| **authentication** | Tokens / Splunk auth |
| **token-auth** | Bearer tokens for MCP |
| **ai** | AI / assistants |

### Add or refresh topics (CLI)

GitHub allows **at most 20 topics**. If the repo is full, remove redundant tags first, then add workshop tags:

```bash
gh repo edit dd-Splunk/splunk-mcp \
  --remove-topic proof-of-concept \
  --remove-topic model-context-protocol \
  --remove-topic token-auth \
  --remove-topic integration

gh repo edit dd-Splunk/splunk-mcp \
  --add-topic marp \
  --add-topic splunk4rookies \
  --add-topic eventgen
```

Topics already on the repo (e.g. `claude`, `mcp`, `splunk`, `cursor`) can stay; `--add-topic` is idempotent for existing names.
