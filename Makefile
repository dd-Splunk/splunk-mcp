SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := help

DC ?= docker compose
TOKEN_FILE ?= .secrets/splunk-token
ENV_FILE ?= tpl.env
ENV_OUT ?= .env
ENV_EXAMPLE ?= tpl.env.example
OP ?= op

export ENV_FILE ENV_OUT ENV_EXAMPLE OP DC

.PHONY: help up wait-token down restart clean logs status \
	update-claude-config update-cursor-config update-goose-config verify-mcp-remote

help: ## Show targets
	@awk 'BEGIN {FS = ":.*##"; printf "Splunk MCP PoC\n\n"} \
		/^[$$()% a-zA-Z_-]+:.*?##/ { printf "  make %-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ## Start stack, wait for token, update MCP client configs
	@echo "Starting Splunk with MCP Server app..."
	@./scripts/compose-up.sh
	@echo ""
	@echo "Splunk is starting..."
	@echo "Web UI:  https://localhost:8000"
	@echo "MCP API: https://localhost:8089/services/mcp"
	@echo ""
	@$(MAKE) wait-token
	@echo "Token ready — updating Claude, Cursor, and Goose MCP configs..."
	@$(MAKE) update-claude-config update-cursor-config update-goose-config

wait-token: ## Wait for .secrets/splunk-token
	@echo "Waiting for token (up to ~2 min)..."
	@for _ in {1..60}; do \
		[[ -f "$(TOKEN_FILE)" ]] && { echo ""; exit 0; }; \
		printf "."; sleep 2; \
	done; \
	echo ""; echo "Timeout: $(TOKEN_FILE) not found"; exit 1

down: ## Stop containers (no secrets required)
	@echo "Stopping stack..."
	@$(DC) down

restart: ## Restart Splunk container (no secrets required)
	@$(DC) restart so1

clean: ## Remove volumes, .env, and secrets (destructive)
	@echo "WARNING: removes containers, volumes, $(ENV_OUT), and $(TOKEN_FILE)."
	@read -p "Are you sure? [y/N] " -n 1 -r; echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DC) down -v; \
		rm -f "$(ENV_OUT)" "$(TOKEN_FILE)"; \
		rm -rf .secrets/* .secrets/.[!.]* .secrets/..?* 2>/dev/null || true; \
		echo "Cleanup complete."; \
	else echo "Cancelled."; fi

logs: ## Follow Splunk logs (docker logs so1)
	@docker logs -f so1 2>&1 || { echo "Hint: run make up"; exit 1; }

status: ## Container status and Splunk API probe
	@echo "Containers:"
	@docker ps -a --filter "name=so1" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || true
	@docker ps -a --filter "name=splunk-init" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || true
	@echo ""; echo "splunk-init Exited (0) is normal (one-shot setup)."
	@echo ""
	@code="$$(docker exec so1 curl -k -s -o /dev/null -w '%{http_code}' \
		https://localhost:8089/services/server/info 2>/dev/null)"; \
	if [[ "$$code" = "200" || "$$code" = "401" ]]; then echo "Splunk is ready ✓"; \
	else echo "Splunk is not ready yet..."; fi

update-claude-config: ## Update Claude Desktop MCP config
	@./scripts/update-claude-config.sh "$(TOKEN_FILE)"

update-cursor-config: ## Update .cursor/mcp.json
	@./scripts/update-cursor-config.sh "$(TOKEN_FILE)"

update-goose-config: ## Update Goose MCP config
	@./scripts/update-goose-config.sh "$(TOKEN_FILE)"

verify-mcp-remote: ## Smoke-test mcp-remote → Splunk
	@./scripts/verify-mcp-remote.sh "$(TOKEN_FILE)"
