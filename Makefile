SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

DC ?= docker compose
TOKEN_FILE ?= .secrets/splunk-token
ENV_FILE ?= tpl.env
ENV_OUT ?= .env
OP ?= op

# Helper: run docker compose with either existing .env or 1Password-injected env
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

.PHONY: help init up wait-token down clean logs claude-update goose-update cursor-mcp verify-mcp-remote status status-exec-check restart

help:
	@echo "Splunk MCP Server - PoC Environment"
	@echo ""
	@echo "Available targets:"
	@echo "  make up             - Start Splunk and configure Claude Desktop and Goose (waits for token)"
	@echo "                       (prefers in-memory env via 1Password; falls back to $(ENV_OUT) if present)"
	@echo "  make init           - [legacy/optional] Write $(ENV_OUT) from $(ENV_FILE) (op inject)"
	@echo "  make init FORCE=1   - Re-generate $(ENV_OUT) (op inject)"
	@echo "  make wait-token     - Wait for $(TOKEN_FILE) to appear"
	@echo "  make down           - Stop Splunk container"
	@echo "  make restart        - Restart Splunk container"
	@echo "  make clean          - Remove containers and volumes (destructive)"
	@echo "  make logs           - Follow Splunk container logs"
	@echo "  make status         - Check Splunk container status"
	@echo "  make claude-update  - Update Claude Desktop config with saved token"
	@echo "  make goose-update   - Update Goose config with Splunk MCP extension"
	@echo "  make cursor-mcp     - Write .cursor/mcp.json for Splunk MCP (from $(TOKEN_FILE))"
	@echo "  make verify-mcp-remote - Smoke-test mcp-remote → Splunk (correct header quoting)"
	@echo ""

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
	@$(call DC_CMD,down)

restart:
	@echo "Restarting Splunk container..."
	@$(call DC_CMD,restart)

clean:
	@echo "WARNING: This will remove all containers, volumes, and .env file (data will be lost)."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		if [[ -f "$(ENV_OUT)" ]]; then \
			$(DC) down -v; \
		else \
			command -v "$(OP)" >/dev/null 2>&1 || { \
				echo "Error: $(ENV_OUT) not found and 1Password CLI (op) not available."; \
				echo "Either run 'make init' to write $(ENV_OUT) or install/authenticate 1Password CLI."; \
				exit 1; \
			}; \
			"$(OP)" run --env-file="$(ENV_FILE)" -- $(DC) down -v; \
		fi; \
		rm -f "$(ENV_OUT)"; \
		rm -f "$(TOKEN_FILE)"; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

logs:
	@$(call DC_CMD,logs -f so1)

# Used by status: DC_CMD must not be embedded in another shell line (Make expands it to a full recipe block).
status-exec-check:
	@$(call DC_CMD,exec so1 curl -k -s https://localhost:8089/services/server/info 2>/dev/null | grep -q serverName)

status:
	@echo "Checking Splunk container status..."
	@$(call DC_CMD,ps)
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
