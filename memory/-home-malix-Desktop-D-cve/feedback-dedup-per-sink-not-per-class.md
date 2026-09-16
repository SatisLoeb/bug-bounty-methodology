---
name: feedback-dedup-per-sink-not-per-class
description: "A dup verdict is posed per individual sink in primary source, never extended across a class by association"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-16T21:03:03.139Z
---

**Error 1 of the Granite miss (the real method error, at Gate 4).** I had 5 arithmetic-class PoCs on disk and wrote in the record "em01/em02/l01/l-03/el01 = known-audit dups" — retiring the WHOLE class as dup by association, without reading each sink's audit line-by-line. Bug **#99 (zero-share on `borrow`)** was a sink I never read: I'd read `deposit` (l01), judged the class "known", and extended the verdict to the `borrow`/`repay` siblings unread.

This is a direct re-violation of my own Gate 4: **dedup is done in primary source at the EXACT sink — not a summary, not a keyword search, not class-association.** It is the wsts tombstone-by-summary lesson re-committed at CLASS scale. "The class is known" is not a tombstone; it is a false-negative tombstone that covers one sink and claims five.

**Living proof the class was never resolved:** the fresh patch `1219a6b` guarded ONLY `borrow` (`(> new-debt-shares u0)`), leaving `repay` (borrower-v1:300), `liquidator paid-shares` (liquidator-v1:255), and LP `deposit` (liquidity-provider-v1:51 = my own cut `l01`) unguarded on the deployed contract today. **A patch that guards one sink of a class is proof the class was resolved at one place, not resolved.** The unguarded siblings are the map.

**Why:** throwing a real finding while believing it's a dup fails at Gate 4 — the one uncontrollable parameter — so the controllable half (reading each sink) must be exact.

**How to apply:** with N candidates of one class, the dedup reads the audit at each individual sink, N times. The class can be dup on one sink and virgin on another. **NOT caused by velocity — a rigor defect, applies at any cadence** (my cadence is fine: Royco 4h, rank 1/782; dup is never a hold reason). Foil (2nd Maxim as a tool): *does the dev's patch guard ALL sinks of the class, or one?* Hunt the sinks he left open. Distinct from [[feedback-test-in-dirty-numbers]] (that one fails at discovery, this at dedup). [[granite-clarity-findings]] [[feedback-manual-poke-bracket-mandatory]] [[feedback-corpus-not-trusted-100-poke-first]]
