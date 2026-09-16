---
name: zest-v2-stacks-next-target
description: "Zest Protocol V2 (Stacks, Immunefi $100K) — NEXT TARGET, chosen 2026-08-02; unaudited emergency oracle swap on a $62.5M lending market"
metadata: 
  node_type: memory
  type: project
  originSessionId: e07ea929-6b1e-4339-bda9-00fe2cca4e71
  modified: 2026-08-13T10:43:09.461Z
---

**Chosen 2026-08-02 as the target after Hermetica hBTC closed null ([[hermetica-hbtc-immunefi-executed-null]]).**
Zest Protocol V2, Stacks/Clarity lending. Immunefi, max $100K, **Critical = 10% of funds affected with a $20K
FLOOR**, High $1K-$20K, **no KYC**, PoC required, **Primacy of Impact on Critical AND High** (so the un-listed
newest market is still covered). Live 2026-01-15, last updated 2026-04-27. Deployer
`SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7`. TVL $62.5M (DeFiLlama) = 12x Hermetica.

**Why ore remains despite FOUR audits** (Clarity Alliance 2025-10-22 / 12-02 / 12-19, Greybeard 2025-12-03 which
alone found 2 Crit + 4 High + 10 Med on commit f4987a8b): the audited code is **7 months and two market versions
stale**. Post-audit deploys: `v0-4-market`(+upgrade) 2026-02-26, `v0-rates` 2026-04-07, and
**`v0-5-market`(+upgrade) 2026-07-30 — deployed after two `abort_by_response` attempts.**

**It was an INCIDENT, patched unaudited under pressure.** On 2026-07-30: `freeze-all` (DAO proposal freezing
deposit/redeem/borrow/repay/accrue/flashloan on all 6 vaults) at 17:26 → `v0-5-market` at 17:35 → new flash-loan
liquidators `fll-v4`/`flh-v2` → `whitelist-fll-v4`/`dewhitelist-fll-v3` at 19:11.

