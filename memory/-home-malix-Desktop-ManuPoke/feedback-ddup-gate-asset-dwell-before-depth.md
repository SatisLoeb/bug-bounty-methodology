---
name: feedback-ddup-gate-asset-dwell-before-depth
description: "Install D-DUP: a blocking pre-engagement gate on asset DWELL + prior-art + obviousness rank. The gate stack judges whether a finding is GOOD; none checks whether it is FIRST — which is what actually kills reports."
metadata:
  node_type: memory
  type: feedback
  originSessionId: 108e7074-fbb8-4383-aebf-841043053102
  modified: 2026-07-29T17:06:19.556Z
---

Run **D-DUP** at intake (to pick the asset) and again immediately before filing (to price the
slot). It is blocking, and it produces pasted artifacts, not prose.

**Why:** 1win (H1) ran two full engagements, April and July 2026. Both produced fully-executed HIGH
findings. Both closed as duplicates. $0 lifetime. Both cleared *every* gate the workspace runs —
scope-check, severity-commit, weight-card, chain-proof, a ten-angle adversarial rebuttal, and
mechanical preflight (PASS ×7 on the lifecycle log).

The stack is **asymmetric**. Scope, severity, chain, weight and adversarial survivability each get
a dedicated artifact. **Dup risk got one prose paragraph inside a rebuttal document**, answered
with a metric that structurally cannot see the collision. The engagement died on the only axis with
no gate — twice.

Two aggravating details worth remembering, because both are easy to repeat:

- The rebuttal's dup angle *named* the risk, dismissed it on the report-count distribution, and
  prescribed "re-check the report count immediately before filing." Executing that instruction
  faithfully would have returned zero again and greenlit the filing again. **A remedy that reads
  the metric which cannot see the failure is worse than no remedy — it manufactures confidence.**
- The mechanism that would have caught it was physically present and never run. A `kill-gate.md`
  template sat in `findings/` under an F-004 name carrying a CONFIRMED `dup-canonical-check`
  pattern whose pre-submit step is exactly "search hacktivity for this class on this asset." It was
  53 KB of blank boilerplate — zero mentions of the target — while the progress log's
  "gates cleared" list silently omitted it. **A template in the directory is not a gate that ran.
  Verify a gate fired by grepping its artifact for the target's name.**

## The gate

**PASS requires 1 and (2 or 3).**

**1. Dwell.** Record the asset's `date_added` verbatim from the scope table. Compute
`dwell = today − date_added`. Paste both.
- `dwell < 60 days` → PASS this check.
- `dwell ≥ 60 days` → the asset is **PRESUMED ALREADY FILED** on every obvious money path.

*The resolved-report count is NOT an input to this gate and may not be cited anywhere in it.*
It measures the triage queue's throughput, not the asset's exposure. See
[[feedback-report-count-distribution-picks-the-asset]].

**2. Prior-art sweep, executed.** Paste URL + hit count for each of: hacktivity search on the
finding class scoped to the program; the program's disclosed reports; asset hostname + class in a
public search. Zero across all three → PASS. Any hit naming the class on this asset → **STOP.**

**3. Obviousness rank.** Enumerate the obvious money paths on the asset (outbound fetcher /
file-or-app builder / auth / payout). State which ordinal your finding occupies for a competent
hunter arriving cold. **Rank 1 or 2 with `dwell ≥ 60 days` → FAIL.** PASS only if the finding
requires a state a self-service account cannot reach — and name that state.

**Intake rule this enforces:** rank candidate assets by `date_added` **DESC**, never by report
count ASC. An asset in scope > 3 months with an obvious money path is presumed already filed and is
not worth a deep engagement regardless of how clean it looks.

## Applied retroactively

F-004 (affiliate postback SSRF on `1w.run`) **fails check 1** — dwell was 158 days. It **fails
check 3** — an outbound postback dispatcher on a self-service affiliate panel is rank-1, the first
place anyone looks. Check 2 was never run. The gate would have refused the engagement *before* the
OOB harness was built.

The deeper misdiagnosis: April's dup was read as a **crowding** failure and answered by switching
to an uncrowded asset. July applied that fix, produced a materially better report, and duped
**faster** (~24h vs 48h). The shared cause was asset **dwell time**, not asset crowding. Asset age
was recorded correctly in three separate artifacts and consistently read with the wrong sign.

Relates to [[project-1win-postback-ssrf]], [[feedback-report-count-distribution-picks-the-asset]],
[[feedback-check-prior-audits-and-competitions-at-intake]],
[[feedback-trigger-reachability-is-payability-gate]].
