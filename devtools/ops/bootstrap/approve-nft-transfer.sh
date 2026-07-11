#!/bin/bash
# Usage: approve-nft-transfer.sh <operator_address> <collection_address> <p_size> <tx-json-out-file> [--rpc-url <url>] [--start-idx N]
#
# For each participant in [start_idx, start_idx + p_size - 1], queue:
#   - setApprovalForAll(operator, true) on the given collection

USAGE_MSG="Usage: approve-nft-transfer.sh <operator_address> <collection_address> <p_size> <tx-json-out-file> [--rpc-url <url>] [--start-idx N]"

: "${1:?$USAGE_MSG}" "${2:?$USAGE_MSG}" "${3:?$USAGE_MSG}" "${4:?$USAGE_MSG}"

OPERATOR_ADDR=$1
COLLECTION_ADDR=$2
P_SIZE=$3
OUT_FILE=$4

shift 4

START_IDX=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="${PARTICIPANT_MNEMONIC//\"/}"
: "${PHRASE:?"Expected PARTICIPANT_MNEMONIC as environment variable, exiting."}"

envelopes=()

for ((i = START_IDX; i < START_IDX + P_SIZE; i++)); do
    p_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$i")

    echo "[$i] queuing setApprovalForAll($OPERATOR_ADDR, true) on $COLLECTION_ADDR for $p_addr"

    envelopes+=("$(jq -cn \
        --argjson idx "$i" \
        --arg collection "$COLLECTION_ADDR" \
        --arg operator "$OPERATOR_ADDR" '
    {
        type: "contract-call",
        from: {
            kind: "participant",
            idx: $idx
        },
        to: $collection,
        sig: "setApprovalForAll(address,bool)",
        args: [$operator, true]
    }
    ')")
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
