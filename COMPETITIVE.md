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

## Moats no one else can show
1. **Both flows proven LIVE on mainnet 177** — real tx: happy-path (atomic DvP) *and* reversal (refund).
2. **Deployment integrity** — on-chain bytecode is **byte-identical** to the audited source.
3. **Test rigor** — 57 unit tests + a stateful invariant proven over **512,000 random calls**; clean
   lint; identical under optimizer + via-IR. Audit-grade for a hackathon.
4. **Real HSP** — the actual `@hsp/core` reference verifier returns **ACCEPT** for a canonical mandate.
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
A: Honest answer: the real `@hsp/core` verifier accepts our canonical mandate (`hsp/selfverify.mts`,
ACCEPT). On-chain we verify a gas-optimized flat mandate. Aligning the on-chain digest to the canonical
`mandateHash` and wiring the Coordinator Receipt loop are the documented next steps — integration, not
redesign.

**Q: Is it just Public payments? The chain is compliance-first.**
A: Yes, Public-only today (Compliant mandates are explicitly rejected, not silently accepted). Compliant
payments via KYC/sanctions attestations is the immediate roadmap and fits HashKey's regulated-DeFi thesis.

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
