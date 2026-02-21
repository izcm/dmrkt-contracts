#!/bin/bash

# Kill previous anvil if running
pkill anvil 2>/dev/null

TOML="./pipeline.toml"

FORK_START_BLOCK=$(awk -F ' ' '$1=="fork_start_block" { print $3 }' $TOML)

# Start a fresh fork
# https://getfoundry.sh/anvil/reference/anvil/
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/"$ALCHEMY_KEY" \
  --port "$RPC_PORT" \
  --chain-id "$CHAIN_ID" \
  --host "$RPC_HOST" \
  --fork-block-number "$FORK_START_BLOCK"  \
  --silent &

# Wait for Anvil to start
sleep 2