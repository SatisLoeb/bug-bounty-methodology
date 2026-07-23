---
name: feedback-reachability-is-kill-gate-not-severity-modifier
description: "Unresolved reachability = NOT READY, never a \"submittable Medium with an honest caveat\"; reachability gates ALL tiers, it is not an optional upgrade to a higher one"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 61439117-954c-497d-af2e-838e1dfc23d9
---

On the Monad epoch-jump finding (2026-07-05) I built a passing PoC (observed state delta: a jumped epoch → pre-activation reward theft), wrote the finding doc, then recommended: **"c'est un Medium soumissible maintenant, avec une section reachability honnête... sinon on soumet le Medium avec le caveat."** I framed resolving the consensus-side reachability as an OPTIONAL "push to High," with "submit the Medium now" as the safe floor. The operator overrode me — "on cherche monad-bft et on vérifie" — and the dig CLOSED the exploit path (5 verified consensus mechanisms guarantee strictly-consecutive epochs; the jump is unreachable). Had he followed my recommendation he'd have submitted a finding dismissable in 20 minutes → reputation hit. It was HIS instinct, against MY advice, that saved it.

**Why (the error's exact name):** I treated reachability as a severity-MODIFIER ("resolve it to upgrade Medium→High") when it is a KILL-GATE ("resolve it or the finding is NOT READY at any tier"). A PoC proves the code does X (evidence_strength). It says NOTHING about whether X is reachable on the deployed system. `severity = min(evidence, chain_completeness, impact)` — unresolved reachability means chain_completeness is UNKNOWN, which caps severity at unknown, not at "Medium." An "honest reachability caveat" in the report is not honesty; it is the dismissal politely pre-announced — writing "severity depends on a thing I didn't verify" documents that the finding is unfinished, it does not make it submittable. This is closure/sunk-cost bias ([[feedback-closure-bias-expand-voies-hunt-seams]], [[doctrine-surgical-reports-fight-to-the-end]]): having invested the PoC + doc, I offered the low-friction path (submit) and relegated the hard, uncertain part (another repo) to "if you want." Backwards — the hard part WAS the gate.

**How to apply:**
- Reachability is a kill-gate, GATING every tier, never an optional upgrade to a higher one. If reachability is unresolved → verdict = **NOT READY**, never "submittable Medium with caveat."
- For a NODE / multi-repo target, a finding of the form "layer L does not enforce invariant I" is INCOMPLETE until traced into the layer that IS supposed to uphold I (here: the execution layer doesn't enforce epoch-consecutiveness → MUST trace monad-bft consensus before any severity-commit). "The other repo isn't in scope / isn't here" is not an excuse to submit on a caveat — it's a reason to go get the repo (it was already cloned locally the whole time).
- A passing PoC is the START of verification, not the end. After it passes, the question is not "what severity" but "is this reachable on the deployed build" — and that answer, not the PoC, sets whether it's submittable at all.
- Watch for the tell in my own output: proposing "submit now, with an honest caveat" for the part I couldn't verify = closure bias. The honest move is to KILL or SUSPEND on the unresolved leg, never to dress it as a floor.
- Do not put myself on the good side of the save. When the operator's override against my recommendation is what prevented the dismissal, own that my recommendation was the danger — don't reframe it as "your fear worked."
