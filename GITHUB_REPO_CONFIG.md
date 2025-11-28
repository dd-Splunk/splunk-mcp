# GitHub Repository Configuration

This file documents the recommended GitHub repository settings for `dd-Splunk/splunk-mcp`.

## How to Apply These Settings

1. Go to: https://github.com/dd-Splunk/splunk-mcp/settings
2. Fill in each section below
3. Click "Save" at the bottom of each section

---

## Repository Settings

### About Section

**Description:**
```
Proof of Concept environment for Splunk MCP (Model Context Protocol) Server integration with Claude Desktop, featuring Docker orchestration, 1Password secrets management, and automated Claude configuration.
```

**Website:**
```
(Leave empty or add documentation URL)
```

**Topics:**
```
splunk, mcp, model-context-protocol, claude, ai, docker, poc, proof-of-concept, integration, authentication, token-auth, rest-api
```

Copy-paste ready topics (comma-separated):
```
splunk,mcp,model-context-protocol,claude,ai,docker,poc,proof-of-concept,integration,authentication,token-auth,rest-api
```

---

## Key Features to Highlight

In the README (already complete), the repository highlights:
- ✅ Splunk 10.0 Enterprise with MCP Server v0.2.4
- ✅ Docker Compose orchestration
- ✅ 1Password CLI secret management
- ✅ Claude Desktop automatic configuration
- ✅ JWT token authentication (15-day validity)
- ✅ Complete documentation (6 guides + API reference)
- ✅ Claude logs indexing (claude_logs index)

---

## Repository Visibility

- **Visibility**: Public ✅ (already set)
- **GitHub Pages**: Disabled (documentation in `/docs` folder)
- **Discussions**: Optional (can be enabled for Q&A)
- **Issues**: Enabled
- **Pull Requests**: Enabled

---

## Branch Protection Rules (Optional)

Consider enabling for `main` branch:
- Require pull request reviews before merging (1 reviewer)
- Require status checks to pass before merging
- Dismiss stale pull request approvals when new commits are pushed
- Require signed commits

---

## Additional Recommendations

### 1. Add Repository Logo/Badge
Consider adding these badges to README (already included):
```markdown
[![Docker](https://img.shields.io/badge/Docker-ready-blue)](#prerequisites)
[![Splunk 10.0](https://img.shields.io/badge/Splunk-10.0-brightgreen)](#overview)
[![MCP 0.2.4](https://img.shields.io/badge/MCP%20Server-0.2.4-brightgreen)](#overview)
```

### 2. Release Strategy
For first release, consider:
- Tag: `v0.1.0`
- Title: "Initial PoC Release"
- Description: Link to QUICK_START.md
- Release notes highlighting features

### 3. Documentation Links
GitHub will automatically show:
- **README.md**: Main landing page
- **INSTALLATION.md** via docs/ folder
- **License**: Add LICENSE file if needed
- **CONTRIBUTING.md** if you want community contributions

---

## Summary

These settings will make your repository:
- Clearly searchable on GitHub (via topics)
- Professional appearance (via description)
- Easy to understand (via documentation)
- Open for collaboration (if desired)

Apply them via: https://github.com/dd-Splunk/splunk-mcp/settings
