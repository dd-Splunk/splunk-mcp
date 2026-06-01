SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

.DEFAULT_GOAL := help

DC ?= docker compose
ENV_FILE ?= tpl.env
ENV_OUT ?= .env
ENV_EXAMPLE ?= tpl.env.example
OP ?= op
MCP_CLIENT ?= cursor
MCP_VERIFY_CLIENT ?= all
MCP_CLIENTS := claude cursor goose
MCP_PROXY_PORT ?= 8090

export ENV_FILE ENV_OUT ENV_EXAMPLE OP DC

.PHONY: help up down restart clean logs status \
	update-mcp-clients update-mcp-client verify-mcp-remote \
	update-claude-config update-cursor-config update-goose-config

help: ## Show targets
	@awk 'BEGIN {FS = ":.*##"; printf "Splunk MCP PoC\n\n"} \
		/^[$$()% a-zA-Z_-]+:.*?##/ { printf "  make %-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ## Start stack and update MCP client configs
	@echo "Starting Splunk with MCP Server app..."
	@./scripts/compose-up.sh
	@echo ""
	@echo "Splunk is starting..."
	@echo "Web UI:  https://localhost:8000"
	@echo "Splunk MCP API: https://localhost:8089/services/mcp"
	@echo "Local MCP proxy: http://localhost:$(MCP_PROXY_PORT)/mcp"
	@echo ""
	@echo "Updating Claude, Cursor, and Goose MCP configs (no secrets written)..."
	@$(MAKE) update-mcp-clients

down: ## Stop containers (no secrets required)
	@echo "Stopping stack..."
	@$(DC) down

restart: ## Restart Splunk container (no secrets required)
	@$(DC) restart so1

clean: ## Remove volumes and .env (destructive)
	@echo "WARNING: removes containers, volumes, and $(ENV_OUT)."
	@read -p "Are you sure? [y/N] " -n 1 -r; echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		$(DC) down -v; \
		rm -f "$(ENV_OUT)"; \
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

update-mcp-clients: ## Update Claude, Cursor, and Goose (no secrets)
	@for c in $(MCP_CLIENTS); do \
		MCP_PROXY_PORT="$(MCP_PROXY_PORT)" ./scripts/mcp-client.sh update "$$c"; \
		echo ""; \
	done

update-mcp-client: ## Update one client (MCP_CLIENT=claude|cursor|goose)
	@MCP_PROXY_PORT="$(MCP_PROXY_PORT)" ./scripts/mcp-client.sh update "$(MCP_CLIENT)"

update-claude-config: ## Alias: MCP_CLIENT=claude
	@$(MAKE) update-mcp-client MCP_CLIENT=claude

update-cursor-config: ## Alias: MCP_CLIENT=cursor
	@$(MAKE) update-mcp-client MCP_CLIENT=cursor

update-goose-config: ## Alias: MCP_CLIENT=goose
	@$(MAKE) update-mcp-client MCP_CLIENT=goose

verify-mcp-remote: ## Verify config + MCP proxy (MCP_VERIFY_CLIENT=all|claude|cursor|goose)
	@MCP_PROXY_PORT="$(MCP_PROXY_PORT)" ./scripts/mcp-client.sh verify "$(MCP_VERIFY_CLIENT)"
