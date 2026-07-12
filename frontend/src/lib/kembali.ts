import { defineChain, parseAbi } from "viem";

export const hashkey = defineChain({
  id: 177,
  name: "HashKey Chain",
  nativeCurrency: { name: "HSK", symbol: "HSK", decimals: 18 },
  rpcUrls: { default: { http: ["https://mainnet.hsk.xyz"] } },
  blockExplorers: { default: { name: "Blockscout", url: "https://hashkey.blockscout.com" } },
});

// Live deployments on HashKey mainnet (177)
export const ADDR = {
  kembali: "0xDea6Da93265871d828B20cace2BADd5F5e70209d",
  demoUsdc: "0x481fE34ed995603abdB9998b7eCc8811e2707d87",
  demoNft: "0x6091e0111fB0F94fAE4b9D3Bbb0c36dD72D43454",
  merchant: "0x39D2bae5EAedA9283535dDC98F1991c81eD5Cd7E",
} as const;

export const explorerTx = (h: string) => `${hashkey.blockExplorers.default.url}/tx/${h}`;
export const explorerAddr = (a: string) => `${hashkey.blockExplorers.default.url}/address/${a}`;

export const kembaliAbi = parseAbi([
  "function open((bytes32 nonce,address signer,bytes32 grantRef,bytes32 requirementRef,address recipient,address token,uint256 amount,uint256 chainId,uint256 deadline,bytes32 settlementBinding,bytes32 requiredCapabilitiesHash) m,bytes signature,address merchant,address asset,uint256 item,uint8 kind,uint64 window) returns (bytes32)",
  "function fulfill(bytes32 id)",
  "function refund(bytes32 id)",
  "function cancel(bytes32 id)",
  "function withdraw(address token)",
  "function withdrawable(address,address) view returns (uint256)",
  "function payments(bytes32) view returns (address payer,address merchant,address token,uint256 amount,address asset,uint256 item,uint8 kind,uint64 deadline,uint8 status)",
]);

export const erc20Abi = parseAbi([
  "function mint(address,uint256)",
  "function approve(address,uint256) returns (bool)",
  "function allowance(address,address) view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
]);

export const nftAbi = parseAbi([
  "function mint(address) returns (uint256)",
  "function nextId() view returns (uint256)",
  "function ownerOf(uint256) view returns (address)",
  "function setApprovalForAll(address,bool)",
  "function isApprovedForAll(address,address) view returns (bool)",
]);

export const STATUS = ["NONE", "HELD", "RELEASED", "REFUNDED"] as const;
export const statusColor: Record<string, string> = {
  HELD: "#B67A63",
  RELEASED: "#3F6B4A",
  REFUNDED: "#8A8078",
  NONE: "#A99C92",
};

// USDC.e / DemoUSDC are 6 decimals.
export const fmtUsdc = (v: bigint) => (Number(v) / 1e6).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
export const short = (a?: string, n = 4) => (a ? `${a.slice(0, n + 2)}…${a.slice(-n)}` : "");
