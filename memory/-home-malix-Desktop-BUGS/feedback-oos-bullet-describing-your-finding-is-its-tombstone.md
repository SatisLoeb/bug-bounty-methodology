---
name: feedback-oos-bullet-describing-your-finding-is-its-tombstone
description: "If the longest section of your report argues against a scope bullet that describes your finding, the bullet is the tombstone, not the obstacle"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8e9825ed-c199-4a09-82f6-dd5dbe4fdeea
  modified: 2026-08-08T16:38:47.366Z
---

**3F grunt (Cantina), closed DUPLICATE 2026-08-08, $0, fee refunded.** Triage had PASSED technical
review the day before: mechanism confirmed, PR#190 gate removal confirmed, invariant control accepted.
It died at client review on two independent grounds, and the second one was visible from day 0:
*"the program's published scope accepts performance-fee treatment of losses and economically imperfect
fee behavior."* That is the exact bullet the report opened by arguing against, across three paragraphs
that I helped write and later reinforced on request.

**Why:** an out-of-scope bullet that describes your finding in its own words is not an obstacle to
argue past, it is evidence that someone already reported the behaviour and the program wrote the
answer into the scope. Same shape as [[feedback-a-known-issue-note-is-a-dup-fossil]], one layer up:
there the fossil was a dated note in the target's repo, here it was a scope bullet. The tell is
EFFORT — when the longest, most-revised section of a report is a scope rebuttal, the scope is usually
right. I treated the length of that section as thoroughness; it was the finding's obituary.

**Second tell, independent and also pre-submission:** the finding self-downgraded High -> Medium on
its own live on-chain data (armed exposure $4,779 family-wide, zero liquidations over the market's
whole life, oracle max drawdown 0.0156% against the 10.78% needed, LTV drifting -0.48%/yr AWAY from
the boundary). A finding whose own evidence walks it down a tier, on a 4-audit target whose OOS list
is a confession map, is low-EV before it is written.

**Duplication density confirms it.** The cluster held at least FOUR reports on the same behaviour:
a primary plus #72 (Rejected), #74 (Duplicate) and #76 (mine, Duplicate). Cantina numbers sequentially
per program, so mine was third of the three visible siblings. The discovery path the report narrates
in its own opening ("I went through the commits that landed on main after the audits closed") is the
first thing every serious hunter does on a public 4-audit repo, so a post-audit delta on a public repo
is a CROWDED lane by construction, not a seam nobody owns. Combine that with a scope bullet naming the
behaviour and the dup probability approaches one.

**How to apply:** at intake, grep the OOS list for the finding's own mechanism BEFORE building. If a
bullet paraphrases it, treat that as a dup-fossil verdict and re-source, unless you can name a NEW
independent impact in one sentence without arguing about the bullet's wording. If the rebuttal needs
paragraphs, you have lost. Ordering matters too: ask the triager to confirm the duplicated report
predates yours, but only as a factual question, never as a dispute — and never dispute at all when
the report itself pre-committed to withdrawing on this exact condition, which this one did in
writing ("Say so and I'll withdraw it").

**What was NOT wrong:** the verification. 4 rounds, 25 PMs read live, full-life log scans on both
markets (186/186 and 136/136 clean), 28-point oracle history, an executed guard-patch disconfirmer,
gist byte-synced. Nothing was refuted. See [[grunt-fee-on-loss-verified-ready]] and
[[feedback-target-diet-is-the-binding-constraint]] — the work was firm-grade, the target was not.
