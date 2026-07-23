---
name: feedback-map-severity-to-program-rubric
description: "Score a finding against the PROGRAM'S OWN written severity rubric, pulled and quoted verbatim, not against a generic funds-at-risk / dollar-magnitude model. The tier can shift a whole level when the rubric scores 'protocol-state / core-operation disruption' with no dollar floor."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

**Perena/Bankineco, 2026-07-21.** I anchored the junior-tranche loss-dodge finding at **Medium**, reasoning from
magnitude: the per-event dodge is bounded by the reserve cap (~3% of the tranche), senior protected, exogenous
trigger → "limited impact on funds" → Medium. That was a **generic funds-at-risk model**, not the program's rubric.
When the operator pasted Perena's ACTUAL severity definitions, the tier moved a full level:
- Their **High** = *"manipulation of protocol state, or significant disruption to core protocol operations"* — **NO
  dollar floor, no magnitude term.** Defeating the tranche's loss-absorption waterfall (the operation that DEFINES
  the product) reliably + repeatably + unprivileged is that clause almost verbatim → **High**, not Medium.
- Their **Critical** example was *"manipulating yield distribution to drain funds"* → my finding = manipulating LOSS
  distribution, one notch down because bounded-redistribution-not-drain → anchors High in their own words.
- **Medium** (*"edge-case, limited impact on user funds"*) became the FALLBACK, not the anchor.

**Why it matters:** a bounded-magnitude finding only maps to Medium under a rubric that scores dollars-at-risk. Many
rubrics (esp. protocol-ops / state-manipulation clauses) DON'T. Anchoring Medium off magnitude when the rubric scores
core-operation disruption is a self-inflicted **under-claim** — you pre-write the triager's lower tier and hand it to
them. Symmetric to overclaim, and just as costly (you leave a tier of reward + signal on the table).

**How to apply:**
1. **Pull the program's severity definitions FIRST** (verbatim, from the bounty page) before deciding a tier — same
   discipline as pulling the exclusions verbatim [[feedback-read-both-or-clauses-in-exclusions]].
2. **Map your impact to their exact clause wording**, quote it back in the report ("your High is X; this is X because…"),
   and note the nearest Critical/High example to anchor the notch.
3. **Don't pre-declare a tier in a concession** ("my read is Medium, would only argue higher if…") — that under-sells;
   state the impact mapped to their clause and let them place it.
4. Magnitude bounds are still worth stating HONESTLY (they cap the per-event dollars) — but frame them as "what's
   subverted is the operation, which recurs on every event" when the rubric scores operations, not dollars.
5. Check whether a bigger tier is reachable by a DIFFERENT axis (here: aggregate junior-exhaustion → senior spill =
   their Critical "direct loss of user funds") and present it mapped-and-bounded, not hidden.

Pairs with [[feedback-payable-impact-not-just-theft]] (impact taxonomy) and [[feedback-dedup-as-reproducible-negative-space]].
The operator ran SIX review passes on this one report; each caught a real defect (circular byte-compare, window/fix
self-contradiction, unsourced audit-scope claim, fee double-count, MEV-framing, and finally this mis-mapped tier). The
review discipline — adversarial re-read against artifacts, not assertions — is the model.
