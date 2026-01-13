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

SCRIPT_ROOT := script
DEV_ROOT    := $(SCRIPT_ROOT)/dev

# dev subtrees
DEV_BASE        := $(DEV_ROOT)
DEV_SETUP       := $(DEV_ROOT)/genesis
DEV_BOOTSTRAP   := $(DEV_SETUP)/bootstrap
DEV_LOGIC       := $(DEV_ROOT)/logic

export DEV_STATE       := $(DEV_ROOT)/state

# entrypoints
DEPLOY_ORDER_ENGINE := $(SCRIPT_ROOT)/DeployOrderEngine.s.sol

# chain
WETH    := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

# args
EPOCH_COUNT = 4
EPOCH_SIZE = 604800 # seconds (7 days)
SECONDS_AGO = $(shell expr $(EPOCH_COUNT) \* $(EPOCH_SIZE))

# ───────────────────────────────────────────────
#   LOGGING / VERBOSITY
# ───────────────────────────────────────────────

# set SILENT=0 to enable forge output
SILENT ?= 1

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
#   DEV — HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

dev-start: dev-fork pipeline-setup
	@echo "🚀 Dev environment ready"

dev-reset: kill-anvil dev-start
	@echo "🔄 Dev reset complete"

pipeline-setup: \
	dev-bootstrap-accounts \
	dev-deploy-core \
	dev-bootstrap-nfts \
	dev-approve
	@echo "🧱 Setup pipeline complete"

pipeline-state: dev-build-epochs
	@echo "🎭 State pipelines complete"

# ───────────────────────────────────────────────
#   DEV — ENVIRONMENT BOOT
# ───────────────────────────────────────────────

dev-fork:dev-prepare
	@echo "🧬 Starting anvil fork..."
	@./$(DEV_ROOT)/start.sh

dev-prepare: 
	@echo "🔢 Finding block number and timestamps..."
	@node ./$(DEV_ROOT)/prepare-fork.js $(SECONDS_AGO)

# ───────────────────────────────────────────────
#   DEV — SETUP / GENESIS
# ───────────────────────────────────────────────

dev-bootstrap-accounts:
	@echo "💻 Bootstrapping dev accounts..."
	forge script $(DEV_BOOTSTRAP)/BootstrapAccounts.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-deploy-core:
	@echo "🧾 Deploying core contracts..."
	forge script $(DEV_SETUP)/DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-bootstrap-nfts:
	@echo "👾 Bootstrapping NFTs..."
	forge script $(DEV_BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-approve:
	@echo "✔ Executing approvals..."
	forge script $(DEV_BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   DEV — STATE / SCENARIOS
# ───────────────────────────────────────────────

dev-history: 
	@echo "📊 Building historical orders..."
	@./$(DEV_STATE)/start-history.sh $(EPOCH_COUNT) $(EPOCH_SIZE)

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
