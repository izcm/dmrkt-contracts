# DevTools

Foundry scripts glued together to simulate marketplace activity. Computes a start block (default: 28 days ago) and forks mainnet at that block. The pipeline goes like:

- Deploys orderbook + demo NFT collections
- Bootstraps accounts derived from the provided mnemonic
- Generates realistic-looking orders and signs them EIP-712 style
- Settles a subset of orders per epoch, with probability decay to leave some unfilled

```
prepare-fork.js          writes fork block + timestamps
     │
start-fork.sh            spins up Anvil
     │
DeployCore               deploys OrderEngine + DMrktLoot → pipeline.toml
     │
Bootstrap (x3)           wraps ETH, mints NFTs, sets approvals
     │
run-epochs.sh  ──loop──► BuildEpoch    generates + signs orders (JSON)
                    │     export-order.sh  POSTs to indexer
                    │     ExecuteOrder     settles subset on-chain
                    └──── advance block time
```

---

## Overview

Built to simulate marketplace activity for an interactive demo. Later grew into something more generic — may be useful to devs wanting production-like activity for demos, testing, or stakeholder previews.

**The fork**

We fork mainnet instead of a blank chain. Currencies like WETH live at their real addresses, and trade receipts contain realistic block numbers.

**Participants**

Participants are derived from a mnemonic. Default participant count is 10, but can be increased / decreased without breaking the pipeline.

Participants are funded during fork startup through Anvil's --mnemonic flag.

Scripts that need to read participants extend [BaseDevScript](./BaseDevScript.s.sol) — e.g. for allowance and transfer approvals. The `actor` field of every generated order or fill is one of the participant addresses.

**The data**

After bootstrapping participants with WETH and NFTs, and doing the necessary approvals, the pipeline creates and signs EIP-712 orders, and then executes trades on a subset of these.

This multi-step process happens per-epoch. Each epoch stores its generated orders and related pipeline state in its own directory.

---

## Epochs

An epoch is a time slice of the pipeline window. The **delta** (`pipeline_end_ts - pipeline_start_ts`) is divided into `EPOCH_COUNT` equal **slices** (`epoch_slice = delta / EPOCH_COUNT`).

Each epoch builds, exports, and settles orders within its slice, advancing Anvil block time accordingly.

**What happens inside one epoch:**

- **Sampling** —Orders are generated from deterministic inputs (collection, side, epoch, etc.), so the simulation gets variation while still producing reproducible results. In short, same input &rarr; same output.
- **Signing** — Signs orders.
- **Export** — Pushes orders to an optional endpoint. Gated behind the `--export` flag, off by default, enabled by the root `Makefile`.
- **Execution** — ...

---

### Data Layout

```
data/
└── <chainId>/
    ├── mnemonic.json    # Mnemonic provided by us
    └── state/
        └── epoch_N/
            ├── orders.json        # The generated orders
            ├── nonces.json        # Last nonce per user, next epoch reads from this
            └── selections.json    # Related to collection-bids (a paused feature)
```

---

## Where to Start

Skim these in order to build a mental model without reading everything:

| #   | File                             | What you learn                                                                                                                             |
| --- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | **`Makefile`** (targets section) | The full pipeline as named steps — what runs, in what order, and what each phase is called.                                                |
| 2   | **`DevConfig.s.sol`**            | All the config knobs in one place — read this to better understand the pipeline context.                                                   |
| 3   | **`runners/run-epochs.sh`**      | The epoch loop in four labelled phases: BUILD → EXPORT → CHOOSE → EXECUTE. The probability decay logic is visible here too.                |
| 4   | `BuildEpoch.s.sol`               | Implements the BUILD phase — generates and signs orders for a single epoch. Dense; skim `run` then follow `_buildOrders` into `MarketSim`. |

**Going deeper:**

| Topic              | Read                                                                            |
| ------------------ | ------------------------------------------------------------------------------- |
| Sampling           | `MarketSim.sol`                                                                 |
| Order signing      | `SignOrder.s.sol`                                                               |
| Bootstrap sequence | `DeployCore` → `BootstrapAccounts` → `BootstrapNFTs` → `Approve` in that order. |

The boostrap sequence is especially good for anyone new to foundry. They're very straight forward.

---

## Setup

**Prerequisites**

| Tool                       | Version | Notes |
| -------------------------- | ------- | ----- |
| Foundry (forge/cast/anvil) | \_\_\_  |       |

**Fork**

```bash
# Set fork window (block range + timestamps) in pipeline.toml
./runners/fork/pipeline-window.sh <seconds_ago> [end_ts]

# Start Anvil fork
./runners/fork/start-fork.sh
```

