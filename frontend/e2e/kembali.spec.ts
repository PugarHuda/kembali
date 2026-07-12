import { test, expect, Page } from "@playwright/test";
import { setupWallet, ADDRESS } from "./wallet";

const KEMBALI = "0xDea6Da93265871d828B20cace2BADd5F5e70209d";
const DEAD = "0x000000000000000000000000000000000000dEaD"; // merchant != signer (avoids SELF_DEAL)

const nav = (p: Page, label: string) => p.locator(".nav button", { hasText: label });
const heading = (p: Page) => p.locator(".main-head h1");
const toast = (p: Page) => p.locator(".toast");
const field = (p: Page, label: string) => p.locator(`.field:has(label:has-text("${label}")) input`).first();

async function connect(p: Page) {
  const block = p.locator(".wallet-block");
  const short = ADDRESS.slice(0, 6);
  // wagmi auto-reconnects the injected wallet; wait for that first, only click Connect if it didn't.
  try {
    await expect(block).toContainText(short, { timeout: 8_000 });
  } catch {
    const btn = p.getByRole("button", { name: "Connect Wallet" });
    if (await btn.isVisible().catch(() => false)) await btn.click().catch(() => {});
    await expect(block).toContainText(short, { timeout: 20_000 });
  }
  await expect(block).not.toContainText("wrong net");
}
const waitDone = (p: Page) => expect(toast(p)).toContainText("✓", { timeout: 120_000 });

// ---------- pure UI (no wallet, no gas) ----------
test.describe("UI walkthrough", () => {
  test("landing renders and Launch App routes to /app", async ({ page }) => {
    await page.goto("/");
    await expect(page.locator("h1")).toContainText("come");
    await expect(page.locator(".esccard")).toContainText("Held");
    await page.getByRole("link", { name: /Launch App/ }).first().click();
    await expect(page).toHaveURL(/\/app$/);
    await expect(page.locator(".side .wordmark")).toContainText("Kembali");
  });

  test("all six views navigate and render their heading", async ({ page }) => {
    await page.goto("/app");
    for (const [btn, title] of [
      ["Overview", "Overview"], ["Open Escrow", "Open Escrow"], ["Settle", "Settle"],
      ["Agent", "Agent"], ["Faucet", "Faucet"], ["Contract", "Contract"],
    ]) {
      await nav(page, btn).click();
      await expect(heading(page)).toHaveText(title);
    }
  });

  test("Window nudge sets 120 and Contract view links to the live address", async ({ page }) => {
    await page.goto("/app");
    await nav(page, "Open Escrow").click();
    await field(page, "Window").locator("xpath=ancestor::div[@class='field']").getByText("120").click();
    await expect(field(page, "Window")).toHaveValue("120");
    await nav(page, "Contract").click();
    await expect(page.locator(".addrbox")).toContainText(KEMBALI);
    await expect(page.locator(".addrbox a")).toHaveAttribute("href", new RegExp(`address/${KEMBALI}`, "i"));
  });

  test("Overview shows three stat tiles and an Idle status pill before any escrow", async ({ page }) => {
    await page.goto("/app");
    const tiles = page.locator(".tiles .tile .tl");
    await expect(tiles).toHaveText(["Wallet Balance", "Active Escrow", "Window Left"]);
    await expect(page.locator(".statuspill")).toContainText("Idle");
    // no escrow yet → active/window tiles read the empty sentinel
    await expect(page.locator(".tile", { hasText: "Active Escrow" })).toContainText("no escrow");
  });

  test("Overview CTAs route to Open / Settle / Agent", async ({ page }) => {
    await page.goto("/app");
    for (const [cta, title] of [
      [/Open an Escrow/, "Open Escrow"], [/Settle/, "Settle"], [/Agent Buy/, "Agent"],
    ] as [RegExp, string][]) {
      await page.goto("/app"); // back to overview each time (CTAs only live there)
      await page.locator(".panel .btnrow button", { hasText: cta }).click();
      await expect(heading(page)).toHaveText(title);
    }
  });

  test("Open form: amount hint recomputes and Kind toggles NFT↔ERC20", async ({ page }) => {
    await page.goto("/app");
    await nav(page, "Open Escrow").click();
    await field(page, "Amount").fill("5000000");
    await expect(page.locator(".field", { hasText: "Amount" }).locator(".hint")).toContainText("5.00 USDC");
    const seg = page.locator(".field:has(label:has-text('Kind')) .seg");
    await expect(seg.locator("button.on")).toHaveText(/NFT/);        // default kind 0
    await seg.getByText(/ERC20/).click();
    await expect(seg.locator("button.on")).toHaveText(/ERC20/);       // switched to kind 1
  });

  test("Settle with no escrow prompts to open one first", async ({ page }) => {
    await page.goto("/app");
    await nav(page, "Settle").click();
    await expect(page.locator(".statusline")).toContainText("no escrow yet");
    await expect(page.locator(".statusline b")).toHaveText("NONE");
  });

  test("an action without a connected wallet flashes 'Connect a wallet first'", async ({ page }) => {
    await page.goto("/app");                                          // no wallet injected here
    await nav(page, "Settle").click();
    await page.locator(".actionrow", { hasText: "Fulfill" }).getByRole("button").click();
    await expect(toast(page)).toContainText("Connect a wallet first"); // run() guard, no tx
  });

  test("Back to site returns to the landing page", async ({ page }) => {
    await page.goto("/app");
    await page.locator(".side-foot").click();
    await expect(page).toHaveURL(/\/$/);
    await expect(page.locator("h1")).toContainText("come");
  });
});

