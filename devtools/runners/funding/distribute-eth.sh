#!/bin/bash
#
# Anvil lets us specify which users are the 10'000 ETH funded group.
#
# When running simulation on eg. Sepolia its likely that a superuser initially holds all funds.
# This script distributes superuser's ETH evenly on participant group.

# positional args
USAGE_MSG="Usage: distribute-eth.sh <participant_count> <wei_per_participant> --rpc-url <url> [--start-idx <idx>]"
: "${1:?"$USAGE_MSG"}"
: "${2:?"$USAGE_MSG"}"

P_COUNT=$1
WEI_PER_USER=$2
shift 2

START_IDX=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"

# env 
: "${DEPLOYER_PK:?DEPLOYER_PK not set}"
: "${PARTICIPANT_MNEMONIC:?PHRASE not set}"

PHRASE="$PARTICIPANT_MNEMONIC"
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

# deployer nonce
nonce=$(cast nonce "$DEPLOYER_ADDR" --rpc-url "$RPC_URL")

for ((i = START_IDX; i < START_IDX + P_COUNT; i++)); do
    # participant
    p=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")

    [[ "$p" == "$DEPLOYER_ADDR" ]] && continue

    echo "[$i] sending $WEI_PER_USER wei to $p"
    cast send "$p" \
        --async \
        --value "$WEI_PER_USER" \
        --private-key "$DEPLOYER_PK" \
        --rpc-url "$RPC_URL" \
        --nonce "$nonce" > /dev/null 2>&1 &
    disown
    ((nonce++))
done

exit 0