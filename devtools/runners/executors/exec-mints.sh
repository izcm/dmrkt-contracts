#!/bin/bash
# Usage: exec-mints.sh <p_size> <tokenids_dir> [--idx-start N] [--out-file FILE]
#
# In order to run mints in parallell, we have written the selected tokenIds per participants to json.
# This script parses the selection using jq, and then runs every participants mints in parallell.
#
# To avoid 429s, keep minting group not much larger than 25 participants
#
# Alchemy free tier: 25 requests per second
# 5 participants run concurrently; each participant mints its own tokens sequentially
# (one at a time), so at most 5 mint requests are in flight at once — comfortably
# under the 25 req/s limit.

USAGE_MSG="Usage: $(basename "$0") <p_size> <tokenids_dir> [--idx-start N] [--out-file FILE]"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

P_SIZE=$1
JSON_DIR=$2
shift 2

IDX_START=0
OUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --idx-start) IDX_START="$2"; shift 2 ;;
        --out-file) OUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

# if no <col>.json
c_count=$(find "$JSON_DIR" -maxdepth 1 -type f -name "0x*.json" | wc -l)

if [[ "$c_count" -eq 0 ]]; then
    echo "No <collection>.json files found in $JSON_DIR"
    exit 1
fi

PHRASE="$PARTICIPANT_MNEMONIC"

[[ -n "$OUT_FILE" ]] && > "$OUT_FILE"

# every participant runs mint calls in own shell
# each participant run all mints async with a 1 second wait
run_one_idx() {
    local idx=$1
    local in_file=$2
    local out_file=$3

    collection=$(basename "$in_file" .json)

    p_key=$(cast wallet private-key "${PHRASE//\"/}" $idx)
    p_addr=$(cast wallet address "$p_key")

    run_one_mint() {
        local tokenId=$1
        local nonce=$2

        tx_hash=$(
            cast send "$collection" "mint(address,uint256)" "$p_addr" "$tokenId" \
            --async \
            --private-key "$p_key" \
            --rpc-url "$RPC_URL" \
            --nonce "$nonce"
        )

        if [[ -n "$out_file" ]]; then
            echo "$tx_hash" >> "$out_file"
        fi

        sleep 0.2
    }

    export p_key

    nonce=$(cast nonce "$p_addr" --rpc-url "$RPC_URL")

    local mint_count=0
    for tokenId in $(jq --arg idx "$idx" '.[$idx][]' "$in_file"); do
        run_one_mint "$tokenId" "$nonce"
        ((nonce++))
        ((mint_count++))
    done

    echo "[idx $idx] sent $mint_count mints for $collection, tx hashes written to $out_file"
}

# export to sub processes
export -f run_one_idx
export PHRASE

for file in "$JSON_DIR"/0x*.json; do
    seq "$IDX_START" $((IDX_START + P_SIZE - 1)) | xargs -P 5 -I{} bash -c 'run_one_idx "$0" "$1" "$2"' {} "$file" "$OUT_FILE"
done
