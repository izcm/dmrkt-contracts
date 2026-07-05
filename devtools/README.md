# devtools

Foundry scripts glued together to simulate marketplace activity. Computes a start block (default: 28 days ago) and forks mainnet at that block.

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

**Contents** — [Overview](#overview) · [Epochs](#epochs) · [Where to Start](#where-to-start) · [Setup](#setup) · [Pipeline Reference](#pipeline-reference)

---

## Overview

Built to simulate marketplace activity for an interactive demo. Later grew into something more generic — may be useful to devs wanting production-like activity for demos, testing, or stakeholder previews.

**The fork**

We fork mainnet instead of a blank chain. Currencies like WETH live at their real addresses, and trade receipts contain realistic block numbers.

**Participants**

Participants are derived from a mnemonic. Default participant count is 10, but can be increased / decreased without breaking the pipeline.

Participants are funded during fork startup through Anvil's `--mnemonic` flag. Set `PARTICIPANT_MNEMONIC` in your `.env` to use a custom mnemonic. If not set, both the fork and the pipeline scripts fall back to the standard Hardhat/Anvil default mnemonic (`test test test ... junk`).

Scripts that need to read participants extend [BaseDevScript](./BaseDevScript.s.sol) — e.g. for allowance and transfer approvals. The `actor` field of every generated order or fill is one of the participant addresses.

**The data**

After bootstrapping participants with WETH and NFTs, and doing the necessary approvals, the pipeline creates and signs EIP-712 orders, and then executes trades on a subset of these.

This multi-step process happens per-epoch. Each epoch stores its generated orders and related pipeline state in its own directory.

---

## Epochs

An epoch is a time slice of the pipeline window. The **delta** (`pipeline_end_ts - pipeline_start_ts`) is divided into `EPOCH_COUNT` equal **slices** (`epoch_slice = delta / EPOCH_COUNT`).

Each epoch builds, exports, and settles orders within its slice, advancing Anvil block time accordingly.

> On testnets there's no past to replay, so everything runs in one epoch instead of many.

**What happens inside one epoch:**

- **Sampling** —Orders are generated from deterministic inputs (collection, side, epoch, etc.), so the simulation gets variation while still producing reproducible results. In short, same input &rarr; same output.
- **Signing** — Signs orders.
- **Export** — Pushes orders to `ORDERS_EXPORT_URL`. Gated behind the `--export` flag passed to `run-epochs.sh`; skipped if not set.
- **Execution** — Match orders to fill and execute trade on-chain.

> Orders are built and executed in the same order across runs. Orders are sorted by token ID so the executed subset is stable regardless of the fork block.

---

### Data Layout

```
data/
└── <chainId>/
    └── state/
        └── epoch_N/
            ├── orders.json        # The generated orders
            ├── nonces.json        # Last nonce per user, next epoch reads from this
            └── selections.json    # Related to collection-bids (a paused feature)
```

---

## Where to Start

Skim these in order to build a mental model without reading everything:

| #   | File                             | What you learn                                                                                                                                 |
| --- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`Makefile`** (targets section) | The full pipeline as named steps — what runs, in what order, and what each phase is called.                                                    |
| 2   | **`DevConfig.s.sol`**            | All the config knobs in one place — read this to better understand the pipeline context.                                                       |
| 3   | **`runners/run-epochs.sh`**      | The epoch loop in four labelled phases: BUILD → EXPORT → CHOOSE → EXECUTE. The probability decay logic is visible here too.                    |
| 4   | `BuildEpoch.s.sol`               | Implements the BUILD phase — generates and signs orders for a single epoch. Its dense; skim `run` then follow `_buildOrders` into `MarketSim`. |

**Going deeper:**

| Topic              | Read                                                                         |
| ------------------ | ---------------------------------------------------------------------------- |
| Sampling           | `MarketSim.sol`                                                              |
| Order signing      | `SignOrder.s.sol`                                                            |
| Bootstrap sequence | `DeployCore` → `BootstrapFunds` → `SelectNFTs` → `Approve` in that order. |

The boostrap sequence is especially good for anyone new to foundry. They're very straight forward.

Foundry scripts that invoke `broadcast` receive a `participantIdx`, which corresponds to the participant's mnemonic index. Bash orchestrates parallel execution across participants by invoking one Foundry script per participant. Within each participant, any transactions executed in parallel use explicitly incremented nonces to ensure they remain valid.

```
Participant A
 ├─ nonce 0
 ├─ nonce 1
 ├─ nonce 2

Participant B
 ├─ nonce 0
 ├─ nonce 1
 ├─ nonce 2

Participant C
 ├─ nonce 0
 ├─ nonce 1
 ├─ nonce 2
```

---

## Setup

**`pipeline.toml`**

You need to create `devtools/pipeline.toml` before running the pipeline. It tells the scripts where your local fork is and where to find WETH:

```toml
[31337]
endpoint_url = "http://localhost:8545"

[31337.address]
weth = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
```

The deploy scripts will populate the rest of the fields (contract addresses, fork block, timestamps) when they run.

**Dependencies**

| Tool                       | Version | Notes |
| -------------------------- | ------- | ----- |
| Foundry (forge/cast/anvil) | \_\_\_  |       |
| curl                       |         |       |
| jq                         |         |       |

**Environment variables**

| Var                    | Description                                                                                         | Example                                      |
| ---------------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `SOURCE_RPC`           | Mainnet RPC URL used to seed the fork                                                               | `https://eth-mainnet.g.alchemy.com<API_KEY>` |
| `RPC_URL`              | Local fork RPC URL                                                                                  | `http://localhost:8545`                      |
| `RPC_HOST`             | Anvil bind address, expects an IP address                                                           | `127.0.0.1`                                  |
| `RPC_PORT`             | Anvil port                                                                                          | `8545`                                       |
| `CHAIN_ID`             | Chain ID for the local fork network                                                                 | `31337`                                      |
| `PARTICIPANT_MNEMONIC` | Optional. Mnemonic for participant accounts. Defaults to the standard Hardhat/Anvil junk mnemonic.  | `word1 word2 ... word12`                     |
| `P_IDX_START`          | Optional. Index of the first participant private key to derive from the mnemonic. Defaults to `0`.  | `0`                                          |
| `P_SIZE`               | Optional. Number of participant private keys to derive, starting at `P_IDX_START`. Defaults to `5`. | `5`                                          |
| `ORDERS_EXPORT_URL`    | Optional. Endpoint to POST orders to when `--export` is passed to `run-epochs.sh`                   | `http://localhost:5000/api/orders`           |

---

## Run

The entrypoint `make` command:

```
make execute-pipeline
```

It computes the fork window, starts anvil, deploys, bootstraps, and runs all epochs. To enable order export, set `ORDERS_EXPORT_URL` in your `.env` and pass `--export` to `run-epochs.sh`.

`make` commands can be ran from project root or from `devtools` directory. To see a reference of available targets:

```
make help
```

> [!TIP]
> To run the full demo environment, see [dmrkt-demo](https://github.com/izcm/dmrkt-demo) (its fun and easy).
>
> It spins up both an indexer, frontend and seeds activity through using `devtools` scripts.

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

| Script               | Usage                                                                                                                                                       |
| -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pipeline-window.sh` | Computes fork start block + window timestamps and writes these to `pipeline.toml`                                                                           |
| `start-fork.sh`      | Starts the anvil fork. Reads start block from `pipeline.toml` and mnemonic from `PARTICIPANT_MNEMONIC`, defaulting to the standard junk mnemonic if not set |
| `run-epochs.sh`      | Orchestrates the full epoch pipeline for each epoch                                                                                                         |
| `export-order.sh`    | POST single order to endpoint specified as env variable `ORDER_POST_URL`. Called by `run-epochs` when `--export` is passed.                                 |

---

### Scripts — Foundry

#### Bootstrap

Many of the scripts are coupled to `OrderEngine.sol` and its EIP-712 definitions, but the scripts in `bootstrap/` are a clean exception — they just wrap ETH, mint NFTs, and set approvals. No order types, no settlement logic. Easy to drop into any Foundry project that needs funded, approved participants.

| Script                 | Description                                                                                                                                     |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `DeployCore.s.sol`     | Deploys contracts and writes addresses to pipeline.toml. Adding more nft-collections is super simple, see script's doc comment for explanation. |
| `BootstrapFunds.s.sol` | Wraps half of each participant's ETH into WETH                                                                                                  |
| `SelectNFTs.s.sol`     | Computes a deterministic token-to-participant assignment for each nft-collection in `pipeline.toml` and writes it to JSON. Assumes collections implement the `DNFT` interface. Minting itself happens in bash (`runners/executors/exec-mints.sh`).      |
| `Approve.s.sol`        | Grants NFT transfer auth + WETH allowance to OrderEngine                                                                                        |
| `BaseDevScript.s.sol`  | Generates private keys from given mnemonic + participant access helpers and logging utilities                                                   |
| `DevConfig.s.sol`      | Single source for reading `pipeline.toml`                                                                                                       |

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

> [!IMPORTANT]
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
