# DoraHacks BUIDL — paste-ready copy

Fill the `<...>` placeholders after deploy. Written to match the honest scope (no overclaim).

---

## Name
**Kembali**

## Tagline (one line)
Reversible stablecoin payments on HashKey Chain — HSP settles finality, Kembali gives it a way back.

## Track
**DeFi** (HSP payment dApp · RWA settlement)

## Tags
`DeFi` `HSP` `RWA` `Payments` `HashKey Chain` `Crypto-AI`

---

## Short description (card, ~2 lines)
HSP makes stablecoin settlement final; real commerce needs recourse. Kembali escrows payment against
an on-chain deliverable + deadline: merchant delivers → atomic DvP; doesn't → the buyer's money comes
back. Trustless, no arbiter, HSP-native, live on HashKey mainnet.

## Full description

**The problem.** HSP makes stablecoin settlement verifiable and *final* — great for trust, fatal for
adoption. Commerce needs recourse: refunds, non-delivery protection, a way to get your money back.
Crypto payments have no chargeback. Across this hackathon's submissions, every payment/agent project
builds control *before* money moves (approve-before-pay, maker-checker, risk scanners). **None gives
the payer recourse *after* money moves.** Kembali owns that empty lane.

**The solution.** Funds don't go straight to the merchant — they sit in a Kembali escrow bound to an
agreed **on-chain deliverable + deadline**:
- Merchant delivers the exact agreed asset before the deadline → **atomic delivery-vs-payment**
  (asset → payer, funds → merchant).
- Merchant fails to deliver by the deadline → **the payer reclaims the funds.** Money *kembali*.

**The key insight.** Because the deliverable is on-chain, "delivered" is a *deterministic* fact — so
Kembali needs **no arbiter, no oracle, no bond, no dispute committee.** Trustless recourse by
construction. (Off-chain goods are a documented extension.)

**Why it fits HashKey.** The deliverable is a tokenized RWA (gold, invoice, receipt NFT) or any
ERC-721/ERC-20 ⇄ USDC.e — this is RWA settlement, HashKey's core thesis. The escrow `id` is the HSP
mandate digest, and the mandate is **verified on-chain**, so the HSP binding is enforced, not
decorative. Signatures validate via **EIP-1271**, so AI-agent / smart-contract wallets can pay.

## Key features
- Reversible payment escrow with atomic DvP settlement (ERC-721 and ERC-20/RWA deliverables).
- On-chain EIP-712 HSP-mandate verification (ecrecover **and** EIP-1271 for agent wallets).
- Relayer/agent submission — funds always pulled from the signer, not the sender.
- Pull-payments so a blacklisted counterparty can't freeze the other party's funds.
- Revocable bearer mandates; anti front-running via signed `settlementBinding`.
- SafeERC20 + balance asserts (USDT-style no-bool ok; fee-on-transfer rejected).

## Proof of quality
- **72 tests + 1 stateful invariant.** The invariant `token.balanceOf == held + credited` holds
  over **512,000 random** open/fulfill/refund/cancel/withdraw sequences (Foundry `runs=1024×depth=500`)
  — the money can't leak.
- **15 end-to-end tests (Playwright) drive the *live* dApp** with injected signing wallets: a full
  UI walkthrough + wallet connect/disconnect/reconnect (no gas), plus every core money flow executing
  **real mainnet-177 transactions through actual UI clicks** — **fulfill / atomic DvP** (payer opens →
  a *second* merchant wallet delivers the ERC-20 → RELEASED → merchant withdraws), **reversal**
  (open → wait window → refund → withdraw), **autonomous Agent Buy** (mint → approve → open), and a
  client-side **SELF_DEAL guard** case.
- **Both flows proven live on mainnet** (fulfill + refund).
- **Compliant + reversible, enforced ON-CHAIN.** `CompliantEscrow.openCompliant()` requires the payer's
  HSP KYC/sanctions attestations (`HSPAttestationRegistry`) via an on-chain `require` before opening the
  audited Kembali escrow — not an off-chain JS check. Proven live: un-attested payer reverts
  `NOT_COMPLIANT`; after attestation the reversible escrow opens (6 unit tests + live mainnet tx).
- **Agent/relayer-safe, proven live.** A *different* agent wallet submits the principal's signed
  mandate; funds are pulled from the signer, so the agent can't redirect them (unit test + live tx:
  escrow.payer == principal, principal balance −amount, agent balance unchanged).
- **Canonical HSP paymentId hashed AND verified on-chain** (`HSPCanonical`), matching the
  `@hsp/core` reference SDK. **Deployment integrity:** on-chain `Kembali` & `HSPCanonical` bytecode
  is a **byte-exact match** to the compiled source (independently diffed).
- Clean CI (build + test). Working web dApp (MetaMask, chain 177) + one-command demo deploy.

## Tech stack
Solidity 0.8.24 · Foundry (tests, invariant, deploy) · EIP-712 / EIP-1271 · ethers v6 web dApp ·
HashKey Chain mainnet (177) · HSP v1 Mandate schema.

## HSP usage
Escrow `id` = EIP-712 HSP v1 Mandate digest (`keccak256`); the mandate (11-field v1 schema, domain
`{name:"HSP",version:"1"}`) is verified on-chain in `open()`. Beyond that flat mandate, `HSPCanonical`
computes **and** verifies the **canonical** HSP paymentId on-chain (nested `Signer`/`Recipient`),
byte-identical to the `@hsp/core` reference SDK (proven live). Compliance uses HSP `attests:kyc/sanctions`
via `HSPAttestationRegistry`. The remaining step is the hosted Coordinator Receipt loop — an integration step, not a redesign.

## Links
- Repo: https://github.com/PugarHuda/kembali
- Live dApp: https://kembali-hsp.vercel.app
- Pitch deck: https://kembali-hsp.vercel.app/pitch
- **Live on HashKey mainnet (chain 177):**
  - Kembali: https://hashkey.blockscout.com/address/0xDea6Da93265871d828B20cace2BADd5F5e70209d
  - CompliantEscrow (on-chain KYC/sanctions gate → reversible escrow): `0xf942DF0a93E7B50987040E72Eb8Db07A35d7a9F3`
  - DemoUSDC: `0x481fE34ed995603abdB9998b7eCc8811e2707d87`
  - DemoNFT: `0x6091e0111fB0F94fAE4b9D3Bbb0c36dD72D43454`
  - HSPCanonical (on-chain canonical HSP mandateHash + Receipt + DelegationGrant hashing + eip712-eoa verify, all == reference SDK): `0x6B99B00BD52Bc134D5658745E64DF1938592e468`
  - HSPAttestationRegistry (compliance path — KYC/sanctions attestations, demonstrated live): `0xda0cEB552af13f5a096D8aA4E5A9FceB9cf6D8D0`
- Demo video: `<url>` (record via DEMO.md, add after)

## What's next
Done since v1: canonical mandate/Receipt/DelegationGrant hashing + verification on-chain (== SDK), and
compliance (KYC/sanctions). Remaining: a hosted HSP Coordinator that produces adapter-signed Receipts;
functional agent spend-budgets enforced from the DelegationGrant; a bonded dispute path for off-chain
deliverables.

## One line for the judges
Everyone here built a gate in front of the payment. We built the door back out — trustlessly, on HSP,
on HashKey mainnet.
