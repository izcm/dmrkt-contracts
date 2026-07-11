SHELL := /bin/bash

# ───────────────────────────────────────────────
#   ROOTS
# ───────────────────────────────────────────────

BOOTSTRAP       := bootstrap
PIPELINES       := pipelines
RUNNERS         := runners

export RUNNERS_FORK        := $(RUNNERS)/fork
export RUNNERS_EXPORTERS   := $(RUNNERS)/orders
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
	CHAIN_ID=11155111
	WETH=0x5f207d42F869fd1c71d7f0f81a2A67Fc20FF7323
	EPOCH_COUNT = 1
else
	include .env
	CHAIN_ID=31337
	WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
	EPOCH_COUNT = 1
endif

-include .env.rpcs

PARTICIPANT_MNEMONIC := $(subst ",,$(PARTICIPANT_MNEMONIC))

export SOURCE_RPC SEPOLIA_RPC RPC_URL CHAIN_ID RPC_HOST RPC_PORT ORDERS_EXPORT_URL DEPLOYER_PK PARTICIPANT_MNEMONIC

export PIPELINE_STATE_DIR := data/$(CHAIN_ID)/state
export TOKENS_BY_P_IDX_DIR := data/$(CHAIN_ID)/state/cols-mint-per-idx

# output files for tx hashes
export TX_OUT_DIR = data/$(CHAIN_ID)/state/tx-out

APPROVALS_ROUND=false # if approvals round -> include all participants

ifeq ($(MODE), sepolia)

# GROUP_IDX selects which P_SIZE-sized group to rotate out of: 0 rotates
# group 0 -> group 1, 1 rotates group 1 -> group 2, etc. Bump this alone to
# advance rotate-weth to the next pair of groups.
GROUP_IDX ?= 0 # this should not be larger than p_size / p_max_size

# if its the initial run -> set idx to 0 and size to max _size
# this executes all bootstrap steps for all participants until MAX_P_SZE
# note that MAX_P_SIZE represents the POSSIBLE NFT HOLDERS do not make it smaller
# than the pool of previous buyers / minters unless u know what ure doing

# -> future runs only have to build + execute orders
ifeq ($(MODE)-$(APPROVALS_ROUND), sepolia-true)
	P_IDX_START=0
	P_SIZE=100
	MAX_P_SIZE=100
else
	P_IDX_START=25
	P_SIZE=25
	MAX_P_SIZE=50
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

# realtime ctx (execute-realtime target)
REALTIME_TIME_WINDOW  = 15552000 # 180 days, in seconds
REALTIME_EXEC_RATE    = 100      # % of built orders to execute
REALTIME_NONCE_SEED   = $(shell date +%s) # non-static since realtime wants new dataset

FUNDER_IDX=0 # strip receiver / distributor of eth and erc20 tokens

TX_MANAGER_TIMESPAN=600

# ───────────────────────────────────────────────
#   FLAGS
# ───────────────────────────────────────────────

SILENT ?= 0

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
endif

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	$(FORGE_SILENT)

EXPORT ?= 0

ifeq ($(EXPORT), 1)
EXPORT_FLAG = --export
endif

# ───────────────────────────────────────────────
#   RESERVED FOR DMRKT-COMPOSE
# ───────────────────────────────────────────────

# This entrypoint is used by another repo that has its own fork prepare pipeline
# compose-entrypoint: EXPORT_FLAG = --export
compose-entrypoint: wait pipeline-setup run-epochs ## Docker Compose entrypoint — assumes fork + pipeline.toml are provided externally

wait:
	@forge clean
	@sleep 4

# ───────────────────────────────────────────────
#   ENTRYPOINTSs
# ───────────────────────────────────────────────

# time warping (RPC_URL must point to a local fork)
execute-pipeline: start pipeline-setup approve run-epochs ## Run the full pipeline
	@echo "🚀 Dev environment ready"

run-epochs: ## Generate, sign, export, and settle orders across all epochs
	@echo "📊 Building orders..."
	@./$(RUNNERS)/run-epochs.sh $(EPOCH_COUNT) $(EXPORT_FLAG)

# only time-window and build + execute orders (testnets)
# timeWindow is 3 months with end_ts set to 60 days from time of writing
execute-realtime: print-participants
	@echo "🔢 Finding block number and timestamps..."
	@./$(RUNNERS_FORK)/pipeline-window.sh --realtime $(REALTIME_TIME_WINDOW)
	@echo "🌀 Running realtime simulation"
	@./runners/run-realtime.sh $(REALTIME_EXEC_RATE) $(REALTIME_NONCE_SEED) --export

rotate-all-weth:
	@for i in $$(seq 0 $$(($(MAX_P_SIZE) / $(P_SIZE) - 1))); do \
		echo "── rotating group $$i ──"; \
		$(MAKE) rotate-weth GROUP_IDX=$$i; \
	done

# ───────────────────────────────────────────────
#   HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

start: prepare fork ## Compute window, start fork
	@echo "🚀 Dev environment ready"

reset: kill-anvil start ## Kill anvil and restart from scratch
	@echo "🔄 Dev reset complete"

pipeline-setup: deploy-core print-participants wrap-weth bootstrap-nfts
	@echo "✅ Core deployed and participants bootstrapped"
	$(MAKE) approve
	@echo "✅ OrderEngine fully authorized"

# ───────────────────────────────────────────────
#   FORK PREPARE & START
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

deploy-core: ## Deploy OrderEngine + NFT collections, write addresses to pipeline.toml
	@echo "🧾 Deploying core contracts..."
	@forge script DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   ETH FUNDING
# ───────────────────────────────────────────────

distribute-eth:
	@echo "Distributing eth..."
	@TX_FILE=$(TX_OUT_DIR)/distribute-eth.json && \
	./$(RUNNERS)/funding/distribute-eth.sh $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $$(($(P_IDX_START) + $(GROUP_IDX) * $(P_SIZE))) && \
	npx tsx ./$(RUNNERS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

strip-eth:
	@echo "Stripping eth..."
	@TX_FILE=$(TX_OUT_DIR)/strip-eth.json && \
	./$(RUNNERS)/funding/strip-eth.sh $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $$(($(P_IDX_START) + $(GROUP_IDX) * $(P_SIZE))) && \
	npx tsx ./$(RUNNERS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

rotate-eth:
	@$(MAKE) strip-eth
	@$(MAKE) distribute-eth GROUP_IDX=$$(($(GROUP_IDX)+1))

# ───────────────────────────────────────────────
#   ERC20 FUNDING
# ───────────────────────────────────────────────

wrap-weth: ## Wrap ETH into WETH for all participants
	@echo "💰 Wrapping WETH..."
	@TX_FILE=$(TX_OUT_DIR)/wrap-weth.json && \
	./$(RUNNERS)/bootstrap/wrap-weth.sh $(WETH) $(P_SIZE) $$TX_FILE --start-idx $(P_IDX_START) && \
	npx tsx ./$(RUNNERS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

distribute-weth:
	@echo "Distributing weth..."
	@TX_FILE=$(TX_OUT_DIR)/distribute-weth.json && \
	./$(RUNNERS)/funding/erc20/distribute-erc20.sh $(WETH) $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $$(($(P_IDX_START) + $(GROUP_IDX) * $(P_SIZE))) && \
	npx tsx ./$(RUNNERS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

strip-weth:
	@echo "Stripping weth..."
	@TX_FILE=$(TX_OUT_DIR)/strip-weth.json && \
	./$(RUNNERS)/funding/erc20/strip-erc20.sh $(WETH) $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $$(($(P_IDX_START) + $(GROUP_IDX) * $(P_SIZE))) && \
	npx tsx ./$(RUNNERS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

rotate-weth:
	@$(MAKE) strip-weth
	@$(MAKE) distribute-weth GROUP_IDX=$$(($(GROUP_IDX)+1))

# ───────────────────────────────────────────────
#   NFT SELECT & BOOTSTRAP
# ───────────────────────────────────────────────

bootstrap-nfts: select-nfts ## Mint tokens per participant from the JSON selection
	@source $(PIPELINE_STATE_DIR)/pipeline.env && \
	for i in $$(seq 0 $$(($$NFT_C_COUNT - 1))); do \
		col_var="NFT_C_$$i"; \
		collection=$${!col_var}; \
		echo "  collection $$i: $$collection"; \
		sleep 20 && \
		./$(RUNNERS)/bootstrap/bootstrap-nfts.sh $(TOKENS_BY_P_IDX_DIR) $(TX_OUT_DIR)/bootstrap-nfts-$$i.json "$$collection" && \
		npx tsx ./$(RUNNERS)/tx-manager/main.ts $(TX_OUT_DIR)/bootstrap-nfts-$$i.json $(TX_MANAGER_TIMESPAN); \
	done

select-nfts: ## Compute deterministic token-to-participant selection for each NFT collection
	@echo "🎲 Selecting NFTs..."
	@forge script $(BOOTSTRAP)/DecideInitialMint.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   APPROVALS
# ───────────────────────────────────────────────

approve: approve-nft-transfer approve-allowances ## Grant NFT + WETH allowances to OrderEngine
	@echo "✅ Approvals complete"

approve-nft-transfer:
	@echo "Approving NFT transfers..."
	@source $(PIPELINE_STATE_DIR)/pipeline.env && \
	for i in $$(seq 0 $$(($$NFT_C_COUNT - 1))); do \
		col_var="NFT_C_$$i"; \
		collection=$${!col_var}; \
		echo "  collection $$i: $$collection"; \
		./$(RUNNERS)/bootstrap/approve-nft-transfer.sh "$$ORDER_ENGINE" "$$collection" $(P_SIZE) $(TX_OUT_DIR)/approve-nft-$$i.json --start-idx $(P_IDX_START); \
		npx tsx ./$(RUNNERS)/tx-manager/main.ts $(TX_OUT_DIR)/approve-nft-$$i.json $(TX_MANAGER_TIMESPAN); \
	done

approve-allowances:
	@echo "Approving WETH allowance..."
	@TX_FILE=$(TX_OUT_DIR)/approve-allowances.json && \
	source $(PIPELINE_STATE_DIR)/pipeline.env && \
	./$(RUNNERS)/bootstrap/approve-allowances.sh "$$ORDER_ENGINE" "$$WETH" $(P_SIZE) $$TX_FILE --start-idx $(P_IDX_START) && \
	npx tsx ./$(RUNNERS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)


# ───────────────────────────────────────────────
#   CHAIN READ HELPERS
# ───────────────────────────────────────────────

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

kill-anvil: ## Kill the running anvil process
	@echo "💀 Killing anvil..."
	pkill anvil 2>/dev/null || true

print-participants: ## Print pipeline participants
	@./$(RUNNERS)/printers/print-participants.sh $(P_SIZE) --start-idx $(P_IDX_START)
