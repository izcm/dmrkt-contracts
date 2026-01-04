import fs from "node:fs/promises";

// === config ===

const DAY = 24 * 60 * 60;
const API_KEY = process.env.ALCHEMY_KEY;

if (!API_KEY) {
  throw new Error("🚨 No API key!");
}

const url = `https://eth-mainnet.g.alchemy.com/v2/${API_KEY}`;
const tomlFile = "./deployments.toml";

// === args ===

const daysAgo = Number(process.argv[2]);
if (!daysAgo) throw new Error("🚨 Pass days ago as param!");

// arg not set => now.timestamp is written to .toml
const historyEndTsArg = process.argv[3] !== undefined ? process.argv[3] : null;

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

  const res = await fetch(url, options(param));
  const data = await res.json();

  return data.result;
};

const blockMeta = async (blocknumber) => {
  const { number, timestamp } = await getBlock(blocknumber);

  return { number: hexToNum(number), timestamp: hexToNum(timestamp) };
};

// === binary search ===

const findBlockBefore = async (secondsAgo) => {
  const latest = await blockMeta("latest");
  const targetTime = latest.timestamp - secondsAgo;

  let lo = 0;
  let hi = latest.number;

  // lo guess too new => fall back to 0
  const loBlock = await blockMeta(lo);
  if (loBlock.timestamp > targetTime) lo = 0;

  // binary search for last block with timestamp <= targetTime
  while (lo <= hi) {
    const mid = (lo + hi) >> 1;
    const { timestamp } = await blockMeta(mid);

    if (timestamp <= targetTime) lo = mid + 1;
    else hi = mid - 1;
  }

  return hi;
};

// === io ===

const writeTimestampsToml = async ({ path, historyStartTs, historyEndTs }) => {
  let toml = await fs.readFile(path, "utf8");

  // regex: grab the [1337.uint] block only
  const sectionRegex = /\[1337\.uint\][\s\S]*?(?=\n\[|$)/;

  const match = toml.match(sectionRegex);

  if (!match) {
    throw new Error("Failed to fetch timestamps: missing {1337.uint] section");
  }

  let section = match[0];

  section = section
    .replace(/history_start_ts\s*=.*\n?/, "")
    .replace(/history_end_ts\s*=.*\n?/, "");

  section +=
    `history_start_ts = ${historyStartTs}\n` +
    `history_end_ts = ${historyEndTs}\n`;

  toml = toml.replace(sectionRegex, section);

  await fs.writeFile(path, toml);
};

// === run ===

const blocknumber = await findBlockBefore(daysAgo * DAY);
const block = await blockMeta(blocknumber);

const historyStartTs = block.timestamp;
const historyEndTs = historyEndTsArg ?? Math.floor(Date.now() / 1000);

await writeTimestampsToml({ path: tomlFile, historyStartTs, historyEndTs });

// === logs ===

console.log("\n" + "=".repeat(60));
console.log("✔ Complete!");
console.log("=".repeat(60));
console.log(`\nFork prepared at block: ${blocknumber.number}`);
console.log(`\n⏰ Timestamps:`);
console.log(`  start: ${historyStartTs}`);
console.log(`  end:   ${historyEndTs}`);
console.log("\n" + "=".repeat(60) + "\n");
