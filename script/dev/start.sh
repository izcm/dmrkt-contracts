#!/bin/bash

# Kill previous anvil if running
pkill anvil 2>/dev/null

TOML="./deployments.toml"

ANVIL_FORK_BLOCK_NUMBER=$(awk -F ' ' '$1=="fork_block_number" { print $3 }' $TOML)

# Start a fresh fork
# https://getfoundry.sh/anvil/reference/anvil/
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/"$ALCHEMY_KEY" \
  --port 8545 \
  --chain-id 1337 \
  --host 0.0.0.0 \
  --fork-block-number "$ANVIL_FORK_BLOCK_NUMBER"  \
  --silent &

# Wait for Anvil to start
sleep 2