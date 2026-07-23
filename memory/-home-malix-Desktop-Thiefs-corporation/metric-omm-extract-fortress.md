---
name: metric-omm-extract-fortress
description: "2026-07-06 /extract hunt on Sherlock Metric-OMM — math vein is a fortress, no payable Medium+; two Info deviations only."
metadata: 
  node_type: memory
  type: project
  originSessionId: 8804554e-5b13-4c68-8d89-1430a3339b18
---

Sherlock **Metric-OMM** oracle-based OMM (bin-curve DEX), $150k, commit 8171fa8, cloned to
`targets/metric-omm`. /extract math-extractible vein hunt → **FORTRESS, no submittable Medium+**.

Why fortress: rounding is uniformly POOL-favorable by design (ceilDiv input-up, floor output-down,
SignedMath.ceilDiv toward +inf). Every candidate died at extract Gate-1 (directionality) or Gate-2
(residual 1–2 internal-wei, non-accumulable; 6-dec USDC scaled 1e12 ⇒ 2 wei rounds to 0 external).

Evidence: 7 executed Foundry fuzz artifacts (`test/ExtractSolvency.t.sol`, `test/ExtractConservation.t.sol`)
— solvency (single/24-op-churn/wide-oracle-spread-to-300%), no-free-lunch, split-no-underpay,
wide-bin-100x exact-in/out consistency + absolute start-price bound, fuzzed decimals 2..18, 20k+ runs,
all green — PLUS 8 read-only FIND agents (find-workflow.js) + 1 extensions agent, all fortress/thin.

Two INFO-only deviations (not payable): (A) AnchoredPriceProvider synthetic-ratio uses additive
per-leg spreads (spreadBps+=spreadBps2) — symmetric approx of asymmetric multiplicative uncertainty,
not systematically exploitable, documented design choice. (B) OracleValueStopLossExtension uses
arithmetic mid (bid+ask)/2 vs pool's geometric sqrt(bid*ask) — but protective-only extension (reverts,
never moves value), sub-bps, fail-open side = OOS.

/power AUTHZ vein (also run) → FORTRESS + 1 ACKNOWLEDGED capability. Executed proofs
`test/PowerTimelockBypass.t.sol` on the real factory: all onlyOwner/onlyPoolAdmin gates reject
unprivileged callers; acceptPoolAdmin seizure-proof; fee caps enforced; provider/oracle role-gated +
band-bounded. The one real capability — createPool enforces NO minimum priceProviderTimelock and
_validatePriceProvider only checks token match, so timelock=0 lets the pool-admin swap to an arbitrary
price provider in the SAME block (atomic ~100% LP rug) — is **NOT submittable: Zellic p.112 documents
it** ("timelock 0 => execute immediately in same tx; configure an appropriate timelock at creation").
Lesson: dedup against the linked audit PDFs BEFORE valuing an authz finding.

/seam (data-flow trace, no-hypothesis) → fortress. Nearly wrote a false-positive HIGH: hypothesized a
1e12 decimals mispricing (oracle price not normalized), messy intermediate data seemed to confirm it,
but CLEAN observation disproved it — scaling maps 1 whole = 1e18 scaled for any <=18-dec token, so the
oracle whole-token price IS the scaled price. Lesson (operator): a hypothesis makes you read to CONFIRM
and slide past the truth; observe what the code DOES. The dust-artifact trap recurred on
/mrrobbot too (collectFees "LP got 0" was sub-external-dust, not principal theft) — VERIFY, don't dismiss.

/mrrobbot (check-matrix + mirror-invariant Door A + darkside Door C) → fortress. All 4 swap loops +
notional branches + add/remove liquidity guard-symmetric (asymmetries design-justified); Door C's four
by-construction invariants (binTotals==Σbins, surplus==fee, shares pro-rata, cursor) all hold; executed
testFuzz_collectFees_neverEatsPrincipal (2000 runs). 17 executed artifacts total, all green.

OOS known issue: oracle-shock two-leg cycle drain (≤ half bin's relative price width). Do NOT restate.
Full writeup: `recon-metric/VERDICT.md`, dedup brief `recon-metric/DEDUP-BRIEF.md`.
Residual non-math surfaces if revisiting: deploy/CREATE3 atomicity (M-2 sibling), compressed-oracle
pusher/namespace (Zellic area, likely OOS), HyperEVM EIP-1153 specifics. Related: [[rheo-size-fork-fortress]].
