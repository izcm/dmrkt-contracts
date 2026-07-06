#!/bin/bash
# Usage: wait-for-receipts.sh <tx_hashes_file>
#
# expects tx_hashes_file to contain txHashes separated by newline

USAGE_MSG="Usage: $(basename "$0") <tx_hashes_file>"

: "${1:?$USAGE_MSG}"

tx_hashes=$1

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RESET="\033[0m"

# blank lines = mints that failed before ever broadcasting (e.g. gas estimation revert)
failed_count=$(grep -c '^$' "$tx_hashes")

# load hashes into array, skipping blank lines
mapfile -t pending < <(grep -v '^$' "$tx_hashes")

ok_count=0
reverted_count=0

# check while length is > 0
while [[ ${#pending[@]} -gt 0 ]]; do
    remaining=()
    for tx_hash in "${pending[@]:0:10}"; do
        [[ -z "$tx_hash" ]] && continue

        status=$(cast receipt "$tx_hash" status --async --rpc-url "$RPC_URL" 2>/dev/null)
        if [[ -z "$status" ]]; then
            remaining+=("$tx_hash")   # not mined yet, keep polling
        elif [[ "$status" == "true" ]]; then
            echo "[ok] $tx_hash"
            ((ok_count++))
        else
            echo "[reverted] $tx_hash"
            ((reverted_count++))
        fi
    done
    pending=("${remaining[@]}")
    [[ ${#pending[@]} -gt 0 ]] && sleep 1
done

echo -e "${GREEN}ok: $ok_count${RESET} | ${RED}reverted: $reverted_count${RESET} | ${YELLOW}failed before broadcast: $failed_count${RESET}"
