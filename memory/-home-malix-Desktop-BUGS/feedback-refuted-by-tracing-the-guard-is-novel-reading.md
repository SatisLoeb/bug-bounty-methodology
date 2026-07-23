---
name: feedback-refuted-by-tracing-the-guard-is-novel-reading
description: "Concluding \"guard holds / self-prevented / REFUTED\" from tracing the code IS novel-reading — the tell to STOP and hunt the un-imagined state, not the verdict"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0e8b7796-917c-4113-a4d6-26f7932d10af
---

**STANDING operator correction (2026-07-11, Ammalgam): "lire le code comme un roman ne revele rien."**

On the Ammalgam fragile-liquidity freeze (prior-memory T1), I ran SIX fork disconfirmers, watched the dev's `update()`/maxLeaf guard catch every collapse path I tried, and concluded **"guard airtight / self-prevented / T1 REFUTED."** That verdict was **novel-reading**: I had reconstructed the guard's author's mental model and *agreed* with it. Understanding the guard to 100% = agreeing with the dev to 100% = the state of MAXIMUM blindness, because the bug lives precisely in the input/state the guard's author never imagined (if they'd imagined it, they'd have guarded it). My 6 PoCs only tested collapse paths I could *derive from understanding the code* — i.e. exactly the states already guarded.

The operator forced the re-hunt with one line. Asking "what input/state did the author NOT imagine here?" instead of "does the guard hold?" produced the un-imagined state in one more PoC: not fragile-drift alone (self-corrects — the guarded path), but **high-fragile × high-borrow_L × time** → saturation penalties accrue vs collapsed effective liquidity → the penalty-mint path hits a *defensive* `require(...,'TS')` the devs wrote believing it unreachable → permanent unhealable freeze, existing-lender funds trapped (Ammalgam poc-blind/TSFreeze.t.sol). A **confirmed** finding I had labeled dead.

**Why: crucial signals I misread.**
- An executed disconfirmer proves *the path I tested* is guarded — NEVER that the surface is dead. "6 disconfirmers → 0 survivors → refuted" is a coverage claim dressed as a verdict.
- A **defensive assert** in the code (`require(x==0, 'TS')` "should not happen", `precaution`, saturating-sub "should never be negative") is a NEON SIGN: the dev already suspected a state they couldn't rule out and slapped a revert on it. That revert firing = the un-imagined state reached = a DoS/freeze finding. Hunt to REACH the assert, don't trust that it's unreachable.
- Both over-claim AND under-claim are fatal. Here I under-claimed (conceded a live freeze) by the same novel-reading reflex that elsewhere makes me over-claim a bypass I didn't prove.

**The mechanical tell (GATING):** when I catch myself writing "guard holds / self-prevented / airtight / refuted / unreachable / can't be created — any tx that would create it reverts" from *reading + tracing the code path*, that sentence IS the trigger to STOP. Do NOT write the verdict. Instead: (1) name the invariant the guard assumes; (2) ask what input/state/time-evolution/multi-actor combination the guard's author did NOT picture; (3) build a PoC for THAT, especially any state that trips a defensive assert. The verdict comes only after the un-imagined state is executed, never from confirming the narrated one.

Distinct-but-related: a class can be genuinely dead (Ammalgam's reset-premium liquidity-manip WAS correctly executed-dead) while an ADJACENT class on the same mechanism is alive. Killing one imagined path ≠ killing the surface. See [[feedback-audited-target-hunt-invariant-not-class]], [[feedback-workflow-agents-coverage-not-verdict]], [[kill-poc-must-sweep-param-space]], [[feedback-closure-bias-expand-voies-hunt-seams]].
