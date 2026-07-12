# Kembali — Competitive Position & Judge Q&A

## The wedge (one sentence)
**Every other payment/escrow project gates the money *before* it moves. Kembali is the only one that
gives the payer a way *back* after it moves — trustlessly, with no arbiter, proven live on mainnet.**

## Head-to-head (DeFi track)
| Project | What it does | Kembali's edge |
|---|---|---|
| **PaymentGuard** | AI maker-checker; unmodified HSP verifier accepts only AI-approved payments; live mainnet | Strong, but it's **pre-payment control** (the crowded lane). Kembali is **post-payment recourse** (the empty lane) — orthogonal, not competing. And Kembali needs **no AI in the trust path**. |
| **Arbit(er)** | Milestone escrow + **AI proof evaluation** for release | Arbit's release depends on an **AI arbiter** (a trust + failure point). Kembali releases on a **deterministic on-chain fact** — no arbiter, no oracle, nothing to corrupt. |
| **AgentPay Passport** | KYC + milestone escrow + **human approval** before signing | Also pre-payment + needs **human-in-the-loop**. Kembali is automatic and trust-minimized. |
| **Credifi / Credo / Tessera** | Credit scoring / under-collateralized lending | Different category (credit, not payment recourse). |
| **AI-RWA Optimizer / Dow** | RWA management / financing | They *manage/finance* RWA; Kembali *settles* it (atomic DvP with recourse). |

**Takeaway:** the closest rivals (Arbit, AgentPay) all rely on an arbiter — AI or human. Kembali is the
only trust-minimized, deterministic recourse layer. It doesn't compete with PaymentGuard; it completes
the picture (control before + recourse after).

## The field grew to 48 — the moat holds
A late flood of submissions clustered on **agent trust/credit** (TrustRail, Tessera, Credo, Credence,
Sentinelfi, Noviq), **agent spend-control** (Scratch Wallet, AgentPay, Kanshi), **HSP compliance**
(Nexash, TEGATA, PaymentGuard), and **merchant payments** (Recon, PactPay). Every one of them is
*pre-payment control, credit, or reconciliation*. **Across all 48 BUIDLs, none does post-payment
recourse — reversibility.** That lane is still entirely Kembali's.

And Kembali isn't *only* recourse: it also covers the crowded areas — **compliance** (HSPAttestationRegistry,
KYC/sanctions, live), **agent-safe commerce** (autonomous agent proven live), **HSP depth** (canonical
paymentId hashed + verified on-chain == reference SDK) — unified and proven on mainnet, while many new
entrants are still testnet or concept. Vs the closest new rivals: **Nexash** gates compliance but has no
recourse; **AllScale** verifies merchant-side agent trust (pre-payment); **Recon** reconciles invoices
(not recourse). Kembali is the only *reversibility primitive*, and it composes the rest.

## Moats no one else can show
1. **Both flows proven LIVE on mainnet 177** — real tx: happy-path (atomic DvP) *and* reversal (refund).
2. **Deployment integrity** — on-chain bytecode is **byte-identical** to the audited source.
3. **Test rigor** — 57 unit tests + a stateful invariant proven over **512,000 random calls**; clean
   lint; identical under optimizer + via-IR. Audit-grade for a hackathon.
4. **Real HSP, on-chain** — the actual `@hsp/core` verifier ACCEPTs our canonical mandate, AND we
   compute the **canonical HSP paymentId on-chain** (`HSPCanonical`, live at `0x6B99…e468`),
   byte-identical to the reference SDK — provable with a live mainnet call.
5. **Agent-ready** — EIP-1271 + relayer submission (funds pulled from the signer).
6. **No arbiter** — deterministic on-chain delivery = trustless by construction.

## Judge Q&A (anticipated)
**Q: How is this different from a normal escrow / Arbit / AgentPay?**
A: Those release on an arbiter's decision (AI or human). Kembali releases on a *deterministic on-chain
fact* — the exact agreed asset either moved or it didn't. No arbiter, oracle, bond, or committee.

**Q: "Delivered" is hard to verify — how do you know?**
A: We scope to *on-chain* deliverables (tokenized RWA / NFT / ERC-20), where delivery is a fact the
contract checks itself (atomic DvP). Off-chain goods are a documented extension (bonded dispute).

**Q: How deep is the HSP integration, really?**
A: Deep and verifiable. (1) The real `@hsp/core` reference verifier ACCEPTs our canonical mandate
(`hsp/selfverify.mts`). (2) We compute the **canonical HSP `mandateHash` ON-CHAIN** — `HSPCanonical`
(live at `0x6B99…e468`) returns the byte-identical `mandateHash` the reference SDK produces, provable
with a live mainnet call. So Kembali produces the *real* HSP paymentId on-chain, matching the reference
implementation — not just HSP-shaped. Kembali's escrow uses a gas-optimized flat mandate for cheap
settlement. Wiring the Coordinator Receipt loop is the one remaining integration.

**Q: Is it just Public payments? The chain is compliance-first.**
A: The escrow is Public-safe by default (Compliant mandates are explicitly rejected, never silently
accepted) — AND we built the compliance path: `HSPAttestationRegistry` (live on mainnet
`0xda0c…D8D0`) lets a trusted issuer attest HSP `attests:kyc:v1` / `attests:sanctions:v1` capabilities,
so a payment can be gated on `compliant(subject, requiredCaps)`. Demonstrated live on mainnet. This is
exactly HashKey's regulated-DeFi thesis, on-chain.

**Q: Security?**
A: CEI + reentrancy guard on every money path; funds can only reach payer or merchant; signature
malleability / r=0 / EIP-1271-malformed rejected; SafeERC20 + balance asserts (fee/lying tokens rejected);
pull-payments isolate a blacklisted party. All covered by the 57 tests + 512k-call invariant.

**Q: Can AI agents use it?**
A: Yes — EIP-1271 smart-contract/agent wallets, and a relayer can submit a principal-signed mandate
(funds always pulled from the signer, never the submitter).

**Q: Why fund/incubate this?**
A: It's the recourse layer HSP deliberately lacks — a prerequisite for real merchant/RWA adoption on a
compliance-first chain. Clear roadmap (compliance, agent budgets, off-chain disputes), live and tested today.

## One line to close
Everyone built a gate in front of the payment. We built the door back out — trustlessly, on HSP,
proven live on HashKey mainnet.
