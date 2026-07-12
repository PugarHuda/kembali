import { test, expect, Page } from "@playwright/test";
import { setupWallet, switchAccount, ensureGas, ADDRESS, ADDRESS_B } from "../e2e/wallet";

// A single, narrated, screen-recorded walkthrough of the LIVE dApp doing REAL mainnet-177 transactions.
// Captions are burned into the video (bottom bar). Pair the audio with VIDEO.md for the VO.

const USDC = "0x481fE34ed995603abdB9998b7eCc8811e2707d87";
const DEAD = "0x000000000000000000000000000000000000dEaD";
const nav = (p: Page, l: string) => p.locator(".nav button", { hasText: l });
const field = (p: Page, l: string) => p.locator(`.field:has(label:has-text("${l}")) input`).first();
const statusB = (p: Page) => p.locator(".statusline b");
const toast = (p: Page) => p.locator(".toast");

// ---- caption / title-card overlay, injected on every navigation ----
async function installOverlay(p: Page) {
  await p.addInitScript(() => {
    const ensure = () => {
      if (!document.getElementById("__cap")) {
        const el = document.createElement("div");
        el.id = "__cap";
        Object.assign(el.style, {
          position: "fixed", left: "0", right: "0", bottom: "0", padding: "22px 56px",
          background: "linear-gradient(transparent, rgba(8,8,10,.92))", color: "#fff",
          font: "500 25px/1.45 -apple-system, system-ui, sans-serif", textAlign: "center",
          zIndex: "2147483647", pointerEvents: "none", textShadow: "0 2px 10px rgba(0,0,0,.7)",
          transition: "opacity .25s ease",
        } as CSSStyleDeclaration);
        document.body && document.body.appendChild(el);
      }
    };
    (window as any).__cap = (t: string) => { ensure(); const el = document.getElementById("__cap"); if (el) el.textContent = t; };
    (window as any).__card = (title: string, sub: string) => {
      ensure();
      let c = document.getElementById("__card");
      if (title === "") { if (c) c.remove(); return; }
      if (!c) {
        c = document.createElement("div"); c.id = "__card";
        Object.assign(c.style, {
          position: "fixed", inset: "0", background: "#0b0b0d", color: "#fff", zIndex: "2147483646",
          display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
          gap: "16px", font: "-apple-system, system-ui, sans-serif", textAlign: "center",
        } as CSSStyleDeclaration);
        document.body.appendChild(c);
      }
      c.innerHTML = `<div style="font-size:60px;font-weight:600;letter-spacing:-1.5px">${title}</div>` +
        `<div style="font-size:25px;opacity:.72;max-width:760px;line-height:1.5">${sub}</div>`;
    };
    if (document.readyState !== "loading") ensure(); else document.addEventListener("DOMContentLoaded", ensure);
  });
}
const cap = (p: Page, t: string) => p.evaluate((x) => (window as any).__cap(x), t);
const card = (p: Page, title: string, sub = "") => p.evaluate(([a, b]) => (window as any).__card(a, b), [title, sub]);
const beat = (p: Page, ms: number) => p.waitForTimeout(ms);
async function say(p: Page, t: string, ms = 4200) { await cap(p, t); await beat(p, ms); }
async function connect(p: Page) {
  const block = p.locator(".wallet-block");
  try { await expect(block).toContainText(ADDRESS.slice(0, 6), { timeout: 8000 }); }
  catch { const b = p.getByRole("button", { name: "Connect Wallet" }); if (await b.isVisible().catch(() => false)) await b.click().catch(() => {}); await expect(block).toContainText(ADDRESS.slice(0, 6), { timeout: 20000 }); }
}
const done = (p: Page) => expect(toast(p)).toContainText("✓", { timeout: 120000 });

