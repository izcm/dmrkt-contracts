#!/bin/bash
#
# Strip eth from the PARTICIPANT_GROUP
# Iterate from start_index to p_count and write an eth-transfer tx envelope
# for wei_per_p from each participant to the destination participant.
#
# - this .json file will be fed into the tx-manager which is the centralized point for tx executons

USAGE_MSG="Usage: strip-eth.sh <destination_idx> <from_count> <tx-json-out-file> --rpc-url <url> [--start-idx <idx>] [--amount <wei>] [--gas-reserve <wei>]"

# positional
: ${1:?"$USAGE_MSG"}
: ${2:?"$USAGE_MSG"}
: ${3:?"$USAGE_MSG"}

DEST_IDX=$1
FROM_COUNT=$2
OUT_FILE=$3
shift 3

START_IDX=0
RPC_URL="${RPC_URL:-http://localhost:8545}" # default anvil
WEI_PER_SENDER="" # empty -> strip full balance (minus gas reserve)
GAS_RESERVE_WEI=1000000000000000 # 0.001 ETH flat buffer, covers this tx's own gas regardless of price at send time

# flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --amount) WEI_PER_SENDER="$2"; shift 2 ;;
        --gas-reserve) GAS_RESERVE_WEI="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="${PARTICIPANT_MNEMONIC//\"/}"
: "${PHRASE:?"Expected PARTICIPANT_MNEMONIC as environment variable, exiting."}"

DEST_ADDR=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$DEST_IDX")

envelopes=()

for ((i = START_IDX; i < START_IDX + FROM_COUNT; i++)); do
    [[ "$i" -eq "$DEST_IDX" ]] && continue

    p_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$i")

    send_amount="$WEI_PER_SENDER"

    # no fixed amount -> drain the full balance, minus enough to cover this tx's own gas
    if [[ -z "$send_amount" ]]; then
        balance=$(cast balance "$p_addr" --rpc-url "$RPC_URL")
        if [[ "$balance" == "0" ]]; then
            echo "[$i] $p_addr balance=0 — skipping"
            continue
        fi

        send_amount=$(echo "$balance - $GAS_RESERVE_WEI" | bc)

        if (( $(echo "$send_amount <= 0" | bc) )); then
            echo "[$i] $p_addr balance too low to cover gas — skipping"
            continue
        fi
    fi

    echo "[$i] queuing $send_amount wei from $p_addr"

    envelopes+=("$(jq -cn \
        --argjson fromIdx "$i" \
        --argjson toIdx "$DEST_IDX" \
        --arg value "$send_amount" '
    {
      type: "eth-transfer",
      from: { kind: "participant", idx: $fromIdx },
      to: { kind: "participant", idx: $toIdx },
      value: $value
    }
    ')")
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
