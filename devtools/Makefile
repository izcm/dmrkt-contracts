SHELL := /bin/bash

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
	WETH=0x5f207d42F869fd1c71d7f0f81a2A67Fc20FF7323
else
	include .env
	CHAIN_ID=31337
	WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
endif

-include .env.rpcs

export SOURCE_RPC SEPOLIA_RPC RPC_URL CHAIN_ID RPC_HOST RPC_PORT ORDERS_EXPORT_URL DEPLOYER_PK PARTICIPANT_MNEMONIC

export PIPELINE_STATE_DIR := data/$(CHAIN_ID)/state
export TOKENS_BY_P_IDX_DIR := data/$(CHAIN_ID)/state/cols-mint-per-idx

# output files for tx hashes
export TX_OUT_MINT := data/$(CHAIN_ID)/state/tx_mint.txt
export TX_OUT_APPROVE := data/$(CHAIN_ID)/state/tx_approve.txt
export TX_OUT_WETH_DEPOSIT := data/$(CHAIN_ID)/state/tx_weth_deposit.txt

INITIAL_RUN ?= false

ifeq ($(MODE), sepolia)
# if its the initial run -> set idx to 0 and size to max _size
# this executes all bootstrap steps for all participants until MAX_P_SZE
# -> future runs only have to build + execute orders
	ifeq ($(INITIAL_RUN), true)
		P_IDX_START=0
		P_SIZE=100
		MAX_P_SIZE=100
	else
		P_IDX_START=5
		P_SIZE=4
		MAX_P_SIZE=30
	endif
else
# use these for anvil mode 	
	P_IDX_START=0
	P_SIZE=10
	MAX_P_SIZE=10
endif

# if MAX is set to any value !== P_SIZE
# it is your responsibility to fund the users P_SIZE..MAX_P_SIZE
export P_IDX_START P_SIZE MAX_P_SIZE

# epoch defs
EPOCH_COUNT = 1

# realtime ctx (execute-realtime target)
REALTIME_TIME_WINDOW  = 15552000 # 180 days, in seconds
REALTIME_EXEC_RATE    = 100      # % of built orders to execute
REALTIME_NONCE_SEED   = $(shell date +%s)

# strip-participants: transfer all eth from participants to STRIP_DEST_ADDR  
STRIP_DEST_ADDR=0x3e34BC287907E257e5BdbB909684ab3F52708f42

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
execute-realtime: print-participants-simple
	@echo "🔢 Finding block number and timestamps..."
	@./$(RUNNERS_FORK)/pipeline-window.sh --realtime $(REALTIME_TIME_WINDOW)
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

fund-approve-prepare: fund-weth approve prepare

start: prepare fork pipeline-setup ## Compute window, start fork, deploy, and bootstrap
	@echo "🚀 Dev environment ready"

reset: kill-anvil start ## Kill anvil and restart from scratch
	@echo "🔄 Dev reset complete"

pipeline-setup: deploy-core print-participants fund-weth bootstrap-nfts
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
	@./$(RUNNERS_FORK)/pipeline-window.sh --replay 2419200

# ───────────────────────────────────────────────
#   SETUP / GENESIS
# ───────────────────────────────────────────────

print-participants: ## Print pipeline participants
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "PARTICIPANTS"
	@echo "───────────────────────────────────────────────"
	@echo ""
	@./$(RUNNERS)/print-participants.sh $(P_SIZE) --start-idx $(P_IDX_START)

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

bootstrap-nfts: select-nfts ## Mint tokens per participant from the JSON selection
	@./$(RUNNERS)/bootstrap/bootstrap-nfts.sh $(P_SIZE) $(TOKENS_BY_P_IDX_DIR) --idx-start $(P_IDX_START) --out-file $(TX_OUT_MINT)
	@./$(RUNNERS)/wait-for-receipts.sh $(TX_OUT_MINT)

fund-weth: ## Wrap ETH into WETH for all participants
	@echo ""
	@echo "💰 Funding WETH..."
	@echo ""
	@./$(RUNNERS)/bootstrap/wrap-weth.sh $(P_SIZE) --token $(WETH) --start-idx $(P_IDX_START) --out-file $(TX_OUT_WETH_DEPOSIT)
	@./$(RUNNERS)/wait-for-receipts.sh $(TX_OUT_WETH_DEPOSIT)

select-nfts: ## Compute deterministic token-to-participant selection for each NFT collection
	@echo ""
	@echo "🎲 Selecting NFTs..."
	@echo ""
	@forge script $(BOOTSTRAP)/SelectNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   APPROVALS
# ───────────────────────────────────────────────

approve: ## Grant NFT + WETH allowances to OrderEngine
	@echo ""
	@echo "───────────────────────────────────────────────"
	@echo "APPROVALS"
	@echo "───────────────────────────────────────────────"
	@echo ""
	@echo "✔ Executing approvals..."
	@echo ""
	@source $(PIPELINE_STATE_DIR)/pipeline.env && \
	./$(RUNNERS)/bootstrap/approvals.sh $(P_SIZE) --start-idx $(P_IDX_START) \
		--nft-transfer-auth "$$ORDER_ENGINE" --token "$$WETH" --spender "$$ORDER_ENGINE" --collections "$$NFT_C_0" \
		--out-file $(TX_OUT_APPROVE)
	@./$(RUNNERS)/wait-for-receipts.sh $(TX_OUT_APPROVE)


# ───────────────────────────────────────────────
#   FUNDING
# ───────────────────────────────────────────────

# primarily for testnets
distribute-eth:
	./runners/funding/distribute-eth.sh $(P_SIZE) \
		--start-idx $(P_IDX_START) \

strip-participants:
	./runners/funding/strip-eth.sh $(P_SIZE) $(STRIP_DEST_ADDR) \
		--rpc-url $(RPC_URL) \
		--start-idx $(P_IDX_START)

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

WETH=$(MAINNET_WETH)

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

START := $(P_IDX_START)
COUNT := $(P_SIZE)

print-participants-simple:
	@seq $(START) $$(( $(START) + $(COUNT) - 1 )) | \
	xargs -I{} cast wallet address \
		--mnemonic $(PARTICIPANT_MNEMONIC) \
		--mnemonic-index {}

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

