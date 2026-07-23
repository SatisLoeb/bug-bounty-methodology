---
name: dydx-bounty-sponsor-disengaged
description: "dYdX Cantina bounty 2026-06-24 — DROPPED: Cantina validates but dYdX (the client) funds/releases rewards and is disengaged → ~1yr to pay → p_bounty≈0 regardless of validation authority"
metadata: 
  node_type: memory
  type: project
  originSessionId: 64c38798-56f9-47f6-a77c-e98422231f3e
---

As of 2026-06-24, on the Cantina Discord a dYdX team member (handle `chiwalfrm`, verified — the "our new product" phrasing + a dYdX X/twitter link identify them as dYdX, NOT Cantina) stated publicly: *"we really don't do bug bounty any more due to lack of manpower… nobody has time to look into the bug bounty,"* pointing to a product launch ~1 week out. Cantina "runs the program end to end," but the crux question a hunter raised — whether Cantina can do final validation / severity / reward **independently** or **sponsor confirmation is still required** — was left UNANSWERED. The hunter (nikhil66) had two findings triaged then frozen "In review."

**RESOLUTION (same day):** Cantina Core Team (Arjun Rao) answered the crux directly — *"If flagged/escalated then Sponsor's input is needed, else Cantina."* So Cantina has **independent** validation/severity/reward authority on the normal path; the disengaged dYdX sponsor only bottlenecks **flagged/escalated** (disputed/borderline) findings. → `p_bounty` is healthy for CLEAN findings, impaired only for arguable ones.

**Net verdict: DROPPED (2026-06-24, operator final call).** The correction that settles it: **Cantina VALIDATES but dYdX (the client) FUNDS/RELEASES the reward** — and dYdX is the disengaged party. Cantina's independent validation authority therefore does NOT restore EV: a Cantina-validated Critical still waits on dYdX to release funds, and a checked-out sponsor means ~1 year to pay, if ever. `p_bounty` = probability of being *paid* in reasonable time ≈ 0, gated by the **payer**, not the validator. **Validation ≠ payment.** DROP regardless of how clean / escalation-resistant the finding is — the binding constraint is upstream of the bug entirely.

Intake/allocation work preserved for the record at `~/Desktop/BUGS/dydx-v4-intake-fresh-20260624/` (TARGET-DOSSIER.md + ALLOCATION-DECISION.md) — NOT to be worked unless dYdX re-engages as a *payer*. The thesis (reusable methodology) was the **off-chain orchestration seam** no protocol audit covered: `comlink /v4/turnkey/uploadAddress` (wallet-binding, no session authz), `comlink /v4/skip-bridge/startBridge` (unauth webhook → Turnkey-signed sweep), v4-web `withdrawHooks.ts` (Skip-route blind-sign). See [[ev-gate-check-program-responsiveness-not-just-severity]].
