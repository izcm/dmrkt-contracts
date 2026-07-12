import {
  createPublicClient,
  createWalletClient,
  defineChain,
  Hex,
  http,
} from "viem";

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

  const rpcUrl = process.env.RPC_URL;
  if (!rpcUrl) throw new Error("RPC_URL not set");

  const chainId = Number(process.env.CHAIN_ID);
  if (!chainId) throw new Error("CHAIN_ID not set");

  const chain = defineChain({
    id: chainId,
    name: `chain-${chainId}`,
    nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  });

  const txEnvelopes: TxEnvelope[] = TxEnvelopeSchema.array().parse(
    JSON.parse(readFileSync(txFile, "utf-8")),
  );

  const walletClient = createWalletClient({
    chain,
    transport: http(rpcUrl),
  });
  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
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

    if (
      txEnvelopes.every(
        (tx) => tx.status === "success" || tx.status === "failure",
      )
    ) {
      break;
    }

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
