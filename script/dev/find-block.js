// === constants ===
const API_KEY = process.env.ALCHEMY_KEY;

if (!API_KEY) {
  throw new Error("🚨 No API key!");
}

const URL = `https://eth-mainnet.g.alchemy.com/v2/${API_KEY}`;

const DAY = 24 * 60 * 60;

// === args ===

const daysAgo = Number(process.argv[2]);
if (!daysAgo) throw new Error("🚨 Pass days ago as param!");

// === semantic helpers ===

const hexToNum = (h) => parseInt(h, 16);
const numToHex = (n) => "0x" + n.toString(16);

const options = (target) => {
  return {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      method: "eth_getBlockByNumber",
      params: [target, false],
      id: 1,
    }),
  };
};

// === http ===

const getBlock = async (blocknumber) => {
  const param = blocknumber === "latest" ? "latest" : numToHex(blocknumber);

  const res = await fetch(URL, options(param));
  const data = await res.json();

  return data.result;
};

const blockClean = async (blocknumber) => {
  const { number, timestamp } = await getBlock(blocknumber);

  return { number: hexToNum(number), timestamp: hexToNum(timestamp) };
};

// === binary search ===

const findBlockFromDaysAgo = async (daysAgo) => {
  const latest = await blockClean("latest");
  const targetTime = latest.timestamp - daysAgo * DAY;

  let lo = 0;
  let hi = latest.number;

  // lo guess too new => fall back to 0
  const loBlock = await blockClean(lo);
  if (loBlock.timestamp > targetTime) lo = 0;

  // binary search for last block with timestamp <= targetTime
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    const { timestamp } = await blockClean(mid);

    if (timestamp <= targetTime) lo = mid + 1;
    else hi = mid - 1;
  }

  return hi;
};

const found = await findBlockFromDaysAgo(daysAgo);
console.log(`Found block ${daysAgo} days ago: #${found}`);
