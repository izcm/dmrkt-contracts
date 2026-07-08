#!/bin/bash
#
# Anvil lets us specify which users are the 10'000 ETH funded group.
#
# When running simulation on eg. Sepolia its likely that a superuser initially holds all funds.
# This script distributes superuser's ETH evenly on participant group.

# positional args

#todo: make localhost:8545 default rpc so --rpc-url isnt mandatory
USAGE_MSG="Usage: distribute-eth.sh <funder_idx> <to_count> <tx-json-out-file> --rpc-url <url> [--start-idx <idx>] [--amount <wei>]"
: "${1:?"$USAGE_MSG"}"
: "${2:?"$USAGE_MSG"}"
: "${3:?"$USAGE_MSG"}"

FUNDER_IDX=$1
TO_COUNT=$2
OUT_FILE=$3
shift 3

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

[[ -n "$OUT_FILE" ]] && > "$OUT_FILE"

PHRASE=${PARTICIPANT_MNEMONIC//\"/}

: "${RPC_URL:?$USAGE_MSG}"
: "${PHRASE:?"Expected participant mnemonic as environment variable, exiting."}"

if [[ -z "$WEI_PER_RECIPIENT" ]]; then
    # no fixed amount -> split the deployer's current balance into TO_COUNT+1
    # equal shares, so the deployer itself keeps one share too
    funder_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$FUNDER_IDX")
    balance=$(cast balance "$funder_addr" --rpc-url "$RPC_URL")
    WEI_PER_RECIPIENT=$(echo "$balance / ($TO_COUNT + 1)" | bc) # +1 part part with funder
    (( $(echo "$WEI_PER_RECIPIENT <= 0" | bc) )) && { echo "deployer balance too low to distribute"; exit 1; }
fi

# - write a tx json object for each idx from decided start / end
# - this .json file will be fed into the tx-manager which is the centralized point for tx executons 

jq -cn \
    --argjson start "$START_IDX" \
    --argjson count "$TO_COUNT" \
    --argjson fromIdx "$FUNDER_IDX" \
    --arg value "$WEI_PER_RECIPIENT" '
[
  range($start; $start + $count) as $i
  | {
      type: "eth-transfer",
      from: { 
        kind: "participant",
        idx: $fromIdx
      },
      to: {
        kind: "participant",
        idx: $i
      },
      value: $value
    }
]
' > "$OUT_FILE"
