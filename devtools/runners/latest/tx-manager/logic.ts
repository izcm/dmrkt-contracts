import {
  Chain,
  Hex,
  HttpRequestError,
  PublicClient,
  Transport,
  WalletClient,
} from "viem";
import { mnemonicToAccount } from "viem/accounts";

import { TxEnvelope } from "./schemas.js";

// gets nonce with any eventual pending
export async function initNonces(
  publicClient: PublicClient<Transport, Chain>,
  nonceTracker: Map<Hex, number>,
  fromIdxs: number[],
) {
  fromIdxs.forEach(async (idx) => {
    const address = accountAtIndex(idx).address;
    const nonce = await publicClient.getTransactionCount({
      address,
      blockTag: "pending",
    });
    nonceTracker.set(address, nonce);
  });
}

// --- tx manager ---

export async function processTxEnvelopes(
  walletClient: WalletClient<Transport, Chain>,
  nonceTracker: Map<Hex, number>,
  txEnvelopes: TxEnvelope[],
  onEnvelopeUpdate: (txEnvelopes: TxEnvelope[]) => void,
) {
  const pending = txEnvelopes.filter(
    (tx) => tx.status !== "success" && tx.status !== "failure",
  );
  // poll transaction receipts

  for (const tx of pending) {
    try {
      if (tx.txHash !== undefined) {
        // already sent before, do not resend
        continue;
      }

      const { nonce, hash: txHash } = await sendTx(
        tx,
        walletClient,
        nonceTracker,
      );

      tx.status = "pending";
      tx.nonce = nonce;
      tx.txHash = txHash;

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

  return { nonce, hash };
}

// --- error handling ---

function isRetryable(err: unknown): boolean {
  if (err instanceof HttpRequestError && err.status) {
    return [403, 408, 413, 429, 500, 502, 503, 504].includes(err.status);
  }
  if (
    err &&
    typeof err === "object" &&
    "code" in err &&
    typeof err.code === "number"
  ) {
    return (
      err.code === -1 ||
      err.code === -32603 ||
      err.code === -32005 ||
      err.code === 429
    );
  }
  // only retry known transient network failures; anything else (bugs,
  // validation errors, unrecognized failures) is treated as permanent
  if (err instanceof Error) {
    return /ECONNRESET|ENOTFOUND|EAI_AGAIN|ETIMEDOUT|ECONNREFUSED|fetch failed/i.test(
      err.message,
    );
  }
  return false;
}

// --- helpers ---

function accountAtIndex(idx: number) {
  const mnemonic =
    "test test test test test test test test test test test junk";
  return mnemonicToAccount(mnemonic, { addressIndex: idx });
}
