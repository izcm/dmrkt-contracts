#!/bin/bash
set -euo pipefail

in_file_path="${1:?Usage: export-order.sh <input-path>}"

file_name="${in_file_path%.*}"
ext="${file_name##.*}"
: "${ext:?${RED}Error: file has no extension${RESET}}"

[[ -f in_file_path ]] || {
    echo "Error: input path does not exist"
    echo "${in_file_path}"
    exit 1
}

[[ -n "$INDEXER_URL" ]] || {
    echo -e "${RED}INDEXER_URL not set${RESET}"
    exit 1
} 

# EPOCH=$1
# ORDER_IDX=$2

# API_RESPONSE=$(
#     curl -X POST \
#     -H "Content-Type: application/json" \
#     --data-binary @"$PIPELINE_STATE_DIR/epoch_$EPOCH/order_$ORDER_IDX" \
#     "$INDEXER_URL"
# )

# echo "$API_RESPONSE"

