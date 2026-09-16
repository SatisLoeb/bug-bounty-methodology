---
name: feedback-rabat-joie-triager-judges-not-rewrites
description: "The rabat-joie/triager role delivers a VERDICT and NAMES weaknesses; it does not rewrite the operator's report."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 86cdc75d-e8ee-41bb-ba01-79bb7950029f
---

When asked to play the "triageur rabat-joie" (killjoy triager), the deliverable is the **ruling**, not authorship. Output: survives/dies, severity mapped to the program rubric, on what executed grounds, plus any framing/severity weaknesses **named as findings** ("a triager will downgrade this on X because Y"). Then STOP. Do NOT go edit the submission or apply the fixes.

**Why:** role separation. The operator writes the report; I am the independent adversary that judges it. The moment I rewrite the report, the check collapses into co-authorship and the operator loses the very thing they asked for — an outside attacker who didn't write the thing. (StackingDAO F-01, 2026-07-24: verdict was correct and thorough — deployed-source pass, found the load-bearing denominator seam — but I then rewrote the submission with 6 edits. Operator: "ton role n'est pas de re ecrire le rapport mais de faire le triageur." Edits were kept, not reverted, but the boundary was crossed.)

**How to apply:** triage = verdict + adversarial attack + named weaknesses (with the exact downgrade angle a real triager would use). Leave the fixing to the operator unless they explicitly say "now edit/rewrite it." Naming "the Impact overclaims the whole-pool number → reframe to pro-rata" is the finding; doing the reframe is overstep. Same discipline as [[feedback-manual-poke-mandatory-bracket]] and [[feedback-hunt-dont-narrate-ev]] — do the assigned job, not the adjacent one.
