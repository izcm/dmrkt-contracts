#!/bin/bash
# Usage: check-balances.sh
#
# prints balance for participant wallets idx 0..100 derived from PARTICIPANT_MNEMONIC

PHRASE="$PARTICIPANT_MNEMONIC"

for idx in $(seq 0 100); do
    p_addr=$(cast wallet address --mnemonic "${PHRASE//\"/}" --mnemonic-index "$idx")
    balance=$(cast balance "$p_addr" --rpc-url "$RPC_URL")
    echo "[idx $idx] $p_addr -> $balance"
done
