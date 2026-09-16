---
name: reffinance-boostfarming-shadow-seam-null
description: "Ref Finance (Immunefi $250k, NEAR AMM) — boost-farming vein + shadow cross-contract seam executed NULL-COÛTEUX; fortress signals; re-source"
metadata: 
  node_type: memory
  type: project
  originSessionId: 2dbf9b9a-dfca-471f-893b-f499932d156b
  modified: 2026-08-15T15:22:24.579Z
---

Ref Finance / Rhea (Immunefi, NEAR, Primacy-of-Rules, max $250k Crit=10%-of-funds min $50k, High $30k, Med $5k, **$99.9k paid in 4+ yr = fortress fingerprint**, no submission fee). TVL ~$31-40M. Scope = 2022 module set of **ref-exchange (v2.ref-finance.near v1.9.20)** + **boost-farm (boostfarm.ref-labs.near v0.5.0)**. OOS audit = jita/Rousselot **Dec-2021 commit 3c04fd2**, x*y=k only, ZERO real bugs, predates boost-farming entirely → OOS tombstone nearly empty.

**Recevability wrinkles:** scoped repos `ref-finance/ref-contracts` + `ref-finance/boost-farm` both now **404 (deleted under Rhea rebrand)**; deployed 1.9.20/0.5.0 drifted past the listed 2022 files; `shadow_actions.rs`, `rated_swap`, `unit_lpt_cumulative_infos.rs` NOT in the listed file set → OOS. Source recovered via forks: exchange 1.9.17 = `chain-rider503z/ref-contracts`; boost-farm 0.5.0 = `Yakhil-cmd/boost-farm-007` (master); 0.3.x = `marco-sundsk/boost-farm` + `cb-defi-notifs/ref-finance-boost-farm-98615845`.

**Operator picked boost-farming vein. Executed source-trace (0.3.0/0.3.2/0.5.0 + exchange shadow) = NULL-COÛTEUX:**
- Reward core (MasterChef rps + f64 booster + settle-first) is audit-firm-grade: **claim-before-modify-power on EVERY path** (stake/unstake/lock/shadow/update_impacted_seeds); `total_seed_power` delta-maintained & consistent; big_decimal 27-dec floor rounding → dust stays in-contract, not stealable.
- 0.5.0 fresh surface = **shadow cross-contract seam** (exchange↔farming, the "composition nobody owns", post-dates all audits). `on_cast_shadow/on_remove_shadow` trust exchange's `amount`, but exchange enforces the invariant: `free_shares(total)=total-max(shadow_in_farm,shadow_in_burrow)`, checked on **mft_transfer (multi_fungible_token.rs), remove_liquidity + remove_liquidity_by_tokens (lib.rs:491/534)** — all in-scope, all present, correct. Casting capped at total → `shadow ≤ total` preserved. No double-spend of LP shares.
- Deployed config NEUTERS two surfaces: `max_locking_duration_sec:1` (lock-boost off), boost heavily suppressed (`boost_suppress_factor`, huge log_base → ~0 effective boost).

**One noted-but-OOS seam:** `get_unit_lpt_assets` LP-share TWAP (`unit_lpt_cumulative_infos.rs`) prices LP collateral for **burrowland** — manipulation would misprice burrow collateral, but impact lands on burrow (OOS) + file not listed + exchange swaps use spot reserves not this TWAP. No in-scope impact.

**Exchange-core vein (operator's 2nd pick) — also executed NULL:** stable_swap `math.rs` (in-scope, shared by rated/degen) = standard Saber/Curve port w/ `[AUDIT_06/07/08]` markers; `swap_to` uses pool-favorable `dy=out-y-1`. `mod.rs` precision (`amount_to_c_amount`/`c_amount_to_amount` around TARGET_DECIMAL) + swap + remove_by_shares (double-floor) + remove_by_tokens/add (normalized_trade_fee both ways) all round pool-favorable → no per-swap or add/remove round-trip extraction. simple_pool x*y=k even more saturated. Only marginal residual = rated_swap rate-scaling (OOS file) + intra-block rate manip (external-oracle, mostly OOS).

**POSTURE CORRECTION (operator, mid-hunt):** I had slid into fortress-prover — reading each path, finding a guard, narrating "as expected null", PRE-declaring the verdict before executing. Predicting "executed-null" = seeking to confirm the wall. Flipped to EXECUTED disconfirmers:
- **Stable exchange harness** (`scratchpad/stableharness`): copies math.rs + mod.rs VERBATIM; self-contained wallet PnL fuzz. **405,100 checks, 0 extraction** across amp/fee/decimals. Caught + fixed TWO biased assertions in my OWN harness (per-token vs value; pre-imbalanced-arb vs self-contained) = disconfirmer-must-not-be-biased in action. Value conserved vs all self-financed attacker sequences.
- **Boost-farm harness** (`scratchpad/bfharness`): faithful transcription of rps floor-math + f64 boost + settle-first telescoping. **14,244,726 checks, 0 failures** over 300k adversarial multi-farmer sequences (INV1 total_seed_power==Σget_seed_power; INV2 Σclaimed≤distributed; f64 boost active ~log2).

**FINAL VERDICT: Ref Finance = EXECUTED fortress-NULL across both directed veins.** Not affirmed — 14.6M+ executed checks, 0 breaks; plus source-trace of shadow (free_shares enforced on all in-scope burn/transfer) + adversarial algebra on on_burrow_liquidation (invariant preserved). **Residual gap (honest):** near-sdk-sim on the REAL deployed wasm NOT run (disk-wedge risk); stable harness IS the real math verbatim, but boost-farm harness is my transcription — a contract PATH I misread (sync_booster_policy ordering, shadow-callback edge, seeds/vseeds dual-map migration) wouldn't be caught by it. To fully close: sim `boost_farming_release.wasm`+`ref_exchange_release_v1912.wasm` with adversarial conservation asserts. RE-SOURCE off-target regardless ($99.9k/4yr). Composition: /firmaudit Phase-0 + xseam + standalone-fuzz. See [[feedback-default-posture-thief-not-fortress-prover]], [[feedback-closure-bias-expand-voies-hunt-seams]], [[depth-is-an-edge-only-where-ore-remains]].
