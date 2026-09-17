---
name: edge-primitive-guarded-wrong-variable
description: "Operator's core edge is ONE reusable mechanism (not a target family) — \"the guard is real and correct but guards the wrong variable, next to the one the attacker controls\" — verified across 3 wins in 3 stacks"
metadata: 
  node_type: memory
  type: project
  originSessionId: 92bde771-2461-462b-95e1-e8bacc979742
  modified: 2026-09-17T01:46:13.965Z
---

**The primitive (promoted at 3 instances — operator's own threshold — positive-space, from WINS).** The operator's edge is a MECHANISM, portable across languages/targets, not a family of targets. Shape: **a guard EXISTS and is CORRECT, but it guards the wrong variable — right beside the variable the attacker actually controls.** Because the guarded sibling proves the dev CAN guard, the missing guard on the adjacent sibling is an INCONSISTENCY in the dev's own code, not a defensible "trusted party" gap. This is Gate-2 "guard échappé" + xseam "unguarded sibling" fused. Answers the open question "is the edge a mechanism or a target family?" → mechanism (carried Clarity → Go+Solidity → TypeScript unchanged).

**Three instances:**
- **ENS #92483** (Critical Chief, PAID): re-authenticates the TOKEN on-chain (`ownerOf`/`getData`), never authorizes the ASSIGNEE (`managerAddress` from subgraph, unvalidated). Guards who-owns, not to-whom-granted. See [[ens-critical-chief-cold-reengagement]].
- **Granite #92663** (Protocol insolvency, Clarity, escalated 2026-09-11, PENDING): gate validates the price is genuine + in-window, never requires it's CURRENT → the checked account selects which genuine in-window Pyth price its own solvency gate reads. Guards price-authenticity, not price-choice. (borrower-v1 borrow/remove-collateral; pyth-adapter-v1 300s window, no monotonic/last-seen guard; renewable liquidation blackout via borrowed-block re-stamp.) See [[granite-clarity-findings]].
- **RSK #90518** (direct theft, Go server × Solidity contracts, DUP'd of #85794): `address + quoteHash` binding guard is correct, but `ParseDepositEvent` feeds it `Logs[0]` by topic0 only → wrong log validates the quote. Guards the binding, reads the wrong log. Off-chain parser bug → on-chain `refundUserPegOut` slashes the LP's collateral. THE upshift/xseam seam (off-chain↔on-chain handoff, address-scoped detection vs unscoped re-parse = guarded sibling vs unguarded sibling).

**Second shared DNA — the DIFFERENTIAL as killshot that pre-empts the by-design/OOS reframe before it's raised.** Same input, one variable flipped, opposite result → isolates the defect OFF the excluded thing. Granite (purest): same op, same genuine oracle, revert at current price / ok at chosen price → defect is caller-selection, not oracle data → "incorrect oracle data" exclusion can't attach while "oracle manipulation" (in-scope) does. RSK: same quote validates alone, fails when a log precedes it → binding fed wrong log, not a contract bug. ENS: authority-creation-not-carry-over. The finding is BUILT so the exclusion attaches nowhere. Pairs with recevabilité front-loading ([[feedback-pull-impacts-in-scope-hunt-all-classes]], [[feedback-in-in-scope-asset-list-is-literal]]).

**Outcome spread = empirical proof of the operator's own central thesis (validity is never the problem; dup/timing/recevability is).** Paid Critical Chief (ENS) / dup'd-with-zero-technical-flank (RSK, the §6 speed-corollary origin) / pending (Granite). A finding as perfect as RSK dying ONLY to dup is the strongest evidence the technical half is solved — nothing else was attackable, so the sole residual variable took it. Do NOT read this as "3 wins landed"; it's one solved technique with three outcomes. Related: [[test-in-dirty-numbers]], [[dedup-per-sink-not-per-class]], [[decentra]].
