---
name: doctrine-seam-rattachement-is-the-value
description: "At a seam/intersection the scope-anchoring work IS the value, not overhead — build the rattachement in parallel with the PoC; fertile and demanding are the same coin (Helix)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 676ee768-18be-4105-b623-333fd6940088
---

Vulns live at intersections because the intersection is the **organizational blind spot**: each team
assumed the OTHER guarded the boundary (SC auditors assumed the off-chain keeper posts sanely; the
keeper/ops assumed the contract enforces it) → the handoff is un-audited BY CONSTRUCTION. That is why
it is the most FERTILE surface. But the same fact makes it the most DEMANDING: since nobody owns the
seam, you must **prove which side you are on** so the impact resolves IN-SCOPE. Fertile (under-audited)
and demanding (must anchor the scope) are the SAME coin — Helix #134 required enormous scope-work AND
paid the most precisely because the two go together.

**Why:** finding the bug at the seam is only half the work. The triager's first reflex on a seam finding
is to push it OUT of scope ("that's the keeper's/admin's side", "design choice", "not under intended
operation", "vendor-side impact"). The money is unlocked by the **rattachement** — the argument that
resolves the scope ambiguity in our favor. The scope-work is not overhead; it is the value.

**How to apply (build the rattachement FROM THE START, in parallel with the disconfirmer-PoC, never bolted on):**
1. **WHO acts** — prove the actor is the UNTRUSTED side (the trader arbitraging the lag), not the trusted
   side (the honest keeper). Classify by who reaches the bug, not who configured the value. (banned-move #1)
2. **Honest-trusted-party framing** — show the trusted party behaves CORRECTLY (keeper posts the right
   delta on time); the loss arises anyway → not admin-misbehavior, not a privileged-address attack (OOS).
3. **Intended-operation framing** — show the exposure occurs under intended-and-reasonable operation and is
   NOT "reasonably avoidable by config" (the discrete lag is inherent — the keeper CAN'T post continuously).
   This pre-empts the program's "not exposed under intended operation" exclusion.
4. **Impact-target test** — the demonstrable harm must land on an IN-SCOPE asset (honest counterparties'
   funds / protocol solvency), never a vendor/the keeper's own funds (the F-POLY execute-then-classify gate).
5. **Category** — frame as an ECONOMIC EXPLOIT (systemic, case-by-case) when it's funding-theft/insolvency,
   not a coding-bug, so it's scored on total economic damage, not a capped technical tier.

Links: [[doctrine-defense-shadow-confession]] (the dev's timing-guard is an aveu he stopped at the TIMING,
not the trader's exploitation of the between-posts shadow) · [[doctrine-surgical-reports-fight-to-the-end]]
(the rattachement is what you defend surgically to the end).
