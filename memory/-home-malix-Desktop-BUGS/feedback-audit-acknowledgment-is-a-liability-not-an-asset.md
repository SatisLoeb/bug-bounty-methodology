---
name: feedback-audit-acknowledgment-is-a-liability-not-an-asset
description: "In a bounty context an audit acknowledgment is the exclusion clause, never supporting evidence; read the program exclusion text BEFORE building, and grep published audits for the mechanism"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: bdadc85d-aa49-46b3-98d7-115c736ad457
  modified: 2026-08-01T12:16:15.316Z
---

**An audit acknowledgment is never an asset in a bounty context. It is always a liability.** If the
strongest formulation of a finding is "your own audit already flagged this", STOP and read the
program's exclusion text before writing anything else.

**Why:** third occurrence of the same error, and the first one that was fatal by written rule.
Perena (carried "same class as an audited finding" across six versions, misread). Berachain (cited
"the audit acknowledges slashing is unhandled" as plausibility support; operator flagged it as the
known-issue exclusion). Lombard 2026-08-01: I built a full High report whose headline section was
literally titled "Why this is the condition your audit already flagged" — that section IS the
disqualifying evidence, pre-packaged for the triager. Lombard's page kills it three times:
"known issues that the project is aware of but has consciously decided not to fix, or any
implemented operational mitigating procedures" (the team's verbatim response was "We accept this
attack and want to mitigate it by fees"), plus "any unfixed vulnerabilities mentioned in these
reports are not eligible", plus Primacy of Rules so no impact-based escape. The program also charges
a non-refundable fee at every severity, so filing = paying into a written exclusion. Second Ammalgam.

The Immunefi escape hatch ("if you can genuinely bypass the fix from a previous audit, it is valid")
does NOT apply to this shape: it requires a fix to bypass. "The promised fix was never deployed" is
by definition an *unfixed* vulnerability named in the report, i.e. squarely inside the exclusion.

**How to apply:**
- **Phase 0 gate, before any depth:** open the program page and read the exclusion text. The four
  fields (program listed / vault funded / date / assets) are not enough; add the exclusion regime and
  Impact-vs-Rules. On Lombard I never opened the program page at all across the whole engagement.
- **Grep the target's published audit reports for the mechanism BEFORE building.** If the mechanism
  appears as an acknowledged/unfixed finding, it is dead on arrival regardless of how good the PoC is.
  The audits are usually in the repo (`docs/audit/`) at the exact URL the program cites.
- **Cross-check the asset list against the contract the PoC actually targets.** Under Primacy of
  Rules an unlisted contract ends the question. On Lombard every interesting behaviour lived on the
  strategy `0xf14F678d…`, which is NOT a listed asset; the listed tranche assets were only the
  peripherals. I audited the out-of-scope contract for the whole engagement.
- Reading audits as a map of accepted conditions (firmaudit Phase A) stays correct as *methodology*.
  The error is failing to cross that map with the program's exclusion text before spending depth.

Related: [[feedback-target-diet-is-the-binding-constraint]], [[ev-gate-check-program-responsiveness-not-just-severity]],
[[feedback-reachability-is-kill-gate-not-severity-modifier]], [[lombard-strategy-tranche-oos-strategy-contract]]
