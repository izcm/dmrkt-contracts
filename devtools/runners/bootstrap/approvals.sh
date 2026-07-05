#!/bin/bash
# Usage: approve.sh <p_size> --nft-transfer-auth ADDR --token ADDR --spender ADDR \
#            --collections ADDR[,ADDR...] [--start-idx N] [--out-file FILE]
#
# For each participant in [start_idx, start_idx + p_size - 1]:
#   - setApprovalForAll(nft-transfer-auth, true) on every collection
#   - approve(spender, max) on the given ERC20 token (e.g. WETH)
# Runs one process per participant in parallel (5 at a time).

USAGE_MSG="Usage: $(basename "$0") <p_size> --nft-transfer-auth ADDR --token ADDR --spender ADDR --collections ADDR[,ADDR...] [--start-idx N] [--out-file FILE]"

: "${1:?$USAGE_MSG}"

P_SIZE=$1
shift

START_IDX=0
OUT_FILE=""
NFT_TRANSFER_AUTH=""
TOKEN=""
SPENDER=""
COLLECTIONS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --nft-transfer-auth) NFT_TRANSFER_AUTH="$2"; shift 2 ;;
        --token) TOKEN="$2"; shift 2 ;;
        --spender) SPENDER="$2"; shift 2 ;;
        --collections) COLLECTIONS="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --out-file) OUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${NFT_TRANSFER_AUTH:?$USAGE_MSG}"
: "${TOKEN:?$USAGE_MSG}"
: "${SPENDER:?$USAGE_MSG}"
: "${COLLECTIONS:?$USAGE_MSG}"

PHRASE="$PARTICIPANT_MNEMONIC"

IFS=',' read -ra COLLECTION_ARR <<< "$COLLECTIONS"

export PHRASE NFT_TRANSFER_AUTH TOKEN SPENDER

[[ -n "$OUT_FILE" ]] && > "$OUT_FILE"

run_one() {
    local idx=$1
    local out_file=$2
    shift 2
    local collections=("$@")

    p_key=$(cast wallet private-key "${PHRASE//\"/}" "$idx")
    p_addr=$(cast wallet address "$p_key")

    nonce=$(cast nonce "$p_addr" --rpc-url "$RPC_URL")

    for collection in "${collections[@]}"; do
        tx_hash=$(cast send "$collection" "setApprovalForAll(address,bool)" "$NFT_TRANSFER_AUTH" true \
            --async \
            --private-key "$p_key" \
            --rpc-url "$RPC_URL" \
            --nonce "$nonce")

        [[ -n "$out_file" ]] && echo "$tx_hash" >> "$out_file"
        ((nonce++))
    done

    tx_hash=$(cast send "$TOKEN" "approve(address,uint256)" "$SPENDER" \
        "115792089237316195423570985008687907853269984665640564039457584007913129639935" \
        --async \
        --private-key "$p_key" \
        --rpc-url "$RPC_URL" \
        --nonce "$nonce")

    [[ -n "$out_file" ]] && echo "$tx_hash" >> "$out_file"

    echo "[idx $idx] sent transfer approval tx (to $NFT_TRANSFER_AUTH) on ${#collections[@]} collection(s)"
    echo "[idx $idx] sent max $TOKEN allowance tx to $SPENDER"
}
export -f run_one

seq "$START_IDX" $((START_IDX + P_SIZE - 1)) | xargs -P 5 -I{} bash -c 'run_one "$0" "$1" "${@:2}"' {} "$OUT_FILE" "${COLLECTION_ARR[@]}"
