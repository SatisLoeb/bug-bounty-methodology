---
name: feedback-consult-operator-bugs-corpus-first
description: "On a target the operator has prior work on, grep ~/Desktop/BUGS FIRST for the relevant kill/finding before re-deriving from scratch."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 18f37fbd-b9f1-4054-a4dd-7c210c6f1e52
---

Before spending depth on a target (especially DeFi/exchange/Injective), **grep `~/Desktop/BUGS/` for prior
engagements on the same protocol/mechanism** — the operator has a large accumulated corpus of executed kills
and landed findings, and often already resolved the exact vein.

**Why:** on the Injective swap-contract I (a) novel-read and killed `/extract` with the WRONG reasoning
(rounding-floors-down) instead of the manipulation-cost gate, then (b) proposed building a test-tube harness to
resolve the "orderbook-shaping → drain support funds" vein — when the operator had ALREADY proven that exact
class dies by SPREAD across multiple engagements (`injective-fresh2026-audit/analysis/S4-recon.md` "attacker
pays the spread to move VWAP"; `ipor-protocol-audit/{KILLS,FINDINGS-STATE,VERDICT-FINAL}.md` demand-spread
manip KILLED, both-sides-cancel, net -fees). Hours of harness work were unnecessary.

**How to apply:**
1. New target → `grep -ril <protocol|mechanism|spread|orderbook|support.fund> ~/Desktop/BUGS --include='*.md'`
   before deep reading. Read the matching KILLS/FINDINGS-STATE/VERDICT/recon files.
2. For any orderbook/AMM/oracle "manipulate X to extract Y" candidate, run [[feedback-model-manipulation-cost-before-crediting-twap-finding]]
   as the FIRST gate (execute the attacker's spread/slippage COST), not after reading the whole file.
3. On a target the operator has worked to fortress-null, hunt the COMPOSITION/seam (their MANIFEST #345 axiom:
   "what survives 5 audits is never a class — it's a composition nobody owns"), not classes (rounding/extract/
   power/reentrancy) which their reviews + mine already sweep.
4. Don't re-sweep a class the operator explicitly says is dead; take the executed prior result and move on.

The operator pays for PROVEN bugs. A comfortable null with wrong reasoning, or a harness for a vein already
killed, both waste their money. Reading ≠ hunting; and re-deriving what's already in their corpus ≠ progress.
