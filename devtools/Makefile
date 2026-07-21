SHELL := /bin/bash

# ───────────────────────────────────────────────
#   ROOTS
# ───────────────────────────────────────────────

BOOTSTRAP       := bootstrap
PIPELINES       := pipelines
OPS             := ops

export OPS_FORK        := $(OPS)/fork
export OPS_EXPORTERS   := $(OPS)/orders
export PIPELINE_EPOCHS    := $(PIPELINES)/epochs
export PIPELINE_EXECUTION := $(PIPELINES)/execution

export TOML               := pipeline.toml

# ───────────────────────────────────────────────
#   PIPELINE CONTEXT
# ───────────────────────────────────────────────

MODE ?= anvil

# EPOCH_SIZE is undefined for sepolia since we aren't replaying past like on a local anvil fork
ifeq ($(MODE), sepolia)
	include .env.sepolia
	CHAIN_ID=11155111
	WETH=0x5f207d42F869fd1c71d7f0f81a2A67Fc20FF7323
# 	EPOCH_COUNT = 1
else
	include .env
	CHAIN_ID=31337
	WETH=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
	EPOCH_COUNT = 4
	EPOCH_SIZE = 604800
	SECONDS_AGO = $(shell expr $(EPOCH_COUNT) \* $(EPOCH_SIZE))
endif

