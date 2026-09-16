---
name: feedback-target-diet-is-the-binding-constraint
description: "Portfolio data (50 OUTCOMES rows) proves target SELECTION, not analysis depth, is what kills our findings — bias sourcing toward fresh-funded / off-chain-seam / crypto-primitive, run the 3 pre-analysis filters before spending any deep pass"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8c7164c7-5d3e-4878-99e4-730b45d08d7f
---

Across the tracked OUTCOMES window (50 rows as of 2026-06-27), the closed outcomes are dominated by `no_go_earned_null` / `duplicate` / `earned_null` / `rejected` / `informative`, with **0 confirmed `bounty_paid` in the window** (1 `acknowledged`, ~8-10 still pending/in-review). The top four death-causes — **OOS (11) · fortress (10) · reachability (10) · dup (6)** — are EVERY ONE a property of the TARGET, decided BEFORE any analysis. A full session (2026-06-26/27: Midas ×2, Reserve, Concrete v2, Circle ×2, Crypto.com) produced 4+ clean engagements and ZERO payable findings, all dying on target-properties (audited→dup/fortress, $4.3K/$14.8K→EV-capped, scope-subset→OOS/reachability).

**Why:** the audit process is excellent at converting a wrong target into an honest null — it has never been the bottleneck, and the nulls are all CORRECT (the OOS/dup/fortress kills are real, not over-strictness). The bottleneck is the FUNNEL feeding the process: a diet of heavily-audited SC cores, microscopic-TVL launches, and scope-constrained subsets. This is the firmaudit T6d "5-fortress lesson" (*the failure is target selection, not depth*) re-proven at portfolio scale. The operator's actual paydays (Polymarket $10K Web2-on-SC, Request $1K API-auth, XRPL/Circle crypto-primitive, TRON $100K node, the firmaudit off-chain seams) all came from UNSATURATED surfaces that are now under-represented in the recent diet. OUTCOMES.jsonl is the recent-window tracker, not the lifetime record — but the recent window is a null-heavy stretch and the data names exactly why.

**How to apply:**
1. **Pull the funds-at-risk / TVL number FIRST** — before the dossier, the corpus-replay, or any workflow. The live `cast`/RPC read scoped 3 of 4 targets this session in minutes; on Midas/Reserve I built the replay before tiring the number. Number first, workflow second.
2. **Run the 3 pre-analysis filters as a hard gate before committing a deep pass:** (a) EV = funds-at-risk × reward-model (10%-of-TVL / severity-matrix / p_bounty) — a $14.8K vault or a dormant pool is SKIP regardless of code beauty; (b) dup/fortress = audit-count on the IN-SCOPE component (≥3 top-firm <6mo + no fresh delta = closed); (c) scope-reachability = can an UNTRUSTED actor reach an in-scope fund-mover (not admin/OOS, not vendor-side impact). Any filter fails → do NOT spend the workflow; route to a different target.
3. **Bias SOURCING toward the profiles that actually paid:** fresh launch WITH real TVL (not micro, not audited) · off-chain/web seam on DeFi (the Upshift profile) · crypto-primitive / novel surface (ZK/MPC/decimals — thin competition). De-prioritize "the next audited SC core to replay."
4. **Corpus-replay-on-our-own-closeouts is a HYGIENE tool, not an income tool** — it found 1 sub-payable dormant Low all session (Solana Pyth-conf). Use it for completeness/learning; never as a revenue strategy.

Links: [[ev-gate-check-program-responsiveness-not-just-severity]] (the per-program EV check this generalizes), [[midas-program-closed-fortress-null]] + [[reserve-program-closed-dup-fortress]] (two of this session's diet-driven nulls), [[doctrine-seam-rattachement-is-the-value]] (the unsaturated-seam profile to source toward).


**2026-08-08, this lesson DID NOT BIND.** It was on file before the 3F grunt engagement and the
target was taken anyway, with a published scope bullet naming the finding's own category. Closed
duplicate, $0. Record now stands at one payment in 87 outcome rows. Escalated and generalised in
[[feedback-absorbable-findings-die-regardless-of-quality]] — a category exclusion is a Phase 0 abandon,
not a section to write, and the tell is needing paragraphs to argue past it.
