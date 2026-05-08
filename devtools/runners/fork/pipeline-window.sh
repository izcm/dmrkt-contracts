#!/usr/bin/env bash
set -euo pipefail

#
# Resolves the fork start block and pipeline timestamp window, then writes them to pipeline.toml.
# Uses cast to find the block closest to <seconds_ago> from now on the source chain.
#
# Usage: pipeline-window.sh <seconds_ago> [pipeline_end_ts]
# Env:   FORK_RPC  — RPC URL of the chain to fork (any provider, e.g. https://eth-mainnet.g.alchemy.com/v2/<key>)
#        TOML         — path to pipeline.toml

# === config ===

: "${FORK_RPC:?🚨 FORK_RPC not set}"
: "${TOML:?🚨 TOML not set}"

SECONDS_AGO=${1:?🚨 pass seconds ago}
PIPELINE_END_TS=${2:-$(date +%s)}

# === get timestamps ===

LATEST_TS=$(cast block latest -f timestamp --rpc-url "$FORK_RPC")

TARGET_TS=$((LATEST_TS - SECONDS_AGO))

FORK_START_BLOCK=$(cast find-block "$TARGET_TS" --rpc-url "$FORK_RPC")
PIPELINE_START_TS=$(cast block "$FORK_START_BLOCK" -f timestamp --rpc-url "$FORK_RPC")

# === write TOML ===

TMP_TOML=$(mktemp)

awk -v start="$PIPELINE_START_TS" \
    -v end="$PIPELINE_END_TS" \
    -v block="$FORK_START_BLOCK" \
    '
    BEGIN { in_section=0; written=0 }

    /^\[31337\.uint\]/ {
        print
        print "pipeline_start_ts = " start
        print "pipeline_end_ts = " end
        print "fork_start_block = " block
        in_section=1
        written=1
        next
    }

    /^\[/ { in_section=0 }

    {
        if (in_section &&
            (index($0, "pipeline_start_ts") ||
            index($0, "pipeline_end_ts") ||
            index($0, "fork_start_block")))
            next

        print
    }

    END {
        if (!written) {
            print ""
            print "[31337.uint]"
            print "pipeline_start_ts = " start
            print "pipeline_end_ts = " end
            print "fork_start_block = " block
        }
    }
' "$TOML" > "$TMP_TOML"

cp "$TMP_TOML" "$TOML"

# === logs ===

sep() { echo "========================================"; }

echo
sep
echo "✔ Complete!"
sep
echo
echo " Fork target block: $FORK_START_BLOCK"
echo
echo "⏰ Timestamps:"
echo "  start: $PIPELINE_START_TS"
echo "  end:   $PIPELINE_END_TS"
echo
sep
