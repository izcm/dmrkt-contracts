#!/bin/bash
# Usage: approve-allowances.sh <p_size> --token ADDR --spender ADDR <tx-json-out-file> [--start-idx N]
#
# For each participant in [start_idx, start_idx + p_size - 1], queue:
#   - approve(spender, max) on the given ERC20 token (e.g. WETH)

USAGE_MSG="Usage: approve-allowance.sh <spender_address> <token_address> <p_size> <tx-json-out-file> [--rpc-url <url>] [--start-idx N]"

: "${1:?$USAGE_MSG}" "${2:?$USAGE_MSG}" "${3:?$USAGE_MSG}" "${4:?$USAGE_MSG}"

SPENDER_ADDR=$1
TOKEN_CONTRACT=$2
P_SIZE=$3
OUT_FILE=$4

shift 4

START_IDX=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="${PARTICIPANT_MNEMONIC//\"/}"
: "${PHRASE:?"Expected PARTICIPANT_MNEMONIC as environment variable, exiting."}"

# always give max allowance
MAX_UINT256="115792089237316195423570985008687907853269984665640564039457584007913129639935"

envelopes=()

for ((i = START_IDX; i < START_IDX + P_SIZE; i++)); do
    p_addr=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$i")

    echo "[$i] queuing approve($SPENDER_ADDR, max) on $TOKEN_CONTRACT for $p_addr"

    envelopes+=("$(jq -cn \
        --argjson idx "$i" \
        --arg token "$TOKEN_CONTRACT" \
        --arg spender "$SPENDER_ADDR" \
        --arg max "$MAX_UINT256" '
    {
        type: "contract-call",
        from: {
            kind: "participant",
            idx: $idx
        },
        to: $token,
        sig: "approve(address,uint256)",
        args: [$spender, $max]
    }
    ')")
done

printf '%s\n' "${envelopes[@]}" | jq -cs '.' > "$OUT_FILE"
