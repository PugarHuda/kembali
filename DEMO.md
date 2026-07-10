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

## Recording checklist
- [ ] Kembali verified on Blockscout (green checkmark) — shows on screen.
- [ ] Scenario A: HELD → fulfill → withdraw → RELEASED, buyer holds NFT.
- [ ] Scenario B: HELD → refund reverts early → wait → refund → withdraw → REFUNDED.
- [ ] Show one tx on Blockscout (the `Opened`/`Released` event) to prove it's real on 177.
- [ ] 30-sec close: the empty lane (post-payment recourse) vs the 27 other submissions.
```
