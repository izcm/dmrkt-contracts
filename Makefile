# ───────────────────────────────────────────────
#   Marketplace Engines — DEV PIPELINE
# ───────────────────────────────────────────────

include .env

# ───────────────────────────────────────────────
#   ROOTS
# ───────────────────────────────────────────────

SCRIPT_ROOT := script
DEV_ROOT    := $(SCRIPT_ROOT)/dev

# dev subtrees
DEV_BASE        := $(DEV_ROOT)
DEV_SETUP       := $(DEV_ROOT)/genesis
DEV_BOOTSTRAP   := $(DEV_SETUP)/bootstrap
DEV_LOGIC       := $(DEV_ROOT)/logic
DEV_STATE       := $(DEV_ROOT)/state

# entrypoints
DEPLOY_ORDER_ENGINE := $(SCRIPT_ROOT)/DeployOrderEngine.s.sol

# chain
RPC_URL := $(ANVIL_RPC_URL)
WETH    := 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

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
	--sender $(SENDER) \
	--private-key $(PRIVATE_KEY) \
	$(FORGE_SILENT)

# ───────────────────────────────────────────────
#   DEV — HIGH-LEVEL PIPELINES
# ───────────────────────────────────────────────

dev-start: dev-fork pipeline-setup
	@echo "🚀 Dev environment ready"

dev-reset: kill-anvil dev-start
	@echo "♻️ Dev reset complete"

pipeline-setup: \
	dev-bootstrap-accounts \
	dev-deploy-core \
	dev-bootstrap-nfts \
	dev-approve
	@echo "🧱 Setup pipeline complete"

pipeline-state: dev-open dev-history
	@echo "🎭 State pipelines complete"

# ───────────────────────────────────────────────
#   DEV — ENVIRONMENT BOOT
# ───────────────────────────────────────────────

dev-fork:
	@echo "🧬 Starting anvil fork..."
	@cd $(DEV_ROOT) && bash start.sh

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
	@echo "🖼️ Bootstrapping NFTs..."
	forge script $(DEV_BOOTSTRAP)/BootstrapNFTs.s.sol \
		$(FORGE_COMMON_FLAGS)

dev-approve:
	@echo "✔ Executing approvals..."
	forge script $(DEV_BOOTSTRAP)/Approve.s.sol \
		$(FORGE_COMMON_FLAGS)

# ───────────────────────────────────────────────
#   DEV — STATE / SCENARIOS
# ───────────────────────────────────────────────

dev-build-history:
	@echo "📊 Building historical orders..."
	forge script $(DEV_STATE)/BuildHistory.s.sol \
		--sig "runWeek(uint256)" 4 \
		$(FORGE_COMMON_FLAGS)

dev-execute-history:
	@echo "📊 Executing historical orders..."
	forge script $(DEV_STATE)/ExecuteHistory.s.sol \
		$(FORGE_COMMON_FLAGS)

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

# ───────────────────────────────────────────────
#   MISC
# ───────────────────────────────────────────────

tree:
	@if [ -z "$(DEPTH)" ]; then DEPTH=3; fi; \
	tree -L $$DEPTH -I "out|lib|broadcast|cache|notes"
