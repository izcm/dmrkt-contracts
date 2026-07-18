#!/bin/bash
# Usage: print-participants.sh <p_size> [--start-idx N]
#
# Prints the mnemonic-derived participant addresses for [start_idx, start_idx + p_size - 1].

USAGE_MSG="Usage: $(basename "$0") <p_size> [--start-idx N]"

: "${1:?$USAGE_MSG}"

P_SIZE=$1
shift

START_IDX=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-idx) START_IDX="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="$PARTICIPANT_MNEMONIC"

echo "DERIVED PARTICIPANTS"
echo "--------------------"
for ((i = START_IDX; i < START_IDX + P_SIZE; i++)); do
    addr=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")
    echo "P$((i)) | $addr"
done
echo "--------------------"
