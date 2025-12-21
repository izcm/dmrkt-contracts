# Marketplace Engines

## Project Structure

### contracts/

Core protocol implementations:

- `orderbook/` - OrderEngine and settlement logic
- `amm/` - Pool-based automated market making
- `nfts/` - Mock ERC721 contracts for testing

### script/

Deployment and development scripts:

- `DeployOrderEngine.s.sol` - Main deployment script
- `dev/` - Bootstrap scripts, account setup, and local dev utilities

### test/

Test suite organized by scope:

- `unit/` - Isolated component tests
- `integration/` - End-to-end settlement and revert scenarios
- `helpers/` - Shared test utilities (OrderHelper, AccountsHelper, SettlementHelper)
- `mocks/` - Test-only contracts (MockWETH, MockERC721)

---

## Testing Scope

This repository contains **both on-chain contracts and off-chain tooling**.

### 🔗 On-chain (production-critical, fully tested)

These contracts are deployed on-chain and are covered by exhaustive tests:

- `contracts/orderbook/`
  - `OrderEngine.sol`
  - `libs/OrderActs.sol`
  - `libs/SignatureOps.sol`

These contracts reach ~100% line / branch coverage and are the **security-critical surface**.

Contracts in `contracts/nfts` are only meant for lab / dev environment and not part of the testing scope.

---

### 🧰 Periphery / Dev Tooling (not tested by design)

The following directories are **not deployed on-chain** and are used only for
local development, scripting, or simulation:

- `periphery/`
- `script/`
- `script/dev/**`

These are intentionally excluded from test coverage.
