import { HttpRequestError } from "viem";
import { describe, expect, it } from "vitest";

import { isRetryable } from "../is-retryable.js";

describe("isRetryable", () => {
  describe("HttpRequestError", () => {
    it.each([403, 408, 413, 429, 500, 502, 503, 504])(
      "returns true for status %i",
      (status) => {
        const err = new HttpRequestError({ url: "http://x", status });
        expect(isRetryable(err)).toBe(true);
      },
    );

    it("returns false for a non-retryable status", () => {
      const err = new HttpRequestError({ url: "http://x", status: 400 });
      expect(isRetryable(err)).toBe(false);
    });
  });

  describe("RPC-style error codes", () => {
    it.each([-1, -32603, -32005, 429])(
      "returns true for code %i",
      (code) => {
        expect(isRetryable({ code })).toBe(true);
      },
    );

    it("returns false for an unrecognized code", () => {
      expect(isRetryable({ code: -32000 })).toBe(false);
    });

    it("ignores a non-numeric code", () => {
      expect(isRetryable({ code: "429" })).toBe(false);
    });
  });

  describe("transient network error messages", () => {
    it.each([
      "ECONNRESET",
      "ENOTFOUND",
      "EAI_AGAIN",
      "ETIMEDOUT",
      "ECONNREFUSED",
      "fetch failed",
    ])("returns true for message containing %s", (msg) => {
      expect(isRetryable(new Error(msg))).toBe(true);
    });

    it("returns false for an unrelated error message", () => {
      expect(isRetryable(new Error("boom"))).toBe(false);
    });
  });

  describe("other inputs", () => {
    it("returns false for undefined", () => {
      expect(isRetryable(undefined)).toBe(false);
    });

    it("returns false for a string", () => {
      expect(isRetryable("nope")).toBe(false);
    });
  });
});
