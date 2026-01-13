import fs from "node:fs/promises";

// === config ===

// TODO: maybe have a temporary anvil fork => query this for correct blocknumber => stop fork => restart at blocknumber
// then API_KEY can be removed as a dev dependency

const DAY = 24 * 60 * 60;
const API_KEY = process.env.ALCHEMY_KEY;

if (!API_KEY) {
  throw new Error("🚨 No API key!");
}

const url = `https://eth-mainnet.g.alchemy.com/v2/${API_KEY}`;
const tomlFile = "./deployments.toml";

// === args ===

const secondsAgo = Number(process.argv[2]);
if (!secondsAgo) throw new Error("🚨 Pass seconds ago as param!");

// arg not set => now.timestamp is written to .toml
const pipelineEndTsArg = process.argv[3] !== undefined ? process.argv[3] : null;

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

const writePipelineWindowToml = async ({
  path,
  pipelineStartTs,
  pipelineEndTs,
  forkBlockNumber,
}) => {
  let toml = await fs.readFile(path, "utf8");

  // regex: grab the [1337.uint] block only
  const sectionRegex = /\[1337\.uint\][\s\S]*?(?=\n\[|$)/;

  const match = toml.match(sectionRegex);

  if (!match) {
    throw new Error("Failed to fetch timestamps: missing {1337.uint] section");
  }

  let section = match[0];

  section = section
    .replace(/pipeline_start_ts\s*=.*\n?/, "")
    .replace(/pipeline_end_ts\s*=.*\n?/, "")
    .replace(/fork_block_number\s*=.*\n?/, "");

  section +=
    `pipeline_start_ts = ${pipelineStartTs}\n` +
    `pipeline_end_ts = ${pipelineEndTs}\n` +
    `fork_block_number = ${forkBlockNumber}\n`;

  toml = toml.replace(sectionRegex, section);

  await fs.writeFile(path, toml);
};

// === run ===

const blocknumber = await findBlockBefore(secondsAgo);
const block = await blockMeta(blocknumber);

const pipelineStartTs = block.timestamp;
const pipelineEndTs = pipelineEndTsArg ?? Math.floor(Date.now() / 1000);

await writePipelineWindowToml({
  path: tomlFile,
  pipelineStartTs,
  pipelineEndTs,
  forkBlockNumber: block.number,
});

// === logs ===

console.log("\n" + "=".repeat(60));
console.log("✔ Complete!");
console.log("=".repeat(60));
console.log(`\nFork prepared at block: ${block.number}`);
console.log(`\n⏰ Timestamps:`);
console.log(`  start: ${pipelineStartTs}`);
console.log(`  end:   ${pipelineEndTs}`);
console.log("\n" + "=".repeat(60) + "\n");
