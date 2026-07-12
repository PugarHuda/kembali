import { defineConfig } from "@playwright/test";

// Records a narrated screen-capture of the LIVE dApp doing real mainnet-177 transactions, with
// burned-in captions. Output: demo/output/<test>/video.webm  →  run: npm run demo
export default defineConfig({
  testDir: "./demo",
  outputDir: "./demo/output",
  timeout: 900_000,           // real on-chain txs + deliberate pacing + a short reversal window
  expect: { timeout: 30_000 },
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: "list",
  use: {
    baseURL: process.env.E2E_BASE_URL || "https://kembali-hsp.vercel.app",
    headless: true,
    viewport: { width: 1280, height: 720 },
    video: { mode: "on", size: { width: 1280, height: 720 } },
    actionTimeout: 30_000,
  },
});
