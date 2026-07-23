---
name: feedback-today-impact-before-poc
description: "Bug bounties pay for vulns with impact TODAY (value at risk NOW). Check on-chain reachability + live value-at-risk BEFORE investing in a PoC — one cast call beats 100 lines of Foundry on a dormant target."
metadata:
  node_type: memory
  type: feedback
  originSessionId: a62cfad9-335c-409f-86e0-a0898ae7594a
---

Operator, on the Aztec engagement: *« les protocoles paient les vulns qui ont un impact aujourd'hui. »* A code-correct, PoC-green vulnerability with **zero value at risk today** is **not payable**, full stop — most funds-at-risk-weighted programs (Cantina/Immunefi) reject or QA-tier a dormant finding no matter how clean the PoC.

**What I did wrong (the anti-pattern):** found the MATP milestone-vesting bypass (MATPCore.approveStaker uncapped vs LATP capped → beneficiary drains milestone-locked allocation via the Withdrawable staker), confirmed it by READING, then built a full Foundry PoC on mocks (green: "bob drained 999 while Pending"). ONLY THEN did I check the live chain — and `getNextMilestoneId() == 0` → no milestones ever created → `createMATP` (requires a Pending milestone) can't succeed → **zero MATP instances exist → zero value at risk.** The whole milestone subsystem is deployed-but-dormant. The bypass is real and code-reachable (executeAllowedAt=0, v2 Withdrawable staker registered with WITHDRAWAL_TIMESTAMP already passed), but there is nothing to drain. A mine armed in an empty room.

**Why:** I have the exact gate for this — KILL-GATE Q5b / the reachability+impact discipline ([[feedback-model-window-actors-day-one]]) — and I applied it as a *report* gate, not to my OWN candidate BEFORE the PoC. The green PoC on mocks proves the CODE PATH, never live impact: on mocks I registered the staker and set the timestamps myself; only the on-chain read tells me if a real target instance exists and holds value.

**How to apply — front-load the today-impact check, it's the FIRST PoC not the last:** the moment a candidate is confirmed-by-reading, BEFORE writing any harness, run the cheapest on-chain reads that answer (a) **does a live instance exist** (event scan / a count getter like nextMilestoneId / nextId==0 = dormant), (b) **does it hold value NOW** (balanceOf the target), (c) **are the enabling gates open TODAY** (timestamps/flags read live, not the code default — Aztec's deployed executeAllowedAt was 0, not the code's 1798761600). One `cast call` (nextMilestoneId==0) would have killed the PoC investment in 5 seconds. Only build the PoC once value-at-risk-today is established. If a finding is real-but-dormant, say so plainly and PARK it (watch nextId/ATPCreated); do not dress it as a live Critical — that's the theatre the operator rejects. Relates to [[feedback-manual-poke-mandatory-bracket]] (poke found it; discipline packages it) and [[feedback-commit-anchored-scope-pays-deployment-impact]] (the ONE exception: when scope is commit-anchored not TVL, dormant-today ≠ severity ceiling — but the DEFAULT bounty stance is funds-at-risk-today).
