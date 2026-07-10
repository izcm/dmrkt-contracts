import { createPublicClient, createWalletClient, Hex, http } from "viem";
import { anvil } from "viem/chains";

import { readFileSync, writeFileSync } from "node:fs";

import {
  initNonces,
  pollReceipts,
  processUnsentEnvelopes,
} from "./dispatch.js";
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

  const onEnvelopeUpdate = (txEnvelopes: TxEnvelope[]) => {
    writeFileSync(txFile, JSON.stringify(txEnvelopes, null, 2));
  };

  while (Date.now() < deadline) {
    await processUnsentEnvelopes(
      walletClient,
      nonceTracker,
      txEnvelopes,
      onEnvelopeUpdate,
    );

    await pollReceipts(publicClient, txEnvelopes, onEnvelopeUpdate);

    logProgress(txEnvelopes);

    await new Promise((res) => setTimeout(res, 5000));
  }
}

function logProgress(txEnvelopes: TxEnvelope[]) {
  const counts = { unsent: 0, pending: 0, success: 0, failure: 0 };

  for (const tx of txEnvelopes) {
    if (tx.status === undefined) counts.unsent++;
    else if (tx.status === "pending") counts.pending++;
    else if (tx.status === "success") counts.success++;
    else if (tx.status === "failure") counts.failure++;
  }

  console.log(
    `[${new Date().toISOString()}] total=${txEnvelopes.length} ` +
      `unsent=${counts.unsent} pending=${counts.pending} ` +
      `success=${counts.success} failure=${counts.failure}`,
  );
}

main();
