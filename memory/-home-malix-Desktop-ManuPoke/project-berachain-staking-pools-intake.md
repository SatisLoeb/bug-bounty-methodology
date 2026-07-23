---
name: project-berachain-staking-pools-intake
description: "Berachain bug bounty — GO on contracts-staking-pools (stBERA LST); live Critical candidate F-01 = commingled WithdrawalVault, PoC pending"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7156c583-7af7-4e92-807a-9f2dd26bbf35
---

# Berachain bug bounty — contracts-staking-pools (stBERA LST) ENGAGED

**Intake 2026-07-23.** Immunefi-style dual Blockchain/DLT + Smart-Contract program. 5 assets:
bera-reth (Rust, OOS=upstream, fork-diff only), beacon-kit (Go consensus), contracts (PoL 31k LOC,
multi-firm saturated → skip), airdrop (mostly OOS), and **contracts-staking-pools** (added to scope
TODAY = freshest; 4142 LOC; **Zenith-only x3** audits; custom SSZ/EIP-4788 proof + EIP-7002 withdrawals).
**TRIAGE VERDICT = GO on contracts-staking-pools.** Workspace: `~/Desktop/BUGS/berachain-2026-audit`
(repos/, security-audits/ 47 PDFs, findings/F-01*, PROGRESS.md). HEAD 417554e.

## Architecture (stBERA)
Factory = SINGLETON: **global** withdrawalVault + accountingOracle; **per-pubkey** {stakingPool(=stBERA
token), smartOperator, stakingRewardsVault, incentiveCollector}. Multi-validator, ONE shared vault. Each
pool is an independent stBERA token with mutually-untrusting users. Oracle `updateTotalDeposits` is
FEEDER_ROLE-gated (audit H-2 fixed) → SSZ proof path mostly trusted-gated EXCEPT permissionless
`activateStakingPool` (proves initial balance). totalAssets = totalDeposits + buffered +
rewardsVault.balance + rebaseableBgt + rebaseableWbera. Recurring audit bug-class = gwei-rounding +
fee-accrual timing on full-exit/withdraw.

## LIVE CANDIDATE F-01 (PoC PENDING — build before submit) — candidate Critical
**WithdrawalVault commingles ALL pools' funds; no per-pool solvency enforcement.**
Proven facts (read from source): (1) factory forces every validator's CL withdrawal credentials =
the one shared `withdrawalVault` (`_validateWithdrawalCredentials`) → all pools' EIP-7002 skims + full
exits land untagged in ONE vault balance. (2) `_finalizeWithdrawalRequest` only checks
`request.assetsRequested > address(this).balance` (GLOBAL). (3) `allocatedWithdrawalsAmount[pubkey]`
per-pool ledger is incremented/decremented but **NEVER read as a gate** (grep-confirmed). ⇒ Pool A's
finalize is payable from pool B's funds. `assetsRequested` is FIXED at request-time rate, paid 1:1 after
~3d; actual CL inflow (variable schedule, or reduced by slash) can be < obligation ⇒ shortfall socialized
cross-pool ⇒ insolvency/permanent-freeze; escalatable to cross-pool theft. NOT in the Zenith reports
(closest = comprehensive L-3/I-7, different). Permissionless; multi-pool is the product's normal mode.

## NEXT (session 2)
1. Build F-01 two-pool Foundry PoC (observe cross-pool balance delta + A-finalize revert NotEnoughFunds).
   Gate to submit per [[feedback-invariant-that-passes-is-not-a-finding]] + [[feedback-execute-the-central-link]].
2. Re-examine permissionless `activateStakingPool` SSZ balances-tree gIndex
   (zeroValidatorBalanceGIndex + validatorIndex/4) for wrong-slot / List length-mixin depth error.
3. Secondary worklist: C2 DelegationHandler ignores slashing (audit I-2 Ack, composes w/ F-01);
   C5 IncentiveCollector EOA claim race (I-1 Ack). Gate everything w/
   [[feedback-check-prior-audits-and-competitions-at-intake]] + [[feedback-diff-forward-to-head-not-just-scope-changelog]].
