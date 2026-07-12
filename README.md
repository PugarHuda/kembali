# Kembali — Reversible Stablecoin Payments on HashKey Chain

**Track: DeFi (HSP payment dApp).** HSP settles payments *finally*. **Kembali** adds the
recourse HSP lacks: funds sit in escrow against an agreed **on-chain deliverable + deadline**.

- Merchant delivers the **exact** agreed asset → **atomic DvP** (asset → payer, funds → merchant).
- Merchant fails to deliver by the deadline → **payer reclaims the funds**. The money *kembali*.

The escrow `id` is an EIP-712 HSP mandate digest verified on-chain; we also compute **and** verify the
**canonical** HSP paymentId on-chain (`HSPCanonical`, byte-identical to the `@hsp/core` reference SDK).

**Live:** landing **https://kembali-hsp.vercel.app** · escrow dApp **/app** · pitch deck **/pitch** · both flows (fulfill + refund) proven on-chain.

### Live contracts — HashKey mainnet (177)
| contract | address |
|----------|---------|
| Kembali (escrow) | [`0xDea6Da93265871d828B20cace2BADd5F5e70209d`](https://hashkey.blockscout.com/address/0xDea6Da93265871d828B20cace2BADd5F5e70209d) |
| CompliantEscrow (on-chain KYC/sanctions gate → escrow) | [`0xf942DF0a93E7B50987040E72Eb8Db07A35d7a9F3`](https://hashkey.blockscout.com/address/0xf942DF0a93E7B50987040E72Eb8Db07A35d7a9F3) |
| HSPCanonical (canonical mandate/receipt/grant hashing + verify) | [`0x6B99B00BD52Bc134D5658745E64DF1938592e468`](https://hashkey.blockscout.com/address/0x6B99B00BD52Bc134D5658745E64DF1938592e468) |
| HSPAttestationRegistry (KYC/sanctions attestations) | [`0xda0cEB552af13f5a096D8aA4E5A9FceB9cf6D8D0`](https://hashkey.blockscout.com/address/0xda0cEB552af13f5a096D8aA4E5A9FceB9cf6D8D0) |
| DemoUSDC · DemoNFT | `0x481fE34ed995603abdB9998b7eCc8811e2707d87` · `0x6091e0111fB0F94fAE4b9D3Bbb0c36dD72D43454` |

### Integrity (independently verified)
- **Deployment integrity** — on-chain `Kembali` & `HSPCanonical` runtime bytecode is a **byte-exact match** to the compiled source (diffed against the artifact).
- **Invariant** — `token.balanceOf == held + credited` holds over **512,000** random calls (`runs=1024×depth=500`).
- **Compliant + reversible, enforced on-chain** and **agent/relayer-safe** — both proven with live mainnet transactions (see below).

Frontend: `frontend/` — **React + TypeScript + Vite + wagmi + viem + zustand + React Router** (editorial design, wired to the live contract). `cd frontend && npm i && npm run dev`.

## Why it's novel
Every other project builds control **before** payment (approve-before-pay, maker-checker).
Kembali is the only one giving the payer recourse **after** payment — without breaking HSP's
verifiability, and **without an arbiter**.

> **QA finding (why no arbiter/bond):** because the deliverable is on-chain, "delivered" is a
> *deterministic* fact — there is nothing subjective to arbitrate. A dispute/bond/arbiter layer
> is redundant and only adds attack surface. So we dropped it. Trustless by construction.

## Contract API (`src/Kembali.sol`)
| fn | who | effect |
|----|-----|--------|
| `open(mandate, signature, merchant, asset, item, kind, window)` | payer | verify EIP-712 HSP mandate on-chain → escrow funds; `id = hashMandate` |
| `fulfill(id)` | merchant | deliver exact `asset/item` (ERC721 or ERC20 RWA) → pay merchant (atomic DvP) |
| `refund(id)` | payer | after deadline, if undelivered → reclaim funds |
| `cancel(id)` | merchant | bow out early → refund payer immediately |

**On-chain compliance gate (`src/CompliantEscrow.sol`).** `openCompliant(mandate, sig, …, requiredCaps)`
does `require(registry.compliant(payer, requiredCaps))` **on-chain** — the payer must hold the required
HSP KYC/sanctions attestations (`HSPAttestationRegistry`) — then opens the audited `Kembali` escrow.
Compliance is enforced by the EVM, not an off-chain check. This is the regulated-DeFi path: a
**compliant *and* reversible** payment, all on-chain.

Safety / hardening:
- **On-chain mandate verification** — `open` verifies the EIP-712 signature, requires `recipient == this`,
  correct `chainId`, non-expired mandate, `window > 0`, and `settlementBinding ==
  keccak256(merchant, asset, item, kind, window)`. HSP `id` binding is *enforced* (not convention);
  terms are signed so tampering/front-running is rejected. Digest equivalence with ethers is verified.
- **Agents & smart wallets** — signature is checked via ecrecover **or EIP-1271**, and funds are pulled
  from the *signer* (not the submitter), so an AI-agent/relayer can settle a principal-signed mandate.
- **Delivery within the window** — `fulfill` requires `now < deadline`; after that only refund.
- **Pull-payments** — payouts are credited and claimed via `withdraw`, so a blacklisted counterparty
  can't freeze the other party's funds. Accounting is invariant-tested over **512,000** random ops.
- **Revocable mandates** — a signed mandate is a bearer authorization; `revoke(nonce)` cancels one
  before it's opened. Keep mandate deadlines short and approve exact amounts (not infinite).
- **SafeERC20 + balance checks** — low-level calls tolerate no-bool tokens (USDT-style); received
  amounts are asserted, so fee-on-transfer/deflationary tokens are rejected (`FEE_TOKEN`) instead of
  quietly making the escrow insolvent.
- **Core is public-payment only** — `Kembali.open()` requires `requiredCapabilitiesHash` empty.
  Compliant (KYC/sanctions) payments go through **`CompliantEscrow`** (above), which enforces the
  attestations on-chain and then opens the same audited escrow.
- **CEI + `lock` reentrancy guard** on every money path; exact-asset enforcement; funds can only
  ever reach `payer` or `merchant`.

## Build & test
```bash
git clone --recursive https://github.com/PugarHuda/kembali   # --recursive fetches forge-std
cd kembali
forge test            # 72 unit tests + 1 invariant: DvP, refund, relayer, EIP-1271, revoke, window-closed,
                      # on-chain compliance gate (attested/uncompliant/expired/revoked), reentrancy,
                      # SafeERC20, fuzz-conservation, access control.
                      # invariant_accounting holds over 512,000 random open/fulfill/refund/withdraw calls:
                      # token.balanceOf(Kembali) == heldFunds + creditedFunds, always.
```
Design logic was first validated as an executable model (`../scratchpad/reversefi_model.mjs`, 19 asserts)
before porting to Solidity.

**End-to-end (Playwright, 15 tests, drives the live dApp):**
```bash
cd frontend && npm i && npx playwright install chromium
npm run e2e:ui        # UI walkthrough + wallet connect/disconnect/reconnect (no gas, ~15s)
npm run e2e           # + real mainnet-177 flows: fulfill/atomic-DvP (two wallets), reversal
                      #   (open→refund→withdraw), Agent Buy, and a SELF_DEAL guard case
```
Injected EIP-1193 wallets (viem, Node-side) sign and send **real transactions** through actual UI
clicks — including a two-wallet account switch that proves the merchant-side fulfill. Set
`E2E_BASE_URL=http://localhost:4173` to test a local `npm run build && npm run preview` first.

## Deploy to HashKey mainnet (177)
```bash
export PRIVATE_KEY=0x...            # funded with HSK for gas
forge script script/Deploy.s.sol --rpc-url hashkey --broadcast --verify
```
Deploys the full surface — **Kembali + HSPCanonical + HSPAttestationRegistry + CompliantEscrow +
DemoUSDC + DemoNFT** — and seeds the deployer (mints kUSD, mints a demo RWA NFT, pre-approves Kembali).
It logs all addresses. Simulate first without `--broadcast`.
- RPC `https://mainnet.hsk.xyz` · explorer `https://hashkey.blockscout.com`
- Production pay token: **USDC.e** `0x054ed45810DbBAb8B27668922D110669c9D88D0a` (6 decimals).
  DemoUSDC (mintable) lets you demo the full flow without spending real stablecoin.

## Demo walkthrough (web/index.html)
1. Connect wallet (auto-adds/-switches to 177). Paste the deployed **Kembali** address.
2. **Payer**: set merchant, token=DemoUSDC, amount, asset=DemoNFT, item=demo id, kind=0 (NFT) →
   `Approve` (pay token) → `Open escrow` (signs the EIP-712 mandate in the wallet; id auto-fills).
3a. **Happy path** — Merchant: `approve deliverable` → `fulfill` (asset → payer) → `Withdraw` (funds → merchant).
3b. **Reversal** — nobody fulfills; after the window the Payer clicks `refund` → `Withdraw` and the money comes back.
Use `Read status` any time to see HELD / RELEASED / REFUNDED.

## HSP integration (`hsp/pay.mjs`)
Self-verify (pin adapter address; no hosted Coordinator needed — mainnet Coordinator URL is
still a placeholder in HSP docs). `id = keccak256(mandate)` binds the HSP mandate to the escrow.
Vendor the SDK: `git clone https://github.com/project-hsp/hsp`.

## Flow
```
Payer ── sign HSP mandate (id = digest) ──► open() ──► [HELD] ── funds escrowed (pulled from signer)
                                                          │
        merchant delivers exact asset before deadline ──► fulfill() ──► [RELEASED]
                                                          │                    └─ merchant withdraw()
        deadline passes, undelivered ─────────────────► refund() ──► [REFUNDED] ─ payer withdraw()
        merchant bows out ────────────────────────────► cancel() ──► [REFUNDED] ─ payer withdraw()
```

## Known limitations (honest)
- **HSP: canonical mandate verified off-chain against the real SDK; on-chain uses a flat variant.**
  `hsp/selfverify.mts` builds a spec-exact canonical HSP v1 mandate (nested `Signer`/`Recipient`,
  `uint64` deadline) and the real `@hsp/core` verifier (`eip712-eoa.v1`) returns **ACCEPT**. The
  on-chain `open()` verifies a gas-optimized flat mandate (address/uint256); aligning the on-chain
  digest to the canonical `mandateHash` and wiring the Coordinator Receipt/verify loop are the
  documented next steps (`hsp/pay.mjs` observe/verify is still stubbed).
- **Compliant payments go through `CompliantEscrow`** — the core `Kembali` is public-only; the
  on-chain KYC/sanctions gate lives in the `CompliantEscrow` wrapper (proven live). Folding the gate
  directly into a single escrow contract would need a redeploy of the immutable core.
- **On-chain deliverables only** — off-chain goods/services need the bonded dispute path (Extensions).
- **Immutable, no admin/pause** — deliberate (trustless), but a post-deploy bug means redeploy+migrate.

## Built since the audit
- **On-chain compliance gate** — `CompliantEscrow` enforces HSP KYC/sanctions attestations on-chain
  before opening the escrow (6 unit tests + live mainnet proof: un-attested reverts `NOT_COMPLIANT`,
  attested opens `HELD`). Moved here from "extensions".
- **Agent/relayer-safe, proven live** — a separate agent wallet submits the principal's signed
  mandate; funds are pulled from the *signer*, so the agent can't redirect them (`escrow.payer ==
  principal`, principal balance −amount, agent balance unchanged). Unit-tested + live tx.

## Extensions (not built — deliberate)
- **Standing agent budgets** — let an agent sign its *own* mandates under a principal's HSP
  DelegationGrant (verify `grantRef` + enforce a spend cap). Today an agent can only relay a
  principal-signed mandate (still fully AI-agent capable via EIP-1271 wallets).
- **Subjective/off-chain deliverables** (physical goods, services): add a bonded dispute path.
  Only needed when delivery isn't provable on-chain.
- **Partial refunds / milestones.**
