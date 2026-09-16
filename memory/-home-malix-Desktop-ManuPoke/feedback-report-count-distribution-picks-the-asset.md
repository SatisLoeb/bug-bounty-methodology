---
name: feedback-report-count-distribution-picks-the-asset
description: "Asset report count measures RESOLVED reports, not submitted ones — it is a queue-latency signal, not freshness. The metric that predicts dup risk is date_added, and it decays in weeks."
metadata:
  node_type: memory
  type: feedback
  originSessionId: b21e2ab0-0b36-418d-9c86-89dc0cf6159c
  modified: 2026-07-29T16:17:29.371Z
---

On a multi-asset bounty program, still read the scope table before picking where to look — but read
the right column. **The per-asset report count counts RESOLVED reports. It does not count submitted
ones.** A zero there is a statement about the triage queue, not about the surface.

**Why — this memory's original evidence was refuted by its own follow-up.** The first version of
this note said: hunt the 0%-report asset, and cited 1win (H1) as proof. That prediction failed.

- April 2026: F-001, a fully-executed 2-account OAuth ATO on `1win.com`, the asset holding **10
  reports = 91% of the program total** → **Duplicate #3328634 in 48h**. $0.
- July 2026: switched to `1w.run`, the asset showing **0 reports** after five months → F-004
  confirmed blind SSRF, executed with OOB proof, submitted 2026-07-26 → **Duplicate #3643826 in
  ~24h**. $0.

Two engagements, opposite asset choices, identical outcome. The "0 reports" reading was the error:
`1w.run` was added to scope in **2026-02**, and an affiliate panel with two-minute self-service
signup and an outbound postback dispatcher had been open to every researcher on the platform for
five months. The counter sat at zero because nothing had been *resolved* yet, and the collision
proves submissions were already queued behind it.

**How to apply:**
- **Rank by `date_added DESC` first.** Recency is the metric that actually predicts contention.
  Report count is secondary and only describes *paid/closed* history.
- **Assume the useful window is weeks, not months.** An asset five months into scope is not fresh
  regardless of what the counter says. Roughly: <2 weeks = genuinely fresh; 1–2 months = contested;
  >3 months with an obvious money path = assume someone already filed.
- **A 0-resolved counter on a program with slow triage is unmeasurable, not empty.** When you cannot
  see submitted volume, treat any attractive surface (open signup + money path + outbound fetch)
  as contested by default and price the engagement accordingly.
- Cross-check where you can: disclosed reports, hacktivity, program response-time stats. Where the
  program gags disclosure, dedup-by-inspection is simply not executable — say so at intake instead
  of substituting the resolved-count for it (cf. the Wolt intake, where both the program and its
  suspended Intigriti predecessor gag disclosure and 862 prior submissions were invisible).
- Corollary, now sharper: **a duplicate is a calendar outcome, not a skill outcome.** Neither report
  quality nor asset switching reduces it. Do not respond to a dup by hunting the same program
  harder — F-004 was a materially better report than F-001 and died the same way.
- What you still get from a fresh-looking asset: it is often a *different application* than the
  flagship (`1w.run` was a separate Nuxt affiliate portal — different auth, API, team, money path).
  That is a reason to expect *different bug classes*, not a reason to expect no competition.

Relates to [[project-1win-postback-ssrf]], [[project-wolt-hackerone-intake]], and
[[feedback-check-prior-audits-and-competitions-at-intake]].
