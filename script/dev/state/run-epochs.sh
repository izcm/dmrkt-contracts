#!/bin/bash

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"
YELLOW="\033[0;33m" # todo: change reverts to yellow

if [ -z "$PIPELINE_STATE_DIR" ]; then
        echo "${RED}PIPELINE_STATE_DIR not set (expected from Makefile)${RESET}"
    exit 1
fi

if [ -z "$1" ]; then
    echo "${RED}Missing Argument - Usage: execute-epoch.sh epoch_count${RESET}"
    exit 1
fi

epoch_count=$1

TOML="./pipeline.toml"

# -------------------------
# PHASE 0: CONFIG / CTX
#--------------------------

START_TS=$(awk -F ' ' '$1=="pipeline_start_ts" { print $3 }' $TOML)
END_TS=$(awk -F ' ' '$1=="pipeline_end_ts" { print $3 }' $TOML)

delta=$(( END_TS - START_TS ))

if ((delta < epoch_count )); then
    echo "epoch size would be 0 - invalid config"
    exit 1
fi

epoch_slice=$(( delta / epoch_count ))

epoch_sleep_time=2
export_sleep_time=0.2

for ((epoch=0; epoch<epoch_count; epoch++));
do
    # TMP: use full delta instead of epoch_slice as build_script.TIME_WINDOW
    # - all orders across epochs will have start/end timestamps valid at pipeline_end_ts
    # - any unsettled order will be valid for demo user to settle themselves in the dmrkt frontend

    #--------------------------
    # PHASE 1: BUILD ORDERS
    #--------------------------
    
    echo
    echo "=== PHASE 1: BUILD ORDERS (epoch $epoch) ==="
    
    forge script "$DEV_STATE"/BuildEpoch.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --sender "$FUNDER" \
        --private-key "$FUNDER_PK" \
        --sig "run(uint256,uint256)" \
        $epoch $delta  \

    sleep $epoch_sleep_time
    
    order_count=$(cat "$PIPELINE_STATE_DIR/epoch_$epoch/order-count.txt")

    #--------------------------
    # PHASE 2: EXPORT ORDERS
    #--------------------------
    
    echo
    echo "=== PHASE 2: EXPORT ORDERS (epoch $epoch) ==="
    echo "orders: $order_count"
    
    for((i = 0; i < order_count; i++)); do
        "$DEV_STATE/export-order.sh" "$PIPELINE_STATE_DIR/epoch_$epoch/orders/order_$i.json"
    done
    
    #--------------------------
    # PHASE 3: EXECUTE ORDERS
    #--------------------------

    echo
    echo "=== PHASE 3: EXECUTE ORDERS (epoch $epoch) ==="
    echo "orders: $order_count"

    success=0
    fail=0

    base_step=$((epoch_slice / order_count))

    for((i = 0; i < order_count; i++)); do
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

            echo -e "[$ts] [epoch:$epoch] [order:$i] ${GREEN}EXECUTED${RESET}"
            ((success++))
        else
            echo -e "[$ts] [epoch:$epoch] [order:$i] ${YELLOW}REVERTED${RESET}"

            ((fail++))
        fi

    done
    echo "Epoch $epoch summary:"
    echo -e "   Executed: $success"
    echo -e "   Reverted: $fail"

    sleep $epoch_sleep_time
done

# final block
cast rpc evm_mine "$(date +%s)" \
    --rpc-url "$RPC_URL"

echo "✔ All epochs completed!"

OUT_FILE="data/31337/latest-block.txt"

echo "Latest block saved to ${OUT_FILE}"

cast block latest --rpc-url "$RPC_URL" > ${OUT_FILE}