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

## WIDEN-THE-NET RESULT (2 workflow passes, 14 agent-lenses + independent read)
**No clean single-tx / single-actor THEFT primitive exists** — core value math conservative & defended:
reentrancy NULL (StBERA hookless, callees trusted, refund CEI-last); operator-fee underflow-freeze DEFENDED
(alreadyCharged<=balanceOf invariant holds); totalDeposits>MAX freeze not permissionlessly reachable;
share-burn rounding protocol-favorable; lifecycle frozen-rate decoupling collapses into F-01 (STRENGTHENS it).
- **F-02 (near-miss, conditional theft, cleaner shape than F-01):** exchange-rate TROUGH. `updateTotalDeposits`
  overwrites totalDeposits with NO monotonic/timestamp guard; `_depositToConsensusLayer` books `totalDeposits+=`
  BEFORE CL credits → a feeder proof during the deposit-credit lag overwrites DOWN → rate trough (only +1/+1
  protection) → attacker self-funds mint-cheap/redeem-rich, profit≈A0·D·D2/[(A0+D)(A0+D2)] (~62.5k BERA @250k).
  KILLERS: not attacker-forced (rides feeder cadence) + OFF-REPO empirical (deposit-credit lag vs feeder
  interval) + borderline known-TOCTOU. **Needs empirical feeder-cadence check before submittable.**
- **F-03 (weak DoS):** 1-gwei requestWithdrawal at totalDeposits≈minEffectiveBalance (StakingPool.sol:207)
  forces full-exit of whole validator → pool permanently bricked. Narrow (pool at floor) + arguably intended.
- ROOT of F-01/F-02/F-03: totalDeposits is overwrite-able with NO reconciliation between EL-optimistic booking,
  CL-lagged reality, fixed-value withdrawal claims, and the shared commingled vault.

## EMPIRICAL FEEDER-CADENCE CHECK (on-chain read-only, 2026-07-24) — DECISIVE
Deployed mainnet(80094) + Bepolia(80069). Mainnet 2 pools (A=0x67b979..c500, B=0x5d73a4..94eb), both
active/healthy, totalDeposits~498k BERA (2x the 250k floor), vault balance 0. Bepolia 1 pool.
**TotalDepositsUpdated = 0 across ALL 3 live pools, entire lifetimes** → the feeder NEVER posts
`updateTotalDeposits`; oracle-overwrite path is DORMANT everywhere; totalDeposits kept by local booking only.
- **F-02 (rate trough) = DEAD.** Trough needs feeder to overwrite-down during deposit in-flight; feeder never
  posts → trough never opens. NOT submittable.