test("Kembali — narrated live demo", async ({ page }) => {
  await installOverlay(page);
  await setupWallet(page);
  await ensureGas(ADDRESS_B);

  // ── Intro ──────────────────────────────────────────────────────────────
  await page.goto("/");
  await card(page, "Kembali", "Reversible stablecoin payments on HashKey Chain — live on mainnet 177");
  await beat(page, 5000);
  await card(page, "", "");
  await say(page, "Stablecoin payments are final. If the merchant never delivers, your money's gone — no chargeback.", 5200);
  await page.mouse.wheel(0, 500); await beat(page, 800); await page.mouse.wheel(0, 600);
  await say(page, "Kembali is the recourse HSP doesn't have: escrow bound to an on-chain deliverable + deadline.", 5200);

  // ── Fulfill / atomic DvP ────────────────────────────────────────────────
  await page.goto("/app");
  await say(page, "This is the live dApp. Let's connect a wallet.", 3200);
  await connect(page);
  await say(page, "Flow one — the happy path: an atomic delivery-versus-payment.", 3800);

  await nav(page, "Faucet").click();
  await say(page, "The buyer mints some test stablecoin…", 2600);
  await page.locator(".actionrow", { hasText: "Mint 1000 test kUSD" }).getByRole("button").click();
  await done(page);

  await nav(page, "Open Escrow").click();
  await say(page, "…then opens an escrow: merchant, amount, and an on-chain deliverable.", 4200);
  await field(page, "Merchant").fill(ADDRESS_B);
  await field(page, "Amount").fill("1000000");
  await field(page, "Window").fill("3600");
  await field(page, "Item").fill("1000000");
  await page.locator(".field:has(label:has-text('Kind')) .seg").getByText(/ERC20/).click();
  await field(page, "Deliverable asset").fill(USDC);
  await say(page, "One click approves the token; the next signs an EIP-712 HSP mandate.", 4000);
  await page.locator(".btnrow button", { hasText: "Approve" }).click();
  await done(page);
  await page.locator(".btnrow button", { hasText: "Open Escrow" }).click();
  await expect(statusB(page)).toHaveText("HELD", { timeout: 120000 });
  await say(page, "Funds are now HELD on-chain. The mandate digest is the payment ID.", 4200);

  await switchAccount(page, 1);
  await expect(page.locator(".wallet-block")).toContainText(ADDRESS_B.slice(0, 6));
  await say(page, "Now we switch to the merchant's wallet to deliver.", 3400);
  await nav(page, "Faucet").click();
  await page.locator(".actionrow", { hasText: "Mint 1000 test kUSD" }).getByRole("button").click();
  await done(page);
  await nav(page, "Settle").click();
  await say(page, "Merchant approves the deliverable, then hits Fulfill…", 3600);
  await page.locator(".actionrow", { hasText: "Approve Deliverable" }).getByRole("button").click();
  await done(page);
  await page.locator(".actionrow", { hasText: "Fulfill" }).getByRole("button").click();
  await expect(statusB(page)).toHaveText("RELEASED", { timeout: 120000 });
  await say(page, "RELEASED. One transaction — asset to the buyer, funds to the merchant. Atomic DvP.", 5000);
  await page.locator(".actionrow", { hasText: "Withdraw" }).getByRole("button").click();
  await done(page);

  // ── Reversal + on-chain guard ───────────────────────────────────────────
  await switchAccount(page, 0);
  await expect(page.locator(".wallet-block")).toContainText(ADDRESS.slice(0, 6));
  await card(page, "But what if they don't deliver?", "The money kembali.");
  await beat(page, 3800); await card(page, "", "");

  await nav(page, "Open Escrow").click();
  await field(page, "Merchant").fill(DEAD);
  await field(page, "Amount").fill("1000000");
  await field(page, "Window").fill("30");
  await page.locator(".field:has(label:has-text('Kind')) .seg").getByText(/NFT/).click();
  await say(page, "New escrow, a short 30-second window.", 3000);
  await page.locator(".btnrow button", { hasText: "Approve" }).click();
  await done(page);
  await page.locator(".btnrow button", { hasText: "Open Escrow" }).click();
  await expect(statusB(page)).toHaveText("HELD", { timeout: 120000 });

  await nav(page, "Settle").click();
  await say(page, "Watch — if the buyer tries to refund right now…", 3000);
  await page.locator(".actionrow", { hasText: "Refund" }).getByRole("button").click();
  await expect(toast(page)).toContainText("TOO_EARLY", { timeout: 20000 });
  await say(page, "…it reverts: TOO_EARLY. The buyer can't rug the merchant mid-window.", 4600);
  await say(page, "The deadline is enforced on-chain. So we wait for the window to pass…", 4200);
  const refundRow = page.locator(".actionrow", { hasText: "Refund" });
  await expect(refundRow.locator(".a-note")).toContainText("refund open", { timeout: 60000 });
  await say(page, "…and now the refund goes through.", 2600);
  await expect(async () => {
    await refundRow.getByRole("button").click();
    await expect(statusB(page)).toHaveText("REFUNDED", { timeout: 12000 });
  }).toPass({ timeout: 90000, intervals: [3000, 5000] });
  await page.locator(".actionrow", { hasText: "Withdraw" }).getByRole("button").click();
  await done(page);
  await say(page, "REFUNDED. The money came back. That's recourse HSP alone doesn't give you.", 5000);

  // ── Agent / relayer-safe ────────────────────────────────────────────────
  await nav(page, "Open Escrow").click();
  await field(page, "Merchant").fill(DEAD);
  await field(page, "Amount").fill("1000000");
  await nav(page, "Agent").click();
  await say(page, "Agent-safe commerce: funds are pulled from the signer, never the submitter.", 4600);
  await say(page, "An agent or relayer can buy on your behalf — and can't redirect a cent.", 4400);
  await page.getByRole("button", { name: /Run Agent Buy/ }).click();
  await expect(statusB(page)).toHaveText("HELD", { timeout: 180000 });
  await say(page, "One click: provisioned and protected. An agent literally cannot rug you.", 4600);

  // ── Outro ───────────────────────────────────────────────────────────────
  await card(page, "Compliant + reversible, on-chain",
    "CompliantEscrow enforces KYC/sanctions on-chain before the escrow opens. 72 tests · 512k-call invariant · bytecode == source.");
  await beat(page, 6000);
  await card(page, "Kembali", "Everyone built a gate in front of the payment. We built the door back out. — live on HashKey Chain");
  await beat(page, 5500);
});
