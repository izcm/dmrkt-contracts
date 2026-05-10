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

# chain
WETH := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

# epoch defs
EPOCH_COUNT ?= 4

# ───────────────────────────────────────────────
#   LOGGING / VERBOSITY
# ───────────────────────────────────────────────

SILENT ?= 1

ifeq ($(SILENT),1)
FORGE_SILENT = --silent
else
FORGE_SILENT =
endif

# ───────────────────────────────────────────────
#   FORGE FLAGS
# ───────────────────────────────────────────────

FORGE_COMMON_FLAGS = \
	--rpc-url $(RPC_URL) \
	--broadcast \
	$(FORGE_SILENT)

# ───────────────────────────────────────────────
#   DOCKER ENTRYPOINTS
# ───────────────────────────────────────────────

execute-pipeline: wait pipeline-setup pipeline-separator run-epochs
	@echo "🚀 Dev environment ready"

wait:
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
#   HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

start: prepare fork pipeline-setup
	@echo "🚀 Dev environment ready"

reset: kill-anvil start
	@echo "🔄 Dev reset complete"

pipeline-setup: \
	deploy-core \
	bootstrap-accounts \
	bootstrap-nfts \
	approve
	@echo "🧱 Setup pipeline complete"

# ───────────────────────────────────────────────
#   ENVIRONMENT BOOT
# ───────────────────────────────────────────────

fork:
	@echo "🧬 Starting anvil fork..."
	@./$(RUNNERS_FORK)/start-fork.sh

prepare:
	@echo "🔢 Finding block number and timestamps..."
	@./$(RUNNERS_FORK)/pipeline-window.sh 2419200

# ───────────────────────────────────────────────
#   SETUP / GENESIS
# ───────────────────────────────────────────────

bootstrap-accounts:
	@echo "💻 Bootstrapping dev accounts..."
	@forge script $(BOOTSTRAP)/BootstrapAccounts.s.sol \
		$(FORGE_COMMON_FLAGS)

deploy-core:
	@echo "🧾 Deploying core contracts..."
	@forge script DeployCore.s.sol \
		$(FORGE_COMMON_FLAGS)

bootstrap-nfts: FORGE_SILENT =
bootstrap-nfts:
	@echo "👾 Bootstrapping NFTs..."
	@forge script $(BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

approve:
	@echo "✔ Executing approvals..."
	@forge script $(BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   STATE / SCENARIOS
# ───────────────────────────────────────────────

run-epochs:
	@echo "📊 Building historical orders..."
	@./$(RUNNERS)/run-epochs.sh $(EPOCH_COUNT) --export

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
	@find . -type f -name "*.sh" -exec chmod +x {} +

tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=3; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"
