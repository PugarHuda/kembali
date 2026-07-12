import type { Page } from "@playwright/test";
import { createWalletClient, http, defineChain } from "viem";
import { privateKeyToAccount } from "viem/accounts";

const RPC = "https://mainnet.hsk.xyz";
const chain = defineChain({
  id: 177, name: "HashKey",
  nativeCurrency: { name: "HSK", symbol: "HSK", decimals: 18 },
  rpcUrls: { default: { http: [RPC] } },
});
// Hackathon deployer/demo key — burnable, holds only worthless test assets (see chat history).
const account = privateKeyToAccount("0x4d98b2d5d5a8f95e58c30fbda021b6f0ec36ee4c1ffa1d0a5b93fa1b9b47cf8c");
const wallet = createWalletClient({ account, chain, transport: http(RPC) });
export const ADDRESS = account.address;

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
  await page.exposeFunction("__walletRPC", async (method: string, params: any[] = []) => {
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
    const info = { uuid: "00000000-0000-0000-0000-000000000abc", name: "Kembali E2E Wallet", icon: "data:image/svg+xml;base64,PHN2Zy8+", rdns: "io.kembali.e2e" };
    const announce = () => window.dispatchEvent(new CustomEvent("eip6963:announceProvider", { detail: Object.freeze({ info, provider }) as any }));
    window.addEventListener("eip6963:requestProvider", announce);
    announce();
  });
}
