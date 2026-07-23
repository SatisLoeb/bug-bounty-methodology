---
name: feedback-invariant-that-passes-is-not-a-finding
description: "When hunting bugs, writing invariant tests that PASS proves the code correct — that is fortress-proving, the opposite of finding a bug."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cb645e11-8651-4234-a23c-d044f4563d96
---

During the Ammalgam saturation hunt I drifted into writing tree-invariant fuzz tests (`tree-empty-after-removal`, `idempotency`, `totalSat==account-sat`) — all PASSED. The operator stopped me: *"tu es juste en train de prouver que le code fait ce qu'il dit qu'il fait c'est ça trouver des failles ????"*

**Why:** An invariant that PASSES demonstrates the code is CORRECT = proving the target is safe = the fortress-prover reflex the whole Protocole Chasse exists to kill (Maxime 2: the bug is the sentence the author did NOT write; reading to confirm the author's intended invariants is maximum blindness). Executed harnesses are the right *tool*, but pointed at "does the property hold?" they prove safety; pointed at "can I make value leave?" they hunt theft. The failure is subtle because the harness is real and executed — it *feels* like rigor.

**How to apply:** Before writing any test ask "does this PASS-ing prove the code is safe, or does it construct a theft?" If PASS = safe → it is fortress-proving, STOP. Instead: RÈGLE ZÉRO — money-exit map (where does value SORT), construct a concrete attacker sequence, observe the delta `value_after < value_before`. The deliverable is an attack with a loss, or the EXACT gate that stops it (the door to pierce next), never a green invariant. Also a *bound* (e.g. "premium ≤ 1%") is measuring correctness, not stealing — construct the seize and observe it. Cf. [[feedback-default-posture-thief-not-fortress-prover]].
