#!/bin/bash
#
# POSTs a single order JSON file to the indexer endpoint. Retries up to 3 times on failure.
# Called by run-epochs.sh for each order when --export is passed.
#
# Usage: export-order.sh <path/to/order_N.json>
# Env:   ORDER_POST_URL, CHAIN_ID

RED="\033[0;31m"
RESET="\033[0m"

in_file_path="${1:?Usage: export-order.sh <input-path>}"

file_name=$(basename "$in_file_path")
ext="${file_name##*.}"

order_idx=${file_name#order_}
order_idx=${order_idx%.json}

[[ -f $in_file_path ]] || {
    echo -e "${RED}Error: input path does not exist"
    echo "${in_file_path}${RESET}"
    exit 1
}

[[ $ext == "json" ]] || {
    echo -e "${RED}Error: file extension is not json $file_name ${RESET}"
    exit 1
}

[[ -n "$ORDER_POST_URL" ]] || {
    echo -e "${RED}ORDER_POST_URL not set${RESET}"
    exit 1
}

MAX_RETRIES=3
RETRY_DELAY=0.2

attempt=1

while true; do
    if curl -X POST -f -s -S -o /dev/null \
        -H "Content-Type: application/json" \
        -H "X-Chain-Id: $CHAIN_ID" \
        --data-binary @"$in_file_path" \
        "$ORDER_POST_URL"
    then
        exit 0 # SUCCESS
    fi
    if ((attempt >= MAX_RETRIES)); then
        exit 1 # FAILURE
    fi

    ((attempt++))
    sleep "$RETRY_DELAY"
done
