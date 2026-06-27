# Anvil lets us specify which users are the 10'000 ETH funded group.
#
# When running simulation on eg. Sepolia its likely that a superuser initially holds all funds.
# This script distributes superuser's ETH evenly on participant group.
#

# positional args
USAGE_MSG="Usage: distribute-eth.sh <participant_count> <wei_per_participant> --rpc-url <url>"
: "${1:?"$USAGE_MSG"}"
: "${2:?"$USAGE_MSG"}"

P_COUNT=$1
WEI_PER_USER=$2
shift 2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rpc-url) RPC_URL="$2"; shift 2 ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

: "${RPC_URL:?$USAGE_MSG}"

# env 
: "${DEPLOYER_PK:?DEPLOYER_PK not set}"
: "${PHRASE:?PHRASE not set}"

for ((i = 0; i < P_COUNT; i++)); do
    p=$(cast wallet address --mnemonic "$PHRASE" --mnemonic-index "$i")
    cast send "$p" \
        --value "$WEI_PER_USER" \
        --private-key "$DEPLOYER_PK" \
        --fork-url "$RPC_URL"
done