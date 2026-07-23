---
name: feedback-corpus-not-100-percent-poke-finds-unnamed-surface
description: "The corpus/intake is a bounded expectation-set (the extractor's story of where THEY think bugs live); the real bug is an indirection OUTSIDE it — the poke finds the surface no class names."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e128024b-a2c9-4cc6-b0e0-d5a42651f787
---

Never trust the corpus (or intake's class-density map) 100%. The corpus is a **bounded expectation-set** = the story of whoever extracted it, where THEY believed bugs live. By the Second Maxim applied to TOOLING (not just code): the bug is always an indirection OUTSIDE where you reached clean understanding — and reaching "clean understanding" via the corpus means you've adopted the extractor's mental model, the state of maximum blindness.

**Why:** the corpus is a **completeness backstop INSIDE known classes**; the **poke** is the discovery pass that finds the surface **no class names**. admin-api.injective.network belongs to no corpus class — no amount of corpus coverage would have surfaced it; only following the weird claim by hand did.

**How to apply:** use the corpus/intake to be exhaustive within named classes (packaging, not-missing), but run the apparatus-OFF poke to find the unnamed surface. Explicit, ASSUMED tension with [[feedback-corpus-coverage-gate-lead-dont-improvise]] (the BUGS-corpus rule "lead with --methods, don't improvise") — **both are true**: the gate/corpus catches the classes the poke misses (packaging); the poke finds the bug the corpus has no class for (discovery). **Order resolves the tension: poke FIRST, apparatus AFTER.** Don't read the coverage-gate as "corpus before hands" — it's "corpus so you don't miss known classes," never "corpus instead of the discovery poke." See [[feedback-manual-poke-mandatory-bracket]].
