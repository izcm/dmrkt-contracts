#!/bin/bash
# Usage: exec-per-idx.sh <p_size> <script_path> [--start-idx N] [--out-file FILE] [extra forge args...]
#
# Runs `run(uint256)` on <script_path> (e.g. bootstrap/Approve.s.sol:Approve) once per
# index in [start_idx, start_idx + p_size - 1], in parallel (5 at a time), passing the
# index as the sole argument.

USAGE_MSG="Usage: $(basename "$0") <p_size> <script_path> [--start-idx N] [--out-file FILE] [extra forge args...]"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

P_SIZE=$1
SCRIPT_PATH=$2
shift 2

START_IDX=0
OUT_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start-idx) START_IDX="$2"; shift 2 ;;
        --out-file) OUT_FILE="$2"; shift 2 ;;
        *) break ;;
    esac
done

export SCRIPT_PATH

run_one() {
    local idx=$1
    local out_file=$2
    shift 2

    output=$(forge script "$SCRIPT_PATH" --sig "run(uint256)" "$idx" "$@" -v 2>&1 \
        | grep -v "No files changed, compilation skipped")

    echo "$output" | sed "s/^/[idx $idx] /"

    if [[ -n "$out_file" ]]; then
        echo "$output" >> "$out_file"
    fi
}
export -f run_one

seq "$START_IDX" $((START_IDX + P_SIZE - 1)) | xargs -P 5 -I{} bash -c 'run_one "$0" "$1" "${@:2}"' {} "$OUT_FILE" "$@"
