# while run-epochs replays history by time warping fork
# this script populates in realtime
# works with testnets eg. Sepolia

# Asuumptions:
# - filenames in ORDERS_DIR with format order_x.json

RED="\033[0;31m"
GREEN="\033[0;32m"
RESET="\033[0m"
YELLOW="\033[0;33m" 

USAGE_MSG="Usage: ./$(basename "$0") <path_to_orders_json> <order_percantage_to_execute>"
: "${PIPELINE_STATE_DIR:?PIPELINE_STATE_DIR not set}"
: "${1:?$USAGE_MSG}"
: "${2:?$USAGE_MSG}"

# positional args
ORDERS_DIR="$1" # path to generated eip-712 orders
EXECUTION_RATE="$2"

# count orders
ORDER_COUNT=$(find "$ORDERS_DIR" -maxdepth 1 -name "order_*" -printf '.' | wc -m)

# also accept positional param execution rate 0-100
# export all
# execute all up to rate %
