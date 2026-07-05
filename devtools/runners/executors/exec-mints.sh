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

USAGE_MSG="Usage: $(basename "$0") <idx_start> <idx_end>"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

COL=0xa1E25aef7feDD5dc15619769111ffa31897b8459
FILE_IN="./data/31337/state/cols-mint-per-idx/0xa1E25aef7feDD5dc15619769111ffa31897b8459.json"

# we might wanna limit the participant count since mint stage does much more rpc calls than rest of pipeline.
# let users pass as positional args instead of only reading .env

IDX_START=$1
P_SIZE=$2

PHRASE="$PARTICIPANT_MNEMONIC"

# every participant runs mint calls in own shell
# each participant run all mints async with a 1 second wait, avoiding err 429
run_one_idx() {
    local idx=$1

    p_key=$(cast wallet private-key "${PHRASE//\"/}" $idx)
    p_addr=$(cast wallet address "$p_key")

    run_one_mint() {
        local tokenId=$1
        local nonce=$2

        cast send "$COL" "mint(address,uint256)" "$p_addr" "$tokenId" \
            --async \
            --private-key "$p_key" \
            --rpc-url "$RPC_URL" \
            --nonce "$nonce"
        sleep 1
    }

    export p_key

    nonce=$(cast nonce "$p_addr" --rpc-url "$RPC_URL")

    for tokenId in $(jq --arg idx "$idx" '.[$idx][]' "$FILE_IN"); do
        run_one_mint $tokenId $nonce
        ((nonce++))
    done
}

# export to sub processes
export -f run_one_idx
export PHRASE FILE_IN COL

seq "$IDX_START" $((IDX_START + P_SIZE)) | xargs -P 5 -I{} bash -c 'run_one_idx "$0"' {}
