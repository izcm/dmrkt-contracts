#!/bin/bash

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"

EPOCH_COUNT=$1
EPOCH_SIZE=$2

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Missing Arguments - Usage: execute-epoch.sh EPOCH_START EPOCH_END EPOCH_SIZE"
    exit 1
fi

SLEEP_SECONDS=2

STATE_DIR="$PROJECT_ROOT/data/1337/state"

for ((epoch=0; epoch<EPOCH_COUNT; epoch++));
do
    echo "🧱 Building history for epoch $epoch"

    forge script "$DEV_STATE"/BuildHistory.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --sender "$SENDER" \
        --private-key "$PRIVATE_KEY" \
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

        cast rpc evm_increaseTime $time_jump --quiet

        if forge script "$DEV_STATE"/ExecuteOrder.s.sol \
            --rpc-url "$RPC_URL" \
            --broadcast \
            --sender "$SENDER" \
            --private-key "$PRIVATE_KEY" \
            --sig "run(uint256,uint256)" \
            --silent \
            $epoch $i
        then
            mined_at=$(cast block latest -f timestamp)
            ts=$(date -d @"$mined_at" "+%Y-%m-%d %H:%M:%S")

            echo -e "[${ts}] [epoch:${epoch}] [order:${i}] ${GREEN}EXECUTED${RESET}"
            ((success++))
        else
            echo -e "[${ts}] [epoch:${epoch}] [order:${i}] ${RED}REVERTED${RESET}"

            ((fail++))
        fi

    done
    echo "📊 Epoch $epoch summary:"
    echo "   ✅ Executed: $success"
    echo "   ❌ Reverted: $fail"

    sleep $SLEEP_SECONDS
done

echo "✔ All epochs completed!"

OUT_FILE="data/1337/latest-block.txt"

echo "Latest block saved to ${OUT_FILE}"

cast block latest > ${OUT_FILE}