import { test, expect, Page } from "@playwright/test";
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { setupWallet, switchAccount, ensureGas, ADDRESS, ADDRESS_B } from "../e2e/wallet";

// A single narrated, screen-recorded walkthrough of the LIVE dApp doing REAL mainnet-177 transactions.
// Captions are burned in; each narration line logs its video-relative start time to demo/offsets.json,
// so demo/mux.mjs can drop the matching neural-VO clip (demo/vo/<id>.mp3) at exactly the right moment.

const VO_DIR = join(process.cwd(), "demo");
const LINES: { id: string; text: string }[] = JSON.parse(readFileSync(join(VO_DIR, "lines.json"), "utf8"));
const DUR: Record<string, number> = JSON.parse(readFileSync(join(VO_DIR, "vo", "durations.json"), "utf8"));
const L = (id: string) => LINES.find((l) => l.id === id)!.text;

const USDC = "0x481fE34ed995603abdB9998b7eCc8811e2707d87";
const DEAD = "0x000000000000000000000000000000000000dEaD";
const nav = (p: Page, l: string) => p.locator(".nav button", { hasText: l });
const field = (p: Page, l: string) => p.locator(`.field:has(label:has-text("${l}")) input`).first();
const statusB = (p: Page) => p.locator(".statusline b");
const toast = (p: Page) => p.locator(".toast");

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
        `<div style="font-size:25px;opacity:.72;max-width:780px;line-height:1.5">${sub}</div>`;
    };
    if (document.readyState !== "loading") ensure(); else document.addEventListener("DOMContentLoaded", ensure);
  });
}
const capOf = (p: Page, t: string) => p.evaluate((x) => (window as any).__cap(x), t);
const cardOf = (p: Page, title: string, sub = "") => p.evaluate(([a, b]) => (window as any).__card(a, b), [title, sub]);
const beat = (p: Page, ms: number) => p.waitForTimeout(ms);
async function connect(p: Page) {
  const block = p.locator(".wallet-block");
  try { await expect(block).toContainText(ADDRESS.slice(0, 6), { timeout: 8000 }); }
  catch { const b = p.getByRole("button", { name: "Connect Wallet" }); if (await b.isVisible().catch(() => false)) await b.click().catch(() => {}); await expect(block).toContainText(ADDRESS.slice(0, 6), { timeout: 20000 }); }
}
const done = (p: Page) => expect(toast(p)).toContainText("✓", { timeout: 120000 });

