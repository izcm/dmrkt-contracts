import { mnemonicToAccount } from "viem/accounts";

export function accountAtIndex(idx: number) {
  const mnemonic =
    "test test test test test test test test test test test junk";
  return mnemonicToAccount(mnemonic, { addressIndex: idx });
}
