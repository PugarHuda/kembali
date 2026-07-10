// Kembali × HSP integration.
//
// Binding: escrow id === HSP paymentId === the EIP-712 Mandate digest (mandateHash).
// One signed mandate => (a) the verifiable HSP receipt AND (b) the escrow key on Kembali.
// Verification is LOCAL via HSPVerifier (pin the adapter address) — no hosted Coordinator,
// which matters because the mainnet Coordinator URL is still a placeholder in HSP docs.
//
// EIP-712 schema below matches HSP wire v1 (docs/guide.md): domain {name:"HSP",version:"1"},
// primaryType "Mandate", 11 fields. paymentId = TypedDataEncoder.hash(domain,types,value).
// NOTE: HSP tags `signer`/`recipient` (profile-tagged refs). For a Public payment we use plain
// addresses; reconcile the tagging with @hsp/core before trusting the digest against a live
// Coordinator. The SAME id is passed to Kembali.open, so on-chain<->off-chain stays consistent.
//
// Setup: `npm i ethers` in this dir. Env: HSP_PRIVATE_KEY, KEMBALI_ADDR, MERCHANT, ASSET, ITEM, KIND
// Run:   node hsp/pay.mjs

import { ethers } from "ethers";

const RPC = "https://mainnet.hsk.xyz";
const CHAIN_ID = 177;
const USDC = "0x054ed45810DbBAb8B27668922D110669c9D88D0a"; // USDC.e (6 decimals)
const KEMBALI = process.env.KEMBALI_ADDR;
const MERCHANT = process.env.MERCHANT;
const ASSET = process.env.ASSET;                 // deliverable contract (ERC721 or ERC20)
const ITEM = BigInt(process.env.ITEM ?? "0");    // ERC721 tokenId OR ERC20 amount
const KIND = Number(process.env.KIND ?? "0");    // 0=ERC721, 1=ERC20
const AMOUNT = 100_000000n;                       // 100 USDC.e
const WINDOW = 24 * 60 * 60;

const ZERO32 = "0x" + "00".repeat(32);
const EMPTY_CAPS = ethers.keccak256("0x");        // Public payment => empty capability set

const DOMAIN = { name: "HSP", version: "1", chainId: CHAIN_ID, verifyingContract: KEMBALI };
const TYPES = {
  Mandate: [
    { name: "nonce", type: "bytes32" },
    { name: "signer", type: "address" },            // HSP: profile-tagged; plain addr for Public
    { name: "grantRef", type: "bytes32" },
    { name: "requirementRef", type: "bytes32" },
    { name: "recipient", type: "address" },         // HSP: tagged ADDRESS
    { name: "token", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "chainId", type: "uint256" },
    { name: "deadline", type: "uint256" },
    { name: "settlementBinding", type: "bytes32" },
    { name: "requiredCapabilitiesHash", type: "bytes32" },
  ],
};

const MANDATE_TUPLE =
  "(bytes32 nonce,address signer,bytes32 grantRef,bytes32 requirementRef,address recipient,address token,uint256 amount,uint256 chainId,uint256 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash)";
const KEMBALI_ABI = [
  `function open(${MANDATE_TUPLE} m,bytes signature,address merchant,address asset,uint256 item,uint8 kind,uint64 window) returns (bytes32)`,
];
const ERC20_ABI = ["function approve(address,uint256) returns (bool)"];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC, CHAIN_ID);
  const wallet = new ethers.Wallet(process.env.HSP_PRIVATE_KEY, provider);

  // settlementBinding commits the mandate to the exact escrow terms (must match the contract's
  // keccak256(abi.encode(merchant, asset, item, kind, window)) — enforced on-chain in open()).
  const binding = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
    ["address", "address", "uint256", "uint8", "uint64"],
    [MERCHANT, ASSET, ITEM, KIND, WINDOW]
  ));

  // 1) Build + sign the HSP mandate; recipient = Kembali escrow.
  const mandate = {
    nonce: ethers.hexlify(ethers.randomBytes(32)),
    signer: wallet.address,
    grantRef: ZERO32,          // no delegation
    requirementRef: ZERO32,
    recipient: KEMBALI,
    token: USDC,
    amount: AMOUNT,
    chainId: CHAIN_ID,
    deadline: Math.floor(Date.now() / 1000) + WINDOW,
    settlementBinding: binding,
    requiredCapabilitiesHash: EMPTY_CAPS,
  };
  const paymentId = ethers.TypedDataEncoder.hash(DOMAIN, TYPES, mandate); // = mandateHash = escrow id
  const signature = await wallet.signTypedData(DOMAIN, TYPES, mandate);
  console.log("HSP paymentId / escrow id:", paymentId);

  // 2) Settlement leg-1: escrow into Kembali. open() verifies the mandate signature on-chain.
  const usdc = new ethers.Contract(USDC, ERC20_ABI, wallet);
  await (await usdc.approve(KEMBALI, AMOUNT)).wait();
  const kembali = new ethers.Contract(KEMBALI, KEMBALI_ABI, wallet);
  const mArr = Object.values(mandate); // struct fields in declared order
  const rcpt = await (await kembali.open(mArr, signature, MERCHANT, ASSET, ITEM, KIND, WINDOW)).wait();
  console.log("Kembali.open settled in tx:", rcpt.hash);

  // 3) Self-verify (don't trust a Coordinator):
  //    const receipt = await hsp.observe(paymentId, rcpt.hash);   // adapter signs a Receipt
  //    const verifier = new HSPVerifier({ chain, adapterAddress: PINNED_FROM_GET_CHAINS });
  //    const d = await verifier.verify({ ...mandate, signature }, receipt, []);
  //    if (!(d.ok && d.outcomeClass === "ACCEPT")) throw new Error("HSP verify failed");
  console.log("Next: merchant fulfill(id) to deliver+get paid, or payer refund(id) after the window.");
}

main().catch((e) => { console.error(e); process.exit(1); });
