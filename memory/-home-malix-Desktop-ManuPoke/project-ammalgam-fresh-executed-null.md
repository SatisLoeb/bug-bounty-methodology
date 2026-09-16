---
name: project-ammalgam-fresh-executed-null
description: "Ammalgam DLEX (Cantina $25k, ETH mainnet) — FRESH blind re-engagement, EXECUTED-NULL fortress on the live in-scope pair"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1cddd5e1-a775-4c40-bc31-1244e19cbfd8
---

**Ammalgam DLEX** — Cantina bounty ($25k Crit / $10k High, deposit $50), ETH mainnet. Oracle-free DLEX = Uniswap-V2 AMM fused with a money market on ONE reserve set; 6 tokens/pair (DEPOSIT_L/X/Y + BORROW_L/X/Y); price = pool's own geometric TWAP; novel per-tranche **saturation** model bounds leverage so liquidations stay ≤1 tranche. 7 audit firms / 4 rounds (ChainSecurity, 0xMacro, Cantina comp, Octane, Savant, Pruvendo, V12). 44 findings already submitted at launch.

**Operator ran this BLIND** ("treat as never seen, don't consult prior engagements") — there IS a prior engagement folder (`~/Desktop/ManuPoke/Ammalgam Bug Bounty` with saturation-premium + straddle-seize reports/submission) that I did NOT read. This fresh pass **independently converged on the same areas** (uncapped saturation premium, solvent-seize) and concluded them **non-payable on the live pair**.

**VERDICT = NULL-COÛTEUX / FORTRESS (executed).** Fresh source pulled from Etherscan (complete core-v1, ~10.2k lines), deep solo read of entire core + 8-subsystem adversarial-verified swarm (20 hypotheses, 19 REFUTED + 1 SUSPEND) + **7 executed mainnet-fork artifacts** vs the live USDC/WETH pair `0x728fD0A966B993fe518B00122D51e494F99aBd6a`. Registry:
1. **Swap depleted-K → DEPOSIT_L shrink**: REFUTED. DEPOSIT_L value = `sqrt(g(rX)*g(rY))` (depletion-adjusted, `g`=calculateReserveAdjustmentsForMissingAssets 19/20) = the SAME `g()` the swap K-check uses → K-passing swap never decreases LP active liquidity. Raw rX*rY can fall but LPs aren't valued on it (TokenController.sol:713-728 documents this). Genuine fortress.
2. **Over-borrow/solvency bypass**: REFUTED. Conservative wide-range solvency (deposits@low/borrows@high over long+mid+block+current tick + PriceExtremes.widen). Executed: healthy + max-LTV positions solvent.
3. **Seize-solvent**: REFUTED. Executed: all 3 liq types revert on a healthy position (HARD=NotEnoughRepaid, SAT/LEV=ZeroPremium).
4. **Saturation-liq seize (uncapped `(newSat/oldSat-1)/10` premium, wide-oldSat vs narrow-newSat domain mismatch)**: REFUTED. Executed: SAT liq reverts ZeroPremium at near-max LTV, after wide re-store, and after warp — narrow newSat never exceeds wide oldSat without a genuine sustained move.
5. **Bad-debt hard-liq over-extraction (the 1 SUSPEND, H2)**: REFUTED as payable. Reaching the bad-debt branch needs a SUSTAINED >25% (OOS) move because the LIQUIDATION price domain is deliberately bounded/lagged (±10 ticks/8s via boundTick). Executed: 80 bounded steps ≈ -99% spot needed; even then liquidator OVERPAYS vs spot (repaid 200 USDC for 44.8-USDC collateral); steady-state bonus ~1%, manip amplification ~0.5%.
6. **Interest/yield theft**: REFUTED (conservation holds; residual = dust rounding, OOS).

**Root reachability killer:** live pair `externalLiquidity = 1.186e17 ≈ 310× internal ALA` (governance/onlyFeeToSetter) → saturation mechanism largely INERT + slippage negligible. The real seams (uncapped sat premium, domain asymmetry, bad-debt bonus) are real MECHANISMS but their payable trigger needs (a) a fresh pair (external=0) with victim LPs — outside the deployed in-scope pair, or (b) an OOS >25% move. Scope requires loss-to-LPs via public fns; sub-33%up/25%down/block moves are OOS.

**Governance-gated (not attacker-reachable):** externalLiquidity, HookRegistry allowlist (owner-only → 1inch token-hooks reentrancy dead), beacon pair-modes (BeaconController), SatTWAP proxy upgrade, TimelockController.

**RE-SOURCE.** SC core = confirmed fortress. Workspace + harness reusable at `~/Desktop/ManuPoke/ammalgam-fresh` (foundry fork PoC vs live pair works; `MY-SEAMS.md`, `DOSSIER.md`). [[feedback-check-prior-audits-and-competitions-at-intake]] [[feedback-trigger-reachability-is-payability-gate]]
