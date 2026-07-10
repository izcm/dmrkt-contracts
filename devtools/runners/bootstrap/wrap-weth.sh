#!/bin/bash
#
# Wrap ETH into WETH for the PARTICIPANT_GROUP.
# Iterate from start_index to p_count and queue a deposit() call for each participant.

USAGE_MSG="Usage: wrap-weth.sh <token_address> <p_count> <tx-json-out-file> [--rpc-url <url>] [--start-idx <idx>] [--amount <wei>] [--gas-reserve <wei>]"

# positional
: ${1:?"$USAGE_MSG"} ${2:?"$USAGE_MSG"} ${3:?"$USAGE_MSG"}

TOKEN_ADDR=$1
P_SIZE=$2
OUT_FILE=$3

shift 3

START_IDX=0
RPC_URL="${RPC_URL:-http://localhost:8545}" # default anvil
AMOUNT="" # empty -> wrap full balance (minus gas reserve)
GAS_RESERVE_WEI=500000000000000000 # 0.5 ETH kept unwrapped for gas

# flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) AMOUNT="$2"; shift 2 ;;
        --gas-reserve) GAS_RESERVE_WEI="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="${PARTICIPANT_MNEMONIC//\"/}"
: "${PHRASE:?"Expected PARTICIPANT_MNEMONIC as environment variable, exiting."}"

envelopes=()

for ((i = START_IDX; i < START_IDX + P_SIZE; i++)); do
    p_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$i")

    wrap_amount="$AMOUNT"

    # no --amount flag ?? wrap full balance minus gas reserve
    if [[ -z "$wrap_amount" ]]; then
        balance=$(cast balance "$p_addr" --rpc-url "$RPC_URL")
        [[ "$balance" == "0" ]] && continue

        wrap_amount=$(echo "$balance - $GAS_RESERVE_WEI" | bc)

        if (( $(echo "$wrap_amount <= 0" | bc) )); then
            echo "[$i] $p_addr balance too low to wrap (need > $GAS_RESERVE_WEI wei reserved for gas)"
            continue
        fi
    fi

    echo "[$i] queuing wrap of $wrap_amount wei for $p_addr"

    envelopes+=("$(jq -cn \
        --argjson idx "$i" \
        --arg contract "$TOKEN_ADDR" \
        --arg value "$wrap_amount" '
    {
        type: "contract-call",
        from: {
            kind: "participant",
            idx: $idx
        },
        to: $contract,
        sig: "deposit()",
        args: [],
        value: $value
    }
    ')")
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
