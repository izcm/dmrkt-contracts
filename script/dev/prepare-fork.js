import fs from "node:fs/promises";

const file = "../../deployments.toml";
// const file = "./deployments.toml";

// get timestamp now() save to nowTs

// backwards 4 weeks = 28 days and fetch blocknumber at the time

// fetch block's block.timestamp => save to historyStartTs

// save blocknumber and call start.sh with blocknumber as argument
const historyStartTs = 1761257000;
const nowTs = 1766342000;

let toml = await fs.readFile(file, "utf8");

// regex: grab the [1337.uint] block only
const sectionRegex = /\[1337\.uint\][\s\S]*?(?=\n\[|$)/;

const match = toml.match(sectionRegex);

if (!match) {
  throw new Error("Failed to fetch timestamps: missing {1337.uint] section");
}

let section = match[0];

section = section
  .replace(/history_start_ts\s*=.*\n?/, "")
  .replace(/now_ts\s*=.*\n?/, "");

section += `history_start_ts = ${historyStartTs}\n` + `now_ts = ${nowTs}\n`;

toml = toml.replace(sectionRegex, section);

await fs.writeFile(file, toml);

console.log("Timestamps written to deployments.toml ✔");
