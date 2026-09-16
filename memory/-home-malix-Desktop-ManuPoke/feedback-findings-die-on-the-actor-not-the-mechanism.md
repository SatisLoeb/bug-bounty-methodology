---
name: feedback-findings-die-on-the-actor-not-the-mechanism
description: "3 rejections, mechanism conceded every time: absent-guard findings assert DESIGN INTENT and die on responsibility. Prefer ESCAPED-guard (factual). Tell: does the PoC REACH the state or BUILD it?"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 1cddd5e1-a775-4c40-bc31-1244e19cbfd8
  modified: 2026-07-26T19:56:36.061Z
---

**In Ammalgam, Perena #83 and Doppler #784 the MECHANISM WAS CONCEDED every single time.** Will didn't
dispute the premium math. Whetstone didn't dispute that `customFee` is unbounded. shibi explicitly
verified that `instant_unstake_junior` reads the stored `share_price`. The analysis was right in all
three. What failed was never the mechanism.

## 1. The triangle (not just "the actor")

"Can the attacker create the precondition?" is the wrong single question. Three branches must ALL pass:

1. **actor ≠ victim**
2. **actor ≠ whoever holds legitimate authority over the damaged thing**
3. **actor can create AND HOLD the state through the window**

One branch each killed one finding:
- **Perena**: no unprivileged party CREATES the state (only the gated `apply_capital_loss` does) → "operational timing issue around privileged accounting". Branch 3 fails at creation.
- **Doppler #784**: anyone creates it, free, via an ungated `Airlock.create` — **and it dies anyway**, because whoever sets the value OWNS the damaged pool → "deployer responsibility". Branch 2 fails.
- **Ammalgam**: actor exists and creates the state, but a profitable third party dissolves it before maturity → branch 3 fails at holding.

**Operational form: SHARED resource vs OWNED resource.** Breaking what you control is your own business.
Breaking a common pot you have no authority over is a finding. StackingDAO drains the shared sBTC pool
and blocks other holders' `refresh-position`. Doppler only harms buyers of the creator's own token.

## 2. The uncomfortable part: the heuristic itself is biased

All three rejects are **"guard missing on the sibling"** findings, which is the primary heuristic
([[xseam]]'s sibling-non-gardé shortcut, mrrobbot's check matrix). In all three the asymmetry was REAL
and UNCONTESTED:
- Ammalgam: no cap on the premium where siblings cap
- Perena: no freshness check where siblings have one
- Doppler: no `MAX_SWAP_FEE` where the sibling hook and `MAX_LP_FEE` both bound

That is not coincidence. **A missing guard is an assertion about DESIGN INTENT, and intent is always
defended with "the responsible party is expected to configure it correctly."** The heuristic is
structurally aimed at findings that die on responsibility rather than on mechanism. It finds real holes
(teams often fix them silently) but it PAYS BADLY.

## 3. What StackingDAO does differently: ESCAPED guard, not absent guard

Not a missing-guard finding. A guard that **EXISTS** (`ERR_OVER_RESERVE`, holding Σtracked ≤ ststxbtc
actually held at Zest) is pushed OUT OF ITS OWN INVARIANT by a permissionless action. That is a
**factual claim about code behaviour**, not a claim about what someone intended. Nothing to defend with
"deployer responsibility" because nobody chose it. That's why it's the strongest of the set.

**PREFERENCE RULE: hunt targets where a guard EXISTS and can be driven out of its domain, over targets
where a guard is MISSING.** Escaped > absent. Factual > intentional.

## 4. The mechanical tell, if you keep only one

> **Does the PoC REACH the vulnerable state, or BUILD it?**

- Ammalgam: warped 120 days.
- Perena: patched out the auth branch.
- Doppler: set the config itself.
- StackingDAO: drives the same permissionless calls a real attacker would.

**A PoC that has to install the state ASSERTS its existence instead of proving it.** Checkable in thirty
seconds, before writing a line of report. If your harness contains `vm.warp` past a liquidation window,
a patched-out authorization, a `vm.prank` as a privileged role, or a config you chose, the state is
yours and not the protocol's.

## 5. Hermetica hBTC (2026-07-26) — the lesson was IN memory and I chased it anyway

Fourth instance, and the one that proves the tell must run FIRST. Hermetica hBTC = **Perena #83 redux**:
a holder redeems at a stale-high NAV *before the keeper books an organic strategy loss* → drains the
reserve, dumps the loss on passive holders. I confirmed it, measured a tiny 0.24% on-chain buffer, and
built a **passing** Clarinet PoC — before the operator flagged it as the same trap that failed twice.

**Why the lesson didn't fire: I ran the REACHABILITY gate and mistook it for the ACTOR gate.** I asked
"is a loss big enough to strand the NAV realistic?" (yes, 0.24% buffer) and read that as GO. But
"a loss is realistic" is [[feedback-trigger-reachability-is-payability-gate]]; it says nothing about
whether the ATTACKER causes or CREATES the adverse state (this file). They are DIFFERENT gates and the
actor gate is the one that kills this class. **Order: run the actor gate (does the attacker create AND
hold the state?) BEFORE reachability, and long before the PoC.**

And the §4 tell was screaming: my PoC **granted `wallet1` a protocol role and transferred sBTC out to
fake the loss** = built the state, textbook. A PASSING PoC felt like proof; it was the warning light.
Confirm-first: on hBTC every user fn (deposit / redeem-via-fund-claim) moves real sBTC and booked NAV
PROPORTIONALLY, so no attacker action manufactures a real-vs-booked divergence — the divergence is only
made by the strategy (organic) or the keeper. That 30-second check (can any user fn create the gap?)
would have killed it before the reachability measurement, let alone the PoC.

Related: [[feedback-trigger-reachability-is-payability-gate]] (can the trigger fire — SEPARATE from the actor gate),
[[feedback-window-finding-measure-both-bounds]] (Ammalgam's branch-3 failure),
[[feedback-model-window-actors-day-one]] (who resets it), [[feedback-payable-impact-not-just-theft]],
[[feedback-model-accounting-invariant-not-economic-ideal]] (Perena, the same shape at Étape 1).
