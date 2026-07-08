import { z } from "zod";
import { createPublicClient, createWalletClient, http } from "viem";
import { mnemonicToAccount } from "viem/accounts";
import { anvil } from "viem/chains";
import { readFileSync, writeFileSync } from "node:fs";

// --- chain clients ---

const walletClient = createWalletClient({
  chain: anvil,
  transport: http(),
});

const publicClient = createPublicClient({
  chain: anvil,
  transport: http(),
});

// --- json schemas ---

const BaseEnvelopeSchema = z.object({
  status: z.enum(["success", "pending", "revert", "assume dropped"]).nullish(),
  txHash: z.string().nullish(),
});

const participant = z.object({
  kind: z.literal("participant"),
  idx: z.number(),
});

const EthTransferSchema = BaseEnvelopeSchema.extend({
  type: z.literal("eth-transfer"),
  from: participant,
  to: participant,
  value: z.string(),
});

const ContractCallSchema = BaseEnvelopeSchema.extend({
  type: z.literal("contract-call"),
  to: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  sig: z.string(),
});

const TxEnvelopeSchema = z.discriminatedUnion("type", [
  EthTransferSchema,
  ContractCallSchema,
]);

type TxEnvelope = z.infer<typeof TxEnvelopeSchema>;

// --- tx manager ---

async function something() {
  const txFile = process.argv[2];

  const json = readFileSync(txFile, "utf-8");
  const envelopes: TxEnvelope[] = TxEnvelopeSchema.array().parse(
    JSON.parse(json),
  );

  // pending txs
  const pending = envelopes.filter(
    (tx) => tx.status === "pending" || tx.status === undefined,
  );

  // phas 2: for all pending txs

  for (const tx of pending) {
    if (tx.type === "eth-transfer") {
      const hash = await walletClient.sendTransaction({
        account: accountAtIndex(tx.from.idx),
        to: accountAtIndex(tx.to.idx).address,
        value: BigInt(tx.value),
      });

      tx.txHash = hash;
    } else {
      // envelope is automatically Erc20TransferSchema here
      console.log("TODO: ERC20 transfer");
    }
  }

  writeFileSync(txFile, JSON.stringify(envelopes));
}

// --- helpers ---

function accountAtIndex(idx: number) {
  const mnemonic =
    "test test test test test test test test test test test junk";
  return mnemonicToAccount(mnemonic, { addressIndex: idx });
}

something();
