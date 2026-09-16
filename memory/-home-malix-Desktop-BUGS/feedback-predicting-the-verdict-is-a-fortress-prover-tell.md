---
name: feedback-predicting-the-verdict-is-a-fortress-prover-tell
description: "Writing \"as expected, null\" / predicting executed-null BEFORE the disconfirmer runs = fortress-prover posture; the tell to catch mid-hunt"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 2dbf9b9a-dfca-471f-893b-f499932d156b
  modified: 2026-08-15T15:22:45.172Z
---

Operator, mid-Ref-Finance-hunt: *"Prédire 'executed-null' avant d'exécuter, c'est te mettre en posture de fortress-prover dès le départ — tu cherches à confirmer le mur au lieu de le percer."*

**The mechanical tell:** any phrase that announces the verdict before an executed artifact produced it — "as expected null", "this is the saturated core so likely clean", "confirmed fortress", "guard present → safe", reading-a-path-then-concluding-safe. Each is an un-executed hypothesis dressed as a conclusion (Maxim 1), and it PRE-COMMITS you to confirming the wall: once you've predicted null you unconsciously build tests that pass instead of tests that break.

**Why:** "guard present → safe" is the reading trap (Maxim 2) — spotting the dev's guard means you've adopted his mental model, the state of maximum blindness. The bug lives in the path his guard doesn't cover, which you stop looking for the moment you narrate "guarded."

**How to apply:** (1) NEVER write the verdict before the disconfirmer runs — write the theft hypothesis + the executed test, run it, THEN read the result. (2) A null is only legal as EXECUTED (fork/sim/fuzz output pasted), never affirmed from reading. (3) Build tests that TRY TO BREAK the invariant (self-contained attacker PnL, value-conservation, denominator-integrity), not tests that confirm a guard. (4) Audit your OWN disconfirmer for bias before trusting it — on Ref I had TWO biased assertions (per-token vs value; crediting the attacker with a pre-existing imbalance they didn't finance) that manufactured false "profit"; fixing them to self-contained/value-based flipped 55k "fails" to 0. A biased PASS burns credibility; a biased setup that suppresses the bug is a false-negative miss. (5) The corrected close is an EXECUTED null (14.6M fuzz checks, artifacts on disk), which honestly names its residual gap (real-wasm sim not run) — that beats an affirmed "fortress" every time.

Reinforces [[feedback-default-posture-thief-not-fortress-prover]], [[feedback-closure-bias-expand-voies-hunt-seams]], [[feedback-refuted-by-tracing-the-guard-is-novel-reading]]. Instance: [[reffinance-boostfarming-shadow-seam-null]].
