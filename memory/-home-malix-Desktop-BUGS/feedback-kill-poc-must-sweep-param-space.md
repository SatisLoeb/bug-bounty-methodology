---
name: feedback-kill-poc-must-sweep-param-space
description: "A kill/refutation PoC must sweep the parameter space, not test one convenient value that hits the guard — a single-point kill is a biased kill"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 67741390-c0c6-408c-b3d2-4d753dbef987
---

A kill-PoC that tests ONE parameter value can produce a FALSE "refuted" if that value happens to hit the guard while adjacent values bypass it. Sweep the space.

**Case (Upshift repouscc first-depositor inflation, 2026-07-01):** I "refuted" the inflation theft with a PoC using donation D == victim V (10000e6 == 10000e6). At D==V the victim's shares = floor(V/(1+D)) = 0 → hits the `shares<1 revert` guard → I concluded "griefing only, theft refuted." That was a BIASED kill (darkside §0.5.3): I tested the single value that makes the kill trivial. The corrected SWEEP (D ∈ {3000,5000,6000,8000,9999,10000}e6) showed D=5000e6 makes the victim mint EXACTLY 1 share (passes the shares<1 guard) and overpay → attacker net +2495e6 (+25% of victim), theft REAL, observed delta. The `shares<1` guard only blocks the zero-share edge; the 1-share-overpay variant sails through.

**Why:** the guard (`if shares < 1 revert`) LOOKED like it killed the whole class; testing only the guard-hitting input confirmed my wish (closure-bias). Both failure directions bit in one episode: I under-conceded (biased kill buried a real theft), then the corrected PoC almost led me to over-claim (it turned out a DUP of accepted Hacken F-2025-14333, whose consequence #2 describes the exact early-LP-cash-out theft → bounty-KILL, pivot-advisory only).

**How to apply:** any refutation/kill PoC on a math/rounding/threshold path must SWEEP the deciding parameter (donation size, deposit ratio, dust/max boundaries, first-vs-later actor), never a single convenient point. Add the sweep + the honest baseline + assert the BEST attacker-net across the sweep. A guard that blocks one edge is not a class-kill until the adjacent inputs are executed. Then STILL run the kill-gate (auditor cross-ref) before believing the survivor is submittable — a real-by-PoC finding can still be a dup of an accepted audit finding. See [[feedback-verify-before-working-no-theater]], [[doctrine-defense-shadow-confession]].
