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

DEVTOOLS_ROOT   := devtools
SEED            := $(DEVTOOLS_ROOT)/seed
SEED_BOOTSTRAP  := $(SEED)/bootstrap
PIPELINES       := $(DEVTOOLS_ROOT)/pipelines
ARTIFACTS       := $(DEVTOOLS_ROOT)/artifacts

export ARTIFACTS_FORK := $(ARTIFACTS)/fork
export ARTIFACTS_RUNNERS := $(ARTIFACTS)/runners
export ARTIFACTS_EXPORTERS := $(ARTIFACTS)/exporters
export PIPELINES_EPOCHS := $(PIPELINES)/epochs
export PIPELINES_EXECUTION := $(PIPELINES)/execution

export PIPELINE_STATE_DIR := $(PROJECT_ROOT)/data/31337/state

# chain
WETH := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

# ───────────────────────────────────────────────
#   LOGGING / VERBOSITY
# ───────────────────────────────────────────────

SILENT ?= 1
EPOCH_COUNT ?= 4

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
else
FORGE_SILENT =
endif

# ───────────────────────────────────────────────
#   FORGE FLAGS (NO PK HERE ✅)
# ───────────────────────────────────────────────

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	$(FORGE_SILENT)

# ───────────────────────────────────────────────
#   DEV — DOCKER ENTRYPOINTS
# ───────────────────────────────────────────────

dev-execute-pipeline: dev-wait pipeline-setup pipeline-separator dev-run-epochs
	@echo "🚀 Dev environment ready"

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
	@echo "🔄 Dev reset complete"

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
	@./$(ARTIFACTS_FORK)/start-fork.sh

dev-prepare:
	@echo "🔢 Finding block number and timestamps..."
	@node ./$(ARTIFACTS_FORK)/prepare-fork.js 2419200

# ───────────────────────────────────────────────
#   DEV — SETUP / GENESIS
# ───────────────────────────────────────────────

dev-bootstrap-accounts:
	@echo "💻 Bootstrapping dev accounts..."
	@forge script $(SEED_BOOTSTRAP)/BootstrapAccounts.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-deploy-core:
	@echo "🧾 Deploying core contracts..."
	@forge script $(SEED)/DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-bootstrap-nfts:
	@echo "👾 Bootstrapping NFTs..."
	@forge script $(SEED_BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-approve:
	@echo "✔ Executing approvals..."
	@forge script $(SEED_BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   DEV — STATE / SCENARIOS
# ───────────────────────────────────────────────

dev-run-epochs:
	@echo "📊 Building historical orders..."
	@./$(ARTIFACTS_RUNNERS)/run-epochs.sh $(EPOCH_COUNT)

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
		echo "❌ Missing COL or ID. Usage: make token-owner COL=0xCollectionAddr ID=TokenId"; \
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

chmod-scripts:
	@find script -type f -name "*.sh" -exec chmod +x {} +

tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=3; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"