| Env var    | Default     | Description                                                                             |
| ---------- | ----------- | --------------------------------------------------------------------------------------- |
| `FORK_RPC` | \_\_\_      | Full mainnet RPC URL — any provider (e.g. `https://eth-mainnet.g.alchemy.com/v2/<key>`) |
| `RPC_HOST` | `localhost` | Fork RPC host                                                                           |
| `RPC_PORT` | \_\_\_      | Fork RPC port                                                                           |
| `CHAIN_ID` | \_\_\_      |                                                                                         |

**Run**

Makefile (maybe move makefileinto into devtools? nah... i think its better in root)

---

## Pipeline Reference

### Configuration — `pipeline.toml`

Shared state file written by deploy scripts and read by pipeline runners.

| Key                 | Set by          | Description                                               |
| ------------------- | --------------- | --------------------------------------------------------- |
| `weth`              | DeployCore      | WETH token address                                        |
| `order_engine`      | DeployCore      | OrderEngine contract address                              |
| `nft_c_{i}`         | DeployCore      | NFT collection addresses, one key per deployed collection |
| `fork_start_block`  | pipeline-window | The fork start block                                      |
| `pipeline_start_ts` | pipeline-window | Pipeline start timestamp                                  |
| `pipeline_end_ts`   | pipeline-window | Pipeline end timestamp                                    |

---

### Scripts — Bash

Located under `runners/`

| Script               | Usage                                                                                                                                                  |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `pipeline-window.sh` | Computes fork start block + window timestamps and writes these to `pipeline.toml`                                                                      |
| `start-fork.sh`      | Starts the anvil fork. Reads start block from `pipeline.toml` and mnemonic from the data directory, defaulting to block 0 and anvil's default mnemonic |
| `run-epochs.sh`      | Orchestrates the full epoch pipeline for each epoch                                                                                                    |
| `export-order.sh`    | POST single order to endpoint specified as env variable `ORDER_POST_URL`. Called by `run-epochs` when `--export` is passed                             |

---

### Scripts — Foundry

#### Bootstrap

| Script                    | Description                                                                                                                                     |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `DeployCore.s.sol`        | Deploys contracts and writes addresses to pipeline.toml. Adding more nft-collections is super simple, see script's doc comment for explanation. |
| `BootstrapAccounts.s.sol` | Wraps half of each participant's ETH into WETH                                                                                                  |
| `BootstrapNFTs.s.sol`     | Iterates over the nft-collections in `pipeline.toml` and mints tokens to participants. Assumes collections implement the `DNFT` interface.      |
| `Approve.s.sol`           | Grants NFT transfer auth + WETH allowance to OrderEngine                                                                                        |
| `BaseDevScript.s.sol`     | Generates private keys from given mnemonic + participant access helpers and logging utilities                                                   |
| `DevConfig.s.sol`         | Single source for reading `pipeline.toml`                                                                                                       |

#### Pipelines

| Script                       | Description                                                               |
| ---------------------------- | ------------------------------------------------------------------------- |
| `BuildEpoch.s.sol`           | Samples orders for an epoch; exports to JSON                              |
| `ExecuteOrder.s.sol`         | Settles a single order on-chain via OrderEngine.settle()                  |
| `MarketSim.sol`              | Pseudo-random token selection and base price generation                   |
| `EpochsJson.s.sol`           | JSON serialization for orders and etc. data like previous epoch's nounces |
| `SignOrder.s.sol`            | EIP-712 order signing                                                     |
| `SettlementValidation.s.sol` | Pre-settlement timestamp + ownership checks                               |
| `FillBid.s.sol`              | Resolves fill recipient for regular and collection bids                   |

> [!NOTE]
> Collection bid feature is paused

---

### Interfaces

Devtools-only interfaces, kept separate from `periphery/interfaces` which is shared with tests and production code.

| Interface               | Description                                                                                           |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| `DNFT.sol`              | Minimal ERC721 extension used by simulation scripts — exposes `MAX_SUPPLY`, `totalSupply`, and `mint` |
| `ISettlementEngine.sol` | Subset of OrderEngine surface used by the pipeline — `settle`, `DOMAIN_SEPARATOR`, nonce check        |

---

### Local NFTs

| Contract              | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| `DMrktLoot.sol`       | ERC721, 500 supply, fully on-chain SVG metadata                        |
| `DMrktNFTLib.sol`     | Trait generation: rarity, elements, stats, color palette, SVG builders |
| `DMrktMathConfig.sol` | Constants: supply, rarity tiers, stat bonuses, element modulos.        |
