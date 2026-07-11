import { afterEach, describe, expect, it, vi } from "vitest";
import { accountAtIndex } from "../account-at-idx.js";

describe("accountAtIdx", () => {
  afterEach(() => vi.unstubAllEnvs());

  it("throws when PARTICIPANT_MNEMONIC is not set", () => {
    expect(() => accountAtIndex(1)).toThrow();
  });

  it("gets correct account", () => {
    vi.stubEnv(
      "PARTICIPANT_MNEMONIC",
      "test test test test test test test test test test test junk",
    );
    expect(accountAtIndex(0).address).toBe(
      "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    );
  });
});
