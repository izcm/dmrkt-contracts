#!/bin/bash
set -euo pipefail

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m" 
YELLOW="\033[0;33m"

if [ -z "$EPOCHS_STATE_DIR" ]; then
    echo "${RED}EPOCHS_STATE_DIR not set${RESET}"
    exit 1
fi

if [ -z "$INDEXER_URL" ]; then
    echo "${RED}INDEXER_URL not set${RESET}"
    echo -e ""
    exit 1
fi
# SERVER="http://localhost:5000/api/orders"

SERVER="$INDEXER_URL"
IN_FILE=$1

ORDER_NAME=$(basename "$IN_FILE")

echo "📤 Exporting $ORDER_NAME..."

