import { describe, expect, it, vi } from "vitest";

import { encodeCall } from "../encode-call.js";
import { accountAtIndex } from "../account-at-idx.js";

vi.mock("../account-at-idx.js", () => ({
  accountAtIndex: vi.fn(),
}));

describe("encodeCall", () => {
  const someAddr = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";

  it("returns concatenated func selector + encoded params", () => {
    const sig = "ownerOf(uint256)";
    const args = [123];

    expect(encodeCall(sig, args)).toBe(
      "0x6352211e000000000000000000000000000000000000000000000000000000000000007b",
    );
  });

  describe("primitive arg encoding", () => {
    it("encodes a single address arg", () => {
      expect(encodeCall("sig(address)", [someAddr])).toBe(
        "0x04bfb3f6000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      );
    });

    it("encodes multiple args of mixed types", () => {
      const sig = "sig(address,uint256,bool)";
      const args = [someAddr, 123n, true];

      expect(encodeCall(sig, args)).toBe(
        "0xfcb58058000000000000000000000000f39fd6e51aad88f6f4ce6ab8827279cfffb92266000000000000000000000000000000000000000000000000000000000000007b0000000000000000000000000000000000000000000000000000000000000001",
      );
    });

    it("returns just the selector when args is empty", () => {
      expect(encodeCall("f()", [])).toBe("0x26121ff0");
    });
  });

  describe("uint/int conversion", () => {
    const sig = "sig(uint256)";
    const arg = 1n;
    const expected =
      "0x136713870000000000000000000000000000000000000000000000000000000000000001";

    it("converts a number arg to BigInt for uint types", () => {
      expect(encodeCall(sig, [Number(arg)])).toBe(expected);
    });

    it("converts a string arg to BigInt for uint types", () => {
      expect(encodeCall(sig, [arg.toString()])).toBe(expected);
    });
    it("accepts a bigint arg as-is for uint types", () => {
      expect(encodeCall(sig, [arg])).toBe(expected);
    });
  });

  describe("object args", () => {
    it("parses participant arg", () => {
      vi.mocked(accountAtIndex).mockReturnValueOnce({ address: someAddr } as any);
      encodeCall("sig(address)", [{ kind: "participant", idx: 1 }]);
      expect(accountAtIndex).toHaveBeenCalledWith(1);
    });
  });

  // --- SAD PATHS ---

  describe("unsupported types", () => {
    it("throws on array types", () => {
      expect(() => encodeCall("sig(uint256[])", [[1, 2, 3]])).toThrow();
    });
  });

  describe("unsupported args", () => {
    it("throws on a non-participant object arg", () => {
      expect(() => encodeCall("sig(address)", [{ foo: "bar" }])).toThrow();
    });

    it("throws on a participant-shaped object with the wrong kind", () => {
      expect(() =>
        encodeCall("sig(address)", [{ kind: "not-participant", idx: 1 }]),
      ).toThrow();
    });
  });
});
