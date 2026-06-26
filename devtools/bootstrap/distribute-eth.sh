# Anvil lets us specify which users are the 10'000 ETH funded group.
# When running simulation on eg. Sepolia its likely that a superuser initially holds all funds.

# This script distributes superuser's ETH evenly on participant group.

# todo: pass cound as arg
PARTICIPANT_COUNT=5

if[ ]
MNEMONIC_TXT="data/11155111/mnemonic.txt"

for i in {0..5}
do

    p=cast wallet address --mnemonic "$PHRASE" --mnemonic-index $i
    cast send "$p"
done