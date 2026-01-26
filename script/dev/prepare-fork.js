import fs from "node:fs/promises";

// === config ===

const DAY = 24 * 60 * 60;
const API_KEY = process.env.ALCHEMY_KEY;

if (!API_KEY) {
  throw new Error("🚨 No API key!");
}

const url = `https://eth-mainnet.g.alchemy.com/v2/${API_KEY}`;
const tomlFile = "./pipeline.toml";

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
  windowStart,
  windowEnd,
  forkStartBlock,
}) => {
  let toml = await fs.readFile(path, "utf8");

  const sectionHeader = "[31337.uint]";
  const sectionRegex = /\[31337\.uint\][\s\S]*?(?=\n\[|$)/;

  let section;

  if (sectionRegex.test(toml)) {
    // [31337].uint exists
    section = toml.match(sectionRegex)[0];
  } else {
    // section doesn't exist => append it
    section = `${sectionHeader}\n`;
  }

  section = section
    .replace(/pipeline_start_ts\s*=.*\n?/, "")
    .replace(/pipeline_end_ts\s*=.*\n?/, "")
    .replace(/fork_start_block\s*=.*\n?/, "");

  section +=
    `pipeline_start_ts = ${windowStart}\n` +
    `pipeline_end_ts = ${windowEnd}\n` +
    `fork_start_block = ${forkStartBlock}\n`;

  if (sectionRegex.test(toml)) {
    // replace existing values
    toml = toml.replace(sectionRegex, section);
  } else {
    // append section header + values
    toml += `${toml.endsWith("\n") ? "" : "\n"}\n${section}`;
  }

  await fs.writeFile(path, toml);
};

// === run ===

const blocknumber = await findBlockBefore(secondsAgo);
const block = await blockMeta(blocknumber);

const pipelineStartTs = block.timestamp;
const pipelineEndTs = pipelineEndTsArg ?? Math.floor(Date.now() / 1000);

await writePipelineWindowToml({
  path: tomlFile,
  windowStart: pipelineStartTs,
  windowEnd: pipelineEndTs,
  forkStartBlock: block.number,
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
