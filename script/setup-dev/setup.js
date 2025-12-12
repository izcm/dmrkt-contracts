const { execSync } = require("child_process");
const fs = require("node:fs");

// MOVE TO HH-SCRIPT: https://medium.com/coinmonks/impersonating-accounts-with-hardhat-21212c94dcec

// ---- CONFIG ----
const WALLET = process.env.WALLET;
const BAYC = "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d"; // BAYC mainnet contract

// --- READ MARKETPLACE FROM DEPLOYMENT OUTPUT ---
const readLogs = () => {
  try {
    const text = fs.readFileSync("deploy-engine.log", "utf8");

    let search = "Engine created at address: ";
    let start = text.search(search);

    if (start === -1) {
      console.log("No match found.");
      return;
    }

    const after = start + search.length;
    const end = text.indexOf("\n", after);

    const marketplace = text.slice(after, end).trim();
    console.log("Marketplace Address: ", marketplace);

    return marketplace;
  } catch (err) {
    console.log(err);
  }
};

const MARKETPLACE = readLogs();

// --- LINKS ---
// https://ethereum.org/developers/docs/apis/json-rpc/
// https://getfoundry.sh/anvil/reference/
// https://v2.hardhat.org/hardhat-network/docs/reference#hardhat-network-methods

// ---- HELPERS ----
const rpc = (method, params = []) => {
  const payload = {
    jsonrpc: "2.0",
    id: 1,
    method,
    params,
  };
  const result = execSync(
    `curl -X POST -s --data '${JSON.stringify(payload)}' http://localhost:8545`
  ).toString();
  return JSON.parse(result);
};

// ---- SCRIPT ----

// Give 1000 ETH
console.log("Giving myself ETH...");
rpc("anvil_setBalance", [
  WALLET,
  "0x3635C9ADC5DEA00000", // 1000 ETH
]);

// Get ape #0 owner
console.log("Fetching owner of Ape #0...");
const owner_raw = execSync(`cast call ${BAYC} "ownerOf(uint256)" 0`)
  .toString()
  .trim();

// trim owner
const owner = "0x".concat(owner_raw.slice(-40));
console.log(`Owner of ape 0 is ${owner}`);

// Impersonate ape #0 owner
console.log("Impersonating Ape #0 owner...");
rpc("anvil_impersonateAccount", [owner]);

// Approve marketplace for all BAYC held by that owner
console.log("🪪 Approving marketplace...");

process.exit(0);

execSync(
  `cast send ${BAYC} "setApprovalForAll(address,bool)" ${MARKETPLACE} true --from ${owner}`,
  { stdio: "inherit" }
);

// Stop impersonation
console.log(`Stopping impersonation of ${owner}`);
rpc("anvil_stopImpersonatingAccount", [owner]);

console.log("Setup complete!");
console.log("Now funded + impersonating + approved.");
