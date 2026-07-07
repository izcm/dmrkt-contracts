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

# retries a command until it returns non-empty output with no "Error" in it
# (e.g. rate limits / DNS hiccups) instead of silently passing empty/broken
# values (nonce, gas price, ...) downstream
with_retry() {
    local max_attempts=5
    local delay=2
    local attempt=1
    local result

    while (( attempt <= max_attempts )); do
        result=$("$@" 2>&1)
        if [[ -n "$result" && "$result" != *"Error"* ]]; then
            echo "$result"
            return 0
        fi
        sleep "$delay"
        ((attempt++))
    done

    echo "FAILED: '$*' did not return a valid result after $max_attempts attempts" >&2
    return 1
}
export -f with_retry

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
        local boosted_gas_price=$3

        local owner_attempt=1
        local owner_max_attempts=5
        while true; do
            owner_check=$(cast call "$collection" "ownerOf(uint256)(address)" "$tokenId" --rpc-url "$RPC_URL" 2>&1)
            sleep 1

            if [[ "$owner_check" == *"execution reverted"* ]]; then
                # token doesn't exist yet -> safe to mint
                break
            elif [[ "$owner_check" == *"Error"* ]]; then
                # network-level failure (DNS/connect/429/...) -> we don't actually
                # know the mint status, retry instead of guessing
                if (( owner_attempt >= owner_max_attempts )); then
                    echo "[idx $idx] tokenId $tokenId: could not verify mint status after $owner_max_attempts attempts, skipping this round"
                    return 1
                fi
                sleep 2
                ((owner_attempt++))
            else
                # call succeeded -> token already has an owner
                echo "[idx $idx] tokenId $tokenId already minted (owner: $owner_check), skipping"
                return 1
            fi
        done

        sleep 2

        tx_hash=$(
            cast send "$collection" "mint(address,uint256)" "$p_addr" "$tokenId" \
            --async \
            --private-key "$p_key" \
            --rpc-url "$RPC_URL" \
            --nonce "$nonce" \
            --gas-price "$boosted_gas_price" 2>&1
        )

        if [[ "$tx_hash" == *"ERC721InvalidSender"* ]]; then
            echo "[idx $idx] tokenId $tokenId already minted (race), skipping"
            return 1
        fi

        if [[ -n "$out_file" ]]; then
            echo "$tx_hash" >> "$out_file"
        fi

        sleep 2
    }

    export p_key

    nonce=$(with_retry cast nonce "$p_addr" --rpc-url "$RPC_URL") || { echo "[idx $idx] giving up: could not fetch nonce"; return 1; }

    gas_price=$(with_retry cast gas-price --rpc-url "$RPC_URL") || { echo "[idx $idx] giving up: could not fetch gas price"; return 1; }
    boosted_gas_price=$(echo "$gas_price * 5" | bc)

    local mint_count=0
    for tokenId in $(jq --arg idx "$idx" '.[$idx][]' "$in_file"); do
        if run_one_mint "$tokenId" "$nonce" "$boosted_gas_price"; then
            ((nonce++))
            ((mint_count++))
        fi
    done

    echo "[idx $idx] sent $mint_count mints for $collection, tx hashes written to $out_file"
}

# export to sub processes
export -f run_one_idx
export PHRASE

for file in "$JSON_DIR"/0x*.json; do
    seq "$IDX_START" $((IDX_START + P_SIZE - 1)) | xargs -P 5 -I{} bash -c 'run_one_idx "$0" "$1" "$2"' {} "$file" "$OUT_FILE"
    # seq 18 18 | xargs -P 5 -I{} bash -c 'run_one_idx "$0" "$1" "$2"' {} "$file" "$OUT_FILE"
    # seq 10 19 | xargs -P 5 -I{} bash -c 'run_one_idx "$0" "$1" "$2"' {} "$file" "$OUT_FILE"
done
