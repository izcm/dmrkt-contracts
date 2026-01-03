#!/bin/bash

EPOCH_START=$1
EPOCH_END=$2
EPOCH_SIZE=$3

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Missing Arguments - Usage: execute-epoch.sh EPOCH_START EPOCH_END EPOCH_SIZE"
    exit 1
fi

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
    
    echo "🎬 Execute history for epoch $EPOCH"

    #./$DEV_STATE/execute-epoch.sh $epoch $EPOCH_SIZE
    forge script $DEV_STATE/ExecuteHistory.s.sol \
        --rpc-url $RPC_URL \
        --broadcast \
        --sender $SENDER \
        --private-key $PRIVATE_KEY \
        --sig "run(uint256,uint256)" \
        $epoch $EPOCH_SIZE


    sleep $SLEEP_SECONDS
done

echo "✔ All epochs completed!"

