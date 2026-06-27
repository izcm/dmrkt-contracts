#!/bin/bash
# Executes pre-built orders in realtime against a live network (e.g. Sepolia).
#
# Unlike run-epochs, this script does not replay history — it submits orders as-is.
# Orders are built by BuildEpoch.s.sol using timestamps from pipeline.toml.
#
# On a live network, evm_increaseTime is not available, so block timestamps cannot be rewound.
# Orders may fail if the current block timestamp falls outside an order's validity window.

# Asuumptions:
# - filenames in ORDERS_DIR with format order_x.json

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"
YELLOW="\033[0;33m" 

USAGE_MSG="Usage: ./$(basename "$0") <path_to_orders_json> <order_percantage_to_execute>"
: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

# positional args
ORDERS_DIR="$1" # path to generated eip-712 orders
EXEC_RATE="$2"

if ! [[ "$EXEC_RATE" =~ ^[1-9][0-9]?$|^100$ ]] ; then
    echo "error: <order_percantage_to_execute> must be a number between 1-100"
    echo "$USAGE_MSG"
    exit 1
fi

# --- PREREQUISITES ---

# count orders
ORDER_COUNT=$(find "$ORDERS_DIR" -maxdepth 1 -name "order_*" -printf '.' | wc -m)
(( ORDER_COUNT )) || { echo "no orders to execute in $ORDERS_DIR"; exit 1; }

# count orders to execute
EXEC_LIMIT=$(( ORDER_COUNT * EXEC_RATE / 100 ))
(( EXEC_LIMIT )) || { echo "no orders to execute when rate is $EXEC_RATE"; exit 1; }

# compute deployer
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

# read rpc's chainId
CHAIN_ID=$(cast chain-id --rpc-url "$RPC_URL")

# read pipeline window from .toml (order.end will always be valid when date.now() < END_TS )
toml_get() {
    local key="$1"
    local val
    val=$(awk "/^\[$CHAIN_ID\.uint\]/{found=1; next} found && \$1=="\"$key"\"{print \$3; exit} /^\[/{if(found) exit}" "$TOML")
    : "${val:?error: $key not found for chain $CHAIN_ID in $TOML}"
    echo "$val"
}
START_TS=$(toml_get pipeline_start_ts)
END_TS=$(toml_get pipeline_end_ts)

if (( END_TS < $(date +%s) )); then
    echo "error: pipeline window has expired"
    exit 1
fi

#--------------------------
# PHASE 1: BUILD ORDERS
#--------------------------

# sim window in seconds
DELTA=$(( END_TS - START_TS ))


forge script "$PIPELINES_EPOCHS"/BuildEpoch.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$DEPLOYER_ADDR" \
    --private-key "$DEPLOYER_PK" \
    --sig "run(uint256,uint256)" \
    0 $DELTA  \

#--------------------------
# PHASE 2: EXPORT ORDERS IF --EXPORT FLAG
#--------------------------

# export all

#--------------------------
# PHASE 3: EXECUTE ORDERS
#--------------------------

success=0
fail=0

# ADD ASYNC FLAG
for((i = 0; i < 1; i++)); do
    if "$(dirname "$0")"/executors/exec-order.sh 0 "$i" \
        --rpc-url "$RPC_URL" \
        --sender "$DEPLOYER_ADDR" \
        --private-key "$DEPLOYER_PK"
    then
        ((success++))
    else
        ((fail++))
    fi
done

echo "Summary: executed=$success reverted=$fail"