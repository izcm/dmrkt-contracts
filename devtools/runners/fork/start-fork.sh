#!/bin/bash
#
# Starts an Anvil mainnet fork at the block written to pipeline.toml by pipeline-window.sh.
# Funds accounts from the chain-specific mnemonic file if present, otherwise uses Anvil's default.
#
# Env:   SOURCE_RPC  — full mainnet RPC URL (any provider, e.g. https://eth-mainnet.g.alchemy.com/v2/<key>)
#        CHAIN_ID, RPC_HOST, RPC_PORT

# Kill previous anvil if running
pkill anvil 2>/dev/null

MNEMONIC_FLAG=()
if [ -n "${PARTICIPANT_MNEMONIC:-}" ]; then
    MNEMONIC_FLAG=(--mnemonic "${PARTICIPANT_MNEMONIC//\"/}")
else
    echo "⚠️  PARTICIPANT_MNEMONIC not set -> using anvil default accounts"
fi

# read fork config
FORK_START_BLOCK=$(awk '/^\[31337\.uint\]/{found=1; next} found && $1=="fork_start_block"{print $3; exit} /^\[/{if(found) exit}' "$TOML")

# Start a fresh fork
# https://getfoundry.sh/anvil/reference/anvil/
anvil --fork-url "$SOURCE_RPC" \
  --chain-id "$CHAIN_ID" \
  --host "$RPC_HOST" \
  --port "$RPC_PORT" \
  "${MNEMONIC_FLAG[@]}" \
  --accounts "${MAX_P_SIZE:-10}" \
  --fork-block-number "${FORK_START_BLOCK:-0}" \
  --silent &

# Wait for Anvil to start
sleep 15