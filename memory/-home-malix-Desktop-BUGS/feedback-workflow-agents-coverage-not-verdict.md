---
name: feedback-workflow-agents-coverage-not-verdict
description: "Workflow fan-out agents are for COVERAGE/mechanism-mapping only, never for the verdict; the agent-then-verify-each loop is double work because they over-claim severity/reachability"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 9a12e8ad-70ee-468d-ac8c-4d9586294984
---

Operator critique (2026-06-24, Injective exchange firmaudit): "utiliser les agents workflow nous fait faire un
double travail puisque 90% de leur output est un faux positif ensuite toi tu les vérifie un à un."

**The accurate decomposition:** workflow/fan-out agents are RELIABLE on the **mechanism** (correct `file:line`, both
legs of an asymmetry, the arithmetic) but UNRELIABLE on the **verdict** (severity / reachability / scope / net-economics).
Concrete proof this session: agents labeled a BO trading-rewards-farming vector **High** — hand-verification walked it
to **Medium-dormant** (no active campaign on-chain, known class, reactive `DisqualifiedMarketIds` mitigation). The
mechanism legs were all correct; only the conclusion was inflated. This is the universal pattern, not a one-off.

**Why:** [[doctrine-surgical-reports-fight-to-the-end]] — verify every load-bearing claim. The CLAUDE.md standing order
("agents over-report 10:1 on audited code; never trust agent/workflow output") is precisely this. The cost the operator
names is real: agent emits → I re-read the same code to verify → duplication.

**How to apply (the correction, going forward):**
- Use fan-out agents ONLY for what they're good at: COVERAGE breadth on a too-big-for-one-context target (e.g. 85K LOC),
  and MECHANICAL mapping (enumerate every caller, cartograph a subsystem, build the null-note coverage map = the
  anti-shallow-dismissal proof). NEVER outsource the verdict to them.
- I OWN the verdict layer by reading the code directly — severity, reachability, conservation, scope, net-economics.
  Do not re-validate their conclusion; derive my own from primary source.
- Hand-verify ONLY (a) the survivors that clear the in-workflow adversarial verifier, and (b) the load-bearing
  contradictions between agents (the spot-vs-BO catch this session). NOT all candidates one-by-one.
- The nuance that keeps fan-out worth it: it is NOT 90% spam — the in-workflow VERIFIER stage refutes most candidates
  before they reach me, and most lanes return clean nulls with coverage maps. The value is the coverage guarantee on a
  target one context can't hold. But when a target turns fortress-like (declining marginal returns after 2 deep passes),
  STOP fanning out and switch to a single focused direct deep-read on the one highest-value unexhausted surface.
- Rule of thumb: if I'd have to re-read the code to trust the answer anyway, and the surface fits one context, read it
  DIRECTLY instead of dispatching an agent. Reserve the fan-out for genuine breadth (many subsystems, parallel coverage).
