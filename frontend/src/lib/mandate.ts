import { keccak256, encodeAbiParameters, toHex } from "viem";
import { hashkey } from "./kembali";

const ZERO32 = ("0x" + "00".repeat(32)) as `0x${string}`;
export const EMPTY_CAPS = keccak256("0x"); // Public payment marker

export const MANDATE_TYPES = {
  Mandate: [
    { name: "nonce", type: "bytes32" },
    { name: "signer", type: "address" },
    { name: "grantRef", type: "bytes32" },
    { name: "requirementRef", type: "bytes32" },
    { name: "recipient", type: "address" },
    { name: "token", type: "address" },
    { name: "amount", type: "uint256" },
    { name: "chainId", type: "uint256" },
    { name: "deadline", type: "uint256" },
    { name: "settlementBinding", type: "bytes32" },
    { name: "requiredCapabilitiesHash", type: "bytes32" },
  ],
} as const;

export type MandateArgs = {
  signer: `0x${string}`;
  kembali: `0x${string}`;
  token: `0x${string}`;
  amount: bigint;
  merchant: `0x${string}`;
  asset: `0x${string}`;
  item: bigint;
  kind: number;
  window: bigint;
  now: bigint;
};

/** Builds the EIP-712 HSP mandate + settlementBinding; paymentId = the typed-data digest. */
export function buildMandate(a: MandateArgs) {
  const settlementBinding = keccak256(
    encodeAbiParameters(
      [{ type: "address" }, { type: "address" }, { type: "uint256" }, { type: "uint8" }, { type: "uint64" }],
      [a.merchant, a.asset, a.item, a.kind, a.window],
    ),
  );
  const domain = { name: "HSP", version: "1", chainId: hashkey.id, verifyingContract: a.kembali } as const;
  const message = {
    nonce: toHex(crypto.getRandomValues(new Uint8Array(32))) as `0x${string}`,
    signer: a.signer,
    grantRef: ZERO32,
    requirementRef: ZERO32,
    recipient: a.kembali,
    token: a.token,
    amount: a.amount,
    chainId: BigInt(hashkey.id),
    deadline: a.now + a.window,
    settlementBinding,
    requiredCapabilitiesHash: EMPTY_CAPS,
  };
  return { domain, message } as const;
}
