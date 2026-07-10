import { HttpRequestError } from "viem";

export function isRetryable(err: unknown): boolean {
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
