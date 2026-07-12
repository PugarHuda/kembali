# Kembali — Deploy Checklist + Demo Script

Two scenarios to record: **(A) happy path** (merchant delivers → gets paid) and
**(B) reversal** (merchant doesn't → buyer's money comes back). ~3 minutes total.

---

## 0. Prerequisites
- **HSK for gas** in your deployer wallet (HashKey mainnet, chain 177).
- **Two MetaMask accounts**: `M` = merchant (= the deployer key), `B` = buyer/payer.
- Foundry (`forge`, `cast`) installed. From `Kembali/`.

Set shell vars:
```bash
export PK=0x<deployer_private_key>        # account M (merchant)
export M=0x<merchant_address>             # = vm.addr(PK)
export B=0x<buyer_address>                # account B (payer)
export BUYER_PK=0x<buyer_private_key>     # account B key (for the revoke helper)
export RPC=https://mainnet.hsk.xyz
```

## 1. Deploy + verify (one command)
```bash
PRIVATE_KEY=$PK PAYER=$B forge script script/Deploy.s.sol --rpc-url hashkey --broadcast --verify
```
Copy the logged addresses:
```
export K=0x<Kembali>        # Kembali
export USDC=0x<DemoUSDC>    # pay token (kUSD, 6 decimals)
export NFT=0x<DemoNFT>      # deliverable; merchant owns id 1
```
Seeded already: **B has 1000 kUSD**, **M owns demo NFT #1 and pre-approved Kembali**.
Confirm on `https://hashkey.blockscout.com` that Kembali is verified.

Open `web/index.html` in a browser. Put `$K` in the **Kembali address** field.

---

## Scenario A — Happy path (merchant delivers)
Goal: buyer pays 100 kUSD, merchant delivers NFT #1, merchant gets paid.

**As account B (buyer):**
| field | value |
|---|---|
| Kembali | `$K` |
| Merchant | `$M` |
| Pay token | `$USDC` |
| Amount | `100000000` (= 100 kUSD, 6 dec) |
| Window (sec) | `86400` |
| Deliverable asset | `$NFT` |
| Item (tokenId) | `1` |
| Kind | `0` (NFT) |

1. Click **Approve** → confirm (approves 100 kUSD).
2. Click **Open escrow** → sign the **HSP mandate** in MetaMask → confirm tx.
   → the **Payment id** field auto-fills. Copy it. Click **Read status** → `HELD`.

**Switch MetaMask to account M (merchant):**
3. Click **Merchant: approve deliverable → Kembali** (already pre-approved from deploy, but shows the step).
4. Click **Merchant: fulfill** → confirm. NFT #1 → buyer; 100 kUSD credited to merchant.
5. Click **Withdraw my credited funds** → confirm. Merchant now holds 100 kUSD.
6. **Read status** → `RELEASED`. On Blockscout: buyer owns NFT #1, merchant +100 kUSD. ✅

> Talking point: *"Atomic delivery-vs-payment, settled and verifiable on HSP — no arbiter."*

---

## Scenario B — Reversal (merchant never delivers → refund)
Goal: buyer pays, merchant goes silent, buyer reclaims after the window. Use a **short window** so
you can show it live.

**As account B (buyer):** same fields as above, but:
| field | value |
|---|---|
| Item (tokenId) | `2` (merchant does NOT own this — nothing gets delivered) |
| Window (sec) | `120` |

1. **Approve** (100 kUSD) → **Open escrow** (sign mandate) → copy the new **Payment id**.
   **Read status** → `HELD`.
2. Try **Payer: refund** now → it reverts `TOO_EARLY` (window still open). *Show this — the buyer
   can't rug the merchant mid-window.*
3. Wait ~2 minutes (the 120s window). Fill in air time with the pitch.
4. Click **Payer: refund** → confirm. Funds credited back to buyer.
5. Click **Withdraw my credited funds** → confirm. **Read status** → `REFUNDED`.
   Buyer whole again. Money *kembali*. ✅

