// Kembali × HSP — REAL reference-verifier self-verify (no Coordinator required).
//
// This runs the ACTUAL @hsp/core reference implementation: it builds a spec-exact
// canonical HSP v1 Mandate (nested Signer{profileId,payload} / Recipient{kind,payload},
// uint64 deadline, real MANDATE_TYPEHASH), computes the canonical mandateHash (= HSP
// paymentId), signs it with the eip712-eoa.v1 SignerProfile, and verifies it with the
// real verifier — proving we integrate the HSP protocol itself, not just its shape.
//
// Setup (vendor the SDK — it is not on npm):
//   git clone https://github.com/project-hsp/hsp && cd hsp && npm install
//   cp <this file> hsp/selfverify.mts   &&   npx tsx hsp/selfverify.mts
//
// Verified output (captured):
//   canonical mandateHash: 0xbef0e22bf110532be08b2c54b1bbdf50740046f459288378e2c202848de76be3
//   HSP eip712-eoa.verify -> {"granted":true, "resolvedSubject":{"scheme":"evm-address", ...}}
//   REAL HSP SELF-VERIFY: ACCEPT ✅
//
// Relationship to the on-chain escrow: Kembali's contract verifies a *gas-optimized*
// mandate (flat address/uint256) on-chain for cheap settlement. This script shows the
// canonical HSP encoding + real verifier acceptance. Making the on-chain digest byte-equal
// to the canonical mandateHash (nested structs on-chain) is the documented next step.

import { keccak256, stringToBytes, encodeAbiParameters, zeroHash } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { mandateHash, requiredCapabilitiesHash } from './packages/core/src/derivations.js';
import { eip712EoaSigner } from './packages/core/src/profiles/signer/eip712-eoa.js';

const account = privateKeyToAccount('0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d');
const KEMBALI = '0x8464135c8F25Da09e49BC8782676a84730C318bC'; // escrow (recipient), replace with deployed address
const USDC = '0x054ed45810DbBAb8B27668922D110669c9D88D0a';    // USDC.e on HashKey mainnet

const signerPayload = encodeAbiParameters([{ type: 'address' }], [account.address]);
const recipientPayload = encodeAbiParameters([{ type: 'address' }], [KEMBALI]);

const domain = { name: 'HSP', version: '1', chainId: 177, verifyingContract: KEMBALI as `0x${string}` };
const body: any = {
  nonce: keccak256(stringToBytes('kembali-demo-1')),
  signer: { profileId: keccak256(stringToBytes('eip712-eoa.v1')), payload: signerPayload },
  grantRef: zeroHash, requirementRef: zeroHash,
  recipient: { kind: 0, payload: recipientPayload },        // RecipientKind.ADDRESS
  token: USDC, amount: 100000000n, chainId: 177,
  deadline: BigInt(Math.floor(Date.now() / 1000) + 86400),
  settlementBinding: zeroHash,
  requiredCapabilitiesHash: requiredCapabilitiesHash([]),   // empty set = Public payment
};

const mh = mandateHash(domain, body);
const proof = await account.sign({ hash: mh });
const decision = await eip712EoaSigner.verify(signerPayload, proof, mh, body);
console.log('payer                 :', account.address);
console.log('canonical mandateHash :', mh, '(= HSP paymentId)');
console.log('HSP eip712-eoa.verify ->', JSON.stringify(decision));
console.log(decision.granted ? '\nREAL HSP SELF-VERIFY: ACCEPT ✅' : '\nFAILED ❌');
