#!/bin/bash
#
# Exports all orders in a directory to the indexer. Calls export-order.sh for each.
#
# Usage: export-orders.sh <orders_dir> <order_count> --chain-id <id> --export-url <url>

GREEN="\033[0;32m"
RED="\033[0;31m"
RESET="\033[0m"

USAGE_MSG="Usage: export-orders.sh <orders_dir> <order_count> --chain-id <id> --export-url <url>"
: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

ORDERS_DIR="$1"
ORDER_COUNT="$2"
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --chain-id) CHAIN_ID="$2"; shift 2 ;;
        --export-url) EXPORT_URL="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${CHAIN_ID:?$USAGE_MSG}"
: "${EXPORT_URL:?$USAGE_MSG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for ((i = 0; i < ORDER_COUNT; i++)); do
    f="$ORDERS_DIR/order_$i.json"
    [[ -f $f ]] || { echo "Error: missing file: $f"; exit 1; }
    [[ $f == *.json ]] || { echo "Error: not a json file: $f"; exit 1; }
done

export_errors=0
for ((i = 0; i < ORDER_COUNT; i++)); do
    "$SCRIPT_DIR/export-order.sh" "$ORDERS_DIR/order_$i.json" \
        --chain-id "$CHAIN_ID" \
        --export-url "$EXPORT_URL" \
        || ((export_errors++))
done

if ((export_errors == 0)); then
    echo -e "   ${GREEN}All $ORDER_COUNT orders exported successfully${RESET}"
else
    echo -e "   ${RED}$export_errors/$ORDER_COUNT orders failed to export${RESET}"
fi
