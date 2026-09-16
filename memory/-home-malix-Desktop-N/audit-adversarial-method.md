---
name: audit-adversarial-method
description: Validated method for bug-bounty/security audits — multi-round adversarial workflow
metadata: 
  node_type: memory
  type: feedback
  originSessionId: fe0b1d9d-6445-41ff-9971-4b7b422a8f71
  modified: 2026-08-31T23:03:56.371Z
---

For security-audit / bug-bounty work, the user endorsed (asked me to document) the **multi-round adversarial workflow** method. Full playbook: `/home/malix/Desktop/N/METHODE-audit-adversarial-multiround.md`.

Core loop: `pipeline(DIMENSIONS, finder→FINDINGS, review→ per-finding parallel[refuter, exploit-builder]→combine)` + a completeness critic. Two opposed verifiers per finding (one tries to REFUTE via the guard, one tries to BUILD the exploit); a finding survives only if the exploit path holds AND no guard refutes.

**Why:** it avoids the two failure modes the user cares about — over-claiming an unproven bypass, and conceding a gate without exhausting it. It also stopped me from staying at surface-level differential-patch analysis.

**How to apply:**
- Two maxims first: a gate proves a control EXISTS not that it HOLDS (pierce it with an executed artifact); hunt the sentence the dev did NOT write.
- Reachability before depth: prove the code is instantiated (dead-code check invalidated a whole lead on Sei — geth txpool).
- Executed artifacts: cite file:line; when full build is blocked, prove via standalone-Go transcription (`go run`).
- Severity honesty: propagated-vs-direct, cgo-vs-pureGo timing, panic recovered(DeliverTx)-vs-unrecovered(Begin/EndBlock), amplification-vs-baseline.
- Never fabricate a finding; feed the "already-verified" map to the next round; stop and declare "fortress" when rounds refute everything with artifacts.
- JS gotcha: `parallel([...])` needs thunks `() => agent(...)`, not already-started promises.

Ultracode/max-effort makes this the default for substantive audit turns. See [[sei-audit-setup]].
