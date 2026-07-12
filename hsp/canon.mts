// Reference target for the ON-CHAIN canonical mandateHash (src/HSPCanonical.sol).
// Runs the real hsp/core SDK to produce the canonical HSP mandateHash for fixed inputs;
// test/HSPCanonical.t.sol asserts the on-chain contract returns the byte-identical value,
// and HSPCanonical is deployed live on mainnet (0x6B99B00BD52Bc134D5658745E64DF1938592e468).
//
// Setup: git clone https://github.com/project-hsp/hsp && cd hsp && npm install
//        cp <this file> hsp/canon.mts && npx tsx hsp/canon.mts
// Output: CANONICAL mandateHash: 0x623569a794a14af48f847d9a9dd64d92166494e160b14caccd4818524cb3933f

import { keccak256, stringToBytes, encodeAbiParameters } from "viem";
import { mandateHash, requiredCapabilitiesHash } from "./packages/core/src/derivations.js";

const SIGNER = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
const KEMBALI = "0xDea6Da93265871d828B20cace2BADd5F5e70209d";
const USDC = "0x481fE34ed995603abdB9998b7eCc8811e2707d87";

const body: any = {
  nonce: keccak256(stringToBytes("kembali-canon-1")),
  signer: { profileId: keccak256(stringToBytes("eip712-eoa.v1")), payload: encodeAbiParameters([{ type: "address" }], [SIGNER]) },
  grantRef: "0x" + "00".repeat(32), requirementRef: "0x" + "00".repeat(32),
  recipient: { kind: 0, payload: encodeAbiParameters([{ type: "address" }], [KEMBALI]) },
  token: USDC, amount: 100000000n, chainId: 177, deadline: 2000000000n,
  settlementBinding: "0x" + "00".repeat(32),
  requiredCapabilitiesHash: requiredCapabilitiesHash([]),
};
console.log("CANONICAL mandateHash:", mandateHash({ name: "HSP", version: "1", chainId: 177, verifyingContract: KEMBALI }, body));
