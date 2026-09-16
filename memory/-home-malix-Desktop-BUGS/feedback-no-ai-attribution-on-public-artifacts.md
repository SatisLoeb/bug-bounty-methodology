---
name: feedback-no-ai-attribution-on-public-artifacts
description: "Never put Claude/AI attribution on the operator's outward-facing artifacts — commits, PRs, reports, advisories"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c442e7ec-5cfa-4063-970f-f1c671671f14
  modified: 2026-08-11T09:40:59.822Z
---

**No Claude/AI attribution on anything the operator publishes.** No `Co-Authored-By: Claude`, no "generated with", no "AI-assisted", no assistant/bot markers — in commits, PR titles/bodies, bug bounty reports, advisories, or any external-facing text. This OVERRIDES the default Claude Code convention of appending a `Co-Authored-By` trailer to commits.

**Why:** the operator is the author of record — he directs the work, reviews every artifact, and owns the reputation attached to it. Bug bounty and OSS credibility are permanent capital in his line of work, and several platforms actively screen against AI-authored submissions (this is the same reason the `chill` skill exists and why "em-dashes → 0" is a hard gate). An AI tag on a public contribution is a liability with zero upside for him. Stated 2026-08-11 on the Sei courtesy PR: "re fais le sans tag de claude ni aucune AI."

**How to apply:**
- Default to NO trailer on any commit that will be pushed to a repo he publishes to. Do not ask each time.
- Before pushing/submitting anything public, grep the artifact for `claude|anthropic|co-authored|generated with|\bAI\b|copilot|assistant` — message, diff, author AND committer fields, PR title and body.
- If an AI tag already went out: prefer **amend + force-push** over closing and reopening. A closed PR is permanent and public, so closing leaves MORE tagged material visible, not less. Amending removes it from the live artifact and preserves the option to close later; closing forecloses that option. (Applied on sei-chain PR #3895: aba4f40 → 43c9e0c.)
- Note the residue honestly: a force-push leaves a timeline entry and the old SHA stays fetchable on GitHub for a while. Say so rather than claiming a clean erase.

Related: [[doctrine-surgical-reports-fight-to-the-end]], [[feedback-report-size-must-match-finding-size-overproduction-is-the-llm-tell]], [[sei-giga-executor-engagement]].
