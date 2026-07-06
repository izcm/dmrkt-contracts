#!/bin/bash
#
# Rotates an ERC20 token between two participant ranges: strips a "from" range's
# tokens into the deployer address via strip-erc20.sh, then distributes it out
# to a "to" range via distribute-erc20.sh.
#
# Phase 1 runs strip-erc20.sh async (its default) and writes tx hashes to
# --strip-out-file, then this script calls wait-for-receipts.sh on that file
# itself before phase 2 — so the deployer's balance is confirmed on-chain
# before phase 2 spends it, without strip-erc20.sh having to block per-tx.
#
# Usage: rotate-erc20.sh <token_address> <from_count> <from_start_idx> <to_count> <to_start_idx> --rpc-url <url> --strip-out-file <file> [--amount <tokens>] [--distribute-out-file <file>]

USAGE_MSG="Usage: rotate-erc20.sh <token_address> <from_count> <from_start_idx> <to_count> <to_start_idx> --rpc-url <url> --strip-out-file <file> [--amount <tokens>] [--distribute-out-file <file>]"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"
: "${3:?$USAGE_MSG}"
: "${4:?$USAGE_MSG}"
: "${5:?$USAGE_MSG}"

TOKEN_ADDR=$1
FROM_COUNT=$2
FROM_START=$3
TO_COUNT=$4
TO_START=$5
shift 5

TOKENS_PER_RECIPIENT="" # empty -> distribute-erc20.sh splits deployer's balance evenly
STRIP_OUT_FILE=""
DISTRIBUTE_OUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        --amount) TOKENS_PER_RECIPIENT="$2"; shift 2 ;;
        --strip-out-file) STRIP_OUT_FILE="$2"; shift 2 ;;
        --distribute-out-file) DISTRIBUTE_OUT_FILE="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"
: "${STRIP_OUT_FILE:?$USAGE_MSG}"
: "${DEPLOYER_PK:?DEPLOYER_PK not set}"

DEPLOYER_ADDR=$(cast wallet address "$DEPLOYER_PK")

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAIT_FOR_RECEIPTS="$SCRIPT_DIR/../../wait-for-receipts.sh"

#--------------------------
# PHASE 1: STRIP "from" range into deployer (async), then wait for receipts
# ourselves so the deployer's balance is confirmed before phase 2 spends it.
#--------------------------

echo "=== PHASE 1: STRIP $FROM_COUNT participants (from idx $FROM_START) into deployer ==="

"$SCRIPT_DIR/strip-erc20.sh" "$TOKEN_ADDR" "$DEPLOYER_ADDR" "$FROM_COUNT" \
    --rpc-url "$RPC_URL" \
    --start-idx "$FROM_START" \
    --out-file "$STRIP_OUT_FILE"

"$WAIT_FOR_RECEIPTS" "$STRIP_OUT_FILE"

#--------------------------
# PHASE 2: DISTRIBUTE to "to" range — async is fine here since the
# deployer's balance is already confirmed after phase 1.
#--------------------------

echo "=== PHASE 2: DISTRIBUTE to $TO_COUNT participants (from idx $TO_START) ==="

AMOUNT_FLAG=()
[[ -n "$TOKENS_PER_RECIPIENT" ]] && AMOUNT_FLAG=(--amount "$TOKENS_PER_RECIPIENT")

DISTRIBUTE_OUT_FLAG=()
[[ -n "$DISTRIBUTE_OUT_FILE" ]] && DISTRIBUTE_OUT_FLAG=(--out-file "$DISTRIBUTE_OUT_FILE")

"$SCRIPT_DIR/distribute-erc20.sh" "$TOKEN_ADDR" "$TO_COUNT" \
    --rpc-url "$RPC_URL" \
    --start-idx "$TO_START" \
    "${AMOUNT_FLAG[@]}" \
    "${DISTRIBUTE_OUT_FLAG[@]}"
