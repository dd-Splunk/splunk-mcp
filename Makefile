.PHONY: help init up down clean logs claude-update status restart

help:
	@echo "Splunk MCP Server - PoC Environment"
	@echo ""
	@echo "Available targets:"
	@echo "  make init           - Initialize environment (inject 1Password secrets)"
	@echo "  make up             - Start Splunk and configure Claude Desktop"
	@echo "  make down           - Stop Splunk container"
	@echo "  make restart        - Restart Splunk container"
	@echo "  make clean          - Remove containers and volumes (destructive)"
	@echo "  make logs           - Follow Splunk container logs"
	@echo "  make status         - Check Splunk container status"
	@echo "  make claude-update  - Update Claude Desktop config with saved token"
	@echo ""

init:
	@echo "Initializing environment..."
	@if ! command -v op > /dev/null 2>&1; then \
		echo "Error: 1Password CLI (op) not found. Please install it first."; \
		exit 1; \
	fi
	@op inject -i tpl.env -o .env
	@echo "Environment initialized. Secrets injected from 1Password."

up: init
	@echo "Starting Splunk with MCP Server app..."
	@docker compose up -d
	@echo ""
	@echo "Splunk is starting..."
	@echo "Web UI will be available at: https://localhost:8000"
	@echo "MCP Server API: https://localhost:8089/services/mcp"
	@echo ""
	@echo "Waiting for token generation (this may take 2-3 minutes)..."
	@for i in {1..60}; do \
		if [ -f .secrets/splunk-token ]; then \
			echo ""; \
			echo "✅ Token generated! Configuring Claude Desktop..."; \
			$(MAKE) claude-update; \
			exit 0; \
		fi; \
		echo -n "."; \
		sleep 2; \
	done; \
	echo ""; \
	echo "⚠️  Token not generated within timeout. Run 'make claude-update' manually once ready."

down:
	@echo "Stopping Splunk container..."
	@docker compose down

restart:
	@echo "Restarting Splunk container..."
	@docker compose restart

clean:
	@echo "WARNING: This will remove all containers, volumes, and .env file (data will be lost)."
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		docker compose down -v; \
		rm -f .env; \
		echo "Cleanup complete."; \
	else \
		echo "Cleanup cancelled."; \
	fi

logs:
	@docker compose logs -f so1

status:
	@echo "Checking Splunk container status..."
	@docker compose ps
	@echo ""
	@docker compose exec so1 curl -k -s https://localhost:8089/services/server/info 2>/dev/null | grep -q serverName && \
		echo "Splunk is ready ✓" || echo "Splunk is not ready yet..."

claude-update:
	@chmod +x scripts/update-claude-config.sh
	@./scripts/update-claude-config.sh .secrets/splunk-token