> Talking point: *"No delivery, no payment kept — recourse that HSP alone doesn't give you."*

---

## Optional cast helpers (if you need more test assets)
```bash
# give buyer more kUSD
cast send $USDC "mint(address,uint256)" $B 1000000000 --rpc-url $RPC --private-key $PK
# mint a fresh deliverable NFT to the merchant, then read its id
cast send $NFT "mint(address)" $M --rpc-url $RPC --private-key $PK
cast call $NFT "nextId()(uint256)" --rpc-url $RPC     # = the id you just minted
# revoke a signed-but-unopened mandate (buyer changed their mind), nonce from the console
cast send $K "revoke(bytes32)" 0x<nonce> --rpc-url $RPC --private-key $BUYER_PK
```

## 🎬 Video script (scene-by-scene, ~3:15) — narration + what to show

**[0:00–0:20] Hook**
> *Show: title / problem.* "Every crypto payment is final. If the merchant doesn't deliver, your money's
> gone — no chargeback. Across this hackathon, everyone built control BEFORE the payment. Nobody built
> the way back AFTER."

**[0:20–0:45] The innovation (lead with this)**
> *Show: the flow diagram.* "Kembali isn't another escrow app — it's a new primitive: **deterministic,
> arbiter-free recourse.** Everyone else adds a trusted party to judge delivery — an AI arbiter, a human,
> an oracle. We *remove* it: for on-chain deliverables, 'delivered' is a fact the contract checks itself."

**[0:45–1:35] Scenario A — Happy path (dApp, live mainnet)**
> *Show: dApp, connect wallet.* "Live on HashKey mainnet." Mint kUSD → **Approve** → **Open escrow**
> (sign the HSP mandate in the wallet). Switch to merchant → **approve deliverable** → **fulfill** →
> **withdraw**. "Atomic delivery-vs-payment: asset to the buyer, funds to the merchant."

**[1:35–2:10] Scenario B — Reversal (the wedge)**
> New escrow, short window. Try **refund** → `TOO_EARLY` ("buyer can't rug the merchant mid-window").
> Wait → **refund** → **withdraw**. "Merchant didn't deliver — the money comes back. *Kembali.*"

**[2:10–2:45] 🤖 Agent mode (the AI × DeFi moment — don't skip)**
> Click **🤖 Agent: autonomous recourse-protected buy**. "Now the AI-meets-DeFi part. One click: an
> autonomous agent provisions funds and opens a protected purchase — no human babysitting. If the seller
> doesn't deliver, the agent reclaims its own money. **Agent commerce that can't be rugged.**"
> *(Show the log; mention it's proven live — `agent/agent-buy.mjs` ran this on mainnet.)*

**[2:45–3:15] Proof + credibility (close)**
> *Show: Blockscout tx for both flows + the agent.* "This is real — both flows and the autonomous agent,
> proven live on mainnet. Kembali computes AND verifies the **canonical HSP paymentId on-chain**,
> byte-identical to the reference SDK. 60 tests, a 512k-call invariant, and the on-chain bytecode is
> byte-identical to the audited source. **Everyone built a gate in front of the payment. We built the
> door back out — trustlessly, on HSP, with agent-safe commerce, live on HashKey Chain.**"

## Recording checklist
- [ ] Lead with the **primitive / no-arbiter** framing (not "it's an escrow").
- [ ] Scenario A: HELD → fulfill → withdraw → RELEASED, buyer holds NFT.
- [ ] Scenario B: HELD → refund reverts early → wait → refund → withdraw → REFUNDED.
- [ ] **🤖 Agent mode** clip — the AI×DeFi highlight.
- [ ] Show a Blockscout tx (open/fulfill/refund + the agent tx) — prove it's real on 177.
- [ ] Close on canonical-HSP-on-chain + 60 tests + bytecode==source.
```
