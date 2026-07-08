import { createPublicClient, createWalletClient, Hex, http } from "viem";
import { anvil } from "viem/chains";

import { readFileSync, writeFileSync } from "node:fs";

import { initNonces, processTxEnvelopes } from "./logic.js";
import { TxEnvelope, TxEnvelopeSchema } from "./schemas.js";

async function main() {
  const txFile = process.argv[2];
  const timespanSeconds = Number(process.argv[3]);

  const txEnvelopes: TxEnvelope[] = TxEnvelopeSchema.array().parse(
    JSON.parse(readFileSync(txFile, "utf-8")),
  );

  const walletClient = createWalletClient({
    chain: anvil,
    transport: http(),
  });
  const publicClient = createPublicClient({
    chain: anvil,
    transport: http(),
  });

  const fromIdxs = txEnvelopes.map((tx) => tx.from.idx);

  const nonceTracker = new Map<Hex, number>();
  await initNonces(publicClient, nonceTracker, fromIdxs);

  const deadline = Date.now() + timespanSeconds * 1000;
  while (Date.now() < deadline) {
    await processTxEnvelopes(
      walletClient,
      nonceTracker,
      txEnvelopes,
      (txEnvelopes) => {
        writeFileSync(txFile, JSON.stringify(txEnvelopes, null, 2));
      },
    );
  }
}

main();
