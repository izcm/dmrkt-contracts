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