test("Kembali — narrated live demo", async ({ page }) => {
  const t0 = Date.now();
  const offsets: { id: string; offset: number }[] = [];
  // speak(): log the video-relative start of this line, show its caption, hold for the VO length.
  const speak = async (id: string, opts: { card?: boolean } = {}) => {
    offsets.push({ id, offset: Date.now() - t0 });
    if (!opts.card) await capOf(page, L(id));
    await beat(page, Math.round((DUR[id] || 3) * 1000 + 500));
  };

  await installOverlay(page);
  await setupWallet(page);
  await ensureGas(ADDRESS_B);

  // ── Intro ──
  await page.goto("/");
  await cardOf(page, "Kembali", "Reversible stablecoin payments on HashKey Chain — live on mainnet 177");
  await speak("intro", { card: true });
  await cardOf(page, "", "");
  await speak("problem");
  await page.mouse.wheel(0, 480); await beat(page, 500); await page.mouse.wheel(0, 560);
  await speak("solution");

  // ── Fulfill / atomic DvP ──
  await page.goto("/app");
  await speak("connect");
  await connect(page);
  await speak("flow1");

  await nav(page, "Faucet").click();
  await speak("faucet");
  await page.locator(".actionrow", { hasText: "Mint 1000 test kUSD" }).getByRole("button").click();
  await done(page);

  await nav(page, "Open Escrow").click();
  await speak("openform");
  await field(page, "Merchant").fill(ADDRESS_B);
  await field(page, "Amount").fill("1000000");
  await field(page, "Window").fill("3600");
  await field(page, "Item").fill("1000000");
  await page.locator(".field:has(label:has-text('Kind')) .seg").getByText(/ERC20/).click();
  await field(page, "Deliverable asset").fill(USDC);
  await speak("sign");
  await page.locator(".btnrow button", { hasText: "Approve" }).click();
  await done(page);
  await page.locator(".btnrow button", { hasText: "Open Escrow" }).click();
  await expect(statusB(page)).toHaveText("HELD", { timeout: 120000 });
  await speak("held");

  await switchAccount(page, 1);
  await expect(page.locator(".wallet-block")).toContainText(ADDRESS_B.slice(0, 6));
  await speak("switchM");
  await nav(page, "Faucet").click();
  await page.locator(".actionrow", { hasText: "Mint 1000 test kUSD" }).getByRole("button").click();
  await done(page);
  await nav(page, "Settle").click();
  await speak("fulfill");
  await page.locator(".actionrow", { hasText: "Approve Deliverable" }).getByRole("button").click();
  await done(page);
  await page.locator(".actionrow", { hasText: "Fulfill" }).getByRole("button").click();
  await expect(statusB(page)).toHaveText("RELEASED", { timeout: 120000 });
  await speak("released");
  await page.locator(".actionrow", { hasText: "Withdraw" }).getByRole("button").click();
  await done(page);

  // ── Reversal + on-chain guard ──
  await switchAccount(page, 0);
  await expect(page.locator(".wallet-block")).toContainText(ADDRESS.slice(0, 6));
  await cardOf(page, "But what if they don't deliver?", "The money kembali.");
  await speak("reversalq", { card: true });
  await cardOf(page, "", "");

  await nav(page, "Open Escrow").click();
  await field(page, "Merchant").fill(DEAD);
  await field(page, "Amount").fill("1000000");
  await field(page, "Window").fill("30");
  await page.locator(".field:has(label:has-text('Kind')) .seg").getByText(/NFT/).click();
  await speak("newesc");
  await page.locator(".btnrow button", { hasText: "Approve" }).click();
  await done(page);
  await page.locator(".btnrow button", { hasText: "Open Escrow" }).click();
  await expect(statusB(page)).toHaveText("HELD", { timeout: 120000 });

  await nav(page, "Settle").click();
  await speak("tryrefund");
  await page.locator(".actionrow", { hasText: "Refund" }).getByRole("button").click();
  await expect(toast(page)).toContainText("TOO_EARLY", { timeout: 20000 });
  await speak("tooearly");
  await speak("wait");
  const refundRow = page.locator(".actionrow", { hasText: "Refund" });
  await expect(refundRow.locator(".a-note")).toContainText("refund open", { timeout: 60000 });
  await speak("refundnow");
  await expect(async () => {
    await refundRow.getByRole("button").click();
    await expect(statusB(page)).toHaveText("REFUNDED", { timeout: 12000 });
  }).toPass({ timeout: 90000, intervals: [3000, 5000] });
  await page.locator(".actionrow", { hasText: "Withdraw" }).getByRole("button").click();
  await done(page);
  await speak("refunded");

  // ── Agent / relayer-safe ──
  await nav(page, "Open Escrow").click();
  await field(page, "Merchant").fill(DEAD);
  await field(page, "Amount").fill("1000000");
  await nav(page, "Agent").click();
  await speak("agent1");
  await speak("agent2");
  await page.getByRole("button", { name: /Run Agent Buy/ }).click();
  await expect(statusB(page)).toHaveText("HELD", { timeout: 180000 });
  await speak("agent3");

  // ── Outro ──
  await cardOf(page, "Compliant + reversible — on-chain",
    "CompliantEscrow enforces KYC/sanctions on-chain before the escrow opens. 72 tests · 512k-call invariant · bytecode == source.");
  await speak("compliance", { card: true });
  await cardOf(page, "Kembali", "Payments that can come back. — live on HashKey Chain");
  await speak("outro", { card: true });
  await beat(page, 800);

  writeFileSync(join(VO_DIR, "offsets.json"), JSON.stringify(offsets, null, 2));
});
