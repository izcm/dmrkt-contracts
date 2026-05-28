# d | mrkt contracts

A minimal marketplace paired with foundry scripts to simulate marketplace activity.

These contracts support the `d | mrkt` interactive demo — its centerpiece being the Foundry simulation pipeline in [`devtools`](./devtools/README.md).

> [!WARNING]
> Not production ready.

---

## Repository Layout

```
contracts/    production contracts
test/         test suite
periphery/    shared builders
devtools/     local simulation pipeline (not production)
```

---

## Deployment

Ensure the following dependencies:

| Tool                       | Version |
| -------------------------- | ------- |
| Foundry (forge/cast/anvil) |         |

Deploy marketplace by running:

```bash
forge script script/DeployOrderEngine.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

Deployment script hardcodes `WETH`

---

## OrderEngine

Located in `contracts/orderbook/OrderEngine.sol`

A single-strategy marketplace engine that accepts signed EIP-712 orders and settles them against matching fills, enforcing the exact terms defined by maker.

There is a single entrypoint for settling an order, the `settle` function. This entrypoint and other external functions are summarized in [Reference - External Functions](#external-functions).

**Strategy**

Orders exist as signed EIP-712 messages offchain until matched against a fill request and settled onchain.

`settle` flow:

1. Resolve settlement roles
2. Transfer payment
3. Transfer NFT
4. Invalidate nonce
5. Emit settlement event

The signed EIP-712 message must exactly match the following `Order` structure:

```solidity
struct Order {
    Side side;
    bool isCollectionBid; // if side = bid and order is for any item in collection
    address collection;
    uint256 tokenId; // ignored if isCollectionBid = true
    address currency;
    uint256 price;
    address actor;
    uint64 start;
    uint64 end;
    uint256 nonce;
}
```

**Limitations**

Supported currencies and collection standards are hardcoded — there are no admin methods to change them. Collections must implement ERC-721 (checked via ERC-165), and the only accepted currency is the `WETH` address passed to constructor.

---

## Reference

### External Functions

All implemented in `OrderEngine`.

| Function                                               | Description                                       |
| ------------------------------------------------------ | ------------------------------------------------- |
| `settle(Fill, Order, Signature)`                       | Match a fill request to a signed order and settle |
| `cancelOrder(uint256 nonce)`                           | Invalidate a nonce, preventing order settlement   |
| `isUserOrderNonceInvalid(address user, uint256 nonce)` | Check whether a nonce has been invalidated        |

### Libraries

Located in `contracts/orderbook/libs/`.

| Library           | Description                                                                                                           |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- |
| `OrderModel`      | `Order` and `Fill` definitions and hashing logic.                                                                     |
| `SignatureOps`    | Signature verification helpers for EOAs and EIP-1271 contract wallets.                                                |
| `SettlementRoles` | Resolves settlement roles (`nftHolder`, `spender`, `tokenId`) from an order/fill pair depending on side and bid type. |

> [!NOTE]
> Order model uses the term `actor` instead of maker / taker.
> Docs may use “maker” and “taker” occasionaly as it's more familiar.

### Errors

| Error                      | Selector     | Defined by        | Meaning                                       |
| -------------------------- | ------------ | ----------------- | --------------------------------------------- |
| `UnauthorizedFillActor()`  | `0xc2b1dce2` | `OrderEngine`     | `fill.actor` != `msg.sender`                  |
| `ZeroActor()`              | `0xb1375a3d` | `OrderEngine`     | Zero address actor                            |
| `InvalidNonce()`           | `0x756688fe` | `OrderEngine`     | Nonce already invalidated                     |
| `InvalidTimestamp()`       | `0xb7d09497` | `OrderEngine`     | Order outside valid window                    |
| `CurrencyNotWhitelisted()` | `0x5f6063cc` | `OrderEngine`     | Currency != `WETH`                            |
| `UnsupportedCollection()`  | `0x0179a917` | `OrderEngine`     | Collection doesn't implement ERC721 interface |
| `InvalidYParity()`         | `0x541b3bce` | `SignatureOps`    | `v` is not 27 or 28                           |
| `InvalidSParameter()`      | `0x0658eabd` | `SignatureOps`    | `s` exceeds EIP-2 upper bound                 |
| `InvalidSignature()`       | `0x8baa579f` | `SignatureOps`    | Recovered signer doesn't match expected       |
| `InvalidOrderSide()`       | `0xea5ea9e2` | `SettlementRoles` | Order side is not buy or sell                 |

---

## Testing

<scope note — what is and isn't covered>

```txt
unit/         isolated lib tests
integration/  end-to-end settle + revert scenarios
helpers/      OrderHelper, AccountsHelper, SettlementHelper
mocks/        MockWETH, MockERC721, etc.
```

Testing scope includes all content in `contracts/*` plus sanity tests for certain helpers.

### Run

```bash
# run all tests
forge test

# coverage
forge coverage
```

---

If you have any questions, or just want to talk web3 infra, feel free to reach out on my [discord](https://discord.com/users/745594868826505227).

**See ya 👾**
