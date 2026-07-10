import { z } from "zod";

export const ParticipantSchema = z.object({
  kind: z.literal("participant"),
  idx: z.number(),
});

const BaseEnvelopeSchema = z.object({
  status: z
    .enum(["success", "pending", "reverted", "failure", "assume dropped"])
    .optional(),
  txHash: z.string().optional(),
  errMsg: z.string().optional(),
  nonce: z.number().optional(),
  gasPrice: z.string().optional(),
  error: z.string().optional(),
});

const EthTransferSchema = BaseEnvelopeSchema.extend({
  type: z.literal("eth-transfer"),
  from: ParticipantSchema,
  to: ParticipantSchema,
  value: z.string(),
});

const ContractCallSchema = BaseEnvelopeSchema.extend({
  type: z.literal("contract-call"),
  from: ParticipantSchema,
  to: z.string().regex(/^0x[a-fA-F0-9]{40}$/),
  sig: z.string(),
  args: z.array(z.union([ParticipantSchema, z.string()])),
});

export const TxEnvelopeSchema = z.discriminatedUnion("type", [
  EthTransferSchema,
  ContractCallSchema,
]);

export type TxEnvelope = z.infer<typeof TxEnvelopeSchema>;
