# ───────────────────────────────────────────────
#   Marketplace Engines — DEV PIPELINE
# ───────────────────────────────────────────────

include .env
export 

# ───────────────────────────────────────────────
#   ROOTS
# ───────────────────────────────────────────────

PROJECT_ROOT := $(shell pwd)
export PROJECT_ROOT

# paths - scripts

SCRIPT_ROOT := script
DEV_ROOT    := $(SCRIPT_ROOT)/dev

# dev subtrees
DEV_BASE        := $(DEV_ROOT)
DEV_SETUP       := $(DEV_ROOT)/genesis
DEV_BOOTSTRAP   := $(DEV_SETUP)/bootstrap
DEV_LOGIC       := $(DEV_ROOT)/logic

export DEV_STATE       := $(DEV_ROOT)/state

# paths - artifacts

export PIPELINE_STATE_DIR := $(PROJECT_ROOT)/data/31337/state

# chain
WETH    := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

# ───────────────────────────────────────────────
#   LOGGING / VERBOSITY
# ───────────────────────────────────────────────

# set SILENT=0 to enable forge output
SILENT ?= 1
EPOCH_COUNT ?= 4

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
else
FORGE_SILENT =
endif

# ───────────────────────────────────────────────
#   FORGE COMMON FLAGS
# ───────────────────────────────────────────────

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	--sender $(FUNDER) \
	--private-key $(FUNDER_PK) \
	$(FORGE_SILENT)

# ───────────────────────────────────────────────
#   DEV — DOCKER ENTRYPOINTS
# ───────────────────────────────────────────────

# assumes pipeline.toml contains:
#	1. weth address
# 	2. pipeline end + start timestamps
dev-execute-pipeline: dev-wait pipeline-setup pipeline-separator dev-run-epochs
	@echo "🚀 Dev environment ready"

# temporarily to wait for anvil
dev-wait:
	@echo "----------------"
	@echo " GETTING READY "
	@echo "----------------"
	@forge clean
	@sleep 4

pipeline-separator:
	@echo ""
	@echo "================="
	@echo " PHASE COMPLETE "
	@echo "================="
	@echo ""

# ───────────────────────────────────────────────
#   DEV — HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

dev-start: dev-prepare dev-fork pipeline-setup
	@echo "🚀 Dev environment ready"

dev-reset: kill-anvil dev-start
	@echo "🔄 Dev reset complete"---------

pipeline-setup: \
	dev-deploy-core \
	dev-bootstrap-accounts \
	dev-bootstrap-nfts \
	dev-approve
	@echo "🧱 Setup pipeline complete"

# ───────────────────────────────────────────────
#   DEV — ENVIRONMENT BOOT
# ───────────────────────────────────────────────

dev-fork:
	@echo "🧬 Starting anvil fork..."
	@./$(DEV_ROOT)/start-fork.sh

# local just defaults to 4 weeks = 2419200
dev-prepare: 
	@echo "🔢 Finding block number and timestamps..."
	@node ./$(DEV_ROOT)/prepare-fork.js 2419200

# ───────────────────────────────────────────────
#   DEV — SETUP / GENESIS
# ───────────────────────────────────────────────

dev-bootstrap-accounts:
	@echo "💻 Bootstrapping dev accounts..."
	@forge script $(DEV_BOOTSTRAP)/BootstrapAccounts.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-deploy-core:
	@echo "🧾 Deploying core contracts..."
	@forge script $(DEV_SETUP)/DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-bootstrap-nfts:
	@echo "👾 Bootstrapping NFTs..."
	@forge script $(DEV_BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-approve:
	@echo "✔ Executing approvals..."
	@forge script $(DEV_BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   DEV — STATE / SCENARIOS
# ───────────────────────────────────────────────

dev-run-epochs: 
	@echo "📊 Building historical orders..."
	@./$(DEV_STATE)/run-epochs.sh $(EPOCH_COUNT)

# ───────────────────────────────────────────────
#   RESET / PROCESS CONTROL
# ───────────────────────────────────────────────

kill-anvil:
	@echo "💀 Killing anvil..."
	pkill anvil 2>/dev/null || true

# ───────────────────────────────────────────────
#   CHAIN READ HELPERS
# ───────────────────────────────────────────────

weth-balance:
	@if [ -z "$(ADDR)" ]; then \
		echo "❌ Missing ADDR. Usage: make weth-balance ADDR=0xYourAddress"; \
		exit 1; \
	fi
	@echo "WETH balance for $(ADDR):"
	@cast call \
		$(WETH) \
		"balanceOf(address)" \
		$(ADDR) \
		--rpc-url $(RPC_URL) | cast from-wei

token-owner:
	@if [ -z "$(COL)" ] || [ -z "$(ID)" ]; then \
		echo "❌ Missing COL or ADDR. Usage: make weth-balance COL=0xCollectionAddr ID=TokenId"; \
		exit 1; \
	fi
	@cast call \
		$(COL) \
		"ownerOf(uint256)" \
		$(ID) \
		--rpc-url $(RPC_URL) 

# ───────────────────────────────────────────────
#   MISC
# ───────────────────────────────────────────────

tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=3; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"
