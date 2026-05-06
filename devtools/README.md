# DevTools

Foundry scripts to simulate marketplace activity. Computes a start block (default: 28 days ago) and forks mainnet at that block. The pipeline goes like:

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

This pipeline was made mostly to demonstrate my own web3 skills through an interactive demo. It later developed into some pretty generic and reusable scripts, and may be of use for developers who wants to simulate a live product for stakeholders or similar use-cases.

**The fork**

We fork mainnet instead of a blank chain. Currencies like WETH live at their real addresses, and trade receipts contain realistic block numbers.

**Participants**

> _Who the actors are. Keywords: mnemonic-derived wallets, funded by anvil --balance, NFT holders, bidders, asks vs bids._

...

**The data**

> _What the pipeline produces. Keywords: signed EIP-712 orders, JSON export, indexer, on-chain settlements, multi-epoch history._

...

---

## Epochs

> _Define the term before using it anywhere. Keywords: time window, order lifecycle, start/end timestamps._

...

**What happens inside one epoch:**

- **Sampling** — ...
- **Pricing** — ...
- **Signing** — ...
- **Export** — ...
- **Execution** — ...

**Across epochs:**

> _How epochs chain together. Keywords: nonce continuity, execution probability decay, block time advancement._

...

---

## Where to Start

Skim these in order to build a mental model without reading everything:

| #   | File                                  | What you learn                                                                                                             |
| --- | ------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| 1   | **`Makefile`** (targets section)      | The full pipeline as named steps — what runs, in what order, and what each phase is called                                 |
| 2   | **`DevConfig.s.sol`**                 | All the config knobs in one place — the key list is the clearest snapshot of what state the system tracks across scripts   |
| 3   | **`artifacts/runners/run-epochs.sh`** | The epoch loop in four labelled phases: BUILD → EXPORT → CHOOSE → EXECUTE. The probability decay logic is visible here too |
| 4   | **`BuildEpoch.s.sol` → `run()` only** | What actually happens inside "build orders" — skip the private helpers on first read                                       |

**Going deeper:**

| Topic              | Read                                                                           |
| ------------------ | ------------------------------------------------------------------------------ |
| Pricing model      | `BuildEpoch.orderPrice()` + `MarketSim.sol`                                    |
| Order signing      | `SettlementSigner.s.sol`                                                       |
| NFT traits & stats | `DMrktNFTLib.sol`                                                              |
| Bootstrap sequence | `DeployCore` → `BootstrapAccounts` → `BootstrapNFTs` → `Approve` in that order |

---

## Setup

**Prerequisites**

| Tool                       | Version | Notes |
| -------------------------- | ------- | ----- |
| Foundry (forge/cast/anvil) | \_\_\_  |       |
| bash                       | \_\_\_  |       |

**Fork**

```bash
# Set fork window (block range + timestamps) in pipeline.toml
node artifacts/fork/prepare-fork.js <seconds_ago> [end_ts]

# Start Anvil fork
./artifacts/fork/start-fork.sh
```

| Env var    | Default     | Description   |
| ---------- | ----------- | ------------- |
| `RPC_HOST` | `localhost` | Fork RPC host |
| `RPC_PORT` | \_\_\_      | Fork RPC port |
| `CHAIN_ID` | \_\_\_      |               |

**Run**

Makefile (maybe move makefileinto into devtools? nah... i think its better in root)

---

## References

### Configuration — `pipeline.toml`

Shared state file written by deploy scripts and read by pipeline runners.

| Key                 | Set by          | Description                  |
| ------------------- | --------------- | ---------------------------- |
| `weth`              | DeployCore      | WETH token address           |
| `order_engine`      | DeployCore      | OrderEngine contract address |
| `collections`       | DeployCore      | NFT collection addresses     |
| `fork_start_block`  | prepare-fork.js | Block to fork from           |
| `pipeline_start_ts` | prepare-fork.js | Epoch window start           |
| `pipeline_end_ts`   | prepare-fork.js | Epoch window end             |

---

### Scripts — Bash

| Script            | Location               | Usage                           |
| ----------------- | ---------------------- | ------------------------------- |
| `start-fork.sh`   | `artifacts/fork/`      | Start Anvil fork                |
| `prepare-fork.sh` | `artifacts/fork/`      | Set fork block + timestamps     |
| `run-epochs.sh`   | `artifacts/runners/`   | Orchestrate full epoch pipeline |
| `export-order.sh` | `artifacts/exporters/` | POST single order to indexer    |

| Var           | Default | Description            |
| ------------- | ------- | ---------------------- |
| `INDEXER_URL` | \_\_\_  | Order indexer endpoint |
| `CHAIN_ID`    | \_\_\_  |                        |

---

### Scripts — Foundry

#### Bootstrap

| Contract                  | Description                                                        |
| ------------------------- | ------------------------------------------------------------------ |
| `DeployCore.s.sol`        | Deploys OrderEngine + DMrktLoot, writes addresses to pipeline.toml |
| `BootstrapAccounts.s.sol` | Wraps half of each participant's ETH into WETH                     |
| `BootstrapNFTs.s.sol`     | Mints DMrktLoot tokens to all participants                         |
| `Approve.s.sol`           | Grants NFT + WETH approvals to the order engine                    |
| `BaseDevScript.s.sol`     | Base: mnemonic key derivation, 10 participants, logging helpers    |
| `DevConfig.s.sol`         | Reads pipeline.toml into typed config struct                       |

#### Pipelines

| Contract                     | Description                                                   |
| ---------------------------- | ------------------------------------------------------------- |
| `BuildEpoch.s.sol`           | Samples + prices + signs orders for an epoch; exports to JSON |
| `ExecuteOrder.s.sol`         | Settles a single order on-chain via OrderEngine.settle()      |
| `OrderSampling.s.sol`        | Pseudo-random token selection across collections              |
| `EpochsJson.s.sol`           | JSON serialization for orders, nonces, selections             |
| `SettlementSigner.s.sol`     | EIP-712 order signing                                         |
| `SettlementValidation.s.sol` | Pre-settlement timestamp + ownership checks                   |
| `FillBid.s.sol`              | Resolves fill recipient for regular and collection bids       |

---

### Local NFTs

| Contract              | Description                                                            |
| --------------------- | ---------------------------------------------------------------------- |
| `DMrktLoot.sol`       | ERC721, 500 supply, fully on-chain SVG metadata                        |
| `DMrktNFTLib.sol`     | Trait generation: rarity, elements, stats, color palette, SVG builders |
| `DMrktMathConfig.sol` | Constants: supply, rarity tiers, stat bonuses, element modulos         |

---

### Data Layout

```
data/
└── <chainId>/
    ├── mnemonic.json          # Anvil mnemonic (gitignored)
    ├── latest-block.txt       # Written by run-epochs.sh
    └── state/
        └── epoch_N/
            ├── orders.json
            ├── nonces.json
            └── selections.json
```
