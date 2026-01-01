#!/bin/bash

source "$ENV_ROOT/.env"

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Missing Arguments - Usage: execute-epoch.sh EPOCH EPOCH_SIZE"
    exit 1
fi

EPOCH=$1
EPOCH_SIZE=$2

echo "🎬 Execute history for epoch $EPOCH"

forge script $DEV_STATE/ExecuteHistory.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --sender $SENDER \
    --private-key $PRIVATE_KEY \
    --sig "run(uint256,uint256)" \
    $EPOCH $EPOCH_SIZE

