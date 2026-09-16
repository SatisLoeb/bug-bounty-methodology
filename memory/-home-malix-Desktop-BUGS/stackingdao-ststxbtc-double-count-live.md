---
name: stackingdao-ststxbtc-double-count-live
description: "StackingDAO (Immunefi) ststxbtc-tracking-v2 double-count + reserve-DoS — CONFIRMED live, PoC reconstructed & passing, gate cleared, ready to draft/submit"
metadata: 
  node_type: memory
  type: project
  originSessionId: f1a1c109-bacb-4d9a-86f8-2aa9c53f2da9
  modified: 2026-08-15T03:29:15.114Z
---

**StackingDAO** (Stacks liquid staking, Immunefi, max $100K). Finding on `ststxbtc-tracking-v2` + `ststxbtc-tracking-data-v2` (both in-scope, added 13 Aug 2026). **Never submitted** — the program was pulled for an audit and relaunched 13 Aug 2026; I re-verify from the report `.md` (the only artifact that survived; original Clarinet PoC was lost and is now rebuilt).

**Two legs, one root** (stale external-position tracking):
- **Theft/insolvency**: deposit X into a supported Zest position → `refresh-position` → withdraw X WITHOUT re-refreshing → wallet `{A,A}`=X (fresh via token hook) AND Zest `{A,position}`=X (stale) both accrue; denominator = `get-total-supply` (= `ft-get-supply`, excludes the phantom) so Σclaimable > sBTC held → drains the pool.
- **Reserve-DoS**: the stale withdrawal makes tracked total > reserve; honest depositors' increasing `refresh-position` then reverts `ERR_OVER_RESERVE` (u10002003). Empirically fired **at least 32×** on mainnet (VERIFIED scan back to 2026-03-04: 32 events, **24 distinct holders**, 8 Mar–24 Jul 2026, BOTH position-zest-v6 AND -v2, 7 holders hit >1× = keeper double-fails). Earlier "20×/18 holders/1 May" was an under-scanned undercount — use the 32/24 floors.

**Survival = GUARANTEED** (not just confirmed): Clarity is immutable + no `-v3` deployed (404 on tracking-v3/data-v3/token-v3) → the code can't have been patched. Facts 2/3/4/5 verbatim on deployed bytecode (sha256 `1bf94011…`, publish_height 1491256). See [[feedback-verify-before-working-no-theater]].

**Reachability = 100% live**: a redesigned `ststxbtc-tracking-v1` (removes the position model = the fix) exists but is **dormant (new `ststxbtc-token` supply = 0)**; `rewards-v8` L274 still feeds `ststxbtc-tracking-v2 add-rewards` 100% each cycle (last 2026-08-12). Drainable sBTC pool = **1.2826 BTC ≈ $147K**, growing. Claims enabled.

**Gate 4 (all 5 public audits) = CLEAR.** My finding is NOT an "unfixed vulnerability mentioned" in any report. Best dedup framing = **incomplete-fix of M-02 + M-04** (BTC-Yielding-LST, Jan 2025, both Resolved): M-02's reserve-guard fix only tests the INCREASE side (my DoS uses the decrease/withdrawal side); M-04's `deactivated-cumm-reward` fix only covers DEACTIVATED positions (mine is an ACTIVE position). C-01 (Upgrade, Jun 2025, Resolved) = arithmetic self-add, different mechanism, my dual-key double survives it. QA-07/L-02 = Acknowledged but not my finding (deactivation under-earn / reserve-arg validation). PoX-5 (12 Aug 2026, relaunch audit) = all on new v1 contracts, 0 mechanism hits.

