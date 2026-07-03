# ───────────────────────────────────────────────
#   ROOTS
# ───────────────────────────────────────────────

BOOTSTRAP       := bootstrap
PIPELINES       := pipelines
RUNNERS         := runners

export RUNNERS_FORK        := $(RUNNERS)/fork
export RUNNERS_EXPORTERS   := $(RUNNERS)/exporters
export PIPELINE_EPOCHS    := $(PIPELINES)/epochs
export PIPELINE_EXECUTION := $(PIPELINES)/execution

export TOML               := pipeline.toml

# ───────────────────────────────────────────────
#   PIPELINE CONTEXT
# ───────────────────────────────────────────────

MODE ?= anvil

# EPOCH_COUNT is 1 since when simulating on sepolia
# (since we aren't replaying past like on a local anvil fork)
ifeq ($(MODE), sepolia)
	include .env.sepolia
	EPOCH_COUNT=1
	CHAIN_ID=11155111
else
	include .env
	CHAIN_ID=31337
endif

-include .env.rpcs

export PIPELINE_STATE_DIR := data/$(CHAIN_ID)/state

export

EPOCH_COUNT = 1
export PARTICIPANT_IDX_START=0
export PARTICIPANT_SIZE=5
# if MAX is set to any value !== PARTICIPANT_SIZE
# it is your responsibility to fund the users P_SIZE..MAX_P_SIZE
export MAX_PARTICIPANT_SIZE=5

# realtime ctx (execute-realtime target)
REALTIME_TIME_WINDOW  = 7776000 # 90 days, in seconds
REALTIME_END_OFFSET   = 5184000 # 60 days from now, in seconds
REALTIME_EXEC_RATE    = 10      # % of built orders to execute
REALTIME_NONCE_SEED   = $(shell data +%s)


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
#   ENTRYPOINTSs
# ───────────────────────────────────────────────

# time warping (RPC_URL must point to a local fork)
execute-pipeline: start pipeline-separator run-epochs ## Run the full pipeline
	@echo "🚀 Dev environment ready"

# only time-window and build + execute orders (testnets)
# timeWindow is 3 months with end_ts set to 60 days from time of writing
execute-realtime: print-participants
	@echo "🔢 Finding block number and timestamps..."
	@./$(RUNNERS_FORK)/pipeline-window.sh $(REALTIME_TIME_WINDOW) $$(($$(date +%s) + $(REALTIME_END_OFFSET)))
	@echo "🌀 Running realtime simulation"
	@./runners/run-realtime.sh $(REALTIME_EXEC_RATE) $(REALTIME_NONCE_SEED) --export

# ───────────────────────────────────────────────
#   SEMANTIC HELPERS
# ───────────────────────────────────────────────

wait:
	@forge clean
	@sleep 4

pipeline-separator:
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "SIMULATE MARKET ACTIVITY"
	@echo "───────────────────────────────────────────────"
	@echo ""

# ───────────────────────────────────────────────
#   HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

start: prepare fork pipeline-setup ## Compute window, start fork, deploy, and bootstrap
	@echo "🚀 Dev environment ready"

reset: kill-anvil start ## Kill anvil and restart from scratch
	@echo "🔄 Dev reset complete"

pipeline-setup: deploy-core print-participants bootstrap-funds bootstrap-nfts
	@echo "✅ Core deployed and participants bootstrapped"
	$(MAKE) approve
	@echo "✅ OrderEngine fully authorized"

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
	@echo "PARTICIPANTS"
	@echo "───────────────────────────────────────────────"
	@echo ""
	@forge script $(BOOTSTRAP)/PrintParticipants.s.sol \
		--rpc-url $(RPC_URL)

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

bootstrap-funds: ## Wrap ETH into WETH for all participants
	@echo ""
	@echo "💰 Funding WETH..."
	@echo ""
	@forge script $(BOOTSTRAP)/BootstrapFunds.s.sol \
		$(FORGE_COMMON_FLAGS)


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

# for testnets 
distribute-eth: 
	./bootstrap/distribute-eth.sh 5 5000000000000000000

# ───────────────────────────────────────────────
#   STATE / SCENARIOS
# ───────────────────────────────────────────────

run-epochs: ## Generate, sign, export, and settle orders across all epochs
	@echo ""
	@echo "📊 Building orders..."
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
MAINNET_WETH := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
SEPOLIA_WETH := 0x5f207d42F869fd1c71d7f0f81a2A67Fc20FF7323

WETH=SEPOLIA_WETH

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
