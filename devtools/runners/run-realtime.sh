#!/bin/bash
# Executes pre-built orders in realtime against a live network (e.g. Sepolia).
#
# Unlike run-epochs, this script does not replay history — it submits orders as-is.
# Orders are built by BuildEpoch.s.sol using timestamps from pipeline.toml.
#
# On a live network, evm_increaseTime is not available, so block timestamps cannot be rewound.
# Orders may fail if the current block timestamp falls outside an order's validity window.
#
# Asuumptions:
# - filenames in ORDERS_DIR with format order_x.json
# Usage: ./$(basename "$0") <order_percentage_to_execute> <nonce_seed> [--export] [--gap <n>]
#
# nonce_seed:
#   Used on testnets when rebuilding orders. It is forwarded to BuildEpoch so
#   newly generated orders use different nonces and don't clash with orders
#   from previous runs.
#

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"
YELLOW="\033[0;33m" 

USAGE_MSG="Usage: ./$(basename "$0") <order_percantage_to_execute> <nonce_seed> [--export] [--gap <n>]"

# positional args
: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"
EXEC_RATE="$1"
NONCE_SEED="$2"
shift 2

EXPORT_ORDERS=false
GAP=25

while [[ $# -gt 0 ]]; do
    case "$1" in
        --export) EXPORT_ORDERS=true; shift ;;
        --gap) GAP="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; echo "$USAGE_MSG"; exit 1 ;;
    esac
done

echo "order_percentage=$EXEC_RATE nonce_seed=$NONCE_SEED gap=$GAP export=$EXPORT_ORDERS"

# expected env vars
: "${PIPELINE_STATE_DIR:?PIPELINE_STATE_DIR not set}"
: "${TOML:?TOML not set}"


if ! [[ "$EXEC_RATE" =~ ^[1-9][0-9]?$|^100$ ]] ; then
    echo "error: <order_percantage_to_execute> must be a number between 1-100"
    echo "$USAGE_MSG"
    exit 1
fi

# --- PREREQUISITES ---

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

if [ "$EXPORT_ORDERS" = "true" ]; then
    : "${ORDERS_EXPORT_URL:?ORDERS_EXPORT_URL not set}"
fi

#--------------------------
# PHASE 1: BUILD ORDERS
#--------------------------

ORDER_OUT="$PIPELINE_STATE_DIR/epoch_0/orders" 

echo
echo "=== PHASE 1: BUILD ORDERS ==="

# sim window in seconds
DELTA=$(( END_TS - START_TS ))

forge script "$PIPELINE_EPOCHS"/BuildEpoch.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$DEPLOYER_ADDR" \
    --private-key "$DEPLOYER_PK" \
    --sig "run(uint256,uint256,uint256,uint256)" \
    -vvvv \
    0 $DELTA $GAP $NONCE_SEED

# count orders
order_count=$(find "$ORDER_OUT" -maxdepth 1 -name "order_*" -printf '.' | wc -m)
(( order_count )) || { echo "no orders to execute in $ORDER_OUT"; exit 1; }

# count orders to execute
EXEC_LIMIT=$(( order_count * EXEC_RATE / 100 ))
(( EXEC_LIMIT )) || { echo "no orders to execute when rate is $EXEC_RATE"; exit 1; }

#--------------------------
# PHASE 2: EXPORT ORDERS IF --EXPORT FLAG
#--------------------------

 if [ "$EXPORT_ORDERS" = "true" ]; then
    echo
    echo "=== PHASE 2: EXPORT ORDERS ==="
    echo "orders: $order_count"

    "$RUNNERS_EXPORTERS/export-orders.sh" "$ORDER_OUT" "$order_count" \
        --chain-id "$CHAIN_ID" \
        --export-url "$ORDERS_EXPORT_URL"
fi

#--------------------------
# PHASE 3: EXECUTE ORDERS
#--------------------------

echo
echo "=== PHASE 3: EXECUTE ORDERS ==="

success=0
fail=0

# later: ADD ASYNC FLAG
for((i = 0; i < EXEC_LIMIT; i++)); do
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