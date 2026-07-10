import {
  Chain,
  Hex,
  PublicClient,
  TransactionReceiptNotFoundError,
  Transport,
  WalletClient,
} from "viem";

import { accountAtIndex } from "./logic/account-at-idx.js";
import { isRetryable } from "./logic/is-retryable.js";
import { TxEnvelope } from "./schemas.js";

// gets nonce with any eventual pending
export async function initNonces(
  publicClient: PublicClient<Transport, Chain>,
  nonceTracker: Map<Hex, number>,
  fromIdxs: number[],
) {
  await Promise.all(
    fromIdxs.map(async (idx) => {
      const address = accountAtIndex(idx).address;
      const nonce = await publicClient.getTransactionCount({
        address,
        blockTag: "pending",
      });
      nonceTracker.set(address, nonce);
    }),
  );
}

// poll transaction receipts
export async function pollReceipts(
  publicClient: PublicClient<Transport, Chain>,
  txEnvelopes: TxEnvelope[],
  onEnvelopeUpdate: (txEnvelopes: TxEnvelope[]) => void,
) {
  const pending = txEnvelopes.filter(
    (tx) => tx.status !== "success" && tx.status !== "failure",
  );

  for (const tx of pending) {
    // skip if tx is unsent
    if (tx.txHash === undefined) continue;

    try {
      const receipt = await publicClient.getTransactionReceipt({
        hash: tx.txHash as Hex,
      });

      tx.status = receipt.status;

      console.log(
        `  <- receipt from=${tx.from.idx} status=${receipt.status} hash=${tx.txHash}`,
      );

      onEnvelopeUpdate(txEnvelopes);
    } catch (err) {
      if (err instanceof TransactionReceiptNotFoundError) {
        // no tx receipt found -> continue
        continue;
      }

      throw err;
    }
  }
}

// process pending
export async function processUnsentEnvelopes(
  walletClient: WalletClient<Transport, Chain>,
  nonceTracker: Map<Hex, number>,
  txEnvelopes: TxEnvelope[],
  onEnvelopeUpdate: (txEnvelopes: TxEnvelope[]) => void,
) {
  const unsent = txEnvelopes.filter((tx) => tx.status === undefined);

  for (const tx of unsent) {
    try {
      const { nonce, hash: txHash } = await sendTx(
        tx,
        walletClient,
        nonceTracker,
      );

      tx.status = "pending";
      tx.nonce = nonce;
      tx.txHash = txHash;

      console.log(
        `  -> sent from=${tx.from.idx} nonce=${nonce} hash=${txHash}`,
      );

      onEnvelopeUpdate(txEnvelopes);
    } catch (err) {
      console.error("send failed:", err);

      // not retruable ?? mark as failed and skip next round
      if (!isRetryable(err)) {
        tx.status = "failure";
        tx.errMsg = err instanceof Error ? err.message : JSON.stringify(err);
        onEnvelopeUpdate(txEnvelopes);
      }
    }
  }
}

async function sendTx(
  tx: TxEnvelope,
  walletClient: WalletClient<Transport, Chain>,
  nonceTracker: Map<Hex, number>,
) {
  const from = accountAtIndex(tx.from.idx);

  const nonce = nonceTracker.get(from.address);
  if (nonce === undefined) {
    throw new Error(`no nonce tracked for ${from.address}`);
  }

  let hash;

  if (tx.type === "eth-transfer") {
    // special case eth transfers
    hash = await walletClient.sendTransaction({
      account: from,
      to: accountAtIndex(tx.to.idx).address,
      value: BigInt(tx.value),
      nonce,
    });
  } else {
    // smart contract call
    hash = await walletClient.sendTransaction({
      account: from,
      to: tx.to as Hex,
      nonce,
    });
  }

  nonceTracker.set(from.address, nonce + 1);

  return { nonce, hash };
}