// ---------- wallet lifecycle (real connect, no gas) ----------
test.describe("Wallet", () => {
  test("connect then Disconnect returns to the Connect button", async ({ page }) => {
    await setupWallet(page);
    await page.goto("/app");
    await connect(page);
    const block = page.locator(".wallet-block");
    await block.getByRole("button", { name: "Disconnect" }).click();
    await expect(block.getByRole("button", { name: "Connect Wallet" })).toBeVisible();
  });
});

// ---------- REAL on-chain flows through the actual UI ----------
test.describe("On-chain flows (real transactions on mainnet 177)", () => {
  test("reversal end-to-end: connect → faucet → open → wait window → REFUND → withdraw", async ({ page }) => {
    await setupWallet(page);
    await page.goto("/app");
    await connect(page);

    // Faucet: mint test kUSD (real tx)
    await nav(page, "Faucet").click();
    await page.locator(".actionrow", { hasText: "Mint 1000 test kUSD" }).getByRole("button").click();
    await waitDone(page);

    // Open an escrow with a short 120s window, merchant != me
    await nav(page, "Open Escrow").click();
    await field(page, "Merchant").fill(DEAD);
    await field(page, "Amount").fill("1000000");   // 1 kUSD (6 dec)
    await field(page, "Window").fill("120");
    await page.locator(".btnrow button", { hasText: "Approve" }).click();
    await waitDone(page);                            // approve mined before we open
    await page.locator(".btnrow button", { hasText: "Open Escrow" }).click();

    // Auto-switches to Settle; escrow must be HELD
    await expect(page.locator(".statusline b")).toHaveText("HELD", { timeout: 120_000 });

    // Wait for the reclaim window to open, then REFUND (the core "money kembali" flow).
    // The UI's "refund open" uses the client clock; the contract checks block.timestamp, which can
    // lag a few seconds behind — an early click reverts TOO_EARLY. Retry until chain state flips.
    const refundRow = page.locator(".actionrow", { hasText: "Refund" });
    await expect(refundRow.locator(".a-note")).toContainText("refund open", { timeout: 180_000 });
    await expect(async () => {
      await refundRow.getByRole("button").click();
      await expect(page.locator(".statusline b")).toHaveText("REFUNDED", { timeout: 15_000 });
    }).toPass({ timeout: 90_000, intervals: [3_000, 5_000, 8_000] });

    // Withdraw the reclaimed funds
    await page.locator(".actionrow", { hasText: "Withdraw" }).getByRole("button").click();
    await waitDone(page);
  });

  test("Agent Buy one-click provisions + opens a protected purchase (validates the receipt-wait fix)", async ({ page }) => {
    await setupWallet(page);
    await page.goto("/app");
    await connect(page);

    // agentBuy uses form.merchant — set it != me so open() doesn't SELF_DEAL
    await nav(page, "Open Escrow").click();
    await field(page, "Merchant").fill(DEAD);
    await field(page, "Amount").fill("1000000");

    await nav(page, "Agent").click();
    await page.getByRole("button", { name: /Run Agent Buy/ }).click();
    // mint -> (receipt) -> approve -> (receipt) -> open -> Settle HELD. Pre-fix this reverted.
    await expect(page.locator(".statusline b")).toHaveText("HELD", { timeout: 180_000 });
  });
});
