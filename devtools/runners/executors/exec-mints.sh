#!/bin/bash
# Usage: $(basename "$0") <script_path> <idx_start> <idx_end> [extra forge args...]
#
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

USAGE_MSG="Usage: $(basename "$0") <idx_start> <idx_end> <tokenids_dir>"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"
: "${3:?$USAGE_MSG}"

# COL=0xa1E25aef7feDD5dc15619769111ffa31897b8459

# we might wanna limit the participant count since mint stage does much more rpc calls than rest of pipeline.
# let users pass as positional args instead of only reading .env

IDX_START=$1
P_SIZE=$2

# directory contains zero / more <col>.json with object:
# "<p_idx>": [x, y, z] tokenids to mint per participant
JSON_DIR=$3

# if no <col>.json 
c_count=$(find "$JSON_DIR" -maxdepth 1 -type f -name "0x*.json" | wc -l)

if [[ "$c_count" -eq 0 ]]; then
    echo "No <collection>.json files found in $JSON_DIR"
    exit 1
fi

PHRASE="$PARTICIPANT_MNEMONIC"

# every participant runs mint calls in own shell
# each participant run all mints async with a 1 second wait
run_one_idx() {
    local idx=$1
    local in_file=$2
    
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

        sleep 1
    }

    export p_key

    nonce=$(cast nonce "$p_addr" --rpc-url "$RPC_URL")

    for tokenId in $(jq --arg idx "$idx" '.[$idx][]' "$in_file"); do
        run_one_mint $tokenId $nonce
        ((nonce++))
    done
}

# export to sub processes
export -f run_one_idx
export PHRASE

for file in "$JSON_DIR"/0x*.json; do
    seq "$IDX_START" $((IDX_START + P_SIZE - 1)) | xargs -P 5 -I{} bash -c 'run_one_idx "$0" "$1"' {} "$file"
done
