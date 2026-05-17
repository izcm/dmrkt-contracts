# d | mrkt engines

A simple orderbook contract with foundry scripts to simulate marketplace activity. Made with the intent to make an interactive demo with a tutorial-ish format, developed into some generic scripts that might be of use for devs making their own foundry pipelines.

## Repository Layout

```
contracts/    production contracts
test/         test suite
periphery/    builders shared by tests and devtools
devtools/     local simulation pipeline (not production)
```

---

## Contracts

Order model uses the term `actor` instead of the traditional maker / taker terminology.
Documentation may still use “maker” and “taker” informally when describing settlement flow.

**OrderEngine.sol** — a single-strategy marketplace engine that accepts signed EIP-712 orders and settles them against matching fills, enforcing the exact terms defined by the maker.

| File                       | Description                                                                                                           |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `libs/OrderModel.sol`      | `Order` and `Fill` definitions and hashing logic.                                                                     |
| `libs/SignatureOps.sol`    | Signature verification helpers for EOAs and EIP-1271 contract wallets.                                                |
| `libs/SettlementRoles.sol` | Resolves settlement roles (`nftHolder`, `spender`, `tokenId`) from an order/fill pair depending on side and bid type. |

---

## Setup

### Dependencies

| Tool                       | Version |
| -------------------------- | ------- |
| Foundry (forge/cast/anvil) |         |

---

## Testing

<scope note — what is and isn't covered>

```
unit/         isolated lib tests
integration/  end-to-end settle + revert scenarios
helpers/      OrderHelper, AccountsHelper, SettlementHelper
mocks/        MockWETH, MockERC721, etc.
```

Testing scope includes all content in `comtracts/*` + sanity tests for certain helpers.

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

Main focus of this repo is the marketplace activity simulation. Its docs are separate, see [devtools/README.md](./devtools/README.md).

```bash
# spin up a local fiork with seeded state
make dev-start
```

---
