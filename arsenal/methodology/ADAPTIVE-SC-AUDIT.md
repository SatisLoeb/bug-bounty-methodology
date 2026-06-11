---
name: Adaptive Smart Contract Audit Framework
description: 4-phase deep audit methodology learned from Reserve Protocol ($10M bounty). Adaptive — phases expand/contract based on signal. Replaces surface scanning with agents.
type: feedback
---

## The Framework

### Phase 0: Triage (2h max)

**Goal:** Decide if target is worth multi-week investment.

**Steps:**
1. Clone repos, count LOC, map architecture
2. Count prior audits — more audits = harder but higher bounty
3. Identify NEWEST/UNAUDITED code — this is always the entry point
4. Check bounty structure (critical only? all severities?)

**Decision gate:**
- Unaudited code found → PROCEED (highest ROI)
- <3 audits + >$50K bounty → PROCEED
- 14+ audits + only low-hanging fruit → SKIP unless unaudited components exist
- No unaudited code + saturated bounty → SKIP

**What Reserve taught us:** 14+ audits killed all surface findings. The ONLY surviving finding was in the UNAUDITED trusted-fillers integration (v4.2.0). Always start with the newest, least-audited code.

---

### Phase 1: Unaudited Code Deep Read (3-5 days, ADAPTIVE)

**Goal:** Line-by-line audit of unaudited/newest code.

**Steps:**
1. Read EVERY line of unaudited contracts (usually <500 LOC — manageable)
2. Build a **CHECK MATRIX**: for every external/public function, list all modifiers and require statements
3. Compare functions that SHOULD have the same checks — inconsistencies = findings
4. Build test harnesses for each finding candidate

**The Check Matrix pattern (from Reserve F-001):**
```
Function          nonReentrant  notDeprecated  sync  bidsEnabled  roleCheck
bid               SIG           SIG            SIG   BODY         ---
createTrustedFill SIG           SIG            SIG   ---          BODY  ← MISSING CHECK
```

This single table found the bidsEnabled bypass. The pattern: two functions that do the same thing (initiate a trade) but one has a check the other doesn't.

**Adaptive expansion:**
- If check matrix reveals 0 inconsistencies → compress to 2 days, move to Phase 2
- If check matrix reveals 2+ inconsistencies → expand to 7 days, deep-dive each one
- If unaudited code is clean → pivot to post-audit code changes (git blame/diff)

**Kill criteria:** If after 3 days of reading, zero suspicious patterns → move to Phase 2 fuzzing (the machine might find what eyes miss).

---

### Phase 2: Invariant Fuzzing (3-5 days, ADAPTIVE)

**Goal:** Let the machine find what manual review misses.

**Steps:**
1. Identify core invariants from documentation + code comments
2. Write Foundry fuzz tests for each invariant
3. Run 10K-50K runs per invariant
4. If any FAIL → deep-dive immediately (potential CRITICAL)
5. Run Slither static analysis on all repos

**Key invariants to always test:**
- `totalSupply` monotonicity (for fee-bearing tokens)
- `mint → redeem` round-trip ≤ original (no free tokens)
- Price curve monotonicity (for auctions)
- `poke/sync` idempotency (same-block repeated calls)
- Balance accounting (sum of user balances = total tracked)

**Adaptive expansion:**
- If fuzzer finds a FAILING invariant → STOP everything, build PoC (potential CRITICAL)
- If 50K runs all pass → compress to 2 days, move to Phase 3
- If Slither finds unguarded reentrancy → verify manually (agents often get this wrong)

**What Reserve taught us:** 200K+ fuzz runs, 8/8 invariants held. The fuzzer confirmed the code was correct but didn't FIND the bug. The bug was a LOGIC inconsistency (missing check), not a MATH error. Fuzzing is for validation, not discovery on well-built protocols.

---

### Phase 3: Cross-Module State Machine (3-5 days, ADAPTIVE)

**Goal:** Find bugs that live BETWEEN contracts, not WITHIN them.

