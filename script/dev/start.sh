#!/bin/bash

source .env

# Kill previous anvil if running
pkill anvil 2>/dev/null

# TODO: have a javscript fetch the actual blocknumber 30 days back dynamically
# + write the blocknumber timestamp to .env or deployments.toml

# use hardcoced value temporarily:
# TARGET_BLOCK=0x15f9000
# HISTORY_START_TS=<derived once>
# NOW_TS=$(date +%s)

# Start a fresh fork
# https://getfoundry.sh/anvil/reference/anvil/
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_KEY \
  --port 8545 \
  --chain-id 1337 \
  --host 0.0.0.0 \
  --fork-block-number 23597600 \
  --silent &

# Wait for Anvil to start
sleep 2
