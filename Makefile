SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

DC ?= docker compose
TOKEN_FILE ?= .secrets/splunk-token
ENV_FILE ?= tpl.env
ENV_OUT ?= .env
OP ?= op

# Secrets-backed Compose: only needed when interpolating tpl.env / .env into the stack (make up).
# Usage: $(call DC_CMD,<compose args>)
define DC_CMD
	@if [[ -f "$(ENV_OUT)" ]]; then \
		$(DC) $(1); \
	else \
		command -v "$(OP)" >/dev/null 2>&1 || { \
			echo "Error: $(ENV_OUT) not found and 1Password CLI (op) not available."; \
			echo "Either run 'make init' to write $(ENV_OUT) or install/authenticate 1Password CLI."; \
			exit 1; \
		}; \
		"$(OP)" run --env-file="$(ENV_FILE)" -- $(DC) $(1); \
	fi
endef

# Lifecycle Compose (down/logs/ps/restart/exec): does not need SPLUNK_* or Splunkbase secrets—only
# the project name from this directory. Avoids requiring `op` when .env is absent.
# Usage: $(call DC_LITE,<compose args>)
define DC_LITE
	@$(DC) $(1)
endef

.PHONY: help init up wait-token down clean logs claude-update goose-update cursor-mcp verify-mcp-remote status status-exec-check restart lint-md lint-md-fix

help:
	@echo "Splunk MCP Server - PoC Environment"
	@echo ""
	@echo "Available targets:"
	@echo "  make up             - Start Splunk; wait for token; run claude-update (Cursor/Goose: see make cursor-mcp / goose-update)"
	@echo "                       (needs secrets: $(ENV_OUT) or op + $(ENV_FILE); see below)"
	@echo "  make init           - [legacy/optional] Write $(ENV_OUT) from $(ENV_FILE) (op inject)"
	@echo "  make init FORCE=1   - Re-generate $(ENV_OUT) (op inject)"
	@echo "  make wait-token     - Wait for $(TOKEN_FILE) to appear"
	@echo "  make down           - Stop stack (no 1Password required)"
	@echo "  make restart        - Restart Splunk container (no 1Password required)"
	@echo "  make clean          - Remove containers and volumes (destructive; no 1Password required)"
	@echo "  make logs           - Follow Splunk logs (no 1Password required)"
	@echo "  make status         - Check Splunk container status"
	@echo "  make claude-update  - Update Claude Desktop config with saved token"
	@echo "  make goose-update   - Update Goose config with Splunk MCP extension"
	@echo "  make cursor-mcp     - Write .cursor/mcp.json for Splunk MCP (from $(TOKEN_FILE))"
	@echo "  make verify-mcp-remote - Smoke-test mcp-remote → Splunk (correct header quoting)"
	@echo "  make lint-md        - Run markdownlint-cli2 on docs (see .markdownlint.json)"
	@echo "  make lint-md-fix    - Same, with --fix for auto-fixable issues"
	@echo ""

lint-md:
	@command -v npx >/dev/null 2>&1 || { echo "Error: npx (Node) required for markdownlint-cli2."; exit 1; }
	@npx --yes markdownlint-cli2

lint-md-fix:
	@command -v npx >/dev/null 2>&1 || { echo "Error: npx (Node) required for markdownlint-cli2."; exit 1; }
	@npx --yes markdownlint-cli2 --fix

init:
	@if [[ -f "$(ENV_OUT)" && "${FORCE:-0}" != "1" ]]; then \
		echo "$(ENV_OUT) already exists; skipping (set FORCE=1 to re-generate)."; \
		exit 0; \
	fi
	@echo "Initializing environment ($(ENV_OUT) via 1Password op inject)..."
	@command -v "$(OP)" >/dev/null 2>&1 || { echo "Error: 1Password CLI (op) not found. Install it or create $(ENV_OUT) manually."; exit 1; }
	@"$(OP)" inject -i "$(ENV_FILE)" -o "$(ENV_OUT)"
	@echo "Environment initialized: $(ENV_OUT) written."

up:
	@echo "Starting Splunk with MCP Server app..."
	@$(call DC_CMD,up -d)
	@echo ""
	@echo "Splunk is starting..."
	@echo "Web UI will be available at: https://localhost:8000"
	@echo "MCP Server API: https://localhost:8089/services/mcp"
	@echo ""
	@$(MAKE) wait-token
	@echo "✅ Token generated! Configuring Claude Desktop..."
	@$(MAKE) claude-update

wait-token:
	@echo "Waiting for token generation (this may take 2-3 minutes)..."
	@for i in {1..60}; do \
		if [[ -f "$(TOKEN_FILE)" ]]; then \
			echo ""; \
			exit 0; \
		fi; \
		printf "."; \
		sleep 2; \
	done; \
	echo ""; \
	echo "⚠️  Token not generated within timeout: $(TOKEN_FILE)"; \
	exit 1

down:
	@echo "Stopping Splunk container..."
	@$(call DC_LITE,down)

restart:
	@echo "Restarting Splunk container..."
	@$(call DC_LITE,restart)

clean:
	@echo "WARNING: This will remove all containers, volumes, and .env file (data will be lost)."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DC) down -v; \
		rm -f "$(ENV_OUT)"; \
		rm -f "$(TOKEN_FILE)"; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

logs:
	@$(call DC_LITE,logs -f so1)

# Used by status: DC_LITE must not be embedded in another shell line (Make expands it to a full recipe block).
status-exec-check:
	@$(call DC_LITE,exec so1 curl -k -s https://localhost:8089/services/server/info 2>/dev/null | grep -q serverName)

status:
	@echo "Checking Splunk container status..."
	@$(call DC_LITE,ps)
	@echo ""
	@$(MAKE) status-exec-check && echo "Splunk is ready ✓" || echo "Splunk is not ready yet..."

claude-update:
	@./scripts/update-claude-config.sh "$(TOKEN_FILE)"

goose-update:
	@./scripts/update-goose-config.sh "$(TOKEN_FILE)"

cursor-mcp:
	@./scripts/update-cursor-config.sh "$(TOKEN_FILE)"

verify-mcp-remote:
	@./scripts/verify-mcp-remote.sh "$(TOKEN_FILE)"
