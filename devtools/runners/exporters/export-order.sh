#!/bin/bash
#
# POSTs a single order JSON file to the indexer endpoint. Retries up to 3 times on failure.
# Called by export-orders.sh for each order when --export is passed.
#
# Usage: export-order.sh <path/to/order_N.json> --chain-id <id> --export-url <url>

USAGE_MSG="Usage: export-order.sh <input-path> --chain-id <id> --export-url <url>"
in_file_path="${1:?$USAGE_MSG}"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        --chain-id) CHAIN_ID="$2"; shift 2 ;;
        --export-url) EXPORT_TO="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${CHAIN_ID:?$USAGE_MSG}"
: "${EXPORT_TO:?$USAGE_MSG}"

MAX_RETRIES=3
RETRY_DELAY=0.2
attempt=1

while true; do
    if curl -X POST -f -s -S -o /dev/null \
        --connect-timeout 3 \
        -H "Content-Type: application/json" \
        -H "X-Chain-Id: $CHAIN_ID" \
        --data-binary @"$in_file_path" \
        "$EXPORT_TO"
    then
        exit 0
    fi
    if ((attempt >= MAX_RETRIES)); then
        exit 1
    fi
    ((attempt++))
    sleep "$RETRY_DELAY"
done
