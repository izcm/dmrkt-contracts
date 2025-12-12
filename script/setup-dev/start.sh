#!/bin/bash

ENV_FILE="../../.env"
source $ENV_FILE

# Kill previous anvil if running
pkill anvil 2>/dev/null

# Start a fresh fork
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY \
  --port 8545 \
  --chain-id 1337 \
  --host 0.0.0.0 \
  --silent &

# Wait for Anvil to start
sleep 2
