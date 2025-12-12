# ───────────────────────────────────────────────
#   Marketplace Engines Makefile 
# ───────────────────────────────────────────────

# Variables
include .env

# paths
DEPLOY_ORDER_ENGINE = script/DeployOrderEngine.s.sol
PATH_DEV_SETUP = script/setup-fork
PATH_FORK_SETUP_SCRIPTS = script/setup-fork

# ───────────────────────────────────────────────
#   Deploy 
# ───────────────────────────────────────────────
dev-fork:
	@echo "🧬 Starting anvil fork..."
	@cd script/setup-dev && bash start.sh

dev-setup-script:dev-fork
	@echo "💻 Running DEV Setup Script..." && \
	forge script script/setup-dev/Setup.s.sol \
		--rpc-url http://127.0.0.1:8545 \
		--broadcast \
		--sender $(ANVIL_SENDER) \
		--private-key $(ANVIL_PK)

	

