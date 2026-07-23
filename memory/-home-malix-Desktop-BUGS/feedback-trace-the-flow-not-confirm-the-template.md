---
name: feedback-trace-the-flow-not-confirm-the-template
description: "A differential/confirmation harness built to prove hypothesis X is blind to the anomaly that doesn't match X; trace the real data-flow value-by-value at the seam FIRST, harness second (bloc 6, not discovery)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 61439117-954c-497d-af2e-838e1dfc23d9
---

Operator caught this on Monad (2026-07-04), before Pass 1, pointing at MANIFEST-injective-funding-hunt.md POSTURE DE LECTURE. My firmaudit triage was hypothesis-driven: every dig agent got a template to confirm ("HUNT: any input where JIT and interpreter diverge", "HUNT: a read/write-set mis-analysis"), and my recommended first move was a "differential harness" — a machine built to CONFIRM my guessed bug-shape.

**Why this is wrong:** a hypothesis makes you read to confirm it; the bug that survives N audits has NO name, matches NO template, so a confirmation-harness glides right over it. A differential harness comparing interp-vs-JIT finds ONLY divergences of the type I already hypothesized — blind to the anomaly that is a value changing *meaning* across the FFI, a *unit* shifting under custom pricing, a bound disappearing at a merge.

**How to apply:** the discovery geste is NOT "build a harness to find bug-type-X." It is: take ONE real value and trace it hop-by-hop across the actual seam (swap↔oracle / Rust↔C++ / interp↔JIT / exec↔state-root), asking at each hop only *"what does this value BECOME here, is it coherent with what it was before?"* Write the flow `A enters → f() turns it into B → g() consumes it as if it were C`. The anomaly is the hop where B ≠ what g() assumes — you didn't search for it, you SAW it by tracing. The harness comes AFTER, as the bloc-6 tool to prove the found anomaly as an observed state-delta — never as the discovery instrument.

**Tell to self-catch:** when you write "build a differential/fuzz harness to find X" or an agent prompt says "HUNT: a [bug-class] where...", you are confirming a hypothesis. STOP — go trace the real flow at the couture instead. Triage-as-hypothesis is OK for RANKING candidate paths; carrying the confirmation-stance INTO the dig (Pass 1) is the trap. Relates to [[feedback-audited-target-hunt-invariant-not-class]], [[protocol-fortress-null-hunt]], [[monad-node-bounty-triage-go]].
