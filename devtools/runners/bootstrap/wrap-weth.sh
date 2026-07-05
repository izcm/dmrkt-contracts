#!/bin/bash
# Usage: wrap-weth.sh <p_size> --token ADDR [--amount WEI] [--no-gas-reserve] [--start-idx N] [--out-file FILE]
#
# For each participant in [start_idx, start_idx + p_size - 1], wraps ETH into WETH (deposit()).
# If --amount exceeds (balance - gas reserve), it's capped to (balance - gas reserve) instead,
# so the participant always keeps enough ETH left over for gas. If --amount is omitted, wraps
# as much as possible (balance - gas reserve).
#
# By default the gas reserve is a flat 0.5 ETH. Pass --no-gas-reserve to instead compute the
# exact gas cost for this call (gas_price * 2 * gas_units, same safety margin as strip-eth.sh)
# and reserve only that.
# Runs one process per participant in parallel (5 at a time).

USAGE_MSG="Usage: $(basename "$0") <p_size> --token ADDR [--amount WEI] [--no-gas-reserve] [--start-idx N] [--out-file FILE]"

: "${1:?$USAGE_MSG}"

P_SIZE=$1
shift

START_IDX=0
OUT_FILE=""
TOKEN=""
AMOUNT=""
FLAT_GAS_RESERVE="500000000000000000" # 0.5 ETH kept unwrapped for gas
NO_GAS_RESERVE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --token) TOKEN="$2"; shift 2 ;;
        --amount) AMOUNT="$2"; shift 2 ;;
        --no-gas-reserve) NO_GAS_RESERVE=1; shift ;;
        --start-idx) START_IDX="$2"; shift 2 ;;
        --out-file) OUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${TOKEN:?$USAGE_MSG}"

PHRASE="$PARTICIPANT_MNEMONIC"

export PHRASE TOKEN AMOUNT FLAT_GAS_RESERVE NO_GAS_RESERVE

[[ -n "$OUT_FILE" ]] && > "$OUT_FILE"

run_one() {
    local idx=$1
    local out_file=$2

    p_key=$(cast wallet private-key "${PHRASE//\"/}" "$idx")
    p_addr=$(cast wallet address "$p_key")

    balance=$(cast balance "$p_addr" --rpc-url "$RPC_URL")

    if [[ "$NO_GAS_RESERVE" -eq 1 ]]; then
        gas_price=$(cast gas-price --rpc-url "$RPC_URL")
        gas_units=$(cast estimate "$TOKEN" "deposit()" --value "$balance" --rpc-url "$RPC_URL")
        gas_reserve=$(echo "$gas_price * 2 * $gas_units" | bc)
    else
        gas_reserve=$FLAT_GAS_RESERVE
    fi

    max_wrap=$(echo "$balance - $gas_reserve" | bc)

    if [[ -z "$AMOUNT" ]]; then
        wrap_amount=$max_wrap
    else
        # cap to max_wrap if AMOUNT is too large
        wrap_amount=$(echo "if ($AMOUNT > $max_wrap) $max_wrap else $AMOUNT" | bc)
    fi

    if (( $(echo "$wrap_amount <= 0" | bc) )); then
        echo "[idx $idx] balance too low to wrap (need > $gas_reserve wei reserved for gas)"
        return
    fi

    nonce=$(cast nonce "$p_addr" --rpc-url "$RPC_URL")

    tx_hash=$(cast send "$TOKEN" "deposit()" \
        --value "$wrap_amount" \
        --async \
        --private-key "$p_key" \
        --rpc-url "$RPC_URL" \
        --nonce "$nonce")

    [[ -n "$out_file" ]] && echo "$tx_hash" >> "$out_file"

    echo "[idx $idx] sent wrap tx for $wrap_amount wei into $TOKEN"
}
export -f run_one

seq "$START_IDX" $((START_IDX + P_SIZE - 1)) | xargs -P 5 -I{} bash -c 'run_one "$0" "$1"' {} "$OUT_FILE"
