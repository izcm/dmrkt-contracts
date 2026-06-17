# ───────────────────────────────────────────────
#   Marketplace Engines — DEV PIPELINE
# ───────────────────────────────────────────────

include .env
export

# ───────────────────────────────────────────────
#   ROOTS
# ───────────────────────────────────────────────

BOOTSTRAP       := bootstrap
PIPELINES       := pipelines
RUNNERS         := runners

export RUNNERS_FORK        := $(RUNNERS)/fork
export RUNNERS_EXPORTERS   := $(RUNNERS)/exporters
export PIPELINES_EPOCHS    := $(PIPELINES)/epochs
export PIPELINES_EXECUTION := $(PIPELINES)/execution

export PIPELINE_STATE_DIR := data/31337/state
export MNEMONIC_JSON      := data/31337/mnemonic.json
export TOML               := pipeline.toml


# epoch defs
EPOCH_COUNT ?= 4

# ───────────────────────────────────────────────
#   LOGGING / VERBOSITY
# ───────────────────────────────────────────────

SILENT ?= 0

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
endif

# ───────────────────────────────────────────────
#   FORGE FLAGS
# ───────────────────────────────────────────────

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	$(FORGE_SILENT)

# ───────────────────────────────────────────────
#   ETC. FLAGS
# ───────────────────────────────────────────────

EXPORT ?= 0

ifeq ($(EXPORT), 1)
EXPORT_FLAG = --export
endif

# ───────────────────────────────────────────────
#   RESERVED FOR DMRKT-COMPOSE
# ───────────────────────────────────────────────

# This entrypoint is used by another repo that has its own fork prepare pipeline
compose-entrypoint: EXPORT_FLAG = --export
compose-entrypoint: wait pipeline-setup pipeline-separator run-epochs ## Docker Compose entrypoint — assumes fork + pipeline.toml are provided externally
	
# ───────────────────────────────────────────────
#   ENTRYPOINT
# ───────────────────────────────────────────────

execute-pipeline: start pipeline-separator run-epochs ## Run the full pipeline
	@echo "🚀 Dev environment ready"

wait:
	@forge clean
	@sleep 4

pipeline-separator:
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "CORE SETUP COMPLETE — SIMULATE MARKET HISTORY"
	@echo "───────────────────────────────────────────────"
	@echo ""

# ───────────────────────────────────────────────
#   HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

start: prepare fork pipeline-setup ## Compute window, start fork, deploy, and bootstrap
	@echo "🚀 Dev environment ready"

reset: kill-anvil start ## Kill anvil and restart from scratch
	@echo "🔄 Dev reset complete"

pipeline-setup: \
	deploy-core \
	print-participants \
	bootstrap-funds \
	bootstrap-nfts \
	approve
	@echo "✅ Core deployed and participants bootstrapped"

# ───────────────────────────────────────────────
#   ENVIRONMENT BOOT
# ───────────────────────────────────────────────

fork: ## Start the anvil fork
	@echo "🧬 Starting anvil fork..."
	@./$(RUNNERS_FORK)/start-fork.sh

prepare: ## Compute fork start block and pipeline window timestamps
	@echo "🔢 Finding block number and timestamps..."
	@./$(RUNNERS_FORK)/pipeline-window.sh 2419200

# ───────────────────────────────────────────────
#   SETUP / GENESIS
# ───────────────────────────────────────────────

print-participants: ## Print pipeline participants
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "BOOTSTRAP"
	@echo "───────────────────────────────────────────────"
	@echo ""
	@echo "⚙️ Start bootstrap sequence..."
	@echo ""
	@forge script $(BOOTSTRAP)/PrintParticipants.s.sol \
		--rpc-url $(RPC_URL)

bootstrap-funds: ## Wrap ETH into WETH for all participants
	@echo ""
	@echo "💰 Funding WETH..."
	@echo ""
	@forge script $(BOOTSTRAP)/BootstrapFunds.s.sol \
		$(FORGE_COMMON_FLAGS)

deploy-core: ## Deploy OrderEngine + NFT collections, write addresses to pipeline.toml
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "DEPLOY"
	@echo "───────────────────────────────────────────────"
	@echo ""
	@echo "🧾 Deploying core contracts..."
	@echo ""
	@forge script DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

bootstrap-nfts: FORGE_SILENT =
bootstrap-nfts: ## Mint NFTs to all participants
	@echo ""
	@echo "👾 Minting NFTs..."
	@echo ""
	@forge script $(BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

approve: ## Grant NFT + WETH allowances to OrderEngine
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "APPROVALS"
	@echo "───────────────────────────────────────────────"
	@echo ""
	@echo "✔ Executing approvals..."
	@echo ""
	@forge script $(BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   STATE / SCENARIOS
# ───────────────────────────────────────────────

run-epochs: ## Generate, sign, export, and settle orders across all epochs
	@echo ""
	@echo "📊 Building historical orders..."
	@echo ""
	@./$(RUNNERS)/run-epochs.sh $(EPOCH_COUNT) $(EXPORT_FLAG)

# ───────────────────────────────────────────────
#   RESET / PROCESS CONTROL
# ───────────────────────────────────────────────

kill-anvil: ## Kill the running anvil process
	@echo "💀 Killing anvil..."
	pkill anvil 2>/dev/null || true

# ───────────────────────────────────────────────
#   CHAIN READ HELPERS
# ───────────────────────────────────────────────

# chain
WETH := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

weth-balance: ## Read WETH balance for an address  (ADDR=0x...)
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

token-owner: ## Read token owner  (COL=0x... ID=N)
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
	@find . -type f -name "*.sh" -exec chmod +x {} +

help: ## List available targets
	@awk 'BEGIN {FS=":.*##"; printf "\n%-22s %s\n\n","target","description"} \
	/^[a-zA-Z_-]+:.*?##/ {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}' \
	$(MAKEFILE_LIST)

tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=3; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"