**SUBMISSION FEE (corrected 2026-08-15)**: StackingDAO now charges a **50 USDC (Ethereum) NON-REFUNDABLE submission fee** — a platform-level Immunefi fee (not the project's), NEW since relaunch. It is NOT shown on the public Information page; it only appears in the authenticated submit flow (`bugs.immunefi.com/dashboard/new-submission`) at the Review stage, paid from the verified wallet. My Phase-0 "free slot model" was WRONG for this program. Still +EV: 50 USDC vs $20K Critical floor is a rounding error; the fee just enforces "submit only high-signal" (this is) and thins the dup queue. Lesson: the public page fee-absence ≠ no fee; the real fee lives behind login. See [[feedback-openapi-is-not-the-full-api-surface]] (same shape: public surface understates the real one).

**EV caveats**: (1) vault funded only **$2,799** (guaranteed-liquid escrow tiny vs $100K max; team pays rest directly — p_bounty MODERATE not zero, engaged sponsor). (2) realistic tier = High "theft of unclaimed yield" ~$15K (10% of pool), argue toward Critical insolvency ($20K min). (3) migration to v1 will eventually cut over → **submit fast**. (4) dedup dismissal risk MODERATE (M-02/M-04/C-01 pattern-match) — lead with incomplete-fix framing.

**Artifacts** (persisted, scratchpad is ephemeral): `~/Desktop/BUGS/stackingdao-pocs/` — `REPORT.md`, `stbtc-double-count-poc_test.ts` (4/4 passing, real contracts + honest baseline + disconfirmer + control/attack), `scripts/verify-onchain.sh` (self-contained curl/python live verifier), `submissions/SCREENSHOTS-GUIDE.md` (5 captures), `deployed-contracts/` snapshots. **Secret gist (SatisLoeb, linked in report's PoC section, clean-room-verified reproduces from it): https://gist.github.com/SatisLoeb/a4d7d97c4a3007e18ea59d857236d65d** (README + PoC + verify-onchain.sh). DoS numbers use conservative floors ("at least 32 / at least 24 distinct, most recently 24 July 2026"); verify-onchain.sh over-delivers 35/26 so a triager re-run confirms. Repo clone `StackingDAO/contracts` HEAD `a8d7d2a`, Clarinet 3.6.0 project runs (needs `npm i @rollup/rollup-linux-x64-gnu --no-save`). Related: [[feedback-audit-acknowledgment-is-a-liability-not-an-asset]], [[feedback-an-oos-bullet-describing-your-finding-is-its-tombstone]], [[ev-gate-check-program-responsiveness-not-just-severity]].

**Severity play (locked)**: primary **Critical Protocol-insolvency** (structural via fact 4 — the theft row is capped at High by the program carve-out "other than unclaimed yield", so insolvency is the ONLY Critical door; PoC LEG1 proves `Σ obligations > pool assets` BEFORE any claim, deficit == phantom); floor **High Theft-of-unclaimed-yield** (verbatim, concede gracefully if reviewer holds the yield-cap); DoS+20× as corroboration only, NOT a third tier.

**STATUS 2026-08-15: SUBMITTED — Immunefi report #88777** (StackingDAO), asset `ststxbtc-tracking-v2`, impact **Protocol insolvency** (Critical), title "Double-counted sBTC rewards from stale supported-position accounting in ststxbtc-tracking-v2 leads to reward-pool insolvency". 50 USDC fee paid. Awaiting triage (project-triaged program; ~48h to confirm receipt, ~336h to resolve for Critical; no KYC required). Report+PoC+gist all finalized & internally consistent (all DoS numbers = conservative floors "at least 32 / at least 24 / seven", "these events" not a naked count; verify-onchain.sh over-delivers 35/26). **HOLD discipline**: don't poke the thread; don't share gist URL anywhere but the submission until patched; if down-scoped to High, insolvency framing is pre-empted in body — concede to $20K Critical floor only if their yield-cap argument holds; never close a dispute the instant they concede ([[injective-cantina-web-bounty-rugpull-signal]]). Pipeline: 1/4 Reported.

---

## SECOND-PASS HUNT REGISTER — 2026-08-15: STACKINGDAO FROZEN = **WATCH** (nullguard-audité)

After #88777, ran a full second pass for a 2nd live finding. Verdict = **NON-CONCLUANT → WATCH**, NOT "fortress" (nullguard fired on a premature fortress-claim and forced this discipline). Register so we never re-hunt the fresh core:

**EXECUTED-NULL veins (read the dispositive body / proven by algebra — NOT inferred):**
- rewards-v8 dual-supply split → conserves exactly (`v2 = protocol − v1`), div0+zero-amount guarded, idempotent
- C-04 stale-ratio → FIXED at all 9 sites (deposit/init-withdraw/withdraw-idle × stSTX/stBTC/ststxbtc call process-rewards before ratio read)
- C-06 double-reservation → FIXED (escrow-based `get-stx-for-ststxbtc = supply−escrow`, separated withdrawal buckets)
- swap-ststx-ststxbtc-v4 → conservation proven by ALGEBRA (ststx ratio unchanged), round-up/down conservative, min-out
- rewards-stx-v2 / rewards-pox5-v1 → H-02 FIXED (add-rewards keeper-only, window-fold keeper-gated)
- native-pool (C-01/02/05/07) → redesigned: signer pinned to native-pool-sm, local tracker removed, rewards via pox-5, validate-stake! allowlist-gated
- **GATE PIERCED (was inferred): pox-5::claim-staker-rewards-for-signer** L2452 `map-set unclaimed→u0`+settle → 2nd claim earned=0 → native-pool `(> earned u0)` reverts → NO double-claim; pox-5 has validate-no-reentrancy
- stBTC first-depositor → dead-shares DILUTE (data-stbtc-v1 uses `pending-shares`, NOT escrow-cores) → H-01 fix holds; C-03 also fixed (both sides excluded during cooldown)
- dao (access-control root) → admin-gated, no self-register; ststx-token mint/burn protocol-gated, **no tracking hooks (ratio-based) → no double-count analog**

**Guard-layer (nullguard 2bis)**: Clarity `try!`/`asserts!` ABORT the tx — no Go/JS fail-open fall-through is expressible, so a grepped `(try! check-is-protocol)` genuinely gates. Bodies read in full: dao, cores, native-pool, signer-managers, staker, pox-5-claim. **UNAUDITED-debt (grepped-only)**: strategy perform-*, reward-split-calculator, commission-sbtc-v1, data setters (low-risk given Clarity abort). **NON-EXECUTED debt**: no fork-PoC disconfirmer on deposit/withdraw (algebra covers all-inputs conservation, but not a strict fork-null).

**UN-TOUCHED = latent, PRE-LAUNCH (0 supply)**: stbtc-token, stbtc-reserve, data-pools-stbtc-v1, stbtc-staker-bond-1-v2, stbtc-withdraw-nft, withdraw-data-stbtc, new ststxbtc-token/ststxbtc-tracking-v1, native-pool custody. Fire-when-funded.

**WATCH TRIGGER**: re-hunt when `stbtc-token` OR new `ststxbtc-token` (no -v2) `get-total-supply > 0`, OR any new `-v3` deploy / new scope asset. Hunt files: `~/Desktop/BUGS/stackingdao-pocs/hunt/`.

**RE-SOURCE citation (nullguard 2.1)**: fresh archi = HIGH saturation (5 audits CA×4+CoinFabrik, top-tier, fresh-fixed, adversarial dev-tests); the only live finding (#88777) came from the OLD non-re-audited exception (tracking-v2), not the fresh core → depth on the fresh core does NOT pay ([[feedback-depth-is-an-edge-only-where-ore-remains]]). Lesson: I twice over-claimed "fortress" on a partial read; nullguard requires a cited artifact or executed-null per vein, not a feeling ([[feedback-default-posture-thief-not-fortress-prover]]).
