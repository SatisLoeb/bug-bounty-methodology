---
name: cosmos-evm-ghost-cache-distinct-from-ghsa-missed-vesting-surface
description: ghost-cache (commitWithCtx) was DISTINCT from GHSA-7g4w (SubBalance vesting-delegation underflow); missed the locked-vs-spendable surface
metadata:
  type: project
---

cosmos/evm @ v0.7.0-beta.0-52 (BlackBox engagement, closed REFUTED 2026-08-14). My ghost-cache
finding (`commitWithCtx` in `x/vm/statedb/statedb.go` writes a stale cached balance from a
non-isolated ghost `StateDB`) is a DISTINCT sink from GHSA-7g4w-cg88-2cq2 "Balance underflow in EVM
StateDB" (`SubBalance` in `x/vm/statedb/state_object.go`, unchecked subtraction wrapping to ~2^256;
~$5.7M drained MANTRA 2026-08-20 + TAC/KiiChain 2026-08-22; published 2026-08-28, 14 days AFTER I
closed). Verified against the advisory + PR #1176. Same component ("StateDB balance write-back
diverges from x/bank truth"), different sink, different mechanism. So GHSA-7g4w — NOT ASA-2026-002
(ICS20 nested precompile) — is the correct class-anchor; the BRIEF's anchor was wrong.

**Why (the missed surface = the lesson):** the real bug needed no nesting. The EVM `StateDB` sees
only an account's **spendable** balance, but `x/staking` + the staking precompile let a **vesting
account delegate its LOCKED balance** — so `SubBalance` subtracts the full delegated amount from a
smaller spendable figure and underflows. I spent the engagement in the nested-precompile ghost-frame
cul-de-sac and never opened the locked-vs-spendable surface where the $5.7M lived. Novel-reading
trap: I adopted the dev's "StateDB balance == spendable" model instead of asking what state (a
vesting account dipping into locked funds) that model never imagined.

**How to apply:** on any EVM-on-Cosmos (or any dual-ledger where an EVM view mirrors a richer native
ledger), the seam is *which balance each layer sees*: spendable vs locked/vesting/bonded. Enumerate
the account TYPES the EVM mirror flattens and drive each through every balance-moving primitive
(delegate, undelegate, transfer, precompile). The bug is the account type the mirror does not
distinguish.

Also here: the Gate-5 defender-inversion — the defender wrongly closed the April HackerOne PoC as
"does not affect live networks" because it was reproduced at 6 decimals and never re-driven at
18-decimal prod params. "Not reproduced under prod params" != "not exploitable"; it means "not yet
driven under those params." Mirror of [[stackingdao-ststxbtc-double-count-live]]. And the 96-day
backport window: [[feedback-main-not-release-guard-diff-heuristic]].