**Steps:**
1. Trace complete lifecycle: creation → operation → settlement/destruction
2. For each state transition, check: what happens if the state changes mid-flight?
3. Focus on EXTERNAL calls that cross contract boundaries
4. Check: can function A in contract X affect function B in contract Y unexpectedly?
5. Mainnet fork tests against real deployed contracts

**Cross-module patterns to check:**
- Basket switch during active trade (BackingManager ↔ BasketHandler)
- Oracle failure during recollateralization (Asset ↔ RecollateralizationLib)
- Fee accrual during rebalancing (Folio fees ↔ auction math)
- Trusted fill lifecycle across blocks (DutchTrade ↔ CowSwapFiller)

**Adaptive expansion:**
- If cross-module trace reveals state inconsistency → expand to 7 days, build PoC
- If all state machines are clean → compress to 2 days
- If mainnet fork test reveals deployed-vs-code divergence → HIGH PRIORITY

**What Reserve taught us:** The cross-module analysis confirmed the code was consistent. StRSR.seizeRSR was safe, DutchTrade lifecycle was protected by closeTrustedFiller. The 14 prior audits had already caught the cross-module bugs. On less-audited protocols, this phase will be more productive.

---

### Phase 4: Impact Quantification + Reporting (2-3 days)

**Goal:** Maximize severity of confirmed findings. Submit with honest, defensible classification.

**Steps:**
1. For each finding: quantify $ impact with concrete numbers
2. Test PoC against mainnet fork (not just local tests)
3. Check if findings CHAIN together (A+B = higher severity than A or B alone)
4. Write report in Cantina/C4/Sherlock format
5. Severity: be honest. Acknowledged Medium > dismissed High.

**Severity decision tree:**
```
Direct fund theft (permissionless, no preconditions) → CRITICAL
Fund theft (requires specific state + timing) → HIGH
Access control bypass + value leakage → HIGH if quantifiable, MEDIUM otherwise
Griefing / DoS on critical function → MEDIUM
Informational inconsistency → LOW
```

**What Reserve taught us:** F-001 was MEDIUM, not HIGH. The attacker can force trades but doesn't directly profit. Honest severity builds credibility for future submissions.

---

## Adaptive Time Allocation

```
TOTAL: 12-20 days per target (adaptive)

Phase 0 Triage:              2 days (fixed)
Phase 1 Unaudited code:      3-7 days (expand if findings emerge)
Phase 2 Fuzzing:             2-5 days (expand if invariant breaks)
Phase 3 Cross-module:        2-7 days (expand if state inconsistency found)
Phase 4 Reporting:           2-3 days (fixed)

HARD STOP: If no finding after Phase 1 + Phase 2 (8-12 days) → evaluate:
  - Unaudited code was clean + fuzz passed → SUBMIT what you have or SKIP
  - Something is suspicious but unproven → one more week on Phase 3
  - Everything is clean → MOVE ON, don't waste more time
```

## Anti-Patterns to Avoid

1. **Surface scanning with multiple agents** — produces 30 "criticals" that all die on verification. Only useful for initial architecture mapping, not for finding bugs.

2. **Reporting broken controls without exploitation** — "x-client-signature not enforced" without XSS = informative. On smart contracts this doesn't apply (all bugs are permissionless), but the principle holds: show the full chain.

3. **Fuzzing without invariants** — random inputs without property assertions finds nothing. Define the invariant FIRST, then fuzz against it.

4. **Ignoring known issues** — Reserve had comments like "known: can be griefed by token donation." Reading these FIRST saves days of wasted analysis.

5. **Inflating severity** — Medium is fine. $5K for 2 weeks of work is $1.25K/week. That's sustainable if you hit one per target. Inflating to High and getting rejected is $0.

## When to Use This Framework

- Smart contract bounties with >$50K max payout
- Protocols with existing audits (the framework is designed for hard targets)
- NOT for surface-level web/API bounties (use gravedigger web methodology instead)
- NOT for contest speed-runs (contests reward breadth; bounties reward depth)
