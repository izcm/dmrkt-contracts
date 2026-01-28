#!/bin/bash

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"
YELLOW="\033[0;33m" # todo: change reverts to yellow

if [ -z "$EPOCHS_STATE_DIR" ]; then
    echo "${RED}EPOCHS_STATE_DIR not set (expected from Makefile)${RESET}"
    exit 1
fi

if [ -z "$1" ]; then
    echo "${RED}Missing Argument - Usage: execute-epoch.sh EPOCH_COUNT${RESET}"
    exit 1
fi

EPOCH_COUNT=$1

TOML="./pipeline.toml"

# -------------------------
# PHASE 0: CONFIG / CTX
#--------------------------

START_TS=$(awk -F ' ' '$1=="pipeline_start_ts" { print $3 }' $TOML)
END_TS=$(awk -F ' ' '$1=="pipeline_end_ts" { print $3 }' $TOML)

DELTA=$(( END_TS - START_TS ))

if ((DELTA < EPOCH_COUNT )); then
    echo "epoch size would be 0 - invalid config"
    exit 1
fi

EPOCH_SLICE=$(( DELTA / EPOCH_COUNT ))

SLEEP_SECONDS=2

for ((epoch=0; epoch<EPOCH_COUNT; epoch++));
do
    echo "🧱 Building orders for epoch $epoch"

    # TMP: use full DELTA as order validity window
    # - all orders valid for entire simulation
    # - execution logic does not reason about time
    # - failures reflect logic/economics, not scheduling
    # - orders always valid for Date.now()

    #--------------------------
    # PHASE 1: BUILD ORDERS
    #--------------------------

    forge script "$DEV_STATE"/BuildEpoch.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --sender "$FUNDER" \
        --private-key "$FUNDER_PK" \
        --sig "run(uint256,uint256)" \
        $epoch "$DELTA"  \

    sleep $SLEEP_SECONDS
    
    order_count=$(cat "$EPOCHS_STATE_DIR"/epoch_$epoch/order-count.txt)

    #--------------------------
    # PHASE 2: EXPORT ORDERS
    #--------------------------
    

    # TODO: EXPORT ORDERS TO INDEXER
    
    #--------------------------
    # PHASE 3: EXECUTE ORDERS
    #--------------------------

    echo "🎬 Executing $order_count orders in epoch $epoch..."

    success=0
    fail=0

    base_step=$((EPOCH_SLICE / order_count))

    #cast rpc evm_increaseTime $EPOCH_SLICE
    #cast rpc evm_mine

    for((i=0; i < order_count; i++)); do
        offset=$(((i % 5) - 2))
        time_jump=$((base_step + offset))

        cast rpc evm_increaseTime $time_jump \
            --rpc-url "$RPC_URL" \
            --quiet

        if forge script "$DEV_STATE"/ExecuteOrder.s.sol \
            --rpc-url "$RPC_URL" \
            --broadcast \
            --sender "$FUNDER" \
            --private-key "$FUNDER_PK" \
            --sig "run(uint256,uint256)" \
            --silent \
            $epoch $i
        then
            mined_at=$(cast block latest \
                --rpc-url "$RPC_URL" \
                -f timestamp)

            ts=$(date -d @"$mined_at" "+%Y-%m-%d %H:%M:%S")

            echo -e "[${ts}] [epoch:${epoch}] [order:${i}] ${GREEN}EXECUTED${RESET}"
            ((success++))
        else
            echo -e "[${ts}] [epoch:${epoch}] [order:${i}] ${YELLOW}REVERTED${RESET}"

            ((fail++))
        fi

    done
    echo "Epoch $epoch summary:"
    echo -e "   Executed: $success"
    echo -e "   Reverted: $fail"

    sleep $SLEEP_SECONDS
done

# final block
cast rpc evm_mine "$(date +%s)" \
    --rpc-url "$RPC_URL"

echo "✔ All epochs completed!"

OUT_FILE="data/31337/latest-block.txt"

echo "Latest block saved to ${OUT_FILE}"

cast block latest --rpc-url "$RPC_URL" > ${OUT_FILE}