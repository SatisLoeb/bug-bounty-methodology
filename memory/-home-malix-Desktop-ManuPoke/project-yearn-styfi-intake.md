---
name: project-yearn-styfi-intake
description: "Yearn stYFI (Immunefi, $200k, EVM/Vyper 0.4.2, FRESH July-2026, apparently UNAUDITED) — GO on the fresh stYFI liquid-staking+governance suite. Crown jewels: WeightAggregator governance vote-weight (Critical gov-manipulation), RewardDistributor self-reported weight (High theft), + LL SCALE=69420 unit-confusion red flag (1UP)."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
  modified: 2026-07-26T21:32:51.261Z
---

Operator pushed me onto Yearn ("ne me dit no-go juste parce que c'est confortable") after the Stacks
run. RIGHT call — genuinely soft fresh surface. Immunefi `yearn`, **$200k**, EVM (ETH/Arb/OP/FTM),
Solidity+Vyper, live 2021 but the stYFI suite is NEW. **Medium tier EXISTS (griefing/gas) + MEV in
scope (Crit/High) + governance-manipulation = Critical.** OOS: third-party-oracle-baddata (not
excluding manip/flashloan), centralization, privileged-addr, listed helper contracts.

**TARGET = the FRESH stYFI suite (repo github.com/yearn/stYFI, Vyper 0.4.2, ~29 contracts).** Deploy
blocks: stYFI core Feb-2026 (block 24377403), **YBC + Teams July-2026 (blocks 25228044 / 25244861 =
weeks old)**. **NO audit reports in repo/README → apparently UNAUDITED (VERIFY externally — load-bearing
for EV).** deployment.json = full source↔address map (deployed==repo HEAD). Cloned depth-80 to
~/Desktop/BUGS/yearn-styfi-2026/stYFI.

**ARCHITECTURE (README):** ERC4626 StakedYFI (1:1 YFI, streaming unstake) → StakingMiddleware hook →
forwards to StakingRewardDistributor + WeightAggregator. 3 liquid lockers (StakeDAO/1UP/Cove) via
LiquidLockerDepositor → LiquidLockerMiddleware → LiquidLockerRewardDistributor + WeightAggregator.
Global RewardDistributor splits rewards each epoch by each component's **SELF-REPORTED weight**
("claimed in order"). WeightAggregator = governance vote-weight (4-epoch ramp) + forwards aggregated
supply to YBCWeightAggregator → YBCElection (governance). VotingEscrowRewardDistributor = veYFI-migrated
weight + decaying boost. Teams/TeamRegistry/TeamAccountant (July-2026). Recent commits added reentrancy
locks ("on sync too" — tell they missed it once).

**CROWN-JEWEL SEAMS (ranked):**
1. **LL SCALE unit-confusion (SHARPEST):** deployment.json LIQUID_LOCKERS SCALE=[1,**69420**,1] for
   [StakeDAO,1UP,Cove]. 1UP scaled 69420× (up-token≠YFI units). If YFI-units and up-token-units are
   mixed anywhere without the scale → 69420× weight/reward inflation (P-LEND-020 vToken-vs-underlying
   class). WeightAggregator `_calculate_staked` (WeightAggregator.vy:302) sums raw
   `balanceOf(depositor)` across LLs with NO scale applied → CHECK whether the 1UP depositor's balanceOf
   is YFI-equiv or up-units. TOP LEAD.
2. **Governance vote-weight (Critical gov-manip):** WeightAggregator weight()=packed 4-epoch ramp
   (_forward :366, _update_staked :322). Surface: ramp holds on transfer (recipient ramps, no instant
   weight; both dirs round conservative). Residual: whale overflow (`assert staked<=WEIGHT_MASK` :372 →
   DoS), cross-component double-count via _calculate_staked balanceOf + re-entrancy, aggregation
   supply-replacement forwarded to YBC.
3. **RewardDistributor self-reported weight (High theft):** a component reports its own weight → if
   inflatable, steal the epoch's rewards. Read RewardDistributor.vy + how each distributor computes its
   reported weight (StakingRewardDistributor snapshots staked; LiquidLockerRewardDistributor uses
   preconfigured weight + decaying boost; VE uses lock snapshot + boost).
4. YBCElection (360 lines, July-2026 freshest) — the election/governance; manipulate → Critical.

**STATUS: intake GO, crown jewels mapped, hunting the SCALE=69420 unit-confusion first.** NEXT: read
LiquidLockerDepositor.vy (SCALE usage, balanceOf units) + confirm whether _calculate_staked mixes scaled
up-units into the YFI-denominated aggregate → weight/reward inflation PoC (Foundry/Titanoboa fork).
Verify unaudited claim. Edge: Vyper 0.4.2 low-dup + accounting-seam wheelhouse + fresh July-2026.
[[feedback-check-prior-audits-and-competitions-at-intake]] [[feedback-diff-forward-to-head-not-just-scope-changelog]]
