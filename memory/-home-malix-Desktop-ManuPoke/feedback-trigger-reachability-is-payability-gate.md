---
name: feedback-trigger-reachability-is-payability-gate
description: "A real mechanism without a REACHABLE adverse trigger is a hardening, not a payable bounty vuln — no matter how green the PoC. Propagation-proven ≠ reachability-proven."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

Operator rabat-joie, 2026-07-20 (Symbiotic adapter-view freeze). I graded a real, in-scope, green-PoC
permanent-freeze finding as "Medium, bank it." Wrong. The finding had NO reachable adverse trigger: the
freeze only fires IF a bound external dependency's view reverts, and I had already proven (deep hunt) that
no unprivileged actor can force that revert. The operator's kill: **a finding whose impact is conditional
on an event no attacker can trigger and I can't prove will happen is a defensive-coding gap, not a
vulnerability.** My own report text convicted it ("not an attacker-drivable exploit... none of it a
Symbiotic-side exploit") — a triager reads that sentence and closes informational/best-practice.

**Why:** this is structurally identical to "F1" (a real asymmetry whose loss needs a position to drift ~20
years), which I correctly killed as out-of-bounty hardening. Same shape recurs: real mechanism (proven) +
missing reachable trigger (absent) = hardening. The distinction from a PAYABLE finding is an actor: the
Ammalgam straddle had an attacker who calls liquidate on a solvable position and REALIZES 20% theft in one
tx (attacker ACTS → damage). The freeze had nobody acting — the dependency breaks on its own. Vulnerability
= attacker does something that causes damage; defensive gap = code doesn't survive an external condition no
one can provoke. Also see [[feedback-model-window-actors-day-one]] (killed the saturation finding for needing
state to sit), [[feedback-today-impact-before-poc]], [[feedback-invariant-that-passes-is-not-a-finding]].

**The PoC trap (sharp):** a green PoC that passes proves PROPAGATION (IF condition THEN impact), NOT
REACHABILITY (an attacker causes the condition). If the PoC establishes the triggering condition itself —
a mock's `setRevertOnPreview(true)`, a hand-set price band, `vm.warp` 20 years, a pranked trusted role —
then that self-set condition IS the fabricated trigger, and the PoC is demonstrating the second half of the
chain while assuming the first. Green ≠ reachable.

**How to apply:** BEFORE grading any finding ≥ Medium, answer one question in writing: *"who, with no
privileged role, takes what concrete action to make the damaging condition occur — and is that action, not
the consequence, in the PoC?"* If the answer is "a trusted role does it" (governance risk, OOS on most
programs), "an external dependency does it on its own" (non-triggerable), or "it happens eventually/naturally"
(un-provable), the finding is a HARDENING → courtesy-disclose out-of-bounty, do NOT submit as a bounty vuln.
Making it payable requires FINDING the non-privileged trigger (real research), never reframing the writeup.
And run the program's EXCLUSIONS check (trusted-role actions, external-dependency failures, theoretical/no-attacker
issues are excluded by most programs) as part of scope, not just the in-scope contract list.
