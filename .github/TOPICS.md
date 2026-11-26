# Repository description & topics

The GitHub **About** description and topics are repository settings, not files, so they can drift from this page. After changing either, update this file too. Check the live values with:

```bash
gh repo view dd-Splunk/splunk-mcp --json description,repositoryTopics
```

## GitHub short description (About)

Set in **Repository → Settings → General → About**, or via CLI:

```bash
gh repo edit dd-Splunk/splunk-mcp --description "Local PoC: Splunk Enterprise + Splunk MCP Server in Docker, with Splunk4Rookies (SA-S4R) sample data and an agentic demo. Connects Cursor, Claude Desktop and Claude Code via mcp-remote. Community project, not an official Splunk product."
```

Keep it free of operational detail (paths, secrets handling): it is public and shown in search results. GitHub allows up to 350 characters.

## Topics

GitHub allows **at most 20 topics**. The repo uses these 14:

| Topic | Notes |
| ----- | ----- |
| **mcp** | Model Context Protocol |
| **mcp-client** | Cursor, Claude Desktop and Claude Code connect through `mcp-remote` |
| **splunk** | Splunk Enterprise |
| **splunk-mcp-server** | Splunkbase app for `/services/mcp` |
| **splunk4rookies** | Workshop / Buttercup Enterprises storyline |
| **eventgen** | SA-Eventgen sample traffic (SA-S4R) |
| **marp** | Marp slide deck in `demo-slides/` |
| **claude** | Claude Desktop |
| **claude-code** | Claude Code |
| **cursor** | Cursor IDE MCP client |
| **llm** | Large language models |
| **docker** | Container runtime |
| **docker-compose** | Compose orchestration |
| **proof-of-concept** | Demo / lab use |

Deliberately left out: vague or overlapping tags (`ai`, `ai-development`, `integration`, `rest-api`, `authentication`, `token-auth`, `local-development`, `poc`, `model-context-protocol`). Add one only if it helps someone find the repo.

### Add or remove a topic (CLI)

```bash
gh repo edit dd-Splunk/splunk-mcp --add-topic <name>
gh repo edit dd-Splunk/splunk-mcp --remove-topic <name>
```

`--add-topic` is idempotent for names already on the repo.
