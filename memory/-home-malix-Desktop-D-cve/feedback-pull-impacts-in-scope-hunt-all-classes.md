---
name: feedback-pull-impacts-in-scope-hunt-all-classes
description: "Pull the program's Impacts-in-Scope table at Phase 0; hunt every payable class, not the theft reflex"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-17T00:09:11.062Z
---

**Mechanism to run at Phase 0, always, before fanout or manual poke:** copy the program's full
"Impacts in Scope" table VERBATIM (every tier). It is the hunt's TARGET MAP — the list of terminal
verbs to chase. Feed the WHOLE list to every finder and every manual poke, and keep an
**impact-ledger** (candidate × impact-class): a payable class with zero hunters is an un-hunted axis,
not a null.

**The failure it fixes — the THEFT REFLEX.** Default hunting optimizes for "direct theft / extraction"
(over-mint, dilution, senior-escapes-haircut) and silently under-covers the other payable classes:
**permanent freezing of funds, protocol insolvency, MEV→freeze/insolvency, temporary freezing,
SC-inoperable / DoS / resource-exhaustion, griefing.** On epoch/liveness-heavy protocols (credit
vaults, state machines, borrower funding, pause) the freeze/DoS/insolvency axis is often the RICHER
surface, and it is exactly what the theft-oriented fanout skips.

**Corpse (near-miss, caught by the operator, 2026-09-16):** on Pareto Credit the gated fanout + my
manual read proved the THEFT axis fair and I nearly closed NO-GO — having never run permanent-freeze /
insolvency / DoS as a first-class target. My coverage-ledger measured "entrypoint covered *for theft*",
not "covered for the other 3 Critical classes + the DoS Mediums" — a whole second axis skipped. Granite
finding A (the paid/escalated one) was itself a FREEZE (renewable liquidation blackout), not a theft —
proof the operator's edge spans freeze/liveness, so a theft-only sweep leaves money on the table.

**How to apply:** encoded operationally (not just here): playbook v1.6.1 §1 Phase 0; the gate-runner
`finding-acceptance-standard.md` step 0 ("PULL Impacts in Scope"); `audit-fanout-template.js`
(`args.impactsInScope` injected into every finder + the materiality gate, warns if absent). darkside's
THIEF-INVENTORY already says it ("chainability to a PAYABLE impact — theft first, but equally
freeze/halt/insolvency where the program pays"); the gap was not applying it in a themed fanout. Related:
[[feedback-dedup-per-sink-not-per-class]] [[feedback-test-in-dirty-numbers]] [[pareto-credit-nogo]].
