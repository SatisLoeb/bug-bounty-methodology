---
name: feedback-commit-anchored-scope-pays-deployment-impact
description: "When a bounty scope is anchored on a COMMIT (not on TVL/balances), a testnet/devnet-only status is a fact about today's TVL, not a ceiling on the finding — cite the anchoring next to your honest devnet admission."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 23c2ad63-ea6a-4ea6-bb7a-7c534409af1f
---

When a program's scope is anchored on a specific COMMIT of the code (not on current on-chain balances/TVL), a "devnet-only / no TVL today" status is a fact about today's deployment, NOT a ceiling on severity. The program pays the vulnerability in the designated code judged on its impact ONCE DEPLOYED.

**Why:** scorers reflexively reach for "it's testnet → downgrade." The commit-anchoring is the sentence that pre-empts that reflex — it makes the honest devnet admission a non-issue instead of a severity-reduction motive. Volunteering the devnet fact yourself (rather than hiding it) is also what a careful scorer trusts; the anchoring is what protects it.

**How to apply:**
- Read the scope doc, find the phrase that anchors on a commit/target rather than balances, and QUOTE it in the Impact section right next to your honest "devnet-only today" line.
- Verify EVERY cited line ref against that exact commit: `git rev-parse HEAD` must equal the scope commit, then confirm each `file:line` still points at the claimed code. A scorer who opens the commit must land on the right numbers — a stale ref is a free reason to bounce the report.
- Keep the impact framing honest (no "headline chain" / current-TVL overreach); the commit-scope carries the "once deployed" weight, you don't need to inflate today's numbers.

On Push Chain F-A01: scope anchored on commit `0648551`, in-scope universalClient = Critical target; devnet TVL admitted openly, severity defended via the anchoring. Cross-ref [[project-push-chain-dualdefense]].
