#!/bin/bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m" 
YELLOW="\033[0;33m"

# TODO: make this into background worker

if [ -z "$PIPELINE_STATE_DIR" ]; then
    echo -e "${RED}PIPELINE_STATE_DIR not set${RESET}"
    exit 1
fi

if [ -z "$INDEXER_URL" ]; then
    echo -e "${RED}INDEXER_URL not set${RESET}"
    exit 1
fi

if [ -z "$1" ] || [ -z "$2" ]; then
    echo -e "${RED}Missing Argument - Usage: export-order.sh EPOCH ORDER_IDX${RESET}"
    exit 1
fi

EPOCH=$1
ORDER_IDX=$2

echo "📤 Exporting order $ORDER_IDX in epoch $EPOCH..."

API_RESPONSE=$(
    curl -X POST \
    -H "Content-Type: application/json" \
    --data-binary @"$PIPELINE_STATE_DIR/epoch_$EPOCH/order_$ORDER_IDX" \
    "$INDEXER_URL"
)

echo "$API_RESPONSE"

