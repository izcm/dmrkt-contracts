#!/bin/bash

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"

EPOCH_COUNT=$1

if [ -z "$1" ]; then
    echo "Missing Argument - Usage: execute-epoch.sh EPOCH_COUNT"
    exit 1
fi

TOML="./pipeline.toml"

START_TS=$(awk -F ' ' '$1=="pipeline_start_ts" { print $3 }' $TOML)
END_TS=$(awk -F ' ' '$1=="pipeline_end_ts" { print $3 }' $TOML)

DELTA=$(( END_TS - START_TS ))

if ((DELTA < EPOCH_COUNT )); then
    echo "epoch size would be 0 - invalid config"
    exit 1
fi

EPOCH_SIZE=$(( DELTA / EPOCH_COUNT ))

SLEEP_SECONDS=2

STATE_DIR="$PROJECT_ROOT/data/1337/state"

for ((epoch=0; epoch<EPOCH_COUNT; epoch++));
do
    echo "🧱 Building orders for epoch $epoch"

    forge script "$DEV_STATE"/BuildEpoch.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --sender "$FUNDER" \
        --private-key "$FUNDER_PK" \
        --sig "run(uint256,uint256)" \
        $epoch "$EPOCH_SIZE"  \

    sleep $SLEEP_SECONDS
    
    order_count=$(cat "$STATE_DIR"/epoch_$epoch/order-count.txt)
    
    echo "🎬 Executing $order_count orders in epoch $epoch..."

    success=0
    fail=0

    base_step=$((EPOCH_SIZE / order_count))

    #cast rpc evm_increaseTime $EPOCH_SIZE
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
            echo -e "[${ts}] [epoch:${epoch}] [order:${i}] ${RED}REVERTED${RESET}"

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

OUT_FILE="data/1337/latest-block.txt"

echo "Latest block saved to ${OUT_FILE}"

cast block latest --rpc-url "$RPC_URL" > ${OUT_FILE}