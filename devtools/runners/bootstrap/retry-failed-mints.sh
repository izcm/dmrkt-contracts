#!/bin/bash
# Usage: retry-failed-mints.sh <collection> [--out-file FILE]
#
# One-off retry for the handful of idx/tokenId pairs that came back
# NOT MINTED / NETWORK ERROR from the last exec-mints.sh run.

USAGE_MSG="Usage: $(basename "$0") <collection> [--out-file FILE]"

: "${1:?$USAGE_MSG}"

collection=$1
shift

OUT_FILE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --out-file) OUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="$PARTICIPANT_MNEMONIC"

declare -A RETRY_TOKENS=(
    [1]="185"
    [6]="394 417"
    [7]="257 284 291 341 343 393"
    [24]="237"
)

for idx in "${!RETRY_TOKENS[@]}"; do
    p_key=$(cast wallet private-key "${PHRASE//\"/}" "$idx")
    p_addr=$(cast wallet address "$p_key")

    nonce=$(cast nonce "$p_addr" --rpc-url "$RPC_URL" -B pending)
    gas_price=$(cast gas-price --rpc-url "$RPC_URL")
    boosted_gas_price=$(echo "$gas_price * 2" | bc)

    for tokenId in ${RETRY_TOKENS[$idx]}; do
        tx_hash=$(
            cast send "$collection" "mint(address,uint256)" "$p_addr" "$tokenId" \
            --async \
            --private-key "$p_key" \
            --rpc-url "$RPC_URL" \
            --nonce "$nonce" \
            --gas-price "$boosted_gas_price" 2>&1
        )

        echo "[idx $idx] tokenId $tokenId -> $tx_hash"

        if [[ "$tx_hash" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
            ((nonce++))
            [[ -n "$OUT_FILE" ]] && echo "$tx_hash" >> "$OUT_FILE"
        fi

        sleep 2
    done
done
