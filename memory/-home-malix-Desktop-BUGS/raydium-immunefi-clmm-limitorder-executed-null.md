---
name: raydium-immunefi-clmm-limitorder-executed-null
description: "Raydium CLMM limit_order (freshest surface, deployed 2026-07-30) = executed measured-null on theft/insolvency/freeze; cp-swap also null; residual = dynamic-fee griefing"
metadata: 
  node_type: memory
  type: project
  originSessionId: 65cd947b-0003-49aa-bdf8-b75066e6ecb7
  modified: 2026-08-12T15:17:34.211Z
---

Raydium Immunefi ($505K, 10%, min $50K, KYC-free, local-fork-only PoC). Chose CLMM (option B) after cp-swap null.

**cp-swap (CPMM, CPMMoo8L...)** — measured double-null: extract(math) every vein Gate-1-killed by reading (fees ceil, curve floor, require_gte K-backstop, min-liquidity lock, canonical Token-2022 fee, inverse-fee gross-up); power(authz) every op Anchor `address=`/signer-gated, no unguarded sibling (pool_creator written only in initialize). See [[gmtrade-gmx-solana-deployed-build-baseline]] for the "deployed = old audited commit" caution — here CLMM was the OPPOSITE (fresh).

**CLMM (raydium-amm-v3, CAMMCzo5...)** — the WIN was provenance: deployed .so (sha256 06d0e0f5, ProgramData slot 436167935 = **2026-07-30**, 13 days live) CONTAINS OpenLimitOrder/Increase/Decrease/Settle/Close + CreateDynamicFeeConfig + CreatePermissionedPool. limit_order is a NOVEL feature grafted onto V3 CLMM, post-dating any classic OtterSec audit → fresh ore, not the excluded set. git HEAD 51fdba2 (2026-07-31) ~= deployed.

**limit_order = executed MEASURED-NULL** (the G3 seam: limit_order × swap-engine × tick FIFO; escrow shares LP token_vault_0/1 so a bug = LP insolvency = Critical). Killed 3 payable classes with executed artifacts (cargo test on the real crate `raydium-clmm`, harness at `/tmp/ray-src/raydium-amm-v3/programs/amm/src/states/conservation_fuzz.rs`):
- theft/insolvency: vault-conservation fuzzer (V0>=0 token0, V1>=0 token1) on real `match_limit_order_with_sqrt_price`/`settle_filled_order`/`decrease_amount`/`increase_amount` — v1 9.6M ops + v3 directed phase-boundary 9.15M ops, all green.
- swap-integration: differential through real `swap_internal` loop (build_pool/build_tick_array_with_tick_states) — limit fill IDENTICAL to isolated match, payout ≤ swapper_paid (1-wei pool-favorable dust).
- freeze/stranding: drainability assertion (every maker fully withdrawable post-settle) — green 114.4k runs.
- authz read-tight: decrease owner-gated, settle/close pay `limit_order.owner` even under admin, order PDA `init` (no reinit), pool_id/tick cross-pool checks.

The settle math is deliberately conservative: floor output, `-1` dust deduction per segment, floor `ideal_remaining` so `Σ ideal_remaining == tick.part_filled_orders_remaining` (invariant preserved even across decrease-resets). This is why brute-force fuzzing finds no break — it's carefully built.

**dynamic_fee — QUANTIFIED then killed by the number.** The confessed liquidity==0 undercharge (swap.rs:676-678) measured on real `swap_internal`: a limit-order fill in a liquidity==0 region is charged the pre-jump rate (base only) vs the volatility-ramped rate the price move implies → the FULL dynamic component is evaded. Executed PoC (`conservation_fuzz.rs::dynamic_fee_liquidity_zero_undercharge_quantify`): **moderate config (control=0.01, realistic) = 0.36% of fill; aggressive (control=99999, max, implausible) = ~10%.** Victim = protocol fee revenue (liquidity==0 → spilt_fees routes to protocol_fee), NOT principal — the dev's "no fund-safety effect" confession HOLDS; at realistic params it IS 0.36% + fee-only → the re-derivation failed to overturn "low-impact" → Informative, not submitted. Right to run it anyway (dig-don't-concede: the number closed the candidate instead of hand-waving). **Other residual CLMM surfaces (un-probed, lower EV):** create_permissioned_pool + admin config (`address = admin::ID` gated); classic V3 tick/sqrt_price/liquidity/reward/fee-growth math (OtterSec-covered → high dup-risk). Lesson reinforced: [[feedback-audited-target-hunt-invariant-not-class]] — the fresh feature (limit_order) was the right target over the audited V3 core, and depth-where-ore-remains [[feedback-depth-is-an-edge-only-where-ore-remains]] held (drilled the fresh 13-day feature, not the picked-clean core), but the feature was genuinely well-built → honest null.
