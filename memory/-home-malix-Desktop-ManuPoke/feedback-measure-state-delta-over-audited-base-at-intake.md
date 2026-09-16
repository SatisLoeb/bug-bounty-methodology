---
name: feedback-measure-state-delta-over-audited-base-at-intake
description: "At intake on a wrapper-over-audited-base target, measure the NEW STATE the delta adds on the money path — near-zero new state means near-zero payable surface, however novel the wrapper looks"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4be8f758-1ac9-4ac4-94f2-ba37a345ea94
  modified: 2026-07-29T10:38:05.301Z
---

On a target that is a **wrapper / concrete implementation over an audited base** (ZenStaker over Tally
Staker, a fork over a canonical protocol), the go/no-go is decided by one cheap measurement taken
*before* deep reading: **how much NEW MUTABLE STATE does the delta add on the money path?**

Not lines of code — *state*. Code with no state it owns can only be a pure function of state someone
else already audited.

Run at intake, in this order (all cheap):
1. `git clone` the audited upstream at the exact claimed tag, and **verify the tag really resolves to
   the claimed commit** (Horizen's did; a mismatch would have invalidated every later diff).
2. md5 every shared `src/` file upstream-vs-target. This is minutes, and it tells you whether the
   OOS-upstream wall genuinely holds or is the finding itself.
3. For each genuinely new file, count the **storage variables it writes** and the **token outflows it
   owns**. Horizen: `RewardAccumulator` = 1 outflow moving 1 variable then a reset; `ZenStaker` = six
   pure views + a zeroed immutable + a factory. Total new money-path state ≈ nil.
4. Ask whether the protective property is true **by construction** or **by check**. Principal in
   ZenStaker lives only in per-delegatee surrogates — the staker's own balance is structurally rewards
   only, so there is no check to bypass. By-construction properties do not yield findings; by-check
   properties do.

**Why:** a lawyered SECURITY.md, a long exclusions list, and a novel-looking wrapper all *feel* like
"they are hiding something here" — and by the first maxim a gate does mark where to dig. But a gate
over a component that owns no state has nothing behind it. Horizen burned a full multi-agent pass
(~60 kills, 22 executed suites) to conclude what the state-delta measurement predicts in ten minutes:
the two contracts add 358 lines and almost no state, so the payable surface was near-zero from the start.

**How to apply:** run steps 1–4 before committing to depth. If the money-path state delta is ~nil and
the protections are by-construction, the realistic ceiling is informational — say so and re-source,
rather than spending the pass proving a fortress. Reserve depth for deltas that add state a user's
funds flow through. Pairs with [[feedback-invariant-that-passes-is-not-a-finding]] (a green invariant is
fortress-proving) and [[feedback-trigger-reachability-is-payability-gate]].
