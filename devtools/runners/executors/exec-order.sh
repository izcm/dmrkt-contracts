#!/bin/bash
#
# Executes a single order on-chain via ExecuteOrder.s.sol and logs the result.
#
# Usage: exec-order.sh <epoch> <order_index> --rpc-url <url> --sender <addr> --private-key <pk>

GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

USAGE_MSG="Usage: exec-order.sh <epoch> <order_index> --rpc-url <url> --sender <addr> --private-key <pk>"
: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

epoch="$1"
order_index="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url)     RPC_URL="$2";     shift 2 ;;
        --sender)      SENDER="$2";      shift 2 ;;
        --private-key) PRIVATE_KEY="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"
: "${SENDER:?$USAGE_MSG}"
: "${PRIVATE_KEY:?$USAGE_MSG}"
: "${PIPELINE_EXECUTION:?PIPELINE_EXECUTION not set}"

if forge script "$PIPELINE_EXECUTION"/ExecuteOrder.s.sol \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --sender "$SENDER" \
    --private-key "$PRIVATE_KEY" \
    --sig "run(uint256,uint256)" \
    --silent \
    "$epoch" "$order_index"
then
    mined_at=$(cast block latest --rpc-url "$RPC_URL" -f timestamp)
    ts=$(date -d @"$mined_at" "+%Y-%m-%d %H:%M:%S")
    echo -e "[$ts] [epoch:$epoch] [order:$order_index] ${GREEN}EXECUTED${RESET}"
    exit 0
else
    echo -e "[epoch:$epoch] [order:$order_index] ${YELLOW}REVERTED${RESET}"
    exit 1
fi
