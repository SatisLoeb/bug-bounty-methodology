---
name: feedback-paid-report-writing-calibration
description: "How a report that actually got PAID on Immunefi is written — the proven voice/structure to match, from Decentraland #87537 ($4K Critical, Paid)"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f1a1c109-bacb-4d9a-86f8-2aa9c53f2da9
  modified: 2026-08-14T23:35:40.382Z
---

The operator's PAID report Decentraland #87537 ($4,000 Critical, Paid 2026-08-13) is the ground-truth template for report voice/rigor. Study it, not the abstract REPORT-STANDARD. Techniques that carried it through triage:

**Why:** these are the moves that survive a skeptical project-side reviewer (this program was project-triaged, not Immunefi-triaged) and convert to payment.

**How to apply (every report):**
- **Constant epistemic tagging: `(measured)` vs `(source)` vs `(not measured)`.** Every load-bearing claim is labeled by how it was established. The 5-services breadth table literally had a "measured / source / not-measured" column. Killshots are empirical (live reads, observed 401→200); inferences (CWE class, reachability of un-traced handlers) are hedged and explicitly flagged "not claiming."
- **Explicit "What this proves / What this does not prove"** in the PoC section. Pre-empts "you didn't demonstrate against a real victim / a live instance" BEFORE the triager says it. He wrote "I did not present any AuthChain belonging to another person, so I have not demonstrated the write against a victim's account" — and it *built* credibility rather than weakening the claim.
- **"What this is not"** section separating the finding from 3 nearby impact/exclusion lines, one by one, generously.
- **Provenance = "a bypass of a control you shipped deliberately"** — cite the exact PR/commit that introduced the guard, so the threat model isn't arguable. (StackingDAO analog = the M-02/M-04 fix-bypass framing.)
- **Duplicate check = hunt the trace the project leaves when it closes this class** (defensive doc entry / unmerged fix branch), citing how THIS project documents known issues, then show its absence across N repos.
- **Precise, restrained impact — explicitly DOWNGRADE what route-names would oversell** ("Two claims I want to keep precise rather than let route names carry them": publish doesn't spend MANA). The restraint is what makes the strong claims land.
- **Radical conduct honesty**: throwaway keypairs, minimal volume, and *flag your own leftover artifact* ("One artefact was left behind and I would rather flag it than have you find it"). Credibility multiplier.
- **Scope-clause rebuttal handled head-on** + offer to withdraw/re-file if they read it differently. Disarming, not defensive.
- **Follow-up discipline**: found a 2nd bug mid-thread → ASKED how to handle it (add here vs new report) instead of spamming; post-fix, re-verified from outside and flagged the one service left unpatched. Professional queue management = trust.
- em-dashes → 0 (confirmed in the paid text). Tables ARE fine on Immunefi (this paid report used narrow 3-5 col tables that rendered) — the "flatten all tables" rule is softer than I'd applied; simple tables OK, prose also fine.

**EV calibration anchor:** a Critical with NO funds access (off-chain, unpublished builder content) paid **$4,000** — the project scoped within Critical by funds-at-risk. So a real-funds Critical (e.g. StackingDAO insolvency, ~$147K sBTC + a $20K program floor) should clear well above $4K. And: the author did NOT fight the down-scope — conceded gracefully. Related: [[decentraland-critical-decodeauthchain-confirmed]], [[stackingdao-ststxbtc-double-count-live]], [[doctrine-surgical-reports-fight-to-the-end]], [[feedback-report-size-must-match-finding-size-overproduction-is-the-llm-tell]].
