---
name: feedback-check-prior-audits-and-competitions-at-intake
description: "The saturation-first landscape scan systematically UNDER-estimates saturation. Before committing depth, grep the repo's audits/ folder + count prior Cantina/Sherlock competitions + the program's submission/paid stats. Do it at INTAKE, not as a post-mortem."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

**The recurring failure of this session (2026-07-20/21):** every "fresh / low-saturation" target the landscape scan
recommended turned out MORE audited than the scan credited, and I discovered it only AFTER spending a hunt:
- Symbiotic: "fresh V2" → 8 audits in folder/audits/.
- Rheo/Size: "2-audit meta-vault" → the core is 10-audit; collections was Cantina-2025-06-audited.
- USDai: "1 Cantina audit, low dup" → 640 submissions + 2-3 audits, and the vein was OOS anyway.
- Citrea/Clementine: "thin-competition BitVM niche" → Sigma Prime v2.0 + a Cantina COMPETITION (CMT-01..36) in the repo's
  audits/ folder; 473 submissions / $2,100 paid.
Each time the workflow found the audits/ folder and deduped in the FIRST pass — meaning the intel was sitting in the repo
the whole time, and I could have known BEFORE launching the hunt.

**Why:** the operator hunts for income; a session of rigorous NULLs on fortresses is the cost of bad target-selection, not
bad hunting. The landscape-scan "saturation: low" label is a WEAK prior — it reads reward/age/platform, not the actual
review history. The real saturation signal is: (1) the repo's own audits/ folder (grep it), (2) prior Cantina/Sherlock/C4
COMPETITIONS on the same code (a competition = 50-500 researchers already swept it), (3) the program's submission count vs
paid total (473 subs / $2.1k paid = fortress). All three are checkable in minutes.

**How to apply — a MANDATORY intake gate BEFORE any hunt workflow, per target:**
1. Clone the repo, `find . -ipath '*audit*'` + read the audit list + the findings (Resolved = dup/ineligible).
2. Search: has this exact code been in a Cantina/Sherlock/C4 competition? (a competition ⇒ treat as diff-mode-only.)
3. Read the program's stats: submissions, total paid, hacker count. High-subs + low-paid = fortress.
4. Only if the crown-jewel seam is genuinely OUTSIDE what the audits+competitions covered (a fresh module, a post-audit
   delta, a composition/off-chain seam no single review owns) → GO. Otherwise RE-SOURCE before spending depth.
The genuinely-payable solo target is PRE-audit or a fresh un-competed module, NOT a "low-reward niche" that has already had
a firm audit + a crowd competition. Pairs with [[feedback-hunt-dont-narrate-ev]], [[feedback-read-both-or-clauses-in-exclusions]],
[[reference-landscape-scan-2026-07-20]] (whose "low saturation" labels proved unreliable).
