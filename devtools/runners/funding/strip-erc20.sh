#!/bin/bash

USAGE_MSG="Usage: strip-erc20.sh <from_count> <destination_address> <token_address> --rpc-url <url> [--start-idx <idx>] [--amount <wei>] [--sync]"

: ${1:?"$USAGE_MSG"}
: ${2:?"$USAGE_MSG"}
: ${3:?"$USAGE_MSG"}

FROM_COUNT=$1
DEST_ADDR=$2
TOKEN_ADDR=$3

shift 3

START_IDX=0
TOKENS_PER_SENDER=""
OUT_FILE=""
ASYNC_FLAG="--async"

# flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) RPC_URL="$2" shift 2 ;;
        --amount) TOKENS_PER_SENDER="$2" shift 2 ;;
        --out-file) OUT_FILE="$2"; shift 2 ;;
        --sync) ASYNC_FLAG=""; shift ;;
         *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

[[ -n "$OUT_FILE" ]] && > "$OUT_FILE"

PHRASE="$PARTICIPANT_MNEMONIC"

# get symbol
TOKEN_SYMBOL=$(cast call "$TOKEN_ADDR" "symbol()(string)" 2>/dev/null) 
TOKEN_SYMBOL="${TOKEN_SYMBOL//\"/}"
TOKEN_SYMBOL="${TOKEN_SYMBOL:-UNKNOWN}"

echo "Start $TOKEN_SYMBOL strip"
echo "$DEST_ADDR is the destination address"

# loop through each participant, use mnemonic index to find their keys and address
for ((i = START_IDX; i < START_IDX + FROM_COUNT; i++)); do
    p_key=$(cast wallet private-key --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")
    p_addr=$(cast wallet address --private-key "$p_key")

    # skip if the currenc address is same as destination
    [[ "$p_addr" == "$DEST_ADDR" ]] && continue

    # no --amount flag ?? strip all tokens 
    send_amount="$TOKENS_PER_SENDER"
    if [[ -z "$send_amount" ]]; then
        balance=$(
            cast erc20-token balance "$TOKEN_ADDR" "$p_addr" --rpc-url "$RPC_URL" | awk '{ print $1 }'
        )
        [[ "$balance" == "0" ]] && continue

        send_amount="$balance"
    fi

    echo "[$i] sending $send_amount $TOKEN_SYMBOL from $p_addr"

    tx_hash=$(
        cast erc20-token transfer "$TOKEN_ADDR" "$DEST_ADDR" "$send_amount"\
            $ASYNC_FLAG \
            --rpc-url $RPC_URL \
            --private-key $p_key \
        )

    [[ -n "$OUT_FILE" ]] && echo "$tx_hash" >> "$OUT_FILE"

done

