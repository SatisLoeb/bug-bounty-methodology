---
name: feedback-test-in-dirty-numbers
description: Build PoCs on dirty inputs by default — round/clean values are a silent false-negative for the entire precision class
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-16T21:03:17.684Z
---

**Error 2 of the Granite miss (a PoC-construction defect, at Gate 3 — distinct from the dedup error).** I proved A/D/B on round whole-dollar prices. Rounding/precision bugs only bite when there is a remainder, so a round-number PoC **structurally cannot reveal the class**.

Corpse: bug **#80206** (liquidation seizure "floors twice around a division" → lands one unit short at a price that is not a whole number of market-token units) beat my #92663 on the same code. Its own commit says it plainly: *"a whole-dollar price divides evenly and hides the defect completely."*

This is not "a missed candidate" — my harness could not trigger the class. It is Gate 3 in a new form: **a PoC on clean values does not test the paths only dirty values reveal.** More vicious than a dedup miss because it is silent — every test passes, every finding is valid, nothing signals that the precision class is hidden behind the round number.

**How to apply:** default to DIRTY inputs — prices carrying cents / non-whole market-token units (e.g. $2,013.742), non-divisible amounts, prime quantities, collateral decimals != the market's — across every division, share-conversion, and valuation sink. Reserve round numbers only for the readability of an ALREADY-found bug, never for discovery. **NOT caused by velocity — a rigor defect in PoC construction, applies at any speed.** Foil (2nd Maxim as a tool): *does the dev test in cents or in round dollars?* Test precisely where his clean-number habit blinds him. Distinct from [[feedback-dedup-per-sink-not-per-class]] (that fails at dedup; this fails at discovery). [[granite-clarity-findings]]
