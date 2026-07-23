---
name: feedback-model-manipulation-cost-before-crediting-twap-finding
description: "For a MOVE-A-PRICE finding (push a spot/TWAP, sandwich, sustained displacement), execute the attacker's manipulation COST (slippage paid to LPs) before crediting the payoff; it usually dwarfs the extraction. Does NOT apply to cost-free free-read bugs."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cb645e11-8651-4234-a23c-d044f4563d96
---

Before crediting any lagging-oracle / TWAP-drift / price-manipulation finding, construct and EXECUTE the
attacker's full P&L, not just the payoff. Moving a geometric TWAP requires sustained multi-block price
displacement, and the slippage to do that is PAID TO THE LPs (the very party you claim loses).

**Why:** on Ammalgam DLEX the whole TWAP-drift residual class (penalty band, saturation-liquidation, hard-liq
over-seize) collapsed on one executed number: to make a healthy borrower liquidatable an attacker paid ~120000 Y
of slippage to pull 5000 X (net -116,600 @1:1), while the LP claim per share ROSE 1.0 -> 2.574. A became
hard-liquidatable (the gate opened) but seizing its <=10,000 Y collateral is dwarfed by the 116,600 setup cost.
The gate opening is not a finding; the delta is. Same trap as conceding/over-claiming a gate: the reachable
mechanism (A is liquidatable) looked like a finding until the COST side was executed.

**SCOPE (do not over-apply):** this gate is CORRECT only for findings that REQUIRE the attacker to MOVE a
price. It does NOT apply to cost-free free-read bugs — staleness-consumption, decimals/exponent mismatch,
`minAnswer`/`maxAnswer` clamp floor, negative/zero answer, sequencer-uptime, read-only-reentrancy — where the
price is ALREADY wrong and the attacker only READS it (no price pushed ⇒ no LP-slippage offset ⇒ P&L is a
category error that will falsely conclude "attacker net < 0 → closed"). A *lagging* oracle is itself the
archetypal zero-cost arb (market moves, oracle lags, you arb the gap). Route free-read bugs through
extract **Gate-0**, never here. See [[feedback-oracle-replay-refute-first-reflex-fix]].

**How to apply:** build the drift engine (cheap: read midTermIntervalConfig + slot count; loop {warp interval;
sync} to move the mid-term tick), then in the SAME probe fund the attacker from its OWN stash and measure net
tokens at the honest pre-drift price AND the LP assets-per-share. If attacker net < 0 and LP/share rose, the
lagging-oracle path is closed by execution regardless of whether the liquidation/penalty gate opened. Relates to
[[feedback-model-window-actors-day-one]] (both: model the rational economic actor before crediting a state a
position must reach) and [[feedback-invariant-that-passes-is-not-a-finding]].
