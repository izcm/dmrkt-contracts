import fs from "node:fs/promises";

const basePath = "./data/1337";

const inFile = `${basePath}/orders-raw.json`;
const outFile = `${basePath}/orders-sanitized.json`;

const raw = await fs.readFile(inFile, "utf8");
const dirty = JSON.parse(raw);

const cleanOrders = dirty.signedOrders.map((order) => {
  const {
    signature: { _, ...cleanSig },
    ...restOrder
  } = order;

  return { ...restOrder, signature: cleanSig };
});

const cleaned = {
  ...dirty,
  signedOrders: cleanOrders,
};

await fs.writeFile(outFile, JSON.stringify(cleaned));

console.log("\n" + "=".repeat(60));
console.log(`Orders sanitized ✔`);
console.log("\n" + "=".repeat(60));
