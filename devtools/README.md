# devtools

Local development environment for simulating marketplace activity — deploys contracts, bootstraps accounts, generates orders, and runs multi-epoch settlement pipelines against an Anvil fork.

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

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Foundry (forge/cast/anvil) | ___ | |
| Node.js | ___ | for `prepare-fork.js` / `export-orders.js` |
| bash | ___ | |
| _any other deps_ | | |

---

## Quickstart

> Assumes a forked Anvil node is running. See [Fork Setup](#fork-setup).

```bash
# 1. Deploy core contracts
forge script seed/DeployCore.s.sol ...

# 2. Bootstrap accounts (wrap ETH → WETH, mint NFTs, set approvals)
forge script seed/bootstrap/BootstrapAccounts.s.sol ...
forge script seed/bootstrap/BootstrapNFTs.s.sol ...
forge script seed/bootstrap/Approve.s.sol ...

# 3. Run the epoch pipeline
./artifacts/runners/run-epochs.sh
```

---

## Fork Setup

```bash
# Set fork window (block range + timestamps) in pipeline.toml
node artifacts/fork/prepare-fork.js <seconds_ago> [end_ts]

# Start Anvil fork
./artifacts/fork/start-fork.sh
```

| Env var | Default | Description |
|---------|---------|-------------|
| `RPC_HOST` | `localhost` | Fork RPC host |
| `RPC_PORT` | ___ | Fork RPC port |
| `CHAIN_ID` | ___ | |

---

## Configuration — `pipeline.toml`

Shared state file written by deploy scripts and read by pipeline runners.

| Key | Set by | Description |
|-----|--------|-------------|
| `weth` | DeployCore | WETH token address |
| `order_engine` | DeployCore | OrderEngine contract address |
| `collections` | DeployCore | NFT collection addresses |
| `fork_start_block` | prepare-fork.js | Block to fork from |
| `pipeline_start_ts` | prepare-fork.js | Epoch window start |
| `pipeline_end_ts` | prepare-fork.js | Epoch window end |

---

## Pipeline Overview

Each epoch: **build orders → sign → export to indexer → execute subset on-chain → advance time**

**Execution probability** decays exponentially across epochs (p₀ = 0.9 → pMin = 0.5) to simulate realistic fill rates.

---

## Scripts Reference

| Script | Location | Usage |
|--------|----------|-------|
| `start-fork.sh` | `artifacts/fork/` | Start Anvil fork |
| `prepare-fork.js` | `artifacts/fork/` | Set fork block + timestamps |
| `run-epochs.sh` | `artifacts/runners/` | Orchestrate full epoch pipeline |
| `export-order.sh` | `artifacts/exporters/` | POST single order to indexer |
| `export-orders.js` | `artifacts/exporters/` | Bulk export to local backend |

### `run-epochs.sh` env vars

| Var | Default | Description |
|-----|---------|-------------|
| `INDEXER_URL` | ___ | Order indexer endpoint |
| `CHAIN_ID` | ___ | |
| _others_ | | |

---

## Contracts Reference

### Seed (deploy + bootstrap)

| Contract | Description |
|----------|-------------|
| `DeployCore.s.sol` | Deploys OrderEngine + DMrktLoot, writes addresses to pipeline.toml |
| `BootstrapAccounts.s.sol` | Wraps half of each participant's ETH into WETH |
| `BootstrapNFTs.s.sol` | Mints DMrktLoot tokens to all participants |
| `Approve.s.sol` | Grants NFT + WETH approvals to the order engine |
| `BaseDevScript.s.sol` | Base: mnemonic key derivation, 10 participants, logging helpers |
| `DevConfig.s.sol` | Reads pipeline.toml into typed config struct |

### Pipelines

| Contract | Description |
|----------|-------------|
| `BuildEpoch.s.sol` | Samples + prices + signs orders for an epoch; exports to JSON |
| `ExecuteOrder.s.sol` | Settles a single order on-chain via OrderEngine.settle() |
| `OrderSampling.s.sol` | Pseudo-random token selection across collections |
| `EpochsJson.s.sol` | JSON serialization for orders, nonces, selections |
| `SettlementSigner.s.sol` | EIP-712 order signing |
| `SettlementValidation.s.sol` | Pre-settlement timestamp + ownership checks |
| `FillBid.s.sol` | Resolves fill recipient for regular and collection bids |

### Local NFTs (demo only)

| Contract | Description |
|----------|-------------|
| `DMrktLoot.sol` | ERC721, 500 supply, fully on-chain SVG metadata |
| `DMrktNFTLib.sol` | Trait generation: rarity, elements, stats, color palette, SVG builders |
| `DMrktMathConfig.sol` | Constants: supply, rarity tiers, stat bonuses, element modulos |

---

## Pricing Model

Orders are priced relative to a base unit, modified by NFT traits:

| Trait | Multiplier |
|-------|-----------|
| Legendary | 8× base |
| Epic | 4× base |
| Rare | 2× base |
| Common | 1× base |
| Thunder element | +5% |
| Fire element | +5% |

---

## Data Layout

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
