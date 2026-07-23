---
name: project-onre-solana-executed-null
description: "OnRe (onre-sol) Solana reinsurance mint/redeem = near-fortress, core value-math clean + vector-jump lead REFUTED by on-chain state-read. RE-SOURCE."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

OnRe (`onre-sol`) — Immunefi $100k, Solana/Anchor, on-chain reinsurance (ONyc yield-bearing token, ~$141M TVL). Single program `onreapp` @ `onreuGhHHgVzMWSkj2oQDLDtvvGvoepBPkqyaubFcwe`. **5 audits (4× Quantstamp + Ackee), NO public contest** (Solana low-dup). Surfaced by the 2026-07-23 landscape scan, chosen over StackingDAO-stBTC for Solana turf-fit. Clone ~/Desktop/BUGS/onre-2026/onre-sol.

**Gate-first PASS (the Aurora lesson applied):** `mainnet-live` tag == HEAD on `programs/` (git diff empty → I audit the DEPLOYED code, zero forward-drift), declare_id matches the scoped address. Code stable since 2026-03.

**Core value-math = CLEAN (verified at source):**
- **ed25519 approval** (`utils/approver/`): KYC access-grant (binds program_id+user_pubkey+expiry, no price). The classic precompile OFFSET-CONFUSION forge is DEFENDED — `parse_ed25519_ix` requires sig/pubkey/msg ix_index == u16::MAX (current-ix sentinel) AND reads pubkey/msg at the SAME offsets the precompile verifies. No forge.
- **mint vs redeem inversion CORRECT**: take_offer `calculate_token_out_amount` DIVIDES by price (`in·10^(out+9)/(price·10^in)`); redeem `process_redemption_core` MULTIPLIES (`in·price·10^out/(10^in·10^9)`). Same price both ends → round-trip = ×1. Both FLOOR (÷, user-adverse) + fees CEIL (`calculate_fees` +MAX_BP−1, protocol-favorable). No extraction.
- supply-cap enforced on ONyc mint (`mint_tokens` current+amt<=max); redemption burns ONyc.
- redemption lifecycle: price computed at FULFILL (fresh, no snapshot-staleness), request PDA `close`d by both cancel & fulfill → no double-spend; fulfill = redemption_admin-gated.
- both take_offer + take_offer_permissionless call verify_offer_approval (no unguarded sibling); allow_permissionless is orthogonal opt-in.

**Primary lead (vector-jump front-run) REFUTED by executed on-chain state-read** (`fork/read_offers.py` = reusable getProgramAccounts+Anchor decoder, public RPC, no key). Deployed: 3 mint-offers (token_out=ONyc; USDC/USDT/`2u1t…` in), all `needs_approval=0` (**KYC dormant on live**), USDT-offer inactive (0 vectors). Both active offers share 3 identical vectors. Computed boundary prices: jumps = 0.00028% (Mar-19) / 0.0046% (May-02) = **CONTINUOUS, non-front-runnable** (devs calibrate each vector's base_price to the prev forward-snapped end). AND no instant ONyc→USDC (redemption is admin-throttled, no reverse offer) → both payability conditions fail.

**Token-2022 transfer-fee asymmetry** (offer path blocks fee-tokens via `has_transfer_fee`, redemption path does NOT) = real but **privileged-config only** (make_redemption_offer = boss||redemption_admin) → no unprivileged trigger → not payable [[feedback-trigger-reachability-is-payability-gate]].

**VERDICT: EXECUTED-NULL on the payable unprivileged surface, RE-SOURCE.** Core clean + primary lead executed-refuted on a 5-audit target = the darkside GATE's RE-SOURCE case (don't prove-null on saturated). Unread (lower-EV, boss-gated): mint_to/vaults/boss-2-step, take_offer_permissionless routing internals, off-chain CCTP cross-chain scripts (OOS). Pairs [[project-flare-fassets-executed-null]] [[project-loopscale-solfork-intake]] (Solana valuation nulls). ~/Desktop/BUGS/onre-2026.
