# Kembali — Reversible Stablecoin Payments on HashKey Chain

**Track: DeFi · HSP payment dApp · RWA settlement**
*"HSP settles the payment. Kembali gives it a way back."*

🔗 **Live dApp:** https://kembali-dapp-hudas-projects-a8e7f558.vercel.app
💻 **Code:** https://github.com/PugarHuda/kembali

---

## The problem

HSP makes stablecoin settlement on HashKey Chain **verifiable and final** — great for trust, but fatal for adoption. Real commerce needs **recourse**: refunds, protection when goods never arrive, a way to get your money back. Crypto payments have no chargeback, so buyers won't transact.

Look at this hackathon's submissions: every payment/agent project builds control **before** money moves — approve-before-pay, maker-checker, spend limits, risk scanners. **Not one gives the payer recourse *after* money moves.** That empty lane is what Kembali owns.

## The solution

Funds don't go straight to the merchant. They sit in a **Kembali escrow**, bound to an agreed **on-chain deliverable + deadline**:

- ✅ **Merchant delivers** the exact agreed asset before the deadline → **atomic delivery-vs-payment** (asset → buyer, funds → merchant).
- ↩️ **Merchant fails** to deliver by the deadline → **the buyer reclaims the funds.** The money *kembali*.

**The key insight:** because the deliverable is on-chain, *"delivered"* is a **deterministic fact** — so Kembali needs **no arbiter, no oracle, no bond, no dispute committee.** Trustless recourse by construction. (Off-chain goods are a documented extension.)

```
Buyer signs 1 HSP mandate → open() → [HELD] (funds escrowed)
   ├─ merchant delivers exact asset before deadline → fulfill() → [RELEASED] → merchant withdraws
   └─ deadline passes, undelivered            → refund()  → [REFUNDED] → buyer withdraws
```

## Why it fits HashKey Chain

- **RWA settlement, the chain's core thesis** — the deliverable is a tokenized RWA (gold, invoice, receipt NFT) or any ERC-721 / ERC-20, swapped atomically against USDC.e.
- **HSP-native** — the escrow `id` **is** the EIP-712 HSP mandate digest, and the mandate is **verified on-chain** in `open()`, so the HSP binding is enforced, not decorative.
- **AI-agent-ready** — signatures validate via **EIP-1271** (smart-contract / agent wallets), and a relayer/agent can settle a principal-signed mandate (funds always pulled from the signer).

## Technical maturity (what most demos skip)

Not a prototype — a hardened contract with an adversarial test suite:

- **57 unit tests + a stateful invariant** — `token.balanceOf(Kembali) == held + credited` holds over **512,000 random** open/fulfill/refund/cancel/withdraw sequences → the money can't leak.
- **On-chain EIP-712 verification** — ecrecover **and** EIP-1271; s/v malleability and r=0 rejected.
- **Anti front-running** — escrow terms committed in `settlementBinding`; mandates are **revocable**.
- **Pull-payments** — a blacklisted counterparty can't freeze the other party's funds (isolation tested).
- **SafeERC20 + balance asserts** — no-bool (USDT) tokens work; fee-on-transfer / "lying" tokens rejected.
- **Encoding proven** — mandate digest & binding cross-checked byte-identical between the dApp (ethers) and Solidity; the full flow was executed end-to-end against a live chain.
- **Clean `forge lint`; identical under optimizer + via-IR.** One bug found in review (ERC20 zero-item) — fixed.

## HSP usage (honest)

The escrow `id` = EIP-712 HSP v1 Mandate digest; the 11-field v1 schema with domain `{name:"HSP",version:"1"}` is verified on-chain. A self-verify path is designed (pin the adapter — no hosted Coordinator required). Reconciling HSP's profile-tagging of `signer`/`recipient` with `@hsp/core` for a live Coordinator is an integration step, not a redesign.

## What's next

Wire the live HSP Coordinator Receipt/verify loop · compliant payments (KYC/sanctions attestations) to match HashKey's regulated-DeFi thesis · standing autonomous agent budgets (HSP DelegationGrant) · bonded dispute path for off-chain deliverables.

## One line for the judges

**Everyone here built a gate in front of the payment. We built the door back out — trustlessly, on HSP, for RWA settlement on HashKey Chain.**
