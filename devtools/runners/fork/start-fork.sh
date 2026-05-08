#!/bin/bash

# Kill previous anvil if running
pkill anvil 2>/dev/null

TOML="./pipeline.toml"
MNEMONIC_JSON="./data/31337/mnemonic.json"

# read fork config
FORK_START_BLOCK=$(awk -F ' ' '$1=="fork_start_block" { print $3 }' $TOML)
PHRASE=$([ -f "$MNEMONIC_JSON" ] && jq -r .mnemonic "$MNEMONIC_JSON" || echo "")

MNEMONIC_FLAG=()
[ -n "$PHRASE" ] && MNEMONIC_FLAG=(--mnemonic "$PHRASE")

# Start a fresh fork
# https://getfoundry.sh/anvil/reference/anvil/
anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/"$ALCHEMY_KEY" \
  --chain-id "$CHAIN_ID" \
  --host "$RPC_HOST" \
  --port "$RPC_PORT" \
  "${MNEMONIC_FLAG[@]}" \
  --accounts 10 \
  --fork-block-number "${FORK_START_BLOCK:-0}" \
  --silent &

# Wait for Anvil to start
sleep 2