#!/bin/bash
#
# Starts an Anvil mainnet fork. With --replay, forks at the block written to
# pipeline.toml by pipeline-window.sh; otherwise forks at the chain's latest block.
# Funds accounts from the chain-specific mnemonic file if present, otherwise uses Anvil's default.
#
# Usage: start-fork.sh [--replay]
#
# Env:   SOURCE_RPC  — full mainnet RPC URL (any provider, e.g. https://eth-mainnet.g.alchemy.com/v2/<key>)
#        CHAIN_ID, RPC_HOST, RPC_PORT

REPLAY=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --replay) REPLAY=1; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

# Kill previous anvil if running
pkill anvil 2>/dev/null

MNEMONIC_FLAG=()
if [ -n "${PARTICIPANT_MNEMONIC:-}" ]; then
    MNEMONIC_FLAG=(--mnemonic "${PARTICIPANT_MNEMONIC//\"/}")
else
    echo "⚠️  PARTICIPANT_MNEMONIC not set -> using anvil default accounts"
fi

FORK_BLOCK_FLAG=()
if [ "$REPLAY" -eq 1 ]; then
    # read fork config
    FORK_START_BLOCK=$(awk '/^\[31337\.uint\]/{found=1; next} found && $1=="fork_start_block"{print $3; exit} /^\[/{if(found) exit}' "$TOML")
    FORK_BLOCK_FLAG=(--fork-block-number "${FORK_START_BLOCK:-0}")
fi

# Start a fresh fork
# https://getfoundry.sh/anvil/reference/anvil/
anvil --fork-url "$SOURCE_RPC" \
  --chain-id "$CHAIN_ID" \
  --host "$RPC_HOST" \
  --port "$RPC_PORT" \
  "${MNEMONIC_FLAG[@]}" \
  --accounts "${P_SIZE:-10}" \
  "${FORK_BLOCK_FLAG[@]}" \
  --silent &

# Wait for Anvil to start
sleep 10

#   --accounts "${P_SIZE:-10}"
