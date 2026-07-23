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
MCP_CLIENTS := cursor goose claude

export ENV_FILE ENV_OUT ENV_EXAMPLE OP DC

.PHONY: help up down restart clean logs status demo-prep verify cloud-bootstrap \
	update-mcp-clients update-mcp-client verify-mcp-remote \
	update-claude-config update-cursor-config update-goose-config \
	s4r-attack-nk-enable s4r-attack-nk-disable s4r-attack-nk-status \
	marp-preview marp-serve marp-html \
	marp-bizcase-preview marp-bizcase-html marp-bizcase-pdf \
	marp-onepager-pdf

help: ## Show targets
	@awk 'BEGIN {FS = ":.*##"; printf "Splunk MCP PoC\n\n"} \
		/^[$$()% a-zA-Z_-]+:.*?##/ { printf "  make %-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

up: ## Start stack and update MCP client configs
	@echo "Starting Splunk with MCP Server app..."
	@./scripts/compose-up.sh
	@echo ""
	@echo "Splunk Web UI:  https://localhost:8000"
	@echo "Splunk MCP API: https://localhost:8089/services/mcp"
	@echo ""
	@echo "Updating Cursor, Goose, and Claude MCP configs (npx mcp-remote)..."
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
	@echo ""
	@init_rc=0; ./scripts/splunk-init-status.sh || init_rc=$$?; \
	echo ""; \
	code="$$(docker exec so1 curl -k -s -o /dev/null -w '%{http_code}' \
		https://localhost:8089/services/server/info 2>/dev/null)"; \
	if [[ "$$code" = "200" || "$$code" = "401" ]]; then echo "Splunk is ready ✓"; \
	else echo "Splunk is not ready yet..."; splunk_rc=1; fi; \
	splunk_rc="$${splunk_rc:-0}"; \
	if [[ "$$init_rc" -ne 0 ]]; then exit "$$init_rc"; fi; \
	exit "$$splunk_rc"

update-mcp-clients: ## Update Claude, Cursor, and Goose (mcp-remote + token)
	@for c in $(MCP_CLIENTS); do \
		echo "Updating $$c (waits for splunk-init, then mints token)..."; \
		./scripts/mcp-client.sh update "$$c" \
			|| { echo "$$c config skipped — run: make update-mcp-client MCP_CLIENT=$$c"; }; \
		echo ""; \
	done

update-mcp-client: ## Update one client (MCP_CLIENT=claude|cursor|goose)
	@./scripts/mcp-client.sh update "$(MCP_CLIENT)"

update-claude-config: ## Claude: npx mcp-remote + bearer token
	@$(MAKE) update-mcp-client MCP_CLIENT=claude

update-cursor-config: ## Cursor: npx mcp-remote + bearer token
	@$(MAKE) update-mcp-client MCP_CLIENT=cursor

update-goose-config: ## Goose: npx mcp-remote + bearer token
	@$(MAKE) update-mcp-client MCP_CLIENT=goose

verify-mcp-remote: ## Verify client configs + Splunk MCP (MCP_VERIFY_CLIENT=all|…)
	@./scripts/mcp-client.sh verify "$(MCP_VERIFY_CLIENT)"

demo-prep: ## Pre-demo check: status + MCP verify + warm-stack reminder
	@echo "=== Splunk MCP demo prep ==="
	@echo "Tip: warm the stack before a live meeting — cold 'make up' can take many minutes."
	@echo ""
	@$(MAKE) status
	@echo ""
	@$(MAKE) verify-mcp-remote
	@echo ""
	@echo "Demo prep complete. Restart Cursor/Claude if you refreshed MCP configs."
	@echo "Splunk Web: https://localhost:8000 | MCP: https://localhost:8089/services/mcp"

verify: ## Stack status then Splunk MCP client verify
	@$(MAKE) status
	@$(MAKE) verify-mcp-remote

cloud-bootstrap: ## Cursor Cloud: Docker, ext4, cgroup workaround, override + .env
	@./scripts/cloud-bootstrap.sh $(CLOUD_BOOTSTRAP_ARGS)

s4r-attack-nk-enable: ## Enable NK purchase-attack Eventgen stanza (then: make restart)
	@./scripts/toggle-s4r-attack-nk.sh enable

s4r-attack-nk-disable: ## Disable NK purchase-attack Eventgen stanza (default mode)
	@./scripts/toggle-s4r-attack-nk.sh disable

s4r-attack-nk-status: ## Show whether NK attack Eventgen stanza is enabled
	@./scripts/toggle-s4r-attack-nk.sh status

marp-preview: ## Open S4R slide deck in Marp preview (single file)
	@cd demo-slides && marp --no-stdin -p s4r-demo-slides.md

marp-serve: ## Serve S4R slides over HTTP (open http://localhost:8080/)
	@cd demo-slides && marp --no-stdin -s .

marp-html: ## Export S4R slides to demo-slides/s4r-demo-slides.html
	@cd demo-slides && marp --no-stdin s4r-demo-slides.md -o s4r-demo-slides.html

marp-bizcase-preview: ## Preview Claude Enterprise business case slides
	@cd demo-slides && marp --no-stdin -p claude-enterprise-bizcase-slides.md

marp-bizcase-html: ## Export business case slides to HTML
	@cd demo-slides && marp --no-stdin claude-enterprise-bizcase-slides.md -o claude-enterprise-bizcase-slides.html

marp-bizcase-pdf: ## Export business case slides to PDF
	@cd demo-slides && marp --no-stdin --pdf claude-enterprise-bizcase-slides.md -o claude-enterprise-bizcase-slides.pdf

marp-onepager-pdf: ## Export one-page business case memo to PDF
	@cd demo-slides && marp --no-stdin --pdf claude-enterprise-one-pager.md -o claude-enterprise-one-pager.pdf
