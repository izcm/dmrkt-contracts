# Centralizes call to BuildEpoch script
#
# Usage:  run-epochs.sh <epoch_count> [--export]
# Env: 
#   - PIPELINES_EPOCHS: BuildEpoch script directory

# --- prerequisites ---

# count orders
ORDER_COUNT=$(find "$PIPELINES_EPOCHS"/BuildEpoch.s.sol )

(( ORDER_COUNT )) || { echo "no orders to execute in $ORDERS_DIR"; exit 1; }

# compute deployer (script runner)
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

# sim window (in seconds)
START_TS=$(awk -F ' ' '$1=="pipeline_start_ts" { print $3 }' "$TOML")
END_TS=$(awk -F ' ' '$1=="pipeline_end_ts" { print $3 }' "$TOML")

DELTA=$(( END_TS - START_TS ))