**The whole v0-4 -> v0-5 diff is FOUR LINES — an stSTX oracle source swap:**
```clarity
;; v0-4:  (contract-call? 'SP4SZE...block-info-nakamoto-ststx-ratio-v2 get-ststx-ratio-v3)
;; v0-5:  (ok (contract-call? 'SP4SZE...data-stx-v1 get-stx-per-ststx))
```
Cause, verified live: **the old oracle now returns `ERR:ArithmeticUnderflow`** (`reserve-v1.total-stx −
ststxbtc-supply` underflows after StackingDAO's reserve migration). An underflow is a hard abort, so v0-4 bricked
every stSTX-collateral path. Both oracles use DENOMINATOR_6 (no decimal mismatch).

**🔴 CLOSED 2026-08-02 — NO-GO, executed null on the payable bar. $0.** Two adversarial workflow rounds + a solo
pass over the ENTIRE unaudited post-audit surface (307 changed lines / 20 hunks across 6 market impls). ~50
candidates → exactly ONE survivor: a **Medium** (cross-asset dust-sweep strands a position so bad-debt socialization
becomes permanently unreachable — `:1476-1487` denominated in THIS call's debt asset vs `:1491` seizability in the
REMAINING asset; window q ∈ [1,9855] zSTX base units; I re-derived the q=9856 threshold independently and it
reproduces). **Zest has NO Medium tier** (Critical $20K-100K / High $1K-20K only), the strand needs an exogenous
bad-debt event the attacker cannot manufacture, and the attacker profits ZERO ⇒ expected payout ≈ 0. Round 2
(registry/rates, vault share math, zToken wrapping, dev-test negative space) returned **0 Critical/High**.
**Lesson: alarming deploy hygiene ≠ a weak core.** Six unaudited deploys and three historical bugs in the first
three versions made this look like rich ore; the CURRENT code is nonetheless sound where money moves. Deployment
sloppiness is a *sourcing* signal, not a *finding* — verify the current code before valuing the target on drift alone.
RE-OPEN: a new market impl; a Medium tier appearing; StackingDAO republishing (would give F-01 a payer).

**⚠ PAYER + SCOPE FACTS THAT RE-RANKED THE THESES (2026-08-02, operator-supplied + verified):**
- **StackingDAO is NO LONGER on Immunefi** — Mateus Paderes (Immunefi) 2026-07-27: "Stacking DAO: asked to unpublish
  their program to work on an internal audit/review." They unpublished 3 days BEFORE deploying the whole new stack.
  ⇒ **p_bounty = 0 for any StackingDAO-root-cause finding.** The code carrying F-01 is exactly what their internal
  review is examining, so they will likely find it themselves.
- **Zest excludes "Incorrect data supplied by third party oracles"** (exception: "Not to exclude oracle
  manipulation/flash loan attacks"), **"Any logic related to flashloans"**, "Liquidation of disabled collateral or
  other protocol safety design decisions", "Impacts requiring ... DAO compromise". ⇒ F-01 routed at Zest is
  LITERALLY the excluded clause; only a *manipulation* framing survives, worth ~152 bps over a ~$1.58M stSTX
  collateral base ≈ $24K phantom borrow. **High dismissal risk — do not submit.**
- ⇒ F-01 = confirmed-real, unpayable. Keep as free responsible disclosure to StackingDAO; re-open if they republish.

**REAL ORE (the pivot): the UNAUDITED LIQUIDATION + BAD-DEBT-SOCIALIZATION rewrite.** All four Zest audits finished
BEFORE the first mainnet deploy (2026-01-14); five market impls shipped since, none audited; `v0-market-vault.get-impl`
= `v0-5-market`. Substantive unaudited diffs: **v0-2→v0-3 = 132 lines**, **v0-3→v0-4 = 33 lines (liquidation rewrite)**.
The v0-3→v0-4 delta adds `(coll-remaining (- user-coll-balance coll-final-raw))` (uint sub ⇒ underflow-abort blocks
liquidation), a `u1`-not-`u0` sentinel in `remaining-debt-to-repay`, and rewrites the `no-collateral-left` predicate
that GATES bad-debt socialization — the exact area of Greybeard Critical **C-2** ("socialize-debt does not decrease
total-borrowed preventing any further liquidations", marked Resolved) and **C-1** ("liquidating, debt repayment
calculated wrongly"). In-scope, untouched by the oracle/flashloan exclusions, lands on Critical (insolvency/theft).

**#1 THESIS (SUPERSEDED as a submission — kept for the mechanism) — the patch reproduced the bug class it was patching.** New formula:
`ratio = (total_stx − stx_for_ststxbtc − stx_for_withdrawals)·1e6 / (ststx_supply − pending_shares)`.
`(- ststx-supply pending-shares)` is the SAME underflow shape. If `pending_shares` ever exceeds `ststx_supply`,
`get-stx-per-ststx` aborts -> `resolve-ststx` aborts (runtime, NOT recoverable by its `unwrap!`) -> borrow, repay,
**liquidate**, collateral-add/remove all brick on stSTX = permanent freeze + insolvency (liquidations blocked).
Redemptions BURN ststx supply — so check whether burn can order ahead of a `remove-pending-shares`.
Live: supply 45,187,293 stSTX · pending-shares 1,202,447 (**2.66% of supply**) · ratio 1.197385.

**#2 THESIS — unbounded ratio.** `resolve-ststx` = `(mul-div-down p ratio STSTX-RATIO-DECIMALS)` with **NO bound,
NO sanity band, NO staleness on `ratio`** — Zest's `oracle-timestamp-fresh`/`max-staleness` guard only the
Pyth/DIA price `p`. Measured: `pending-shares` inflates stSTX collateral value by **273 bps** vs the same formula
with it zeroed. Find who can move it: `add-pending-shares`/`remove-pending-shares` gate on
`.dao check-is-protocol contract-caller` — enumerate StackingDAO's protocol contracts and hunt an
untrusted-reachable writer. This is the `save-pending-rewards` accumulator family already studied on StackingDAO.

**#3** `fll-v4`/`flh-v2` (`impl-trait .vault-traits.flash-callback`, 3 days old): authenticate `callback` — does it
verify the caller is the vault? Plus `set-operator`/`transfer-ownership`.

Workspace `~/Desktop/BUGS/hermetica-fresh/zest/` has v0-4/v0-5 market, both oracles, fll-v4, flh-v2, freeze-all.
Reuse the clarinet-3.23.1 mainnet-fork harness from [[hermetica-hbtc-immunefi-executed-null]].


**RE-CHECK 2026-08-08. Re-open trigger FIRED, gate FAILED, stays closed.** Second emergency in 8 days:
2026-08-06 `sdm1` 11:36 (pause liquidation on v0-5 + pause all vault states + revoke FLH_V2/FLL_V4
flashloan perms) then `sdm2` 15:16 (`set-impl .v0-6-market`, authorize v0-6 / de-authorize v0-5 on all
6 vaults, grant perms to FLH_V3/FLL_V5). `v0-market-vault.get-impl` now decodes to `v0-6-market`.
**The entire code delta is two identical one-line oracle-pointer swaps** (`v0-5`->`v0-6` market and
`v0-2`->`v0-3` data, both `data-stx-v1` -> `data-stx-v2`) plus new flashloan liquidators `fll-v5`/`flh-v3`.
Both classes are excluded ("Incorrect data supplied by third party oracles", "Any logic related to
flashloans"). **Zero new in-scope lines.** Program slug moved to `zest-protocol-v2`, live, **no Medium
tier** (Critical $20K-100K / High $1K-20K), no KYC, **vault $149.95**, and **last updated 2026-08-07 —
the day after the incident**, so its exclusions may have been tightened in response (the 3F question,
with a visible date this time). See [[feedback-absorbable-findings-die-regardless-of-quality]].

**The ONE un-exhausted thread, if this is ever re-opened:** the exclusion covers *incorrect data supplied
by* a third-party oracle, but the carve-out explicitly keeps *oracle manipulation* in scope. Never done:
enumerate StackingDAO's protocol contracts and hunt an untrusted-reachable writer of
`add-pending-shares`/`remove-pending-shares` (gated on `.dao check-is-protocol contract-caller`), which
feeds `get-stx-per-ststx`. `data-stx-v2` is 2 days old and its write-authorization surface has never been
enumerated by anyone. Ceiling is modest: ~152 bps over ~$1.58M stSTX collateral ~= $24K affected, and at
10%-of-funds-affected that is ~$2.4K, i.e. High not Critical.

**RE-HUNT 2026-08-13 (operator: "don't prove fortress, find vulns", away/remote-control, ultracode). The ONE
un-exhausted thread is now EXECUTED-NULL, and a 9-dimension adversarial workflow found 0 payable survivors.**
- CURRENT oracle formula (data-stx-v2, StackingDAO SP4SZE, deployed 08-06) = `(total-stx − stx-for-ststxbtc −
  stx-for-withdrawals)·1e6 / (ststx-supply − escrow)` where escrow = Σ ststx-token.get-balance over 8 fixed
  stacking-dao-core-* contracts. (NOTE: the memory-era "pending-shares" denominator is GONE; it's `escrow` now.)
- Oracle-MANIPULATION carve-out enumerated to null: every stx-reserve-v2 numerator writer is
  `.dao check-is-protocol`-gated (lines 40,88,97,111,121,130,147...); the one outsider-writable lever (transfer
  stSTX into an escrow-core to shrink active-supply, inflate ratio) is unprofitable by derivation (break-even
  needs attacker-collateral·LTV > the ENTIRE STX backing); minting stSTX moves the ratio the wrong way. So an
  untrusted actor cannot atomically move get-stx-per-ststx for profit ⇒ only "incorrect third-party data"
  (EXCLUDED) remains. Thread closed.
- Live impl confirmed = v0-6-market (get-impl 0x06...v0-6-market); NO deployer activity after 2026-08-06.
  v0-4↔v0-6 diff = exactly 2 lines (the oracle-source swap at :1016). zToken valuation + index-cache sound
  (cache keyed by {stacks-block-time,aid} ⇒ always current-block accrued lindex, re-primed post-write-down;
  freshness enforced on pyth/DIA feed). egroup LTV defensive (check-egroup-invariant: superset-mask ⇒ ≤ LTV).
- 9-agent adversarial workflow (liquidation/baddebt/ztoken/share-math/accrual/callcode-dispatch/authz/
  liquidator-callback/mirror-invariant) → 0 payable survivors. The one non-empty agent re-derived the SAME
  immaterial dust-Medium (:1476-1487 over-seizure bounded to <~1 debt base unit ≈ $0.002, hand-verified) and
  confirmed Greybeard C-2 FIXED (socialize-debt decrements total-borrowed at v0-vault-stx.clar:965).
- **VERDICT: executed NULL-COÛTEUX, 3rd independent close. RE-SOURCE.** No Medium tier, key classes excluded,
  StackingDAO unpublished (p_bounty≈0 for oracle-root), only survivor = unpayable dust. Corpus at
  ~/Desktop/BUGS/zest-v2-fresh/. Depth here is exhausted; the fix is a fresh target, not more drilling.
  RE-OPEN triggers unchanged: a NEW market impl (v0-7+), a Medium tier appearing, StackingDAO republishing.
