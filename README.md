# Marketplace Engines

<one-liner about what this repo is>

---

## Repository Layout

```
contracts/    production contracts
test/         test suite
periphery/    shared builders + interfaces
devtools/     local simulation pipeline (not production)
```

---

## Contracts

**`OrderEngine.sol`** — <what it does>

| File                      | Description |
| ------------------------- | ----------- |
| `libs/OrderModel.sol`     |             |
| `libs/SignatureOps.sol`   |             |
| `libs/SettlementRoles.sol`|             |

---

## Testing

<scope note — what is and isn't covered>

```
unit/         isolated lib tests
integration/  end-to-end settle + revert scenarios
helpers/      OrderHelper, AccountsHelper, SettlementHelper
mocks/        MockWETH, MockERC721, etc.
```

Production contracts (`contracts/orderbook/`) reach ~100% line / branch coverage and are the security-critical surface. Contracts and scripts in `devtools/` are for demo purposes only and are not part of the testing scope.

---

## Running Tests

```bash
# run all tests
forge test

# coverage
forge coverage
```

---

## Dev Pipeline

Local simulation pipeline lives in `devtools/` — see [devtools/README.md](./devtools/README.md) for the full breakdown.

```bash
# spin up a local fork with seeded state
make dev-start
```

---

## Setup

**Prerequisites**

| Tool                       | Version |
| -------------------------- | ------- |
| Foundry (forge/cast/anvil) |         |

**Environment**

Copy `.env.example` to `.env` and fill in:

| Var        | Description |
| ---------- | ----------- |
| `FORK_RPC` | Mainnet RPC URL |
| `RPC_URL`  | Fork RPC URL (used by Makefile) |
| `CHAIN_ID` |             |
