SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

DC ?= docker compose
TOKEN_FILE ?= .secrets/splunk-token

.PHONY: help init up wait-token down clean logs claude-update cursor-mcp verify-mcp-remote status restart

help:
	@echo "Splunk MCP Server - PoC Environment"
	@echo ""
	@echo "Available targets:"
	@echo "  make init           - Create .env (op inject) if missing"
	@echo "  make init FORCE=1   - Re-generate .env (op inject)"
	@echo "  make up             - Start Splunk and configure Claude Desktop (waits for token)"
	@echo "  make wait-token     - Wait for $(TOKEN_FILE) to appear"
	@echo "  make down           - Stop Splunk container"
	@echo "  make restart        - Restart Splunk container"
	@echo "  make clean          - Remove containers and volumes (destructive)"
	@echo "  make logs           - Follow Splunk container logs"
	@echo "  make status         - Check Splunk container status"
	@echo "  make claude-update  - Update Claude Desktop config with saved token"
	@echo "  make cursor-mcp     - Write .cursor/mcp.json for Splunk MCP (from $(TOKEN_FILE))"
	@echo "  make verify-mcp-remote - Smoke-test mcp-remote → Splunk (correct header quoting)"
	@echo ""

init:
	@if [[ -f .env && "${FORCE:-0}" != "1" ]]; then \
		echo ".env already exists; skipping (set FORCE=1 to re-generate)."; \
		exit 0; \
	fi
	@echo "Initializing environment (.env via 1Password op inject)..."
	@command -v op >/dev/null 2>&1 || { echo "Error: 1Password CLI (op) not found. Install it or create .env manually."; exit 1; }
	@op inject -i tpl.env -o .env
	@echo "Environment initialized: .env written."

up: init
	@echo "Starting Splunk with MCP Server app..."
	@$(DC) up -d
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
	@$(DC) down

restart:
	@echo "Restarting Splunk container..."
	@$(DC) restart

clean:
	@echo "WARNING: This will remove all containers, volumes, and .env file (data will be lost)."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DC) down -v; \
		rm -f .env; \
		rm -f "$(TOKEN_FILE)"; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

logs:
	@$(DC) logs -f so1

status:
	@echo "Checking Splunk container status..."
	@$(DC) ps
	@echo ""
	@$(DC) exec so1 curl -k -s https://localhost:8089/services/server/info 2>/dev/null | grep -q serverName && \
		echo "Splunk is ready ✓" || echo "Splunk is not ready yet..."

claude-update:
	@./scripts/update-claude-config.sh "$(TOKEN_FILE)"

cursor-mcp:
	@./scripts/update-cursor-config.sh "$(TOKEN_FILE)"

verify-mcp-remote:
	@./scripts/verify-mcp-remote.sh "$(TOKEN_FILE)"
