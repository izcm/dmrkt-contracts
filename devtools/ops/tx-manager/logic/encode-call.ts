import { encodeAbiParameters, Hex, toFunctionSelector } from "viem";
import { accountAtIndex } from "./account-at-idx.js";

type ParticipantArg = { kind: "participant"; idx: number };

function isParticipantArg(arg: unknown): arg is ParticipantArg {
  return (
    typeof arg === "object" &&
    arg !== null &&
    "kind" in arg &&
    arg.kind === "participant" &&
    "idx" in arg &&
    typeof arg.idx === "number"
  );
}

export function encodeCall(sig: string, args: unknown[]) {
  // get function selector
  const selector = toFunctionSelector(sig);

  const inner = sig.slice(sig.indexOf("(") + 1, sig.indexOf(")"));
  const types = inner === "" ? [] : inner.split(",");

  const values = args.map((arg, i) => {
    const type = types[i];

    // special case – participant
    if (isParticipantArg(arg)) {
      return accountAtIndex(arg.idx).address;
    }

    if (typeof arg === "object" && arg !== null && !Array.isArray(arg)) {
      throw new Error(`Unsupported object arg: ${JSON.stringify(arg)}`);
    }

    if (type.endsWith("[]"))
      throw new Error(`Arrays are not supported: ${type}`);

    if (type.startsWith("uint") || type.startsWith("int"))
      return BigInt(arg as string | number | bigint);

    return arg;
  });

  const encodedParams = encodeAbiParameters(
    types.map((type) => ({
      type,
    })),
    values,
  );

  return (selector + encodedParams.slice(2)) as Hex;
}
