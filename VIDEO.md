# 🎬 Kembali — Demo + Pitch (combined), with natural VO + subtitles

> **Rendered capture:** [`media/kembali-demo.mp4`](media/kembali-demo.mp4) — a ~3-min silent screen
> recording of the **live** dApp doing **real mainnet-177 transactions** (connect → fulfill/atomic-DvP
> → reversal + TOO_EARLY guard → agent buy), with **captions burned in**. Regenerate anytime:
> `cd frontend && npm run demo` (Playwright drives the live site and records to `demo/output/`).
> Add the voice-over below (record it, or TTS the VO lines) and you have the full submission video.

One video (~4:40) that **explains every feature and demos it live**. Pitch-deck narrative and the
live dApp walkthrough are merged: talk while you click. Subtitles ship in **`subtitles.srt`** — drop
that file into YouTube (or burn it in) and it lines up with the VO below.

**How to record:** screen-record `https://kembali-hsp.vercel.app` (landing → `/app`) and, for the
pitch beats, `/pitch`. Two MetaMask accounts: **B** = buyer/payer, **M** = merchant. Speak at ~85% of
your normal speed — one breath per line. Clarity beats polish.

The VO is written to sound **spoken, not read** — contractions, short sentences, a human cadence.
Say it in your own accent; don't enunciate like a robot. Pauses are marked `…`.

---

## Section 1 — The problem (0:00–0:22)
**VO:**
> "Stablecoin payments have one problem nobody talks about — they're final. You pay… and if the
> merchant never delivers, that's it. No chargeback, no recourse, your money's just gone. That's the
> wall between crypto and real commerce."

**On screen:** landing hero (`/` — the "Payments that can come back." headline), slow scroll.

---

## Section 2 — The gap (0:22–0:42)
**VO:**
> "HSP fixed settlement — it made payments verifiable and final. Great for trust… but finality is
> exactly what scares buyers off. Look around this hackathon: everyone adds control *before* money
> moves — approvals, KYC, spend limits. Nobody gives you a way back *after*. That's the lane Kembali
> owns."

**On screen:** `/pitch` slides 2–3 (problem / the empty lane).

---

## Section 3 — The primitive (0:42–1:08)
**VO:**
> "And Kembali isn't just another escrow app — it's a new primitive. Deterministic, arbiter-free
> recourse. Every other escrow needs *someone* to judge whether delivery happened — an oracle, a
> human, an AI arbiter, a bond game. We removed all of it. Because the deliverable lives on-chain,
> 'delivered' isn't an opinion — it's a fact the contract checks itself. Your payment sits in escrow,
> bound to an on-chain deliverable and a deadline. Merchant delivers the exact asset — atomic swap,
> funds released. Merchant doesn't — after the deadline, your money comes back. *Kembali.*"

**On screen:** `/pitch` innovation slide + the flow diagram (OPEN → HELD → FULFILL/REFUND).

---

## Section 4 — LIVE: Fulfill / atomic DvP (1:08–2:00)
**VO:**
> "Let me show you — all of this is live on HashKey mainnet, real transactions. First the happy path:
> an atomic delivery-versus-payment. The buyer opens an escrow — one click approves the stablecoin,
> the next signs an EIP-712 HSP mandate right in the wallet. That signature's digest *is* the payment
> ID. Funds are now held on-chain. Now I switch to the merchant's wallet — approve the deliverable,
> hit Fulfill… and in a single transaction the asset goes to the buyer and the funds release to the
> merchant. No middleman ever touched it. Merchant withdraws, and the status reads RELEASED."

**On screen:** `/app` → connect **B** → Faucet (mint kUSD) → Open (Approve, then Open Escrow → sign in
MetaMask) → status **HELD** → **Disconnect/Reconnect as M** → Settle → Approve Deliverable → Fulfill →
status **RELEASED** → Withdraw. (Tip: open a Blockscout tx in a tab to flash "real, on 177.")

---

