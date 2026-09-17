---
name: feedback-method-was-all-filters-add-generation-and-recall
description: "The methodology was ALL filters (precision-only) → its optimum is the empty set → it ratcheted to NO-GO/fortress. Fix: 3 organs — GENERATE (spine, win-seed criterion) + FILTER (gates, demoted to stage-2) + MEASURE-RECALL (false-NO-GO ledger). Generate first; a NO-GO needs a kill-list."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-17T09:45:04.831Z
---

**The operator's diagnosis (2026-09-17), correct and formal.** The method's loss function had only a
PRECISION term (don't submit a bad finding: 3 axes, 5 gates, materiality — every organ a REJECT organ). A
machine of only filters has the **empty set as its optimum** (reject everything → precision perfect, recall
zero, nothing penalizes recall) — so it *ratchets toward NO-GO/fortress*, which is exactly what a whole session
produced (Lombard, Coinbase ×6, tenbin, alchemix — all "fortress", zero generated attacks). Three faces:
(1) only the precision term exists; (2) the **corpse-rule can only birth filters** — a filter can "die of its
absence" (clean corpse) but a generator cannot, so the corpse-rule is structurally incapable of producing a
generator; (3) **no recall metric** — a false NO-GO (abandoning a real bug) leaves no corpse by construction,
so the dominant error is invisible and un-penalized. Sharpest consequence: **the playbook documented the half
that never earned a dollar.** Every win (ENS Chief, Decentraland, Upshift, Royco, RSK, Granite-A) came from
GENERATION, never from a gate; gates only *prevented* bad submissions.

**Why / the fix (3 organs, built in `D-cve/playbook/`):**
1. **GENERATE — `generative-spine.md` (STAGE 1, primary, the earner).** Per surface, BEFORE any gate: write N
   attack-hypotheses the dev did NOT imagine (2nd-Maxim kernel). Admission criterion = the **WIN-SEED** (a
   generator enters when it PRODUCED a win — positive space from victories), the opposite-sign twin of the
   corpse-rule. Generators are invention-PROMPTS (cold-blackbox, guarded-wrong-variable, seam-density, P1–P9,
   dirty-numbers, differential, become-the-actor), NEVER a match-menu. Mine every win for the generator it seeds.
2. **FILTER — `finding-acceptance-standard.md` + playbook (STAGE 2, demoted).** Validates what stage 1 produced;
   never runs alone.
3. **MEASURE RECALL — `recall-ledger.md` + `recall-check.sh` (the missing loss term, with teeth).** Every NO-GO
   records its **kill-list** (hypotheses generated & how each died); a NO-GO without a kill-list is an un-hunted
   surface, not a NO-GO. `recall-check.sh` confronts each recalled target with public findings (reports.immunefi,
   comps) → a hit = **recall-corpse**: generation-gap (never hypothesized → names a missing generator) or
   gate-error (wrongly killed). Sparse signal (most findings private) but the only recall signal there is.

**How to apply.** GENERATE first, always — understanding the code is the model you then attack, not the goal.
File a NO-GO only with a kill-list. Run `recall-check.sh` on a cadence. Mine every paid/confirmed finding for a
generator (win-seed), not only losses for filters. **Anti-recursion test on every future organ: does it OUTPUT
attack-hypotheses (generator) or take a candidate → yes/no (filter)?** If it rejects, it is not generation.
The real proof is behavioral: watch whether the recall-ledger catches corpses and generation widens — not
whether these docs exist or the gate pass-rate looks clean. Related: [[edge-primitive-guarded-wrong-variable]],
[[feedback-seam-density-is-the-surface-selection-axis]], [[feedback-manual-poke-bracket-mandatory]],
[[ens-critical-chief-cold-reengagement]], [[feedback-no-dubious-low-submissions]].
