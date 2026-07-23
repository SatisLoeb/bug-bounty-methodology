---
name: boros-tooling-calibration
description: "Pointer: the Boros-session tool/skill/corpus calibrations are encoded DURABLY (feedback files + darkside skill + corpus-query + a new cast tool), not just here — memory truncates, those load every session"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 676ee768-18be-4105-b623-333fd6940088
---

The Pendle Boros blind firmaudit (2026-06-24) produced 4 tooling calibrations. They are encoded in the
SOURCE-OF-TRUTH locations that load every session (NOT only in memory — memory truncates). This entry is a
POINTER; the content lives in:

1. **Workflow MAPS coverage, never DECIDES; hand-verify EVERY verdict incl REFUTED; grep callers before
   trusting "never called" (the `_bookMatch` dead-code waste).** → `~/arsenal/tracking/feedback_workflow_is_coverage_not_finding_handverify_every_verdict.md`
   + encoded as **darkside §0.5.3(e)** (loaded whole every darkside invocation).
2. **corpus `--methods` (the detection_tell → your investigative LENS) >> `--route` in real value — lead with
   `--methods`.** → `~/arsenal/tracking/feedback_corpus_methods_beats_route_lead_with_the_tell.md`
   + encoded in the **`corpus-query.sh` usage header** (the tool itself).
3. **Run the cheapest economic disconfirmer (magnitude gain vs cost, from on-chain reads + deployed fee/rate
   formulas) BEFORE the expensive fork PoC.** → `~/arsenal/tracking/feedback_cheapest_economic_disconfirmer_before_fork_poc.md`
   + referenced in darkside §0.5.3(e).
4. **On-chain reads: use `cast`, don't hand-parse hex** (the Etherscan-curl + python-extraction pattern caused
   repeated §0.5.3 self-corrections — wrong addresses, off-by-one slots, hand-decoded structs). → new tool
   **`~/arsenal/tools/onchain-read.sh`** (proxy/admin/call/slot/ctorargs/src via cast).

The earned-null OUTCOMES row is logged with `composition_skills_applied:[intake,firmaudit,darkside,corpus-query,
workflow]` (the SKILL-SELF-ATTRIBUTION measurement). Meta-lesson: the pipeline AIMED + MAPPED correctly; the
hand-verification DECIDED — every agent "Critical" was false; an honest null on a fortress is the pipeline
working, not failing. Relates to [[doctrine-verify-before-working-no-theater]], [[skill-infrastructure-topology]],
[[project-web-corpus-solodit-equivalent]].
