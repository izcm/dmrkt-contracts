#!/bin/bash

source "$ENV_ROOT/.env"

EPOCH_START=$1
EPOCH_END=$2
EPOCH_SIZE=$3

#EPOCH_SIZE=604800 # 7 days

SLEEP_SECONDS=2

for epoch in $(seq $EPOCH_START $EPOCH_END);
do
    echo "🧱 Building history for epoch $epoch"

    forge script $DEV_STATE/BuildHistory.s.sol \
        --rpc-url $RPC_URL \
        --broadcast \
        --sender $SENDER \
        --private-key $PRIVATE_KEY \
        --sig "run(uint256,uint256)" \
        $epoch $EPOCH_SIZE  \

    sleep $SLEEP_SECONDS
    
    ./$DEV_STATE/execute-epoch.sh $epoch $EPOCH_SIZE

    sleep $SLEEP_SECONDS
done

echo "✔ All epochs completed!"


