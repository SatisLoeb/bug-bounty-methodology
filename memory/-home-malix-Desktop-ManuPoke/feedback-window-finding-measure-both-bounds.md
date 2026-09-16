---
name: feedback-window-finding-measure-both-bounds
description: "A finding that rests on a WINDOW has TWO bounds — both are substrate facts to MEASURE, not one; for shared-pot/loss-amplifier findings also verify the loss-SOURCE exists"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7156c583-7af7-4e92-807a-9f2dd26bbf35
---

**As soon as a finding rests on a WINDOW (a timing gap, a race, a stale-until-refresh interval, a
shared-pot solvency window), BOTH bounds — the OPENING bound and the CLOSING bound — are facts to measure
at the substrate, not one.** Measuring only one bound and assuming the other is exactly how a window that
is actually CLOSED reads as open.

**Why:** Berachain F-01 (commingled WithdrawalVault, no per-pool solvency). I fork-PoC'd it on real deployed
bytecode — pool B drains pool A, A permanently frozen — and got attached to the amplifier. It died TWICE at
the substrate, on two facts I never measured:
1. **The loss-SOURCE** (Leg 2, permanent insolvency): beacon-kit does NOT slash/penalize
   (state_processor.go:271 "does not enforce rewards, penalties, and slashing"; commented-out; withdrawals =
   full return). No loss ⇒ nothing to mis-socialize.
2. **The window's OPENING bound** (Leg 1, temporary freeze): the deficit needs CL funds to arrive AFTER a
   pool can finalize. I measured the CLOSING bound (fund arrival ≈ 27.4h: MinValidatorWithdrawabilityDelay
   256ep × 192 × 2s) but NEVER the OPENING bound — the 72h finalization gate (WithdrawalVault L291,
   129,600 blocks). 27.4h < 72h ⇒ every request self-funds before it can finalize ⇒ the window never opens.
   The gate never entered the reasoning, mine OR the operator's.
The tell I ignored: **the PoC had to ARTIFICIALLY create the gap** (`vm.deal` withheld B's CL portion). Funds
you must withhold to make the PoC pass are funds that arrive on their own on-chain. Empirically confirmed:
5/5 prod withdrawals finalized clean incl. a real cross-pool overlap, 0 reverts.

**How to apply:** the moment a finding's reachability depends on a window/race/timing gap, WRITE DOWN BOTH
bounds as measurable quantities and read EACH from the substrate (spec constant, on-chain block time, code
gate, deployed config) BEFORE building the PoC — never derive one and assume the other. For a shared-pot /
loss-amplifier finding (commingling, socialization, cross-tenant), add a third mandatory read: does the
LOSS-SOURCE the amplifier needs actually EXIST at the substrate (does the chain slash? does the token
rebase? is the oracle live?). If the PoC must inject/withhold a value to open the window, that value is the
unmeasured bound — go measure it on-chain. Upstream of, and composes with,
[[feedback-trigger-reachability-is-payability-gate]]. Instance: [[project-berachain-staking-pools-intake]].
