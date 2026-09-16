---
name: feedback-derived-artefacts-are-part-of-the-diff
description: "When I de-escalate a claim in a report body, the derived artefacts (fix section, references, preflight grid, rejection matrix) keep the old strong claim unless I diff them too"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dee528a0-0d9e-4bc1-b625-4ce067702e36
  modified: 2026-07-30T13:05:49.280Z
---

Revising the BODY of a report and leaving the derived artefacts stale happened **three times on one
submission** (TruFin F-1, 2026-07-30) before the operator named the pattern. Each time I retracted an
overclaim in the prose and the same claim survived in: the Recommended Fix section, the References
annotations, the internal preflight grid, and the rejection matrix.

**Why:** the body is what I'm "writing"; the fix/refs/grid/matrix feel like metadata I already finished.
They aren't. The matrix in particular is where my **triage responses** come from, so a stale claim there is
the most expensive place for one to live: I would have replied to a triager with an argument my own report
contradicts, and they could quote my text back at me. Concretely, the matrix still said "the team's own
Aptos port meters it" after the body had established that the Aptos floor exists for an unrelated framework
reason and that NO port solved this problem.

**How to apply:** a claim retraction is a diff across the WHOLE artefact set, not an edit to a paragraph.
After changing any load-bearing claim, grep the full file for the retracted phrasing and check every one of:
fix/remediation section · reference annotations · preflight or rubric self-scoring · rejection matrix ·
title · memory notes · QUEUE/OUTCOMES rows. Mechanical close: grep the OLD claim's distinctive words and
require 0 hits outside an explicit "do not use this argument" note.

Corollary that also bit here: when a de-escalation makes an argument weaker, ALSO write the "do NOT argue X"
instruction into the matrix, not just the replacement. The matrix's job is to stop future-me reaching for
the retracted version under triage pressure.

Related: [[doctrine-surgical-reports-fight-to-the-end]],
[[feedback-refuted-by-tracing-the-guard-is-novel-reading]],
[[feedback-report-size-must-match-finding-size-overproduction-is-the-llm-tell]].
