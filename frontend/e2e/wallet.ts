import type { Page } from "@playwright/test";
import { createWalletClient, createPublicClient, http, defineChain, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const RPC = "https://mainnet.hsk.xyz";
const chain = defineChain({
  id: 177, name: "HashKey",
  nativeCurrency: { name: "HSK", symbol: "HSK", decimals: 18 },
  rpcUrls: { default: { http: [RPC] } },
});
// Hackathon deployer/demo key — burnable, holds only worthless test assets (see chat history).
// Also the seeded `merchant` (owns demo NFT #1), so it must be the PAYER when we want to test fulfill.
const accountA = privateKeyToAccount("0x4d98b2d5d5a8f95e58c30fbda021b6f0ec36ee4c1ffa1d0a5b93fa1b9b47cf8c");
// Throwaway second wallet — plays the merchant in the atomic-DvP fulfill flow. Holds only test assets
// + a little HSK we top up for gas. Public/burnable by design.
const accountB = privateKeyToAccount("0xa5e9c1b3d7f2048602468ace13579bdf02468ace13579bdf02468ace13579bdf");
const wallets = [
  createWalletClient({ account: accountA, chain, transport: http(RPC) }),
  createWalletClient({ account: accountB, chain, transport: http(RPC) }),
];
const accounts = [accountA, accountB];
const pcNode = createPublicClient({ chain, transport: http(RPC) });

export const ADDRESS = accountA.address;
export const ADDRESS_B = accountB.address;

let active = 0; // which injected account is currently "selected" (like a MetaMask account switch)

async function rawRpc(method: string, params: any[]) {
  const r = await fetch(RPC, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const j: any = await r.json();
  if (j.error) throw new Error(j.error.message || "rpc error");
  return j.result;
}

/** Inject a real signing EIP-1193 provider (window.ethereum + EIP-6963) backed by viem in Node. */
export async function setupWallet(page: Page) {
  active = 0; // reset per test
  await page.exposeFunction("__walletRPC", async (method: string, params: any[] = []) => {
    const account = accounts[active];
    const wallet = wallets[active];
    switch (method) {
      case "eth_requestAccounts":
      case "eth_accounts": return [account.address];
      case "eth_chainId": return "0xb1"; // 177
      case "net_version": return "177";
      case "wallet_switchEthereumChain":
      case "wallet_addEthereumChain":
      case "wallet_watchAsset":
      case "wallet_revokePermissions": return null;
      case "wallet_getPermissions": return [];
      case "wallet_requestPermissions": return [{ parentCapability: "eth_accounts" }];
      case "eth_signTypedData_v4": {
        const typed = JSON.parse(params[1]);
        const types = { ...typed.types };
        delete types.EIP712Domain;
        // eth_signTypedData_v4 JSON encodes all numbers as strings; viem wants bigint for uint/int.
        const msg: any = { ...typed.message };
        for (const f of typed.types[typed.primaryType]) {
          if (/^u?int\d*$/.test(f.type) && msg[f.name] != null) msg[f.name] = BigInt(msg[f.name]);
        }
        return await wallet.signTypedData({ account, domain: typed.domain, types, primaryType: typed.primaryType, message: msg });
      }
      case "eth_sendTransaction": {
        const tx = params[0];
        return await wallet.sendTransaction({ account, to: tx.to, data: tx.data, value: tx.value ? BigInt(tx.value) : undefined });
      }
      default:
        return await rawRpc(method, params);
    }
  });

  // Switch the selected account (Node-side state); the page fires accountsChanged so wagmi re-reads it.
  await page.exposeFunction("__setActive", (i: number) => { active = i; return accounts[i].address; });

  await page.addInitScript(() => {
    const provider: any = {
      isMetaMask: true,
      _cbs: {} as Record<string, Function[]>,
      request: ({ method, params }: { method: string; params?: any[] }) => (window as any).__walletRPC(method, params || []),
      on(e: string, cb: Function) { (this._cbs[e] ||= []).push(cb); return this; },
      removeListener() { return this; },
      removeAllListeners() { return this; },
    };
    (window as any).ethereum = provider;
    (window as any).__switchAccount = async (i: number) => {
      const addr = await (window as any).__setActive(i);
      (provider._cbs["accountsChanged"] || []).forEach((cb: Function) => cb([addr]));
      return addr;
    };
    const info = { uuid: "00000000-0000-0000-0000-000000000abc", name: "Kembali E2E Wallet", icon: "data:image/svg+xml;base64,PHN2Zy8+", rdns: "io.kembali.e2e" };
    const announce = () => window.dispatchEvent(new CustomEvent("eip6963:announceProvider", { detail: Object.freeze({ info, provider }) as any }));
    window.addEventListener("eip6963:requestProvider", announce);
    announce();
  });
}

/** Switch the connected wallet in-page (emits accountsChanged like a MetaMask account switch). */
export async function switchAccount(page: Page, i: number) {
  return page.evaluate((idx) => (window as any).__switchAccount(idx), i);
}

/** Ensure `addr` has at least `min` HSK for gas; top up from account A if not. Real tx. */
export async function ensureGas(addr: `0x${string}`, min = 0.03, top = 0.08) {
  const bal = await pcNode.getBalance({ address: addr });
  if (bal >= parseEther(String(min))) return;
  const hash = await wallets[0].sendTransaction({ account: accounts[0], to: addr, value: parseEther(String(top)) });
  await pcNode.waitForTransactionReceipt({ hash });
}
