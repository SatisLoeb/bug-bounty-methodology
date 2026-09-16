---
name: feedback-under-downgrade-pivot-to-defenders-own-artifacts
description: "In a triage rebuttal, when they attack your most-INTERPRETABLE impact leg (dilution/magnitude/'just redistribution between users'), do NOT relitigate that leg's mechanism — re-anchor on the leg whose evidence is the DEFENDER'S OWN production artifacts (their txs, their keeper, their main position), which they cannot requalify."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Operator directive, 2026-07-24, StackingDAO F-01 clear-for-submission ("pour la suite, pas pour le
rapport"): a multi-leg finding has legs that live in different epistemic spaces, and under downgrade
pressure you fight on the space where you can't lose, not the space where the mechanism is arguable.

**The setup.** F-01 has two legs on one root cause: §1 theft-of-yield (the double-count drains the
sBTC pool) and §2 a reserve DoS (`ERR_OVER_RESERVE`). §1's severity rests on the `add-rewards`
denominator argument — correct, but it lives in INTERPRETATION space: a defender has room to reframe
"insolvency of a reward subsystem" as "redistribution between users / small magnitude / dilution,"
and drag it into a severity debate you can only answer with more mechanism. §2 rests on THREE real
`ERR_OVER_RESERVE` transactions already on mainnet: their own keeper, their own main position (v6),
their own retry an hour later failing. That lives in FACT space: a triager pulls the tx hashes and
sees their own history.

**The move.** If the response pushes on the theft leg ("dilution / magnitude / just redistribution"),
do NOT go explain yourself on the denominator — that's fighting on their turf, where "it's arguable"
is a win for them. Re-anchor on the three production events. They can't requalify their own executed
transactions. You never win by out-arguing the interpretation of your most-interpretable leg; you win
by moving to the leg whose evidence is the defender's own on-chain artifact.

**Generalize.** Whenever a finding has one leg backed by the target's OWN production state/txs/keeper
behavior and another backed by your interpretation of a mechanism, and the team contests the
interpretive leg: pivot, don't defend. The irrefutable-because-it's-theirs leg is the anchor; the
mechanism leg is support, not the hill. Pick the response ground by which side owns the evidence.

This is the response-phase twin of [[feedback-dedup-as-reproducible-negative-space]] (there: the
triager re-runs YOUR zero; here: the triager re-reads THEIR OWN txs) and the tactical application of
"every axis shut by an artifact not an argument." Pairs [[project-stackingdao-stbtc-double-count]].
Do not confuse with conceding the theft leg — §1 stands; the point is which leg you STAND ON when
they push, not which you drop.
