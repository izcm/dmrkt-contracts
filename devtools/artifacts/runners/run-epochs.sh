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

# --- compute address 0 from mnemonic and use as funder ---
PHRASE=$(jq -r .mnemonic "$MNEMONIC_JSON")

DEPLOYER_PK=$(cast wallet private-key --mnemonic "$PHRASE" --mnemonic-index 0)
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

# --- timestamps and epochs ---

START_TS=$(awk -F ' ' '$1=="pipeline_start_ts" { print $3 }' $TOML)
END_TS=$(awk -F ' ' '$1=="pipeline_end_ts" { print $3 }' $TOML)

delta=$(( END_TS - START_TS ))

if ((delta < epoch_count )); then
    echo "epoch size would be 0 - invalid config"
    exit 1
fi

epoch_slice=$(( delta / epoch_count ))
epoch_sleep_time=2

# --- logic for counting orders to execute ---

p0=0.9      # probability of execution epoch 0
pMin=0.5    # min probability
k=0.2       # rate constant

# --- helpers ---

ensure_json() {
    local file=$1
    local c_addr=$2

    if [ ! -f "$file" ]; then
        jq -n --arg "c_addr" "$c_addr" '{collection:$c_addr, tokenIds:[]}' > "$file"
    fi
}

add_token() {
    local file="$1"
    local col="$2"
    local tid="$3"

    ensure_json "$file" "$col"

    tmpfile=$(mktemp)

    jq --argjson tid "$tid" ' 
        if (.tokenIds | index($tid)) == null then
            .tokenIds += [$tid] else . end ' \
            "$file" > "$tmpfile" && mv "$tmpfile" "$file"
}

for ((epoch=0; epoch < epoch_count; epoch++));
do
    # TMP: use full delta instead of epoch_slice as build_script.TIME_WINDOW
    # - all orders across epochs will have start/end timestamps valid at pipeline_end_ts
    # - any unsettled order will be valid for demo user to settle themselves in the dmrkt frontend

    #--------------------------
    # PHASE 1: BUILD ORDERS
    #--------------------------
    
    echo
    echo "=== PHASE 1: BUILD ORDERS (epoch $epoch) ==="
    
    forge script "$PIPELINES_EPOCHS"/BuildEpoch.s.sol \
        --rpc-url "$RPC_URL" \
        --broadcast \
        --sender "$DEPLOYER_ADDR" \
        --private-key "$DEPLOYER_PK" \
        --sig "run(uint256,uint256)" \
        $epoch $delta  \

    sleep $epoch_sleep_time
    
    order_count=$(cat "$PIPELINE_STATE_DIR/epoch_$epoch/order-count.txt")
    order_out="$PIPELINE_STATE_DIR/epoch_$epoch/orders"

    #--------------------------
    # PHASE 2: EXPORT ORDERS
    #--------------------------
    
    echo
    echo "=== PHASE 2: EXPORT ORDERS (epoch $epoch) ==="
    echo "orders: $order_count"
    
    for((i = 0; i < order_count; i++)); do
        if "$ARTIFACTS_EXPORTERS/export-order.sh" \
            "$order_out/order_$i.json"
        then
            echo -e "[epoch:$epoch] [order:$i] ${GREEN}EXPORTED${RESET}"
        else
            echo -e "[epoch:$epoch] [order:$i] ${RED}EXPORT_ERR${RESET}"
        fi
    done
    
    #--------------------------
    # PHASE 3: CHOOSE LINGER
    #--------------------------
    
    echo
    echo "=== PHASE 3: EXECUTE ORDERS (epoch $epoch) ==="
    
     # --- compute orders to execute ---
    
    p=$(awk -v p0="$p0" -v pMin="$pMin" -v k=$k -v epoch="$epoch" \
        'BEGIN { print pMin - (pMin - p0) * exp( -k * epoch )}')

    exec_limit=$(awk -v p="$p" -v order_count="$order_count" \
        'BEGIN { printf "%d", p * order_count}')

    if (( exec_limit == 0)); then
        echo "No executions this epoch"
        continue
    fi

    echo
    echo "orders to skip:    $((order_count - exec_limit))"
    echo "orders to execute: $exec_limit"
    echo 

    #--------------------------
    # PHASE 4: EXECUTE ORDERS
    #--------------------------

    success=0
    fail=0

    # base_step=$((epoch_slice / order_count))
    base_step=$((epoch_slice / exec_limit))

    for((i = 0; i < exec_limit; i++)); do
        offset=$(((i % 5) - 2))
        time_jump=$((base_step + offset))

        cast rpc evm_increaseTime $time_jump \
            --rpc-url "$RPC_URL" \
            --quiet

        if forge script "$PIPELINES_EXECUTION"/ExecuteOrder.s.sol \
            --rpc-url "$RPC_URL" \
            --broadcast \
            --sender "$DEPLOYER_ADDR" \
            --private-key "$DEPLOYER_PK" \
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