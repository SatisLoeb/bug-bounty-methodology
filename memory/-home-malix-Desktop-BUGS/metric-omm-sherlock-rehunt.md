---
name: metric-omm-sherlock-rehunt
description: "Metric OMM (Sherlock live contest, oracle-anchored bin AMM) — thief re-hunt CONFIRMED a real 99.99% drain (F-2) but it is a DESIGNATED known-issue (OOS); full in-scope surface swept to earned EXECUTED fortress-null; re-source"
metadata: 
  node_type: memory
  type: project
  originSessionId: ba696e08-08e4-43a2-af5d-28fd94a8b6dd
---

Metric OMM — Sherlock audit contest (audits.sherlock.xyz/contests/1279), LIVE Jul 6→27 2026. Oracle-anchored bin AMM (price from external Pyth/Chainlink provider, not reserves); 3 chains (Eth/Base/HyperEVM). Pool High=61K / Critical=121K. 3 audits (Zellic + collaborative + known-issues doc), ALL designated by README L64-67 as "known issues / acceptable risks" → OOS. Workspace `~/Desktop/BUGS/metric-sherlock/` (HUNT-STATE-thief-rehunt.md has the full executed trace).

**Re-hunt in thief posture ([[feedback-default-posture-thief-not-fortress-prover]]) — the process worked, the target held.** My FIRST verdict on this target was a WRONG fortress-null (dismissed on "no value now"). The thief re-frame correctly PRODUCED a real exploit — then honest primary-source verification killed it as OOS. Both failure modes avoided (no fortress-reflex, no over-claim).

**F-2 (my strongest, PoC-green, then KILLED): `priceProviderTimelock` zero-floor → same-block provider swap → 99.99% LP drain.** `createPool` L213 accepts timelock=0 (no floor); `executeAfter=block.timestamp+0`, guard `block.timestamp<execAfter` = `X<X`=false → propose+execute same block → swap price source to attacker provider → drain. PoC `zzz_F2_DrainDelta.t.sol` PASSED (victim −99.99%, baseline timelock>0 blocks it). **BUT OUT OF SCOPE:** Zellic report (README-designated known-issues) documents it — Zellic L5008 "priceProviderTimelock ... No on-chain lower bound" + inline note "if timelock is 0, executable in the same transaction." Also honest-victim weak (timelock public+immutable) + team M-9 acknowledged-wontfix precedent (permissionless-misconfig = feature). Dropped, not submitted.

**Full in-scope surface = EARNED EXECUTED fortress-null** (2 workflows, 10 veins + solo reads, each executed/code-cited):
- swap-math rounding monotonically pool-protective (input ceil/output floor/avg ceil); M-3 fixed PR#58.
- NO drift/velocity guard in core (refactored out; AuditFindings M02/M03 describe absent code); velocity guard = optional periphery extension, default OFF, "admin must be trusted." Half-bin-width OOS cap is GEOMETRIC not rate-based → its absence doesn't widen it.
- bin loops bounded (L02 distance-domain [-999999,999999] + M04 guards); rounding surplus `balance·mult−binTotals≥0` swept to admin (kills decimals-mismatch).
- AnchoredPriceProvider band-clamp one-directional (source can only WIDEN); geomean mid CANCELS in execution price = f(bid,ask) only → asymmetric widening can't make a cheap buy/dear sell (LP-protective or fail-closed). Governance owner-gated, no permissionless source swap.
- reentrancy guard GLOBAL-effective (single transient slot) → no cross-action reentry.
- router/adder: payer=msg.sender pinned in transient at entry + pool's post-callback `IncorrectDelta` receipt check → untrusted caller only pulls from themselves; M-1/M-2/H-1 fixed, residues = L-10/self-harm.
- extensions: NO shipped extension gates removeLiquidity → honest LP always withdraws; selectors checked; order-packing sound.
- composition seam (4 handoffs) each enforces the invariant the other assumes.
- ONE live incomplete-fix: exact-INPUT functions lack the Zellic-3.4 zero-guard (Zellic asked to verify them; devs didn't) → free cursor advance is REAL but NON-extractable (needs dust bin; ~1e12 calls on real liquidity) = Zellic's own Low "no profitable exploit" = OOS restatement.

**Verdict: NO-GO / earned executed fortress-null.** 3-audit fortress + heavy known-issues designation = the fresh-delta ore is mined; per [[feedback-depth-is-an-edge-only-where-ore-remains]] + [[feedback-target-diet-is-the-binding-constraint]], re-source (fresh-funded / off-chain-seam / crypto-primitive), do not drill deeper. **Re-open triggers:** new commit to in-scope code; a periphery entry that sets payer≠msg.sender; an in-scope token with a transfer hook wired to a pool; the periphery beginning to custody funds across txs.
