#!/bin/bash

EPOCH_COUNT=$1
EPOCH_SIZE=$2

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Missing Arguments - Usage: execute-epoch.sh EPOCH_START EPOCH_END EPOCH_SIZE"
    exit 1
fi

SLEEP_SECONDS=2

for epoch in $(seq $EPOCH_COUNT);
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
    
    # defaults to localhost:8545
    cast block latest > output.txt

    cast rpc evm_increaseTime $EPOCH_SIZE
    cast rpc evm_mine

    cast block latest >> output.txt

    echo "🎬 Execute history for epoch $epoch"

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