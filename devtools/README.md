# devtools

Foundry scripts glued together to simulate marketplace activity. Computes a start block (default: 28 days ago) and forks mainnet at that block.

```
pipeline-window.sh       writes fork block + timestamps
     │
start-fork.sh            spins up Anvil
     │
DeployCore               deploys OrderEngine + DMrktLoot → pipeline.toml
     │
SelectNFTs               computes token-to-participant selection → JSON
     │
wrap-weth.sh / bootstrap-nfts.sh / approve-*.sh  ──►  build tx envelopes ──► tx-manager sends them
     │
run-epochs.sh  ──loop──► BuildEpoch    generates + signs orders (JSON)
                    │     export-orders.sh  POSTs to indexer
                    │     ExecuteOrder     settles subset on-chain
                    └──── advance block time
```

<!-- TODO: this is a first pass at reflecting the tx-manager/envelope step — feel free to redraw entirely. -->

**Contents** — [Overview](#overview) · [Epochs](#epochs) · [Where to Start](#where-to-start) · [Setup](#setup) · [Pipeline Reference](#pipeline-reference)

---

## Overview

Built to simulate marketplace activity for an interactive demo. Later grew into something more generic — may be useful to devs wanting production-like activity for demos, testing, or stakeholder previews.

**The fork**

We fork mainnet instead of a blank chain. Currencies like WETH live at their real addresses, and trade receipts contain realistic block numbers.

**Participants**

Participants are derived from a mnemonic. Default participant count is 10, but can be increased / decreased without breaking the pipeline.

Participants are funded during fork startup through Anvil's `--mnemonic` flag. Set `PARTICIPANT_MNEMONIC` in your `.env` — this is now **mandatory**, not optional.

> [!WARNING]
> Don't use the standard Hardhat/Anvil junk mnemonic (`test test test ... junk`). Its `account[0]` now has contract code deployed on it on mainnet, which breaks NFT minting: `_safeMint` calls `onERC721Received` on any recipient with code, and that contract's own logic causes the mint to revert. Pick any other mnemonic for `PARTICIPANT_MNEMONIC`.

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
<change_this_its_not_good_start>

| #   | File                             | What you learn                                                                                                                                 |
| --- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`Makefile`** (targets section) | The full pipeline as named steps — what runs, in what order, and what each phase is called.                                                    |
| 2   | **`DevConfig.s.sol`**            | All the config knobs in one place — read this to better understand the pipeline context.                                                       |
| 3   | **`ops/run-epochs.sh`**          | The epoch loop in four labelled phases: BUILD → EXPORT → CHOOSE → EXECUTE. The probability decay logic is visible here too.                    |
| 4   | `BuildEpoch.s.sol`               | Implements the BUILD phase — generates and signs orders for a single epoch. Its dense; skim `run` then follow `_buildOrders` into `MarketSim`. |

**Going deeper:**

| Topic              | Read                                                                                                                                    |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Sampling           | `MarketSim.sol`                                                                                                                         |
| Order signing      | `SignOrder.s.sol`                                                                                                                       |
| Bootstrap sequence | `DeployCore` → `SelectNFTs` → `wrap-weth.sh` → `bootstrap-nfts.sh` → `approve-nft-transfer.sh` / `approve-allowances.sh` in that order. |

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

**Environment variables** (set these in `.env`)

| Var                    | Description                                                                                                                  | Example                                      |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `SOURCE_RPC`           | Mainnet RPC URL used to seed the fork                                                                                        | `https://eth-mainnet.g.alchemy.com<API_KEY>` |
| `RPC_URL`              | Local fork RPC URL                                                                                                           | `http://localhost:8545`                      |
| `PARTICIPANT_MNEMONIC` | Optional. Mnemonic for participant accounts. Defaults to the standard Hardhat/Anvil junk mnemonic.                           | `word1 word2 ... word12`                     |
| `DEPLOYER_PK`          | Optional. Private key used to deploy core contracts. Defaults to the private key of `PARTICIPANT_MNEMONIC` idx 0 if not set. | `0xabc123...`                                |
| `ORDERS_EXPORT_URL`    | Optional. Endpoint to POST orders to when `--export` is passed to `run-epochs.sh`                                            | `http://localhost:5000/api/orders`           |

<!-- TODO: confirm which of RPC_HOST/RPC_PORT are actually read from .env vs only used by start-fork.sh internally -->

**Makefile variables** (internal / overridable via `make VAR=value`, not `.env`)

| Var                   | Description                                                              | Default                              |
| --------------------- | ------------------------------------------------------------------------ | ------------------------------------ |
| `RPC_HOST`            | Anvil bind address, expects an IP address                                | `127.0.0.1`                          |
| `RPC_PORT`            | Anvil port                                                               | `8545`                               |
| `CHAIN_ID`            | Chain ID for the local fork network — set by Makefile based on `MODE`    | `31337`                              |
| `P_IDX_START`         | Index of the first participant private key to derive from the mnemonic.  | `0`                                  |
| `P_SIZE`              | Number of participant private keys to derive, starting at `P_IDX_START`. | `10`                                 |
| `TOKENS_BY_P_IDX_DIR` | <!-- TODO: describe -->                                                  | `data/31337/state/cols-mint-per-idx` |
| `TX_OUT_DIR`          | <!-- TODO: describe -->                                                  | `data/31337/state/tx-out`            |
| `TX_MANAGER_TIMESPAN` | <!-- TODO: describe -->                                                  | `600`                                |

<!-- TODO: this table is still incomplete — GROUP_IDX, MAX_P_SIZE, FUNDER_IDX, EPOCH_COUNT, MODE, SILENT, EXPORT are all Makefile vars too; add rows or decide which are worth documenting. -->

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

Located under `ops/`

| Script                    | Usage                                                                                                                                                       |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `fork/pipeline-window.sh` | Computes fork start block + window timestamps and writes these to `pipeline.toml`                                                                           |
| `fork/start-fork.sh`      | Starts the anvil fork. Reads start block from `pipeline.toml` and mnemonic from `PARTICIPANT_MNEMONIC`, defaulting to the standard junk mnemonic if not set |
| `run-epochs.sh`           | Orchestrates the full epoch pipeline for each epoch                                                                                                         |
| `orders/export-orders.sh` | POSTs built orders to `ORDERS_EXPORT_URL`. Called by `run-epochs.sh` when `--export` is passed.                                                             |

<!-- TODO: this table is incomplete — ops/ also has funding/, bootstrap/, helpers/, exec-order.sh under orders/, and tx-manager/ (documented separately below). Fill in a row per script, or per-subdirectory if that's cleaner. -->

---

### Scripts — tx-manager (TypeScript)

<!--
TODO: write this section. Rough shape to cover:

- What it is: a small viem-based dispatcher under `ops/tx-manager/` that actually sends transactions —
  none of the bash scripts below call `cast send` directly anymore.
- The envelope pattern: bash scripts (wrap-weth.sh, bootstrap-nfts.sh, distribute-eth.sh, etc.) don't send
  transactions themselves — they build a JSON array of "envelopes" (either `eth-transfer` or `contract-call`,
  see schemas.ts) describing what should be sent, and write it to a file under `TX_OUT_DIR`.
- tx-manager (`main.ts`) reads that file, and for every unsent envelope: derives the signer via
  `account-at-idx.ts`, encodes calldata via `encode-call.ts` (for contract-calls), tracks nonces per
  account, sends the tx, and polls for a receipt.
- Status lifecycle written back into the same JSON file: unsent (no status) -> pending -> success | failure.
- Retries: `is-retryable.ts` classifies errors (nonce issues, rate limits, etc.) to decide whether to
  retry a failed send or mark it permanently failed.
- Why this exists instead of just using forge scripts to broadcast: <!-- fill in your reasoning here -->

-->

---

### Scripts — Foundry

#### Bootstrap

`bootstrap/` now only holds two Foundry scripts — deployment and token selection. Funding (WETH wrapping), minting, and approvals no longer happen in Foundry; they're bash scripts under `ops/` that build tx envelopes for tx-manager to send (see the tx-manager section above).

<!-- TODO: one line here on why funding/minting/approvals moved out of Foundry and into bash+tx-manager, for anyone wondering why bootstrap/ shrank. -->

| Script                       | Description                                                                                                                                                                                                                                                           |
| ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bootstrap/DeployCore.s.sol` | Deploys contracts and writes addresses to pipeline.toml. Adding more nft-collections is super simple, see script's doc comment for explanation.                                                                                                                       |
| `bootstrap/SelectNFTs.s.sol` | Computes a deterministic token-to-participant assignment for each nft-collection in `pipeline.toml` and writes it to JSON. Assumes collections implement the `DNFT` interface. Minting itself happens in bash (`ops/bootstrap/bootstrap-nfts.sh`), reading this JSON. |
| `BaseDevScript.s.sol`        | Generates private keys from given mnemonic + participant access helpers and logging utilities                                                                                                                                                                         |
| `DevConfig.s.sol`            | Single source for reading `pipeline.toml`                                                                                                                                                                                                                             |

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
