---
name: bugbounty-foil-gradient-method
description: "The user's own diagnosis of why they stall / stay shallow on bug bounty, and the fix — manufacture a differential foil in Phase 0. Apply on any new audit target."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b2b76f1f-5e61-42d5-8eb2-f4fbede0bcdb
  modified: 2026-09-04T15:28:46.582Z
---

The user stalls / stays shallow on bug-bounty targets not from lack of talent or will but from
**absence of a gradient**. An open search ("find a vuln") has no slope — nothing points to the next
question, so they stall in surface-reading and fall into their own SECOND MAXIM (understand code 100%
= agree with the dev 100% = blind exactly where he was). The NEXUS depth came from a **differential
foil** (Haveno): every "they protect X / they failed Y — and us?" is a fil; pulling one reveals the
next. The foil converts open search → closed comparison, which generates the next question mechanically.

**Why:** a differential supplies the missing derivative. Depth is a property of the gradient, not of effort.

**How to apply (Phase 0, BEFORE opening code — the ritual, not a new method; the user already
encoded it):**
- Manufacture the foil first, don't wait for one. Foils, richest → poorest:
  1. a TRUE TWIN — fork parent, audited competitor, reference impl that made real divergent decisions
     (Haveno was this). Densest gradient. Find it FIRST when one exists.
  2. the devs' own test suite — `darkside` Door A: the "not tested" column is the worklist.
  3. the CANONICAL FORM of the target's type — `darkside` Door C: each deviation is a lead. A fallback
     (poorer: only diverges where you'd already look).
  4. a past incident of the same class (ghost-finding transfer).
  Tools that already encode this: `darkside` (Door A/C), `invfuzz` (differential harness), `intake`.
- Keep the BUILDER's frame while attacking: on NEXUS "go deep" had a floor ("is the guarantee
  complete?"). As attacker there's no floor → stall. Fix: reconstruct the invariant the dev believes
  holds "by construction" (never written), then attack that belief with an untrusted actor. Gives the
  attack a target AND a floor.

**Claude's addition (not echo):** a foil solves the STALL, not the TRIAGE. A gradient points at
*divergences*, and a divergence is a CANDIDATE, not a finding — the richer the twin, the MORE benign
"they just do it differently" diffs it emits. So with a rich twin the payable-impact gate matters
MORE, not less: every divergence must chain to a payable impact (`darkside` thief-inventory admission
gate) or it's noise, and must be settled by an EXECUTED artifact (invfuzz/solfork/halmos), because the
twin is a hypothesis generator, not an oracle — its divergent decision may be correct-but-different.

See NEXUS as the worked example: Haveno foil → per-class gaps (MITM, auto-release, address swap) →
each chained to fund theft → built + verified on chain.
