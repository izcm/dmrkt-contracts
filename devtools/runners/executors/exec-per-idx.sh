#!/bin/bash
# Usage: exec-per-idx.sh <script_path> <idx_start> <idx_end> [extra forge args...]
#
# Runs `run(uint256)` on <script_path> (e.g. bootstrap/Approve.s.sol:Approve) once per
# index in [idx_start, idx_end], in parallel (5 at a time), passing the index as the
# sole argument.

USAGE_MSG="Usage: $(basename "$0") <script_path> <idx_start> <idx_end> [extra forge args...]"

: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"
: "${3:?$USAGE_MSG}"

SCRIPT_PATH=$1
IDX_START=$2
IDX_END=$3
shift 3

export SCRIPT_PATH

run_one() {
    idx=$1
    shift
    forge script "$SCRIPT_PATH" --sig "run(uint256)" "$idx" "$@" -v 2>&1 \
        | grep -v "No files changed, compilation skipped" \
        | sed "s/^/[idx $idx] /"
}
export -f run_one

seq "$IDX_START" "$IDX_END" | xargs -P 5 -I{} bash -c 'run_one {} "$@"' _ "$@"
