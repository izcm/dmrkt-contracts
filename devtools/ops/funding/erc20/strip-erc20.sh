#!/bin/bash
#
# Strip eth from the PARTICIPANT_GROUP
# Iterate from start_index to p_count and transfer wei_per_p to destination participant. 
#

USAGE_MSG="Usage: strip-eth.sh <token_address> <destination_idx> <from_count> <tx-json-out-file> [--rpc-url <url>] [--start-idx <idx>] [--amount <wei>] [--no-gas-reserve]"

# positional
: ${1:?"$USAGE_MSG"} ${2:?"$USAGE_MSG"} ${3:?"$USAGE_MSG"} ${4:?"$USAGE_MSG"}

TOKEN_ADDR=$1
DEST_IDX=$2
FROM_COUNT=$3
OUT_FILE=$4

shift 4

START_IDX=0
RPC_URL="${RPC_URL:-http://localhost:8545}" # default anvil
WEI_PER_SENDER="" # empty -> strip full balance (minus gas)
NO_GAS_RESERVE=0 # --no-gas-reserve sends the full balance with nothing held back for gas

# flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) TOKENS_PER_SENDER="$2"; shift 2 ;;
        --no-gas-reserve) NO_GAS_RESERVE=1; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="${PARTICIPANT_MNEMONIC//\"/}"
: "${PHRASE:?"Expected PARTICIPANT_MNEMONIC as environment variable, exiting."}"


TOKEN_SYMBOL=$(cast call "$TOKEN_ADDR" "symbol()(string)" 2>/dev/null) 
TOKEN_SYMBOL="${TOKEN_SYMBOL//\"/}"
TOKEN_SYMBOL="${TOKEN_SYMBOL:-UNKNOWN}"

DEST_ADDR=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$DEST_IDX")

envelopes=()

for ((i = START_IDX; i < START_IDX + FROM_COUNT; i++)); do
    p_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$i")

    # skip if the current address is same as destination
    [[ "$p_addr" == "$DEST_ADDR" ]] && continue

    send_amount="$TOKENS_PER_SENDER"

    # no --amount flag ?? strip all tokens 
    if [[ -z "$send_amount" ]]; then
        balance=$(
            cast erc20-token balance "$TOKEN_ADDR" "$p_addr" --rpc-url "$RPC_URL" | awk '{ print $1 }'
        )
        [[ "$balance" == "0" ]] && continue

        send_amount="$balance"
    fi

    echo "[$i] queuing $send_amount $TOKEN_SYMBOL from $p_addr"

    envelopes+=("$(jq -cn \
        --argjson fromIdx "$i" \
        --argjson toIdx "$DEST_IDX" \
        --arg contract "$TOKEN_ADDR" \
        --arg tokens "$send_amount" '
    {
        type: "contract-call",
        from: {
            kind: "participant",
            idx: $fromIdx
        },
        to: $contract,
        sig: "transfer(address,uint256)",
        args: [
            { kind: "participant", idx: $toIdx },
            $tokens
        ]
    }
    ')")
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
