#!/bin/bash

EPOCH_COUNT=$1
EPOCH_SIZE=$2

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Missing Arguments - Usage: execute-epoch.sh EPOCH_START EPOCH_END EPOCH_SIZE"
    exit 1
fi

SLEEP_SECONDS=2

for ((epoch=0; epoch<EPOCH_COUNT; epoch++));
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

    cast rpc evm_increaseTime $EPOCH_SIZE
    cast rpc evm_mine

    echo "🎬 Execute history for epoch $epoch"

    # TODO: just have a super minimal executeorder.s.sol script 
    # execute per order and forward betweem
    # ARGS: EPOCH EPOCH_SIZE AND EXCLUDE_CB
    # pass the name of some file containing the excludeFromCb tokenIds for order
    # (the array of tokenIds to avoid for collectionBids (sold later in pipeline)
    # can u pass a tokenId array from bash ..? (or must it be file path and read l8r?)

    #./$DEV_STATE/execute-epoch.sh $epoch $EPOCH_SIZE
    
    #forge script $DEV_STATE/ExecuteHistory.s.sol \
    #    --rpc-url $RPC_URL \
    #    --broadcast \
    #    --sender $SENDER \
    #    --private-key $PRIVATE_KEY \
    #    --sig "run(uint256,uint256)" \
    #    $epoch $EPOCH_SIZE


    # sleep $SLEEP_SECONDS
done

echo "✔ All epochs completed!"

OUT_FILE="data/1337/latest-block.txt"

echo "Latest block saved to ${OUT_FILE}"

cast block latest > ${OUT_FILE}