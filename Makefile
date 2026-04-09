SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

DC ?= docker compose
TOKEN_FILE ?= .secrets/splunk-token
ENV_FILE ?= tpl.env
ENV_OUT ?= .env
OP ?= op

# Local env template: copy from repo example once, then edit op:// paths (see README).
ENV_EXAMPLE ?= tpl.env.example

# Secrets-backed Compose: only needed when interpolating $(ENV_FILE) / .env into the stack (make up).
# Usage: $(call DC_CMD,<compose args>)
define DC_CMD
	@if [[ -f "$(ENV_OUT)" ]]; then \
		$(DC) $(1); \
	else \
		command -v "$(OP)" >/dev/null 2>&1 || { \
			echo "Error: $(ENV_OUT) not found and 1Password CLI (op) not available."; \
			echo "Either create $(ENV_FILE) (cp $(ENV_EXAMPLE) $(ENV_FILE)), run 'make init' to write $(ENV_OUT), or install/authenticate 1Password CLI."; \
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

.PHONY: help init check-env-for-up up wait-token down clean logs claude-update goose-update cursor-mcp verify-mcp-remote status status-exec-check restart lint-md lint-md-fix

help:
	@echo "Splunk MCP Server - PoC Environment"
	@echo ""
	@echo "Available targets:"
	@echo "  make up             - Start Splunk; wait for token; run claude-update (Cursor/Goose: see make cursor-mcp / goose-update)"
	@echo "                       (needs secrets: $(ENV_OUT) or op + $(ENV_FILE); see below)"
	@echo "  make init           - [optional] Write $(ENV_OUT) from $(ENV_FILE) (op run + scripts/materialize-env.sh)"
	@echo "  make init FORCE=1   - Re-generate $(ENV_OUT)"
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
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
		echo "Error: $(ENV_FILE) not found. Create it from the tracked example:"; \
		echo "  cp $(ENV_EXAMPLE) $(ENV_FILE)"; \
		echo "Then set your op://vault/item/field paths in $(ENV_FILE)."; \
		exit 1; \
	fi
	@if [[ -f "$(ENV_OUT)" && "${FORCE:-0}" != "1" ]]; then \
		echo "$(ENV_OUT) already exists; skipping (set FORCE=1 to re-generate)."; \
		exit 0; \
	fi
	@echo "Materializing $(ENV_OUT) via op run + scripts/materialize-env.sh (same op:// resolution as make up)..."
	@command -v "$(OP)" >/dev/null 2>&1 || { echo "Error: 1Password CLI (op) not found. Install it or create $(ENV_OUT) manually."; exit 1; }
	@"$(OP)" run --env-file="$(ENV_FILE)" -- ./scripts/materialize-env.sh "$(ENV_OUT)"
	@echo "Environment initialized: $(ENV_OUT) written."

# Ensures Splunk will receive real secrets at create time (avoids empty SPLUNKBASE_* / ansible failure).
check-env-for-up:
	@if [[ -f "$(ENV_OUT)" ]]; then \
		echo "Using $(ENV_OUT) for Compose (verify SPLUNK_* and SPLUNKBASE_* are set)."; \
	else \
		if [[ ! -f "$(ENV_FILE)" ]]; then \
			echo "Error: $(ENV_OUT) not found and $(ENV_FILE) missing."; \
			echo "Copy the example and edit op:// paths, then retry:"; \
			echo "  cp $(ENV_EXAMPLE) $(ENV_FILE)"; \
			exit 1; \
		fi; \
		command -v "$(OP)" >/dev/null 2>&1 || { \
			echo "Error: $(ENV_OUT) not found and 1Password CLI (op) not available."; \
			echo "Create $(ENV_OUT) (e.g. make init) or install/sign in to op before make up."; \
			exit 1; \
		}; \
		"$(OP)" run --env-file="$(ENV_FILE)" -- sh -c ' \
			if [ -z "$$SPLUNK_PASSWORD" ] || [ -z "$$SPLUNKBASE_USER" ] || [ -z "$$SPLUNKBASE_PASS" ]; then \
				echo "Error: SPLUNK_PASSWORD, SPLUNKBASE_USER, and SPLUNKBASE_PASS must be non-empty after op run."; \
				echo "Fix op:// paths in $(ENV_FILE) (item names with spaces must match exactly). Test with: op read \"op://...\""; \
				echo "Do not start the stack with plain docker compose up without these env vars."; \
				exit 1; \
			fi'; \
	fi

up: check-env-for-up
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

# Use docker logs (not docker compose logs) so missing host .env does not print misleading
# "variable is not set" warnings; credentials are only needed at container create (make up).
logs:
	@docker logs -f so1 2>&1 || { echo "Hint: container so1 not found. Is the stack up? Try: make up"; exit 1; }

# Used by status: avoid compose exec without env (same as logs).
# Splunk answers /services/server/info with 401 when unauthenticated (no serverName in body); 200 with auth. Both mean the mgmt API is up.
status-exec-check:
	@code="$$(docker exec so1 curl -k -s -o /dev/null -w "%{http_code}" https://localhost:8089/services/server/info 2>/dev/null)"; \
	[ "$$code" = "200" ] || [ "$$code" = "401" ]

status:
	@echo "Checking Splunk container status..."
	@docker ps -a --filter "name=so1" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || true
	@docker ps -a --filter "name=splunk-init" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null || true
	@echo ""
	@echo "splunk-init Exited (0) is normal: one-time setup finished."
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
