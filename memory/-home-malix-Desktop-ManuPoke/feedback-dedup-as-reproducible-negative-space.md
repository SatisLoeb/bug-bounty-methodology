---
name: feedback-dedup-as-reproducible-negative-space
description: "Defend a finding against known-class/dup pushback by converting \"not in the audit scope\" into a reproducible negative-space artifact, not an assertion"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 95853d7a-e236-418b-a353-da744a061ae8
---

When a finding risks a "known class / incomplete-fix / dup of prior audit" knock (e.g. Perena instant_unstake = un-guarded sibling of the M-01 staleness class the Hashlock review already fixed on mint/burn), the weak move is asserting "the tranche path was out of scope." The strong move is a REPRODUCIBLE NEGATIVE-SPACE artifact the triager can re-run on the same public document:
- cite the exact audited **commit hash** verbatim from the report (Hashlock: commit 97b69ae, "Program 1: programs/bankineco — Audited GitHub Commit Hash: 97b69ae7…"),
- give **grep counts = 0** across the whole report for every term that would prove coverage (tranche:0 junior:0 senior:0 kamino:0 apply_capital_loss:0 … over all 46 pages),
- quote the report's own **scope enumeration** ("Intended Functions" = the simple-vault ix set) showing the finding's instruction isn't in it,
- and KEEP a standalone path-direct fallback that stands without the audit ("the guard M-01 added lives on mint/burn; the unstake path has none").

**Why:** a triager who opens the same PDF at the same commit reproduces your zero-count → the dedup defense becomes checkable fact, not your word. **How to apply:** any finding that is a sibling of a fixed/known issue — source the "it's fresh" claim as a negative-space grep against the cited commit + report enumeration, never a bare assertion; and always carry a fallback that holds even if the audit-scope point were wrong. Pairs with report-nerve's negative-space articulation and [[feedback-check-prior-audits-and-competitions-at-intake]]. Instance: [[project-perena-bankineco-intake]] (4 rigor passes, dedup sourced verbatim, Medium submitted).
