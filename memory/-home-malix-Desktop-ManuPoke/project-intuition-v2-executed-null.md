---
name: project-intuition-v2-executed-null
description: "Intuition MultiVault V2 (Immunefi $100k, ERC1155x4626 + bonding curves on Base) — EXECUTED-NULL fortress on the CRITICAL-only bar. Curve math conservation-proofed (hand + 8-finder), emissions caps hold, residual = Diligence dup. RE-SOURCE."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7156c583-7af7-4e92-807a-9f2dd26bbf35
---

# Intuition MultiVault V2 — executed-NULL fortress (Critical-only bar)

**Program:** Immunefi (immunefi.com/bug-bounty/intuition), repo github.com/0xIntuition/intuition-contracts-v2
@HEAD 94bddae (9333 SLOC). Deployed on Base: MultiVault 0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e,
BondingCurveRegistry, LinearCurve (default curveId=1), OffsetProgressiveCurve (curveId=2, SLOPE=1e17/OFFSET=3e19),
TrustBonding, SatelliteEmissionsController, AtomWalletFactory. Workspace ~/Desktop/BUGS/intuition-2026.
**Reward = CRITICAL-only pays ($100k = theft/freeze/vault-or-emissions accounting corruption); High=$5k, Med=$2.5k.**
Negative space: 2× Consensys Diligence (in-repo audits/*.pdf, 15+14pp, EMISSIONS-focused; Major = eligibleRewards
epoch-calc + §5.2 utilization-rollover) + Code4rena Mar-2026 ($17.5k) + mitigation review + Trail of Bits.
Prior-audit findings OOS; MetaLayer bridge + third-party = OOS.

## Verdict: NULL on the Critical bar (hand-analysis + 8-finder executed hunt agree)
- **Curve math clean (my own read of OffsetProgressiveCurve + confirmed by finders):** price=SLOPE·(shares+OFFSET),
  pure fn of totalShares. Rounding textbook-protocol-favorable everywhere (deposit convertToShares DOWN, redeem
  convertToAssets DOWN, previewMint UP, previewWithdraw UP). Deposit a → immediate redeem returns exactly a in real
  math, LOSES dust w/ rounding → NO round-trip extract. First-depositor inflation killed TWICE: OFFSET baseline
  (price≠0 at 0 shares) + minShare DEAD-SHARES burned on every atom/triple creation.
- **Conservation invariant holds:** totalAssets ≥ curve-area(totalShares) preserved across deposit/redeem/fee/
  donation → _updateVaultOnRedeem `totalAssets-assets` can't underflow (no freeze). Each (termId,curveId) is a
  fully-isolated VaultState {totalAssets,totalShares,balanceOf} (MultiVault.sol:61) → no cross-curve corruption.
- **Emissions/TrustBonding tight:** single-claim-per-epoch, only prevEpoch claimable, per-user ratio≤1e4 (only
  scales DOWN, no over-claim), hard aggregate budget cap totalClaimed≤_emissionsForEpoch≤maxEpochEmissions, Base
  double-mint guarded, Satellite claimed+reclaim=max=funded (per-epoch balanced), transfer CONTROLLER_ROLE-gated,
  veTRUST snapshots use fixed binary-search (retroactive-inflation patched).
- **AtomWallet (4337):** 2-step Ownable + isController, ownership bound to atom, angles pierced → fortress. Fee-claim
  + MigrationMode role/owner-gated (OOS).
- **Only residual:** system-utilization rollover sourcing only from E-1 (bounded, non-attacker-forceable) = DECISIVE
  DUP of Diligence Report-2 §5.2 "Inaccurate Utilization Calculation and Rollover Issues" (Major) → OOS.

## Session pattern (the real lesson)
Multi-audited LIVE bounties are fortresses for a solo hunter: InfiniFi (348 findings, 5 reviews) + Intuition (2×
Diligence+ToB+C4) both executed-NULL same-day. Non-fortress EV lives in TIME-BOXED CONTESTS caught in WEEK 1
(before the crowd sweeps), or the operator's already-PROVEN parked leads. RE-SOURCE accordingly.
[[feedback-check-prior-audits-and-competitions-at-intake]] [[project-infinifi-intake]]
