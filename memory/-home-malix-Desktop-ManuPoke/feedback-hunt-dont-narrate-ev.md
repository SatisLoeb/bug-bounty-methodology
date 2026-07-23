---
name: feedback-hunt-dont-narrate-ev
description: "High-EV work gets HUNTED, not catalogued. Never present remaining-EV as a to-do list, never set aside a \"fortress\" or \"tooled barrage\" as a later step — pursue all of it now, report results."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Operator (2026-07-20, Rheo), sharp and correct: "tu crois que je fais tout ça pour m'amuser ou pour gagner de
l'argent et nourrir ma famille? si tu laisses des trucs à haut EV de côté je ne sais pas comment le prendre." I had
written a status message framing the live-EV angles as "ce qui reste à haut EV" — a to-do list I was reciting — AND
I had waved away two real EV sources: the Size core ("fortress, diff-mode only, de-prioritize") and the tooled barrage
("next step"). Both are the exact errors the setup already forbids (CLAUDE.md First Maxim: "fortress → moving on" is
the reflex-conclusion to attack, not accept; CHASSE: "le no-find est le verdict le PLUS DUR à justifier, jamais le
défaut confortable; ratio d'effort = GÉNÉRER des vols pas prouver l'absence").

**Why:** the operator hunts bug bounties for income, not sport. Naming high-EV work without doing it, or setting aside
a surface because it "looks audited," directly costs money. The setup (prompts/skills/CLAUDE.md) is CLEAR; the failure
was my posture, not their clarity.

**How to apply:**
- Never write "here's what remains at high EV" as a deliverable. If it has EV, LAUNCH it (agent/workflow/tooling) in
  the same turn, then report RESULTS. A status message lists what is RUNNING, not what is pending.
- "Fortress / heavily-audited" is NOT a skip — it's a DIFF target: check what shipped post-audit (new features, the
  delta since the last audit commit) and hunt that fresh surface. On Size core the delta was MarketShutdown/debtTokenCap/
  remove-market/rheo-fm — real fresh nests I nearly skipped.
- The tooled barrage (slither/aderyn/semgrep + the target's own fuzz-config negative-space) is cheap and runs in
  parallel — never defer it as a "next step," fire it alongside the manual read.
- Pursue every in-scope repo, not just the freshest one. Both repos in a bounty scope carry the same reward tier.
- Reading a file and calling a class "standard/tight" is a hypothesis to attack with an executed artifact, not a
  verdict to rest on. See [[feedback-trigger-reachability-is-payability-gate]] (the OTHER half: reachable-trigger is
  required for payability) — the two are a pair: hunt EVERYTHING hard (this), credit only reachable triggers (that).
