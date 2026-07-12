import { defineConfig } from "@playwright/test";

// Real click-through against the LIVE deployed app, with an injected EIP-1193 wallet that
// signs + sends REAL transactions on HashKey mainnet 177 (viem + deployer key, Node-side).
export default defineConfig({
  testDir: "./e2e",
  timeout: 300_000,          // on-chain tests wait a 120s escrow window + real tx confirmations
  expect: { timeout: 20_000 },
  fullyParallel: false,
  workers: 1,                // single deployer account -> serialize to avoid nonce races
  retries: 0,
  reporter: "list",
  use: {
    baseURL: "https://kembali-hsp.vercel.app",
    headless: true,
    actionTimeout: 20_000,
    trace: "retain-on-failure",
  },
});