- **F-03 (forced-full-exit at floor) = NOT reachable** (pools 2x above floor).
- **F-01 = REAL but LATENT.** Fixed-value FCFS withdrawal queue + commingled vault + no per-pool solvency
  invariant → a validator LOSS (slashing; audit ACKs it's unhandled) is mis-socialized onto the queue tail
  (early finalizers full, tail permanently frozen) and cross-pool via the shared vault. Not exploitable with
  today's 2 healthy pools + empty vault; activates on any loss/timing event. Critical-impact class w/ a
  realistic trigger, but reachability is debatable at triage.
BOTTOM LINE: no clean payable-TODAY theft on this SC surface. F-01 = only real defect (latent, slashing-triggered).
Gate w/ [[feedback-trigger-reachability-is-payability-gate]] + [[feedback-today-impact-before-poc]].

## F-01 EXECUTED on MAINNET FORK (2026-07-24) — mechanism PROVEN (not reasoned)
`test/F01_CrossPoolFork.t.sol` PASSES on real deployed bytecode + real pool state + real operator WBERA:
pool B holder requests 1000 BERA (only 683.7 covered by its own operator WBERA), pool A holder requests
500 (fully self-funded) → vault holds 1183.7 < 1500 owed → B finalizes & takes full 1000 (extracting
316.3 BERA of A's funds) → A's finalize REVERTS NotEnoughFunds (frozen). HONEST GATE: precondition = a
pool-side shortfall (B's 316.3 CL portion not arriving = slashing [audit I-2 ACK] or CL-delay past the 3d
finalization window); mechanism proven on live chain, impact = temp-freeze(timing)/permanent-insolvency(loss);
commingling AMPLIFIES a single-pool loss into multi-pool (loser = a DIFFERENT pool's honest holder).
NUKE barrage (slither+aderyn+semgrep) = 0 exploitable miss (all 12 HIGH = FP/OZ-lib/role-gated/canonical
reentrancy/already-analyzed underflow lines); logic-layer negative space invisible to scanners = confirms
F-01 semantic. So F-01 is now EXECUTED, not "latent-reasoned" — much stronger submission if operator wants it.

## 🔴 F-01 KILLED (2026-07-24) — rabat-joie substrate check. DO NOT SUBMIT. TARGET EXHAUSTED → RE-SOURCE.
Operator forced the check I skipped: **does Berachain even slash? NO.** Confirmed at source (repos/beacon-kit):
state_processor.go:271 dev comment verbatim "Currently, beacon-kit does not enforce rewards, penalties, and
slashing for validators"; `processRewardsAndPenalties`+`processSlashingsReset` COMMENTED OUT in processEpoch;
processOperations = deposits only (no block-body slashing); only DecreaseBalance = withdrawals = FULL return,
no haircut; MinEpochsToInactivityPenalty/EpochsPerSlashingsVector = dead spec-config. ⇒ NO consensus loss
mechanism exists.
- Leg 2 (permanent insolvency, my headline) = DEAD on reachability (Ammalgam axis) — `test_F01_permanent
  Insolvency_slashHaircut` models an IMPOSSIBLE event.
- Leg 1 (temporary cross-pool displacement via exit delay) = real code, but SELF-HEALS (B's exit returns in
  full, repays pot), B doesn't profit, and "temporary freezing of funds" NOT in this program's SC impact
  table (only PERMANENT freezing). Not payable.
- Audit "slashing unhandled" citation = FACTUALLY INVERTED (nothing to handle) — a landmine AND wrong.
- Permissionless pool creation CONFIRMED (`deployStakingPoolContracts` no modifier) but irrelevant (no loss
  to direct).
F-01 = commingled-vault + no per-pool solvency = REAL defect but HARDENING, no reachable trigger = Symbiotic
pattern ([[project-symbiotic-rwa-layer-oos]]). Report drafts submissions/berachain-F01-* NOT sent (correct).
**DURABLE LESSON: for a loss-AMPLIFIER finding (commingling/socialization/cross-tenant), verify the LOSS
SOURCE exists at the SUBSTRATE (does the chain slash? does the token rebase?) BEFORE building the amplifier
PoC. The fork PoC proved the AMPLIFIER on real bytecode but the SOURCE it amplifies doesn't exist.**
[[feedback-trigger-reachability-is-payability-gate]]

## NEXT (session 2 → 3)
1. Build F-01 two-pool Foundry PoC (observe cross-pool balance delta + A-finalize revert NotEnoughFunds).
   Gate to submit per [[feedback-invariant-that-passes-is-not-a-finding]] + [[feedback-execute-the-central-link]].
2. Re-examine permissionless `activateStakingPool` SSZ balances-tree gIndex
   (zeroValidatorBalanceGIndex + validatorIndex/4) for wrong-slot / List length-mixin depth error.
3. Secondary worklist: C2 DelegationHandler ignores slashing (audit I-2 Ack, composes w/ F-01);
   C5 IncentiveCollector EOA claim race (I-1 Ack). Gate everything w/
   [[feedback-check-prior-audits-and-competitions-at-intake]] + [[feedback-diff-forward-to-head-not-just-scope-changelog]].
