---
name: feedback-a-known-issue-note-is-a-dup-fossil
description: "A dated \"known and accepted\" note in a target's own repo is evidence a prior report exists, not just a design-intent argument to rebut"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dee528a0-0d9e-4bc1-b625-4ce067702e36
  modified: 2026-08-06T10:42:30.411Z
---

TruFin F-1 (2026-08-05) was closed **duplicate of #79034** three hours after submission, with
#79542, #86749 also cited and #83147/#87225 already closed as dups of it. **Five prior reports on
the identical mechanism.** $0.

**NOVELTY IS BINARY AND ORTHOGONAL TO QUALITY.** My report beat #79034 on every measurable axis:
2 attoINJ vs their 0.1 INJ, the `add_message`-vs-`add_submessage` mechanism they missed (TruYields
credited it by name), 4 tests with baseline + disconfirmer + harness validation vs their 1 bare
test, the `min_deposit` in/out asymmetry as root cause, and 99.91%-of-stake concentration measured
on-chain vs their "does not necessarily freeze the whole vault". **A strictly superior artifact on
the same finding is worth $0.** No amount of write-up quality converts a duplicate into a payment.
This is the hardest lesson: it is not "I was unlucky", it is "quality does not buy novelty".

**What I got wrong, and it was not the technical work.** The finding was real and they confirmed
every mechanical claim. What failed was the dup call.

1. **A dated "known and accepted" note in the target's own repo is a DUP FOSSIL, not merely a
   design-intent obstacle.** `contracts/injective-staker/README.md`, commit `9cc8862`, 2026-05-21:
   "We treat this as a known and accepted operational property." Teams do not pre-emptively
   document an obscure chain-parameter interaction. They document it **because someone reported
   it**. The commit date approximates when the first report landed. I read that note, argued
   against it for six review rounds, and named a Known-Issue close "the single most likely adverse
   outcome" — but I treated it as an argument to defeat rather than as evidence of a report I
   could not see.

2. **Corpus dup-checks are structurally blind to bug-bounty program submissions.** My check
   returned 0 hits for `max_entries` across 2971 findings / 53 competitions, and that was TRUE and
   IRRELEVANT: the Immunefi corpus covers **audit competitions only**. Private program reports
   (#79034 etc.) exist in no corpus and are unknowable from outside. A clean corpus result on a
   *bounty program* means "no competition found this", never "nobody reported this". Never quote a
   corpus non-dup as dup evidence for a program submission.

3. **My own report contained the project's rebuttal.** Their stated reason the floor is deliberate
   ("a user must always be able to exit their full position") is exactly the full-exit constraint I
   derived myself in the Recommended Fix after operator pressure. When your own fix analysis
   surfaces the design constraint that justifies the current behaviour, that is a KILL signal on
   the finding, not a refinement of it.

**ENCODED AS A GATE (2026-08-05), do not re-derive by hand.**
`~/arsenal/audit-lifecycle/bin/dup-fossil-check.sh <repo> [mechanism-keyword ...]` greps git
history for 12 acceptance markers plus the mechanism, prints dated hits, exits 1 on any hit. Wired
as **step 0 of `on-finding.sh --stage 1`**, before the scope check. Retroactive proof on TruFin:
5 hits, the decisive one `9cc8862` 2026-05-21 — **one day after #79034 was filed on 2026-05-20**.
The note is the triage response promoted to documentation, and the timestamp shows it.

On exit 1 the gate demands two one-line answers before any further hour is spent: what impact does
my finding reach that the note does NOT cover, and which actor reaches it that the note's threat
model excludes. If either answer is "a better PoC" or "more precise numbers", stop and re-source. Combine with [[feedback-audit-acknowledgment-is-a-liability-not-an-asset]]
(same family: the target's own acknowledgment is a liability) and
[[feedback-hardening-is-not-verification]] (six rounds of hardening never questioned the dup call).

Related: [[trufin-immunefi-injective-unbonding-freeze]], [[immunefi-corpus-wiring]],
[[ev-gate-check-program-responsiveness-not-just-severity]].
