#!/bin/bash
#
# Distributes the deployer's ERC20 balance evenly across the participant group.
# Mirrors distribute-eth.sh, but for a given token instead of native ETH.

# positional args
USAGE_MSG="Usage: distribute-erc20.sh <token_address> <to_count> --rpc-url <url> [--start-idx <idx>] [--amount <tokens>] [--out-file <file>]"
: "${1:?"$USAGE_MSG"}"
: "${2:?"$USAGE_MSG"}"

TOKEN_ADDR=$1
TO_COUNT=$2
shift 2

START_IDX=0
TOKENS_PER_RECIPIENT="" # empty -> split deployer's balance evenly, deployer keeps a 1/(TO_COUNT+1) share
OUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) TOKENS_PER_RECIPIENT="$2"; shift 2 ;;
        --out-file) OUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

[[ -n "$OUT_FILE" ]] && > "$OUT_FILE"

: "${RPC_URL:?$USAGE_MSG}"

# env
: "${DEPLOYER_PK:?DEPLOYER_PK not set}"
: "${PARTICIPANT_MNEMONIC:?PHRASE not set}"

PHRASE="$PARTICIPANT_MNEMONIC"
DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

if [[ -z "$TOKENS_PER_RECIPIENT" ]]; then
    # no fixed amount -> split the deployer's current balance into TO_COUNT+1
    # equal shares, so the deployer itself keeps one share too
    balance=$(cast erc20-token balance "$TOKEN_ADDR" "$DEPLOYER_ADDR" --rpc-url "$RPC_URL" | awk '{ print $1 }')
    TOKENS_PER_RECIPIENT=$(echo "$balance / ($TO_COUNT + 1)" | bc) # +1 part with funder
    (( $(echo "$TOKENS_PER_RECIPIENT <= 0" | bc) )) && { echo "deployer balance too low to distribute"; exit 1; }
fi

# deployer nonce
nonce=$(cast nonce "$DEPLOYER_ADDR" --rpc-url "$RPC_URL")

for ((i = START_IDX; i < START_IDX + TO_COUNT; i++)); do
    # receiver
    p=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$i")

    [[ "$p" == "$DEPLOYER_ADDR" ]] && continue

    echo "[$i] sending $TOKENS_PER_RECIPIENT tokens to $p"
    tx_hash=$(cast erc20-token transfer "$TOKEN_ADDR" "$p" "$TOKENS_PER_RECIPIENT" \
        --async \
        --private-key "$DEPLOYER_PK" \
        --rpc-url "$RPC_URL" \
        --nonce "$nonce")

    [[ -n "$OUT_FILE" ]] && echo "$tx_hash" >> "$OUT_FILE"
    ((nonce++))
done

exit 0
