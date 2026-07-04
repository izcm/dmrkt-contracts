#!/bin/bash
#
# Anvil lets us specify which users are the 10'000 ETH funded group.
#
# When running simulation on eg. Sepolia its likely that a superuser initially holds all funds.
# This script distributes superuser's ETH evenly on participant group.

# positional args
USAGE_MSG="Usage: distribute-eth.sh <to_count> --rpc-url <url> [--start-idx <idx>] [--amount <wei>]"
: "${1:?"$USAGE_MSG"}"

TO_COUNT=$1
shift 1

START_IDX=0
WEI_PER_RECIPIENT="" # empty -> split deployer's balance evenly, deployer keeps a 1/(TO_COUNT+1) share

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) WEI_PER_RECIPIENT="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"

# env
: "${DEPLOYER_PK:?DEPLOYER_PK not set}"
: "${PARTICIPANT_MNEMONIC:?PHRASE not set}"

PHRASE="$PARTICIPANT_MNEMONIC"
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

if [[ -z "$WEI_PER_RECIPIENT" ]]; then
    # no fixed amount -> split the deployer's current balance into TO_COUNT+1
    # equal shares, so the deployer itself keeps one share too
    balance=$(cast balance "$DEPLOYER_ADDR" --rpc-url "$RPC_URL")
    WEI_PER_RECIPIENT=$(echo "$balance / ($TO_COUNT + 1)" | bc) # +1 part part with funder
    (( WEI_PER_RECIPIENT <= 0 )) && { echo "deployer balance too low to distribute"; exit 1; }
fi

# deployer nonce
nonce=$(cast nonce "$DEPLOYER_ADDR" --rpc-url "$RPC_URL")

for ((i = START_IDX; i < START_IDX + TO_COUNT; i++)); do
    # participant
    p=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")

    [[ "$p" == "$DEPLOYER_ADDR" ]] && continue

    echo "[$i] sending $WEI_PER_RECIPIENT wei to $p"
    cast send "$p" \
        --async \
        --value "$WEI_PER_RECIPIENT" \
        --private-key "$DEPLOYER_PK" \
        --rpc-url "$RPC_URL" \
        --nonce "$nonce"
    ((nonce++))
done

exit 0