## Section 5 — LIVE: Reversal + the on-chain guard (2:00–2:40)
**VO:**
> "Now the part that actually matters — what if the merchant never delivers? Fresh escrow, short
> window. Watch: if the buyer tries to refund *right now*, it reverts — TOO_EARLY. The buyer can't rug
> the merchant mid-window; the deadline's enforced on-chain. We let the window pass… and now refund
> goes through. Buyer withdraws — status REFUNDED. The money came back. That's the recourse HSP alone
> doesn't give you."

**On screen:** `/app` Open with **Window = 120** → HELD → click **Refund** (show the `TOO_EARLY` error
toast) → wait out the countdown → **Refund** → **REFUNDED** → Withdraw.

---

## Section 6 — Agent / relayer-safe (2:40–3:12)
**VO:**
> "Next — agent-safe commerce. This is the AI-meets-DeFi piece. The escrow always pulls funds from
> whoever *signed* the mandate — never from whoever *submits* it. So an autonomous agent, or a relayer,
> can place a buy on your behalf and still can't redirect a single cent. We proved it live: one wallet
> signs, a completely different agent wallet submits the transaction, and the funds come out of the
> signer. The agent pays gas and nothing else. An agent literally cannot rug you."

**On screen:** `/app` Agent view → "Run Agent Buy" (mint→approve→open in one click → HELD). Optionally
flash the relayer proof: Blockscout tx where `escrow.payer == principal` but the sender is a different
address.

---

## Section 7 — Compliant + reversible, ON-CHAIN (3:12–3:44)
**VO:**
> "And for regulated settlement — which is HashKey's whole thesis — compliance is enforced on-chain.
> CompliantEscrow checks the buyer's KYC and sanctions attestations in an on-chain registry — a hard
> require — before the escrow can even open. No attestation, the transaction reverts. It's not a
> checkbox in some backend; it's the EVM saying no. Compliant *and* reversible, both on-chain."

**On screen:** `/pitch` compliance slide, or Blockscout for `CompliantEscrow`
`0xf942DF0a93E7B50987040E72Eb8Db07A35d7a9F3` — show a reverted `NOT_COMPLIANT` call, then the
successful `openCompliant`.

---

## Section 8 — Technical depth (3:44–4:18)
**VO:**
> "Under all of this is audit-grade engineering. Seventy-two tests plus a stateful invariant that runs
> half a million random operations and proves the money can never leak. Fifteen end-to-end tests drive
> this live dApp with real mainnet transactions. The canonical HSP payment ID is hashed and verified
> on-chain, matching the reference SDK. And the deployed bytecode is a byte-for-byte match to the
> audited source — we checked. Nothing here is a mock."

**On screen:** terminal `forge test` summary (72 passed) + the 512k invariant line; then the Playwright
`15 passed` run; then the bytecode-diff "EXACT MATCH" output.

---

## Section 9 — Close (4:18–4:40)
**VO:**
> "So that's Kembali. Everyone else in this room built a gate in front of the payment. We built the
> door back out — trustlessly, HSP-native, live on HashKey Chain. Payments that can come back."

**On screen:** back to the landing hero; end card with the four live contract addresses.

---

### Live contracts to flash on the end card (mainnet 177)
```
Kembali                 0xDea6Da93265871d828B20cace2BADd5F5e70209d
CompliantEscrow         0xf942DF0a93E7B50987040E72Eb8Db07A35d7a9F3
HSPCanonical            0x6B99B00BD52Bc134D5658745E64DF1938592e468
HSPAttestationRegistry  0xda0cEB552af13f5a096D8aA4E5A9FceB9cf6D8D0
```

### Recording checklist
- 1080p, ~4:40. OBS / QuickTime. Mic close, room quiet.
- Have both flows *pre-warmed* (buyer already has kUSD) so no dead air waiting on faucet txs — except
  the 120s reversal wait, which you fill with the Section 6–7 talking points.
- Upload to YouTube (unlisted is fine), attach `subtitles.srt` as the caption track, paste the link
  into the BUIDL "Demo video" field.
