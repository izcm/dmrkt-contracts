#!/bin/bash
#
# The deterministic selection process DecideInitialMint.s.sol
# outputs a .json file per collection, on the form:
# { "<participant_idx>": [...selectedTokenIds], ... }
#
# This script parses each <collection>.json in tokenids_dir and writes
# mint envelopes to the provided <tx-json-out-file> for the tx-manager.
#
# Usage: bootstrap-nfts.sh <tokenids_dir> <tx-json-out-file> <collection_addr>

USAGE_MSG="Usage: bootstrap-nfts.sh <tokenids_dir> <tx-json-out-file> <collection_addr>"

: "${1:?$USAGE_MSG}" "${2:?$USAGE_MSG}" "${3:?$USAGE_MSG}"

JSON_DIR=$1
OUT_FILE=$2
COLLECTION=$3

PHRASE="${PARTICIPANT_MNEMONIC//\"/}"
: "${PHRASE:?"Expected PARTICIPANT_MNEMONIC as environment variable, exiting."}"

envelopes=()

file="$JSON_DIR/$COLLECTION.json"

if [[ ! -f "$file" ]]; then
    echo "No selection file found for collection $COLLECTION at $file"
    exit 1
fi

for idx in $(jq -r 'keys[]' "$file"); do
    p_addr=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$idx")
    token_count=$(jq --arg idx "$idx" '.[$idx] | length' "$file")

    echo "[$idx] queuing mint of $token_count token(s) on $COLLECTION for $p_addr"

    for tokenId in $(jq --arg idx "$idx" '.[$idx][]' "$file"); do
        envelopes+=("$(jq -cn \
            --argjson idx "$idx" \
            --arg collection "$COLLECTION" \
            --arg tokenId "$tokenId" '
        {
            type: "contract-call",
            from: {
                kind: "participant",
                idx: $idx
            },
            to: $collection,
            sig: "mint(address,uint256)",
            args: [
                { kind: "participant", idx: $idx },
                $tokenId
            ]
        }
        ')")
    done
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