PARTICIPANT_MNEMONIC := $(subst ",,$(PARTICIPANT_MNEMONIC))

# DEPLOYER_PK is read from the environment/.env if already set, otherwise derived from PARTICIPANT_MNEMONIC idx 0
DEPLOYER_PK ?= $(shell cast wallet private-key --mnemonic "$(PARTICIPANT_MNEMONIC)" --mnemonic-index 0)

# for pipeline.toml config per chain
# only needed when pipeline.toml contains several chains
-include .env.rpcs

export SEPOLIA_RPC SOURCE_RPC RPC_URL CHAIN_ID RPC_HOST RPC_PORT ORDERS_EXPORT_URL DEPLOYER_PK PARTICIPANT_MNEMONIC

export PIPELINE_STATE_DIR := data/$(CHAIN_ID)/state
export TOKENS_BY_P_IDX_DIR := data/$(CHAIN_ID)/state/cols-mint-per-idx

# output files for tx hashes
export TX_OUT_DIR = data/$(CHAIN_ID)/state/tx-out
$(shell mkdir -p $(TX_OUT_DIR))

ifeq ($(MODE), sepolia)
# if its the initial run -> set idx to 0 and size to max _size
# this executes all bootstrap steps for all participants until MAX_P_SZE
# note that MAX_P_SIZE represents the POSSIBLE NFT HOLDERS do not make it smaller
# than the pool of previous buyers / minters unless u know what ure doing

# -> future runs only have to build + execute orders
	P_IDX_START=0
	P_SIZE=20
	MAX_P_SIZE=100
else
# use these for anvil mode 	
	P_IDX_START=0
	P_SIZE=10
	MAX_P_SIZE=$(P_SIZE)
endif

# if MAX is set to any value !== P_SIZE
# it is your responsibility to fund the users P_SIZE..MAX_P_SIZE
export P_IDX_START P_SIZE MAX_P_SIZE

# realtime ctx (run-realtime target)
REALTIME_TIME_WINDOW  = 15552000 # 180 days, in seconds
REALTIME_EXEC_RATE    = 80      # % of built orders to execute
# REALTIME_NONCE_SEED   = $(shell date +%s) # non-static since realtime wants new dataset

FUNDER_IDX=0 # strip receiver / distributor of eth and erc20 tokens

TX_MANAGER_TIMESPAN=1800 # txs that don't resolve affter 30 minutes are assumed to be dropped
# sepolia is very slow...

# ───────────────────────────────────────────────
#   FLAGS
# ───────────────────────────────────────────────

SILENT ?= 0

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
endif

ifeq ($(MODE), anvil)
	LEGACY_FLAG=--legacy
endif

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	$(LEGACY_FLAG) \
	$(FORGE_SILENT)

EXPORT ?= 0

ifeq ($(EXPORT), 1)
EXPORT_FLAG = --export
endif

# ───────────────────────────────────────────────
#   ENTRYPOINTSs
# ───────────────────────────────────────────────

pipeline: deploy-core print-participants distribute-eth-to-all \
	bootstrap-nfts wrap-weth approve run-epochs

# time warping
replay-pipeline: start-replay pipeline

run-epochs: ## Generate, sign, export, and settle orders across all epochs
	@echo "📊 Building orders..."
	@./$(OPS)/run-epochs.sh $(EPOCH_COUNT) $(P_SIZE) $(EXPORT_FLAG)

# only time-window and build + execute orders (testnets)
# timeWindow is 3 months where end timestampset to 60 
run-realtime: print-participants
	@./$(OPS_FORK)/pipeline-window.sh --realtime $(REALTIME_TIME_WINDOW)
	@echo "🌀 Running realtime simulation"
	@./$(OPS)/run-realtime.sh $(P_SIZE) $(or $(NONCE_SEED), 0) $(or $(EPOCH),0) \
		--rate $(REALTIME_EXEC_RATE) \
		--start-idx $(P_IDX_START) \
		--fillers-size $(or $(FILLERS_SIZE), $(P_SIZE)) \
		--fillers-start-idx $(or $(FILLERS_IDX_START), $(P_IDX_START)) \
		$(EXPORT_FLAG)

# 	@./$(OPS)/run-realtime.sh $(REALTIME_EXEC_RATE) $(REALTIME_NONCE_SEED) --export

# as apposed to `approve` and `wrap-weth`, run-realtime does not update `p_idx_start` 
# this is because we want to build orders across the participant group
# same goes for the filler_idx_start; filler pool only grows, as participants get funded we can keep start_idx as 0
separate-deploy: distribute-eth-to-all deploy-core bootstrap-nfts
full-realtime: # run this after deploy-core with a funded idx 0
	@set -e; \
	for i in $$(seq 0 $$(($(MAX_P_SIZE) / $(P_SIZE) - 1))); do \
		IDX_START=$$(($(P_IDX_START) + $$i * $(P_SIZE))); \
		FILLERS_SIZE=$$(($(P_IDX_START) + ($$i + 1) * $(P_SIZE))); \
		if [ $$i -ne 0 ]; then \
			$(MAKE) wrap-weth P_IDX_START=$$IDX_START; \
			$(MAKE) approve P_IDX_START=$$IDX_START; \
		fi; \
		$(MAKE) run-realtime NONCE_SEED=$$i EPOCH=$$i \
			FILLERS_SIZE=$$FILLERS_SIZE; \
	done

# run realtime with local fork and no time replay
anvil-realtime: prepare fork-realtime distribute-eth-to-all deploy-core bootstrap-nfts full-realtime 

# ───────────────────────────────────────────────
#   HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

start-replay: prepare fork-replay ## Compute window, start fork
	@echo "🚀 Dev environment ready"

pipeline-setup: deploy-core print-participants bootstrap-nfts
	@echo "✅ Core deployed and participants bootstrapped"
	$(MAKE) approve
	@echo "✅ OrderEngine fully authorized"

# ───────────────────────────────────────────────
#   FORK PREPARE & START
# ───────────────────────────────────────────────

fork-replay: ## Start the anvil fork
	@echo "🧬 Starting anvil fork..."
	@./$(OPS_FORK)/start-fork.sh --replay

fork-realtime: 
	@echo "🧬 Starting anvil fork..."
	@./$(OPS_FORK)/start-fork.sh

prepare: ## Compute fork start block and pipeline window timestamps
	@echo "🔢 Finding block number and timestamps..."
	@./$(OPS_FORK)/pipeline-window.sh --replay 2419200

# ───────────────────────────────────────────────
#   SETUP / GENESIS
# ───────────────────────────────────────────────

deploy-core: ## Deploy OrderEngine + NFT collections, write addresses to pipeline.toml
	@echo "🧾 Deploying core contracts..."
	@forge script $(BOOTSTRAP)/DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   ETH FUNDING
# ───────────────────────────────────────────────

distribute-eth:
	@echo "Distributing eth..."
	@TX_FILE=$(TX_OUT_DIR)/distribute-eth.json && \
	./$(OPS)/funding/distribute-eth.sh $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $(P_IDX_START) && \
	npx tsx ./$(OPS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

distribute-eth-to-all: 
	@$(MAKE) distribute-eth P_SIZE=$(MAX_P_SIZE)

strip-eth:
	@echo "Stripping eth..."
	@TX_FILE=$(TX_OUT_DIR)/strip-eth.json && \
	./$(OPS)/funding/strip-eth.sh $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $(P_IDX_START) && \
	npx tsx ./$(OPS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

rotate-eth:
	@$(MAKE) strip-eth
	@$(MAKE) distribute-eth P_IDX_START=$$(($(P_IDX_START)+$(P_SIZE)))

# ───────────────────────────────────────────────
#   ERC20 FUNDING
# ───────────────────────────────────────────────

wrap-weth: ## Wrap ETH into WETH for all participants
	@echo "💰 Wrapping WETH..."
	@TX_FILE=$(TX_OUT_DIR)/wrap-weth.json && \
	./$(OPS)/bootstrap/wrap-weth.sh $(WETH) $(P_SIZE) $$TX_FILE --start-idx $(P_IDX_START) && \
	npx tsx ./$(OPS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

distribute-weth:
	@echo "Distributing weth..."
	@TX_FILE=$(TX_OUT_DIR)/distribute-weth.json && \
	./$(OPS)/funding/erc20/distribute-erc20.sh $(WETH) $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $(P_IDX_START) && \
	npx tsx ./$(OPS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

strip-weth:
	@echo "Stripping weth..."
	@TX_FILE=$(TX_OUT_DIR)/strip-weth.json && \
	./$(OPS)/funding/erc20/strip-erc20.sh $(WETH) $(FUNDER_IDX) $(P_SIZE) $$TX_FILE \
		--start-idx $(P_IDX_START) && \
	npx tsx ./$(OPS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)

rotate-weth:
	@$(MAKE) strip-weth
	@$(MAKE) distribute-weth P_IDX_START=$$(($(P_IDX_START)+$(P_SIZE)))

# ───────────────────────────────────────────────
#   NFT SELECT & BOOTSTRAP
# ───────────────────────────────────────────────

bootstrap-nfts: select-nfts ## Mint tokens per participant from the JSON selection
	@source $(PIPELINE_STATE_DIR)/pipeline.env && \
	for i in $$(seq 0 $$(($$NFT_C_COUNT - 1))); do \
		col_var="NFT_C_$$i"; \
		collection=$${!col_var}; \
		echo "  collection $$i: $$collection"; \
		./$(OPS)/bootstrap/bootstrap-nfts.sh $(TOKENS_BY_P_IDX_DIR) $(TX_OUT_DIR)/bootstrap-nfts-$$i.json "$$collection" && \
		npx tsx ./$(OPS)/tx-manager/main.ts $(TX_OUT_DIR)/bootstrap-nfts-$$i.json $(TX_MANAGER_TIMESPAN); \
	done

select-nfts: ## Compute deterministic token-to-participant selection for each NFT collection
	@echo "🎲 Selecting NFTs..."
	@forge script $(BOOTSTRAP)/SelectNFTs.s.sol \
		--sig "run(uint256,uint256)" \
		$(P_SIZE) $(P_IDX_START) \
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
		./$(OPS)/bootstrap/approve-nft-transfer.sh "$$ORDER_ENGINE" "$$collection" $(P_SIZE) $(TX_OUT_DIR)/approve-nft-$$i.json --start-idx $(P_IDX_START); \
		npx tsx ./$(OPS)/tx-manager/main.ts $(TX_OUT_DIR)/approve-nft-$$i.json $(TX_MANAGER_TIMESPAN); \
	done

approve-allowances:
	@echo "Approving WETH allowance..."
	@TX_FILE=$(TX_OUT_DIR)/approve-allowances.json && \
	source $(PIPELINE_STATE_DIR)/pipeline.env && \
	./$(OPS)/bootstrap/approve-allowances.sh "$$ORDER_ENGINE" "$$WETH" $(P_SIZE) $$TX_FILE --start-idx $(P_IDX_START) && \
	npx tsx ./$(OPS)/tx-manager/main.ts $$TX_FILE $(TX_MANAGER_TIMESPAN)


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
	@./$(OPS)/helpers/print-participants.sh $(P_SIZE) --start-idx $(P_IDX_START)

print-balances: ## Print ETH and WETH balances for participants idx P_IDX_START..+P_SIZE
	@./$(OPS)/helpers/check-balances.sh $(WETH) $(P_SIZE) --start-idx $(P_IDX_START)
