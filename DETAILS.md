# Kembali — Reversible Stablecoin Payments on HashKey Chain

**Track: DeFi · HSP payment dApp · RWA settlement**
*"HSP settles the payment. Kembali gives it a way back."*

🔗 **Live dApp:** https://kembali-dapp-hudas-projects-a8e7f558.vercel.app
💻 **Code:** https://github.com/PugarHuda/kembali
⛓️ **Live on HashKey mainnet (177):** [Kembali `0xDea6…209d`](https://hashkey.blockscout.com/address/0xDea6Da93265871d828B20cace2BADd5F5e70209d)

✅ **Both flows proven live on mainnet** — real transactions:
- **Happy path (atomic DvP)** — merchant delivered NFT, got paid:
  [OPEN](https://hashkey.blockscout.com/tx/0x95479389af8ecce92207d804ae498f146dcc6977ff5cb3826e91511e8232f0e4) → [FULFILL](https://hashkey.blockscout.com/tx/0x06247a51b5757341a683dfb94d50f03baff6cabbbe3800a90abf8ac4e1c6f3f9) → [WITHDRAW](https://hashkey.blockscout.com/tx/0xc4788250dd7f7d86f8e559732b461f59465b07f6608d60a1c656d89fa4761725)
- **Reversal (money kembali)** — merchant didn't deliver, buyer reclaimed:
  [OPEN](https://hashkey.blockscout.com/tx/0xf22a8fab1a919deaf4c0f2e1f76f4d69a79027b46e4f087810875d7acc0e2713) → [REFUND](https://hashkey.blockscout.com/tx/0xa34225a8bf90cf91d65f0630c2d44ad91da4ff500e8c6eef70fd3b63a9c3cf39) → [WITHDRAW](https://hashkey.blockscout.com/tx/0xfb19cb5d90c11f5408e484e52415a7584e5671878a9840dca080575f899ad096)

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
- **Deployment integrity:** the on-chain runtime bytecode is **byte-identical** to this audited source (incl. metadata) — the live mainnet contract *is* the tested code, verified.
- **Proven live on mainnet 177:** the full reversal flow (open → refund → withdraw) executed with real transactions.
- **Compliance path (built + live):** `HSPAttestationRegistry` gates payments on HSP `attests:kyc:v1` /
  `attests:sanctions:v1` — a trusted issuer attests, and `compliant(subject, caps)` returns true/false;
  demonstrated live on mainnet. Directly on HashKey's regulated-DeFi thesis.

## HSP usage (honest, and verified against the real SDK)

We ran the **actual `@hsp/core` reference verifier** — not just the format. `hsp/selfverify.mts` builds a **spec-exact canonical HSP v1 mandate** (nested `Signer{profileId,payload}` / `Recipient{kind,payload}`, `uint64` deadline, the real `MANDATE_TYPEHASH`), computes the canonical **mandateHash** (= HSP paymentId), signs it with the `eip712-eoa.v1` SignerProfile, and the real verifier returns **`granted: true` (ACCEPT)**:

```
canonical mandateHash: 0xbef0e22bf110532be08b2c54b1bbdf50740046f459288378e2c202848de76be3
HSP eip712-eoa.verify -> { granted: true, resolvedSubject: { scheme: "evm-address", ... } }
```

And we now compute the **canonical HSP `mandateHash` ON-CHAIN too**: `HSPCanonical` (deployed live at
[`0xb5c7…9a5A`](https://hashkey.blockscout.com/address/0xb5c7a7761221931ee15c8C70DdF4192a94C49a5A))
implements the spec-exact nested `Signer`/`Recipient` structs + `uint64 deadline`, and a **live
mainnet call returns the byte-identical `mandateHash`** the reference SDK produces
(`0x623569…3933f`) — i.e., Kembali produces the *real* HSP paymentId on-chain, matching the reference
implementation. It also **verifies the eip712-eoa signer proof on-chain** (`HSPCanonical.verify` — 65-byte
proof, low-s, recover == signer), mirroring the reference verifier's accept/reject. Kembali's `open()`
still uses a gas-optimized flat mandate for cheap settlement; the
canonical hashing is proven on-chain and off-chain — and **differential-tested across 6 varied vectors**
(kinds, amounts up to 2²⁵⁶, deadlines up to 2⁶⁴−1, empty/long payloads, different domains): the live
contract matches the reference SDK on every one (`hsp/canon-diff.mts`). Full Coordinator Receipt/verify is the remaining integration.

## What's next

Wire the live HSP Coordinator Receipt/verify loop · compliant payments (KYC/sanctions attestations) to match HashKey's regulated-DeFi thesis · standing autonomous agent budgets (HSP DelegationGrant) · bonded dispute path for off-chain deliverables.

## One line for the judges

**Everyone here built a gate in front of the payment. We built the door back out — trustlessly, on HSP, for RWA settlement on HashKey Chain.**
