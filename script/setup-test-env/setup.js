import { execSync } from "child_process";

// ---- CONFIG ----
const WALLET = process.env.WALLET;
const MARKETPLACE = "0xYourMarketplace";
const BAYC = "0xBC4CA0eda7647A8ab7C2061c2E118A18a936f13D"; // BAYC mainnet contract

// ---- HELPERS ----
function rpc(method, params = []) {
  const payload = {
    jsonrpc: "2.0",
    id: 1,
    method,
    params,
  };
  const result = execSync(
    `curl -s -X POST -H "Content-Type: application/json" --data '${JSON.stringify(
      payload
    )}' http://localhost:8545`
  ).toString();
  return JSON.parse(result);
}

// ---- SCRIPT ----

// Give 1000 ETH
console.log("💸 Giving yourself ETH...");
rpc("anvil_setBalance", [
  YOUR_WALLET,
  "0x3635C9ADC5DEA00000", // 1000 ETH
]);

// Get ape #0 owner
console.log("Fetching owner of ape #0...");
const owner = execSync(`cast call ${BAYC} "ownerOf(uint256)" 0`)
  .toString()
  .trim();
console.log(`Owner of ape 0 is ${owner}`);

// Impersonate ape #0 owner
console.log("🕵️ Impersonating Ape #0 owner...");
rpc("anvil_impersonateAccount", [owner]);

// Approve marketplace for all BAYC held by that owner
console.log("🪪 Approving marketplace...");
execSync(
  `cast send ${BAYC} "setApprovalForAll(address,bool)" ${MARKETPLACE} true --from ${owner}`,
  { stdio: "inherit" }
);

console.log("🚀 Setup complete!");
console.log("You're now funded + impersonating + approved.");
