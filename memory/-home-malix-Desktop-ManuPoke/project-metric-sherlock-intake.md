---
name: project-metric-sherlock-intake
description: Metric DEX (Sherlock
metadata: 
  node_type: memory
  type: project
  originSessionId: 7a1cec50-aec0-40f4-9311-a86e2cb19f35
---

Metric = oracle-anchored bin-DEX, Sherlock contest #1279, $150k. Solidity/Foundry (evm_version=prague, EIP-1153 transient, CREATE3). Fork: github.com/sherlock-audit/2026-07-metric-SatisLoeb → ~/Desktop/BUGS/metric-2026/repo. 3 sub-repos: metric-core (MetricOmmPool 848 + SwapMath 390 + libs), metric-periphery (router + liquidityAdder + extensions), smart-contracts-poc (AnchoredPriceProvider 412 + oracles).

DUP GATE (mandatory [[feedback-check-prior-audits-and-competitions-at-intake]]) — 3 docs in audits/ (known-issues.pdf, zellic.pdf, collaborative.pdf, pdftotext'd):
- **OOS/KNOWN = the oracle-shock two-leg-cycle drain** ("oracle update rescales bin bounds, reserves unchanged until trade; attacker cycle s→intermediate→s extracts fair value after shock" — explicitly *not eligible*, and tiny: ~0.02% at realistic X∈[0.8,1.2]). The front-door oracle-anchored attack is DEAD.
- Mention counts: deviation 61 / drift 26 / round 59 / ceil 54 = HEAVILY swept. **band 2 / uMax 0 / solvency 0 = UNDER-audited.**

EXECUTED-FORTRESS (the sponsor-handed seam, verified NOT conceded):
AnchoredPriceProvider band clamp + SwapMath decomposition are SOUND.
- Clamp is per-edge: bidOut=min(refBid,cBid)≤refBid, askOut=max(refAsk,cAsk)≥refAsk. A curator source (never reviewed) can only WIDEN → pool-favorable. Synthetic path correctly sums per-leg spread (line 268 `spreadBps += spreadBps2`, my "dropped spread2" candidate = FALSE).
- SwapMath.midAndSpreadFeeX64FromBidAsk: mid=sqrt(bid·ask) (geometric), baseFee=ask/mid−1=sqrt(ask/bid)−1. Decomposition is EXACT: buy=mid·(1+fee)=ask, sell=mid/(1+fee)=bid. So buy@ask sell@bid regardless of band asymmetry → my "geometric-mid skew" candidate = REFUTED by algebra. Widening always pool-favorable at execution. Rounding (mid floor-sqrt, fee ceil) is pool-favorable (audits hammered round=59).
- Config underflow candidate (half=spreadBps·1e18+minMargin could exceed BPS_BASE_U if minMargin unbounded → `BPS_BASE_U−half` underflow) = likely fail-closed DoS via refBid>=refAsk guard; low-value, unverified constructor bound.

4-KERNEL DIFF (buy{0,1}InBin{In,Out}, SwapMath 360/446/532/671): rounding systematically pool-favorable EXCEPT one — `buyToken0InBinSpecifiedOut` uses `calculateBinPositionAfterSellingAmount0(…,Floor)` @L375 (swapper-favorable: floored final pos → lower avg price → undercharge while full amountOut delivered), vs its Ceil mirror `buyToken1InBinSpecifiedOut` @L461. The SpecifiedIn kernels rescale out/pos independently (L629/632, L768/771) but consistent-to-ULP + charge ≤ offered.

EXECUTED-NULL on the rounding hypothesis: built `metric-core/test/SwapConservation.invfuzz.t.sol` — asserts pre-fee input (feeExclusiveInputScaled) ≥ EXACT linear-price integral over the TRUE un-floored position ramp. **0-tolerance, 50k runs PASS** — the L375 Floor undercharge is fully absorbed by ceil-price + ceilDiv-required-token. The sponsor's "rounding always favors the pool / check it can't be amplified" HOLDS on the exact-out buy path. (Gotcha: return tuple is (finalBinPos, delta0, delta1, lpFee) — delivered token0 = -delta0 = 2nd slot.)

SOLVENCY = EXECUTED-NULL. Hand-pierced 6 sub-surfaces, all pool-favorable/consistent: (i) per-bin share rounding add=ceil L109/remove=floor L205; (ii) binTotals==Σ binState maintained (pool uses GROSS amountIn @L703 then −protocolFee @L736/744 = net, matches kernel's per-bin net); (iii) spread/protocol/admin fees held as the balance*SCALE−binTotals−notionalFee RESIDUAL that collectFees @386-388 reads; (iv) notional fee retained (recipient output reduced / swapper input increased @L750-793) + booked notionalFeeToken{0,1}; (v) scaled↔external PROVABLY safe by direction — deltasScaledToExternal @L612 SignedMath.ceilDiv both: positive input rounds UP (pool≥credited), negative output rounds toward-zero=floor-mag (pool≤debited); (vi) IncorrectDelta @L261 enforces on-chain the swapper paid; removeLiquidity NOT whenNotPaused-gated + pure share math ⇒ withdraw-when-paused works. Executed: `metric-core/test/SolvencyInvariant.invfuzz.t.sol` — 2 stateful fuzzes (spread 20k + notional 0.5% 15k runs), assert Σ binState ≤ reserves after every add/swap/remove op → PASS. Gap closed by proof not fuzz: asymmetric-decimal conversion (direction-safe by construction; base fixture is 18/18=mult 1). Don't re-audit solvency.

RESIDUAL LIVE (not yet hunted): (2) EIP-1153 transient reentrancy — NULL: the `MetricReentrancyGuardTransient.sol:20 Unreachable code` warning is BENIGN (simulateSwapAndRevert @314 ends in explicit `revert SimulateSwap` @359 → modifier epilogue unreachable; dev-aware, clears @358 before the rolling-back revert). Guard is a sound global mutex (_currentAction()!=0 blocks any guarded reentry); (3) cross-bin loop + round-trip (buy→sell) net conservation (single-bin proven, multi-bin/round-trip not). The pricing layer + the exact-out rounding = executed-fortress; don't re-audit those.
