---
name: feedback-never-generalize-a-revert-claim-from-one-call-shape
description: "A DoS/'everything reverts' claim tested on ONE call shape is an extrapolation, not a finding — sweep shapes against a control, and model the actual balance/state the guard reads"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1cddd5e1-a775-4c40-bc31-1244e19cbfd8
  modified: 2026-07-25T11:10:11.765Z
---

**Never generalize a revert-claim ("the pool is bricked", "every call fails", "the function is unusable")
from ONE call shape.** Sweep the shapes against a CONTROL instance and model the real state the guard reads.

**Why:** on Doppler F-01 I wrote "above 100% fee every swap reverts, the pool is permanently un-swappable"
after sweeping FIVE fee values but only ONE shape (exact-input buy, 0.5 ETH). Under challenge I swept shapes
and it collapsed: **exact-OUTPUT swaps still execute** (the fee lands on the *unspecified* side, which for
exact-output is the INPUT token, so the trader merely overpays ~17.8×), dust exact-input "succeeds" delivering
zero (early-return on `outputAmount <= 0`), and a **whale CAN exit** with a big enough bag. The real finding
was EXTORTIONATE (holder recovers 5.64% of fair value), not FROZEN. A triager who ran the second shape himself
would have gutted the load-bearing leg.

**The compounding trap — model the state the guard actually reads.** The guard was
`if (feeCurrency.balanceOf(address(poolManager)) < feeAmount) revert` — it tests the **SHARED singleton
balance**, not the pool's own reserves. On a thin local deployment exact-output reverted (looked "bricked");
with `vm.deal(manager, 10_000 ether)` (mainnet-realistic, the v4 singleton holds every pool's funds) it
**succeeded at the ruinous price**. Same code, opposite verdict, decided entirely by a balance I hadn't
modelled. Read the guard's operand and ask "whose balance is this, and what is it in production?"

**How to apply:**
- Enumerate the shape axes before claiming universality: exact-input vs exact-output, both directions
  (buy/sell), dust / normal / extreme size, and the caller's own capacity (a whale may pass where a
  retail bag fails).
- Run every shape against a CONTROL instance (a normal-config twin). A revert only counts as attributable
  to your bug if the same shape SUCCEEDS on the control. Otherwise you may be reporting the shape's own limits.
- Any surviving shape re-characterizes the finding (DoS → overcharge/griefing). Quantify what the survivor
  COSTS instead of dropping it; the measured multiple is usually a better headline than the false absolute.
- Mirror of [[feedback-invariant-that-passes-is-not-a-finding]]: there, a green invariant isn't a finding;
  here, a red revert on one path isn't a universal. Both are "one execution ≠ the general claim."
- Same family as [[feedback-window-finding-measure-both-bounds]] (measure BOTH bounds) and
  [[feedback-trigger-reachability-is-payability-gate]].

**Tell you're about to do it:** the PoC varies ONE parameter (the fee, the amount, the address) across many
values while the CALL SHAPE stays fixed, and the writeup then says "every / always / never / permanently."
