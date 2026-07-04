#!/bin/bash
#
# Rotates ETH between two participant ranges: strips a "from" range's ETH into
# the deployer address via strip-eth.sh, then distributes it out to a "to"
# range via distribute-eth.sh.
#
# Phase 1 passes --sync to strip-eth.sh (rather than its default --async) —
# the deployer's balance must actually be confirmed on-chain before phase 2
# spends it, otherwise distribute-eth.sh could run against a stale/insufficient
# balance.
#
# Usage: rotate-eth.sh <from_count> <from_start_idx> <to_count> <to_start_idx> --rpc-url <url> [--amount <wei>]

USAGE_MSG="Usage: rotate-eth.sh <from_count> <from_start_idx> <to_count> <to_start_idx> --rpc-url <url> [--amount <wei>]"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"
: "${3:?$USAGE_MSG}"
: "${4:?$USAGE_MSG}"

FROM_COUNT=$1
FROM_START=$2
TO_COUNT=$3
TO_START=$4
shift 4

WEI_PER_RECIPIENT="" # empty -> distribute-eth.sh splits deployer's balance evenly

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --amount) WEI_PER_RECIPIENT="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"
: "${DEPLOYER_PK:?DEPLOYER_PK not set}"

DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#--------------------------
# PHASE 1: STRIP "from" range into deployer — --sync so strip-eth.sh waits
# for each receipt, ensuring the deployer's balance is settled before
# phase 2 spends it (rather than the --async fire-and-forget it uses standalone).
#--------------------------

echo "=== PHASE 1: STRIP $FROM_COUNT participants (from idx $FROM_START) into deployer ==="

"$SCRIPT_DIR/strip-eth.sh" "$FROM_COUNT" "$DEPLOYER_ADDR" \
    --rpc-url "$RPC_URL" \
    --start-idx "$FROM_START" \
    --sync

#--------------------------
# PHASE 2: DISTRIBUTE to "to" range — async is fine here since the
# deployer's balance is already confirmed after phase 1.
#--------------------------

echo "=== PHASE 2: DISTRIBUTE to $TO_COUNT participants (from idx $TO_START) ==="

AMOUNT_FLAG=()
[[ -n "$WEI_PER_RECIPIENT" ]] && AMOUNT_FLAG=(--amount "$WEI_PER_RECIPIENT")

"$SCRIPT_DIR/distribute-eth.sh" "$TO_COUNT" \
    --rpc-url "$RPC_URL" \
    --start-idx "$TO_START" \
    "${AMOUNT_FLAG[@]}"
