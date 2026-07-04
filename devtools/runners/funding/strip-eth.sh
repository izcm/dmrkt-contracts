#!/bin/bash
#
# Strip eth from the PARTICIPANT_GROUP
# Iterate from start_index to p_count and transfer wei_per_p to destination address. 
#
USAGE_MSG="Usage: strip-eth.sh <from_count> <destination_address> --rpc-url <url> [--start-idx <idx>] [--amount <wei>] [--sync]"

# positional / flag args
: ${1:?"$USAGE_MSG"}
: ${2:?"$USAGE_MSG"}

FROM_COUNT=$1
DEST_ADDR=$2

shift 2

START_IDX=0
WEI_PER_RECIPIENT="" # empty -> strip full balance (minus gas)
GAS_LIMIT=21000
ASYNC_FLAG="--async" # --sync (used by rotate-eth.sh) drops this so callers can wait for confirmation

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) WEI_PER_RECIPIENT="$2"; shift 2 ;;
        --sync) ASYNC_FLAG=""; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"
: "${PARTICIPANT_MNEMONIC:?PHRASE not set}"
PHRASE="$PARTICIPANT_MNEMONIC"

echo "Start stripping"
echo "$DEST_ADDR is the destination address"

for ((i = START_IDX; i < START_IDX + FROM_COUNT; i++)); do
    p_key=$(cast wallet private-key --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")
    p_addr=$(cast wallet address --private-key "$p_key")

    [[ "$p_addr" == "$DEST_ADDR" ]] && continue

    send_amount="$WEI_PER_RECIPIENT"
    if [[ -z "$send_amount" ]]; then
        # no fixed amount -> drain the full balance, minus enough to cover this tx's own gas
        balance=$(cast balance "$p_addr" --rpc-url "$RPC_URL")
        [[ "$balance" == "0" ]] && continue

        gas_price=$(cast gas-price --rpc-url "$RPC_URL")
        gas_units=$(cast estimate "$DEST_ADDR" --value "$balance" --rpc-url "$RPC_URL")
        gas_cost=$(echo "$gas_price * 2 * $gas_units" | bc)
        send_amount=$(echo "$balance - $gas_cost" | bc)

        if (( $(echo "$send_amount <= 0" | bc) )); then
            echo "[$i] $p_addr balance too low to cover gas — skipping"
            continue
        fi
    fi

    echo "[$i] sending $send_amount wei from $p_addr"

    cast send "$DEST_ADDR" \
        $ASYNC_FLAG \
        --value "$send_amount" \
        --private-key "$p_key" \
        --rpc-url "$RPC_URL" \
        --gas-limit "$GAS_LIMIT"
done
