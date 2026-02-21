# The off-chain tooling

_The star of the show ⭐_

The next section covers the main part of this demo: the dev-tooling.

These scripts run only on a local development chain and are not connected to any real contracts or funds. They intentionally poke and reshape state to build predictable orderbook scenarios for the indexer.

**🟡 Runs only on a local chain.**

---

## Artifacts

The `selections` folder (per epoch:collection) contains the tokenIds chosen for either on-chain execution (ownership change) or skipping.

Skipped tokens correspond to orders that are exported to the indexer but intentionally not executed on-chain.

TokenIds from skipped orders are written to `ensure-lingers.json`, an artifact shared between all epochs.

The pipeline builder uses this file to avoid modifying their ownership state. This guarantees the orders remain fillable at the end of the pipeline.
