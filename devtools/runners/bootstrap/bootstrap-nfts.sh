#!/bin/bash
#
# The deterministic selection process DecideInitialMint.s.sol
# outputs a .json file per collection, on the form:
# { "<participant_idx>": [...selectedTokenIds], ... }
#
# This script parses each <collection>.json in tokenids_dir and writes
# mint envelopes to the provided <tx-json-out-file> for the tx-manager.
#
# Usage: bootstrap-nfts.sh <tokenids_dir> <tx-json-out-file>

USAGE_MSG="Usage: bootstrap-nfts.sh <tokenids_dir> <tx-json-out-file>"

: "${1:?$USAGE_MSG}" "${2:?$USAGE_MSG}"

JSON_DIR=$1
OUT_FILE=$2

# if no <col>.json
c_count=$(find "$JSON_DIR" -maxdepth 1 -type f -name "0x*.json" | wc -l)

if [[ "$c_count" -eq 0 ]]; then
    echo "No <collection>.json files found in $JSON_DIR"
    exit 1
fi

PHRASE="$PARTICIPANT_MNEMONIC"

envelopes=()

for file in "$JSON_DIR"/0x*.json; do
    collection=$(basename "$file" .json)

    for idx in $(jq -r 'keys[]' "$file"); do
        p_addr=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$idx")

        for tokenId in $(jq --arg idx "$idx" '.[$idx][]' "$file"); do
            echo "[$idx] queuing mint of tokenId $tokenId on $collection for $p_addr"

            envelopes+=("$(jq -cn \
                --argjson idx "$idx" \
                --arg collection "$collection" \
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
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
