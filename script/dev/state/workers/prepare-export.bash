#!/bin/bash

# script is ment to be run after run-epoch.sh
# is assumes fork has forwarded and depends on these assumptions!

# this script only builds orders (no time warping)
OUT="$PROJECT_ROOT/data/31337/state/active_orders"

# run-epoch.sh has forwarded fork to approx END_TS
PIPELINE_START_TS=$(awk -F ' ' '$1=="pipeline_start_ts" { print $3 }' "$TOML")
PIPELINE_END_TS=$(awk -F ' ' '$1=="pipeline_end_ts" { print $3 }' "$TOML")

# set EPOCH_SIZE according to how you'd like the span of order timestamps to be

# order timestamps are calculated relative to NOW_TS +/- some offset derived from EPOCH_SIZE
# larger size => orders gets end + start with larger span

# END_TS - START_TS will be the epochSize & epoch=0 
EPOCH_SIZE=$((PIPELINE_END_TS - PIPELINE_START_TS))

echo "🧱 Building active orders..."

forge script "$DEV_STATE"/BuildEpoch.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$FUNDER" \
    --private-key "$FUNDER_PK" \
    --sig "run(uint256,uint256)" \
    0 "$EPOCH_SIZE"  \

order_count=$(cat "$PIPELINE_STATE_DIR"/epoch_$epoch/order-count.txt)

echo "✔ Order build completed!"
echo "📤 $order_count orders ready for export"