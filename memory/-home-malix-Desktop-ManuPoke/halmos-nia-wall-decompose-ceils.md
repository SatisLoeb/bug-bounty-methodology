---
name: halmos-nia-wall-decompose-ceils
description: Halmos (yices/z3) times out on AMM interpolation/mulDiv nonlinear queries; decompose into ceil-rounding lemmas + hand-compose the monotonicity leg.
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b82a51e8-b61a-4dff-bea2-53ab1f8204ff
---

Proving AMM per-bin conservation with Halmos: yices AND z3 hit the **NIA wall** (unknown/timeout) on even a *single*-`mulDiv` monotonicity over symbolic products like `lower*(MAX-pos)+upper*pos)/MAX` — 300s still TIMEOUT. bitwuzla often closes these but needs `HALMOS_ALLOW_DOWNLOAD=1` (a network fetch → blocked by OPSEC default), so it's usually unavailable offline.

**Why:** a full solver run (sqrt + 4-deep nested mulDiv) is hopeless; but the *rounding direction* — where an inverted Floor/Ceil = extraction actually lives — is division by a **constant** (`ceilDiv(x, 2^64)`, `/MAX_POS`), which yices CAN prove.

**How to apply:** don't run the whole invariant symbolically. Decompose:
1. `grossFee >= net`, `requiredToken*2^64 >= amount*price`, `mean >= min` → each is constant-denominator ceil/add → **Halmos-PROVEN (bounded)**.
2. The `sqrt`/interpolation monotonicity leg → hand-trivial (`lower + (upper-lower)*pos/MAX` is linear increasing) → compose by hand; INDÉCIS there is a *tool limitation*, not a counterexample.
3. Decouple sqrt: it only picks the STOP position; deterministic helpers compute the charge and every refinement is pool-favorable — so a per-position charge bound covers the whole exact-in path (stronger than fuzzing sqrt).

For the legs Halmos can't reach, close with Foundry fuzz. And when fuzzing a fee/accounting column, add a **concrete anti-vacuity assertion** (e.g. "one swap MUST accrue nonzero notional fee & move both tokens") so a green isn't all-reverts. See [[feedback-invariant-that-passes-is-not-a-finding]].
