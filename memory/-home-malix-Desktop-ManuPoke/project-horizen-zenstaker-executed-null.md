---
name: project-horizen-zenstaker-executed-null
description: "Horizen ZenStaker + RewardAccumulator (Immunefi, live mainnet) — EXECUTED-NULL fortress, NO-GO, do not re-audit the on-chain scope"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4be8f758-1ac9-4ac4-94f2-ba37a345ea94
  modified: 2026-07-29T10:37:47.059Z
---

**Horizen ZEN staking — Immunefi. EXECUTED-NULL → RE-SOURCE. Closed 2026-07-29.**

Wrapper over the audited Tally/ScopeLift Staker. Scope commit `ab92502`. Phase B live mainnet
(chain 26514) since 2026-07-27. Workspace `~/Desktop/ManuPoke/horizen-fresh`
(`OPERATOR-NOTES.md` = full graveyard, `evidence/` = 22 executed Foundry suites).

Live: ZenStaker `0x6BF7CF29a8bcE11Aa62Cf593d165C244fA4d3E31`, RewardAccumulator
`0x06f5555fee73EDdc385b6d76FE00DB2D96ccDaE8`, ZEN `0x57da2D504bf8b83Ef304759d9f2648522D7a9280`
(stake **and** reward token). 354,107 ZEN staked ≈ 87% of chain supply; reward pool only 4,132 ZEN.

**Why it is a fortress — structural, not clever.** The two in-scope contracts Horizen actually wrote
total **358 lines and add almost no state**. `RewardAccumulator` = one token outflow moving one
variable then a reset. `ZenStaker` = six pure views + a zeroed immutable + a surrogate factory.
Principal is protected **by construction** (it only ever lives in per-delegatee surrogates; all four
STAKE_TOKEN transfers are depositor↔surrogate), not by a bypassable check. `Staker.sol` == audited
upstream v1.0.1 (`b5b6f98`, tag verified) minus **exactly two `indexed` keywords** ⇒ the OOS-upstream
wall genuinely holds. Deployed runtime bytecode == pinned source (only immutables + metadata differ).

**Killed leads (don't re-derive):**
- 6:1 seam — accumulator `timeWindow=431700` (~5d) vs `REWARD_DURATION=2592000` (30d), an undocumented
  deviation from their own script default. 24-window mainnet-fork sim: guard never trips, in-flight
  buffer converges to exactly 6 tranches, tail fully drains after funding stops. **Delay, not loss.**
- 1-wei re-stretch grief (pushes `rewardEndTime` a full window for 1 wei) — excluded *verbatim* by
  SECURITY.md 1(a) "blending a new contribution into the ongoing REWARD_DURATION rate", needs **no
  additional mechanism**, and leverage is zero while the keeper flushes non-zero tranches.
- `_fetchOrDeploySurrogate` TOCTOU (mapping written after the constructor's external call) — real
  PoC freezing 700e18, but reachability is **zero**: the only external call is `STAKE_TOKEN.approve`,
  STAKE_TOKEN is immutable = ZEN, and ZEN is not a proxy (EIP-1967 slot = 0x0) so it can never gain a hook.
- Empty-pool stranding (their item 7, declared "practically unreachable") — archive reads prove the pool
  was funded (227,994 ZEN) before the single ever `RewardNotified`; identity EP means nobody can zero
  another staker's EP. Total unattributable surplus on live mainnet = **75 wei**.
- `Staker__InsufficientRewardBalance` as a novel brick — guard reduces to `unclaimedLiability >= 0`;
  margin is exactly 1 wei but never negative across 1,145 fuzzed flushes.
- `notifyAlreadyTransferredRewards` underflow — `accumulatedRewards <= balanceOf` is a true invariant.

**Informational only:** `AUDIT_DELTA.md` is incomplete on three counts — it never mentions
`RewardAccumulator.sol` at all, omits `getVotes(address)` from its list of added views, and misses that
the binary calculator was silently updated past v1.0.1. `getVotes` is IVotes-shaped and flash-manipulable
but has **zero consumers** (217/217 verified chain contracts, plus frontend/subgraph greps).

**NUKE barrage also run (2026-07-29)** — 684 signals, 0 new surface; corroborated the same CEI locus
(`RewardAccumulator.sol:160` state-after-external-call, real but unreachable: ZEN has no hook, not a proxy,
`rewardToken` immutable). Its one untouched class `flashloan/economic` is now EXECUTED-CLOSED: notify
changes a RATE never a lump (`rewardPerTokenAccumulated` byte-identical across the flush) ⇒ nothing to
sandwich; same-block accrual 0; reward exactly pro-rata. Don't re-run NUKE here.

**Payout ceiling was low anyway:** principal-affecting critical caps at $10k, accumulator-bounded tier
is a flat $3k, KYC required. Residual (all de-rated): Goldsky mapping is O(1)/event and its DoS is
explicitly OOS; StLighter `0x2762dF…` holds **0 ZEN / 0 staked** (inert, and third-party).

[[feedback-measure-state-delta-over-audited-base-at-intake]] [[feedback-invariant-that-passes-is-not-a-finding]]
[[feedback-trigger-reachability-is-payability-gate]] [[feedback-read-both-or-clauses-in-exclusions]]
