import { mnemonicToAccount } from "viem/accounts";

export function accountAtIndex(idx: number) {
  const mnemonic = process.env.PARTICIPANT_MNEMONIC;
  if (!mnemonic) throw new Error("PARTICIPANT_MNEMONIC is not set");
  return mnemonicToAccount(mnemonic, { addressIndex: idx });
}
