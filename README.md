# Marketplace Engines

## The on-chain protocol

### contracts/

Core protocol implementations:

- `orderbook/` - OrderEngine and settlement logic

### test/

Test suite organized by scope:

- `unit/` - Isolated component tests
- `integration/` - End-to-end settlement and revert scenarios
- `helpers/` - Shared test utilities (OrderHelper, AccountsHelper, SettlementHelper)
- `mocks/` - Test-only contracts (MockWETH, MockERC721)

---

## Testing Scope

This repository contains both the on-chain protocol and local development tooling.

### 🔗 On-chain (production-critical, fully tested)

These contracts / libraries are deployed on-chain and are covered by exhaustive tests:

- `contracts/orderbook/`
  - `OrderEngine.sol`
  - `libs/OrderModel.sol`
  - `libs/SignatureOps.sol`
  - `libs/SettlementRoles.sol`

They all reach ~100% line / branch coverage and are the **security-critical surface**.

Contracts in `periphery/nfts` are only meant for lab / dev environment and not part of the testing scope.

Test helpers are tested proportionally to the risk they introduce.

Eg: `OrderHelper` not returning `Orders` of expected format could silently corrupt tests and invalidate tests results, so unit tests are implemented to detect this.

---

### 🧰 Periphery / Dev Tooling (not tested by design)

The following directories are **not deployed on-chain** and are used only for
local development, scripting, or simulation:

- `periphery/`
- `script/`
- `script/dev/**`

These are intentionally excluded from test coverage.

---

# The off-chain tooling

_The star of the show ⭐_

The next section covers the main part of this demo: the dev-tooling.

These scripts run only on a local development chain and are not connected to any real contracts or funds. They intentionally poke and reshape state to build predictable orderbook scenarios for the indexer.

**🟡 Runs only on a local chain.**

---

## Artifacts

The `selections` folder (per epoch:collection) contains the tokenIds chosen for either on-chain execution (ownership change) or skipping.

Skipped tokens correspond to orders that are exported to the indexer but intentionally not executed on-chain.

TokenIds from skipped orders are written to `ensure-lingers.json`, an artifact shared between all epochs.

The pipeline builder uses this file to avoid modifying their ownership state. This guarantees the orders remain fillable at the end of the pipeline.
