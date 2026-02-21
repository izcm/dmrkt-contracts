// script assumes a running local / external backend
import { readFile } from "node:fs/promises";

const server = "http://localhost:5000/api/orders";

const inFile = "./data/1337/orders-sanitized.json";

const raw = await readFile(inFile, "utf8");

const obj = JSON.parse(raw);
const orders = obj.signedOrders;

orders.map(async (order) => {
  const payload = await fetch(server, {
    method: "POST",
    headers: {
      "content-type": "application/json",
    },
    body: JSON.stringify(order),
  });

  // TODO: make this check status code when implemented
  if (!payload.ok) {
    console.error("Failed to ingest order", await res.text());
    process.exit(1);
  }
});

console.log("\n" + "=".repeat(60));
console.log("Orders exported ✔");
console.log("\n" + "=".repeat(60));
