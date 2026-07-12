# Kembali — Reversible Stablecoin Payments on HashKey Chain
### DeFi track · HSP payment dApp · "verify the settlement, then give it a way back"

---

## 1. The problem (that nobody else in this hackathon is solving)
HSP makes stablecoin settlement **verifiable and final** — great for trust, fatal for adoption.
Real commerce needs **recourse**: refunds, non-delivery protection, a way to get your money back.
Crypto payments have no chargeback. Merchants and buyers won't transact without one.

Look at the 27 submissions: every payment/agent project builds control **before** money moves —
approve-before-pay, maker-checker, spend limits, risk scanners. **Not one gives the payer recourse
*after* money moves.** That is the empty lane. Kembali owns it.

> **Kembali = the reversibility layer HSP deliberately doesn't have — without breaking HSP's verifiability.**

**The innovation:** it's not another escrow app — it's a **new primitive: deterministic, arbiter-free recourse.**
Everyone else adds a trusted party to judge delivery (AI arbiter, human approver, oracle, bond game).
Kembali *removes* it — for on-chain deliverables, "delivered" is a fact the contract checks itself, so
recourse is trustless by construction. One reusable primitive → RWA settlement, agent commerce,
marketplaces, subscriptions, remittance. (See INNOVATION.md.)

## 2. How it works (60 seconds)
Funds don't go straight to the merchant. They sit in a Kembali escrow, bound to an agreed
**on-chain deliverable + deadline**:

```
Payer signs 1 HSP mandate ──► open()  ─── funds escrowed ──► HELD
   (id = mandate digest)                                      │
                                   ┌────────── merchant delivers exact asset before deadline
                                   ▼                          │  (atomic DvP: asset→payer)
                                fulfill() ──► RELEASED ──► merchant withdraws funds
                                   ▲
   deadline passes, nothing delivered ──► refund() ──► REFUNDED ──► payer withdraws. Money *kembali*.
```

The **key design insight**: because the deliverable is on-chain, "delivered" is a *deterministic*
fact — so Kembali needs **no arbiter, no oracle, no bond, no dispute committee**. Trustless recourse
by construction. (Subjective/off-chain goods are a documented extension.)

## 3. Why it wins on this chain
- **Fits the DeFi/RWA track exactly** — deliverable = tokenized RWA (gold, invoice, receipt NFT) ⇄
  USDC.e, with atomic delivery-vs-payment. This is RWA settlement, HashKey's core thesis.
- **HSP-native** — the escrow `id` is the EIP-712 mandate digest, verified **on-chain** so the
  binding is enforced, not decorative. It uses the HSP v1 Mandate schema and is built to be the HSP
  `paymentId`; matching a live HSP Coordinator needs the profile-tagging reconciled (see Known
  limitations) — an integration step, not a redesign.
- **AI-agent ready** — signatures validate via **EIP-1271** (smart-contract / agent wallets) and a
  relayer/agent can settle a principal-signed mandate (funds always pulled from the signer).
  Standing autonomous agent budgets are a documented next step.

## 4. Technical maturity (the part most demos skip)
Not a prototype — a hardened contract with an adversarial test suite:
- **57 unit + 1 stateful invariant**; the invariant `token.balanceOf == held + credited` holds over
  **128,000 random** open/fulfill/refund/withdraw sequences → the money can't leak.
- **On-chain EIP-712 verification** (ecrecover **and** EIP-1271), s/v malleability rejected.
- **Anti front-running** — terms committed in `settlementBinding`; **revocable** bearer mandates.
- **Pull-payments** — a blacklisted counterparty can't freeze the other party's funds.
- **SafeERC20 + balance asserts** — no-bool (USDT) tokens work; fee-on-transfer tokens rejected.
- **Encoding proven** — mandate digest & settlementBinding cross-checked byte-identical between
  ethers (frontend) and Solidity, so the dApp actually settles.
- Working web dApp (MetaMask, chain 177) + one-command demo deploy that seeds a live scenario.

## 5. What's live vs next
**Live:** contract + full test suite + web demo + deploy script (deploys Kembali + demo RWA/USDC,
seeds a runnable fulfill/refund scenario on mainnet 177).
**Next:** wire the real HSP Coordinator Receipt/verify loop (self-verify path already designed);
compliant payments (KYC/sanctions attestations) to match HashKey's regulated-DeFi thesis; bonded
dispute path for off-chain deliverables.

## 6. One line for the judges
**Everyone here built a gate in front of the payment. We built the door back out — trustlessly,
on HSP, on HashKey mainnet.**
