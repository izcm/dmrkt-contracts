#!/bin/bash


RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"
YELLOW="\033[0;33m" 

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

[[ -n "$INDEXER_URL" ]] || {
    echo -e "${RED}INDEXER_URL not set${RESET}"
    exit 1
} 

MAX_RETRIES=3
RETRY_DELAY=0.2

attempt=1

while true; do
    if curl -X POST -f -s -S -o /dev/null \
        -H "Content-Type: application/json" \
        --data-binary @"$in_file_path" \
        "$INDEXER_URL/api/orders"
    then
        echo -e "[order:$order_idx] ${GREEN}EXPORTED${RESET}"
        break
    fi
    if ((attempt >= MAX_RETRIES)); then
        echo -e "[order:$order_idx] ${RED}FAILED after $attempt attempts${RESET}"
        break
    fi

    echo -e "[order:$order_idx] ${YELLOW}retry $attempt/$MAX_RETRIES...${RESET}"
    ((attempt++))
    sleep "$RETRY_DELAY"
done
