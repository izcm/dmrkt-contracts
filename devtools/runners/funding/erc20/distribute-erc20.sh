#!/bin/bash
#
# Distributes the deployer's ERC20 balance evenly across the participant group.
# Mirrors distribute-eth.sh, but for a given token instead of native ETH.

# positional args
USAGE_MSG="Usage: distribute-erc20.sh <token_address> <funder_idx> <to_count> <tx-json-out-file> [--rpc-url <url>] [--start-idx <idx>] [--amount <tokens>]"

# positional
: "${1:?"$USAGE_MSG"}" "${2:?"$USAGE_MSG"}" "${3:?"$USAGE_MSG"}" "${4:?"$USAGE_MSG"}"

TOKEN_ADDR=$1
FUNDER_IDX=$2
TO_COUNT=$3
OUT_FILE=$4

shift 4

START_IDX=0
RPC_URL="${RPC_URL:-http://localhost:8545}" # default anvil
TOKENS_PER_RECIPIENT="" # empty -> split deployer's balance evenly, deployer keeps a 1/(TO_COUNT+1) share

PHRASE=${PARTICIPANT_MNEMONIC//\"/}
: "${PHRASE:?"Expected participant mnemonic as environment variable, exiting."}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) TOKENS_PER_RECIPIENT="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

if [[ -z "$TOKENS_PER_RECIPIENT" ]]; then
    # no fixed amount -> split the deployer's current balance into TO_COUNT+1
    # equal shares, so the deployer itself keeps one share too
    funder_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$FUNDER_IDX")
    balance=$(cast erc20-token balance "$TOKEN_ADDR" "$funder_addr" --rpc-url "$RPC_URL" | awk '{ print $1 }')
    TOKENS_PER_RECIPIENT=$(echo "$balance / ($TO_COUNT + 1)" | bc) # +1 part with funder
    (( $(echo "$TOKENS_PER_RECIPIENT <= 0" | bc) )) && { echo "deployer balance too low to distribute"; exit 1; }
fi

# - write a tx json object for each idx from decided start / end
# - this .json file will be fed into the tx-manager which is the centralized point for tx executons 

# function transfer(address _to, uint256 _value) public returns (bool success)

jq -cn \
    --argjson start "$START_IDX" \
    --argjson count "$TO_COUNT" \
    --argjson fromIdx "$FUNDER_IDX" \
    --arg contract "$TOKEN_ADDR" \
    --arg tokens "$TOKENS_PER_RECIPIENT" '
[
  range($start; $start + $count) as $i
  | select($i != $fromIdx)
  | {
      type: "contract-call",
      from: {
        kind: "participant",
        idx: $fromIdx
      },
      to: $contract,
      sig: "transfer(address, uint256)",
      args: [
        { kind: "participant", idx: $i },
        $tokens
      ]
    }
]
' > "$OUT_FILE"
