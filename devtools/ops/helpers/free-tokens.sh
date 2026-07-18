cd /home/izcm/Projects/dmrkt/dmrkt-contracts/devtools
RPC=$RPC_URL

CONTRACT=0x97ad583F2b3230c7B6E4901a73Ce2096703c623C

i=0

> free-tokens.txt
jq -r '.[].args[1]' data/11155111/state/tx-out/bootstrap-nfts-0.json | sort -n -u | while read -r id; do
  echo "checking $id..."
  owner=$(cast call "$CONTRACT" "ownerOf(uint256)" "$id" --rpc-url "$RPC" 2>/dev/null)
  [[ -z "$owner" ]] && echo "$id" >> free-tokens.txt
  ((i++))
  if (( i % 20 == 0 )); then sleep 1; fi
done
wc -l free-tokens.txt

jq --slurpfile ids <(jq -R . free-tokens.txt) \
  '[.[] | select(.args[1] as $t | $ids | index($t))]' \
  data/11155111/state/tx-out/bootstrap-nfts-0.json > /tmp/filtered.json \
  && mv /tmp/filtered.json data/11155111/state/tx-out/bootstrap-nfts-0.json
