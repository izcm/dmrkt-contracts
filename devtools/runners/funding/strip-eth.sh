#!/bin/bash
#
# Strip eth from the PARTICIPANT_GROUP
# Iterate from start_index to p_count and transfer wei_per_p to destination address. 
#
USAGE_MSG="Usage: strip-eth.sh <participant_count> <destination_address> --rpc-url <url> [--start-idx <idx>] [--amount <wei>]"

# positional / flag args
: ${1:?"$USAGE_MSG"}
: ${2:?"$USAGE_MSG"}

P_COUNT=$1
DEST_ADDR=$2

shift 2

START_IDX=0
WEI_PER_USER="" # empty -> strip full balance

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) WEI_PER_USER="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${PARTICIPANT_MNEMONIC:?PHRASE not set}"
PHRASE="$PARTICIPANT_MNEMONIC"

echo "Start stripping"
echo "$DEST_ADDR is the destination address"

for((i = START_IDX; i < START_IDX + P_COUNT; i++)) do
    p_key=$(cast wallet private-key "${PHRASE//\"/}" "$i")
    p_addr=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")

    [[ "$p_addr" == "$DEST_ADDR" ]] && continue

    echo "[$i] sending $WEI_PER_USER from $p_addr"
    
    cast send "$DEST_ADDR" \
        --async \
        --value "$WEI_PER_USER" \
        --private-key "$p_key" \
        --rpc-url "$RPC_URL"
done
