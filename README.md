# Kembali — Reversible Stablecoin Payments on HashKey Chain

**Track: DeFi (HSP payment dApp).** HSP settles payments *finally*. **Kembali** adds the
recourse HSP lacks: funds sit in escrow against an agreed **on-chain deliverable + deadline**.

- Merchant delivers the **exact** agreed asset → **atomic DvP** (asset → payer, funds → merchant).
- Merchant fails to deliver by the deadline → **payer reclaims the funds**. The money *kembali*.

The escrow `id` **is** the HSP `paymentId` (`keccak256(mandate)`), so one signed HSP mandate
produces both the verifiable settlement receipt and the escrow key.

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

Safety / hardening:
- **On-chain mandate verification** — `open` verifies the EIP-712 signature, requires `recipient == this`,
  correct `chainId`, non-expired mandate, `window > 0`, and `settlementBinding ==
  keccak256(merchant, asset, item, kind, window)`. HSP `id` binding is *enforced* (not convention);
  terms are signed so tampering/front-running is rejected. Digest equivalence with ethers is verified.
- **Agents & smart wallets** — signature is checked via ecrecover **or EIP-1271**, and funds are pulled
  from the *signer* (not the submitter), so an AI-agent/relayer can settle a principal-signed mandate.
- **Delivery within the window** — `fulfill` requires `now < deadline`; after that only refund.
- **Pull-payments** — payouts are credited and claimed via `withdraw`, so a blacklisted counterparty
  can't freeze the other party's funds. Accounting is invariant-tested over 128k random ops.
- **Revocable mandates** — a signed mandate is a bearer authorization; `revoke(nonce)` cancels one
  before it's opened. Keep mandate deadlines short and approve exact amounts (not infinite).
- **SafeERC20 + balance checks** — low-level calls tolerate no-bool tokens (USDT-style); received
  amounts are asserted, so fee-on-transfer/deflationary tokens are rejected (`FEE_TOKEN`) instead of
  quietly making the escrow insolvent.
- **Public payments only** — `requiredCapabilitiesHash` must be empty; Compliant (KYC/sanctions)
  payments need a trusted issuer/verifier (out of scope — see Extensions).
- **CEI + `lock` reentrancy guard** on every money path; exact-asset enforcement; funds can only
  ever reach `payer` or `merchant`.

## Test
```bash
forge test            # 57 unit + 1 invariant: DvP, refund, relayer, EIP-1271, revoke, window-closed,
                      # compliance-rejected, reentrancy, SafeERC20, fuzz-conservation, access control.
                      # invariant_accounting holds over 128k random open/fulfill/refund/withdraw calls:
                      # token.balanceOf(Kembali) == heldFunds + creditedFunds, always.
```
Design logic was first validated as an executable model (`../scratchpad/reversefi_model.mjs`, 19 asserts)
before porting to Solidity.

## Deploy to HashKey mainnet (177)
```bash
export PRIVATE_KEY=0x...            # funded with HSK for gas
forge script script/Deploy.s.sol --rpc-url hashkey --broadcast --verify
```
Deploys **Kembali + DemoUSDC + DemoNFT** and seeds the deployer (mints kUSD, mints a demo RWA NFT,
pre-approves Kembali). It logs all addresses. Simulate first without `--broadcast`.
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
- **HSP fidelity is format-level, not spec-exact.** We match the v1 Mandate struct/domain and derive
  the same digest client/contract-side, but HSP profile-*tags* `signer`/`recipient` and pins
  `verifyingContract` to the HSP deployment — we use plain addresses and Kembali's own address. So
  our `paymentId` won't match a live HSP Coordinator until the tagging is reconciled via `@hsp/core`.
  Receipts/Attestations aren't produced/verified yet (`hsp/pay.mjs` observe/verify is stubbed).
- **Public payments only** — Compliant (KYC/sanctions) mandates are rejected; see Extensions.
- **On-chain deliverables only** — off-chain goods/services need the bonded dispute path (Extensions).
- **Immutable, no admin/pause** — deliberate (trustless), but a post-deploy bug means redeploy+migrate.

## Extensions (not built — deliberate)
- **Compliant payments** — verify HSP KYC/sanctions attestations from a trusted issuer for
  non-empty `requiredCapabilitiesHash`. Kembali is Public-only today.
- **Standing agent budgets** — let an agent sign its *own* mandates under a principal's HSP
  DelegationGrant (verify `grantRef` + enforce a spend cap). Today an agent can only relay a
  principal-signed mandate (still fully AI-agent capable via EIP-1271 wallets).
- **Subjective/off-chain deliverables** (physical goods, services): add a bonded dispute path.
  Only needed when delivery isn't provable on-chain.
- **Partial refunds / milestones.**
