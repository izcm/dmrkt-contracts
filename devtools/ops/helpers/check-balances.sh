#!/bin/bash
# Usage: check-balances.sh <weth_address> [SIZE] [--start-idx IDX]
#
# prints ETH and WETH balances for participant wallets idx START..START+SIZE-1
# derived from PARTICIPANT_MNEMONIC

USAGE_MSG="Usage: check-balances.sh <weth_address> [SIZE] [--start-idx IDX]"

# positional
: ${1:?"$USAGE_MSG"}

WETH=$1
shift

SIZE=100
START=0

if [[ "$1" != --* && -n "$1" ]]; then
    SIZE="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-idx) START="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

PHRASE="$PARTICIPANT_MNEMONIC"

for idx in $(seq "$START" $((START + SIZE - 1))); do
    p_addr=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$idx")
    balance=$(cast balance "$p_addr" --rpc-url "$RPC_URL")
    weth_balance=$(cast call "$WETH" "balanceOf(address)" "$p_addr" --rpc-url "$RPC_URL" | cast to-dec)
    echo "[idx $idx] $p_addr -> ETH: $balance, WETH: $weth_balance"
done
