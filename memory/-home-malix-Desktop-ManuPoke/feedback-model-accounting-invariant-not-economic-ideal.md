---
name: feedback-model-accounting-invariant-not-economic-ideal
description: "At xseam Étape 1, model the invariant as the protocol's ACCOUNTING promise (what it commits to state, and when), not the economic ideal — a value stale vs external reality is not a seam if the invariant only binds it to accepted/booked state."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

The single most load-bearing correction from Perena #83 (operator, 2026-07-23, after 2× rejection): the
error was at **xseam Étape 1 (model the product invariant), not Étape 5 (the PoC)**. I wrote the
invariant in ECONOMIC terms — "the junior tranche absorbs the loss" — when the protocol's real promise
is ACCOUNTING: "the junior absorbs losses the protocol has **ACCEPTED**." Under the true invariant
nothing was broken. What I called a staleness seam was the **accounting boundary the protocol
deliberately drew** (`losses_accepted` flag, `apply_capital_loss` / `trigger_vault_circuit_breaker`
trusted-signer booking, `VaultLossNotAccepted` gate). The word "accepted" WAS the whole finding, and it
was in the code the entire time.

**Why this is the deepest xseam failure mode:** Étape 1 is the foundation; a mis-modeled invariant makes
every downstream artifact chase a phantom. Worse, my Step-3 PoC (junior instant-unstake payout
**byte-identical when the external vault value is cut 40%**) — which I read as "seam confirmed!" — was
actually **proof the invariant HOLDS**: the junior price reflects accepted state, there is no accepted
loss, so decoupling from external vault reality is the design, not a leak. **A "decoupled from external
reality" result confirms an accounting boundary as often as it exposes a seam.** I mistook
design-confirmation for seam-discovery and built a report + appeal + fork re-drive on top of it. The
triager's kill was precisely this: "the untrusted action is only exiting before those trusted workflows
have updated the tranche state" + live vault decodes `losses_accepted = 0` (no accepted loss exists).

**The tell I missed:** my invariant was economic ("absorbs the loss" = silently inserts "on
realization"), but the protocol's controls were accounting ("accepted losses", explicit accept/book
gates). **When a protocol has explicit accept/book/commit gates around a value, the invariant is
accounting-scoped, not economic.** "Stale between bookings" is by-design.

**How to apply — at xseam Étape 1, before writing the invariant:**
1. Ask "what does the protocol COMMIT TO STATE, and WHEN?" — not "what is economically true." Write the
   invariant in terms of the protocol's own booked/accepted state, not the external ideal.
2. Distinguish "reflects X" from "reflects booked-X." A staleness seam is real ONLY if the protocol
   PROMISES the stored value is fresh w.r.t. the thing you're comparing it to. If freshness w.r.t.
   external X is gated behind a trusted booking step (a `*_accepted` flag, an admin `apply_*`, a keeper
   `refresh_*`), then lag vs external-X is the accounting boundary, NOT a seam.
3. Treat a "decoupled from external reality" PoC result as AMBIGUOUS: it confirms a deliberate accounting
   boundary just as easily as it exposes a leak. Resolve which by reading whether the protocol commits
   to that freshness — do not read decoupling as automatic seam-confirmation (Second Maxim inverted: a
   deliberately-written boundary read as an exploitable silence).

This sits UPSTREAM of [[feedback-trigger-reachability-is-payability-gate]]: even if the adverse trigger
were unprivileged-reachable, there is no bug because the invariant is not violated. It is the Étape-1
version of [[feedback-invariant-that-passes-is-not-a-finding]] — here the "invariant that passes" was
the one I should have MODELED, and my green decoupling-PoC was passing it. Pairs
[[project-perena-bankineco-intake]]. Contrast the clean case: [[project-stackingdao-stbtc-double-count]]
— there the invariant IS accounting ("Σ tracked amount ≤ real balance") and the user's own
deposit→refresh→withdraw sequence VIOLATES it and CREATES the adverse state, unprivileged. That is a real
seam; Perena was the accounting boundary mistaken for one.
