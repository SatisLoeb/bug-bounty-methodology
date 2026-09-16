---
name: project-royco-day-intake
description: Royco Day (Cantina $30k) — measured NULL on surviving in-scope impacts; only finding (reentrancy) OOS-grandfathered under appeal
metadata: 
  node_type: memory
  type: project
  originSessionId: 56f4a565-d414-47b2-92bd-0f8389277fa9
  modified: 2026-08-16T09:01:36.849Z
---

**Royco Day** — Cantina competition, $30k pot, ended 17 Aug 2026. Commit fa6d2497, src/ only. 12K LOC.
Non-custodial yield tranching (Senior/Junior/LPT over Balancer-v3 venue), async EntryPoint singleton
(commingled escrow per asset), Kernel core, Accountant NAV/coverage/liquidity/IL. Workspace: ~/Desktop/BUGS/royco-day.

**STATUS (2026-08-16, last day): MEASURED NULL on the two surviving in-scope impacts. Don't re-audit without a NEW surface.**

- **Only finding = H-01 entrypoint reentrancy → escrow double-spend. SUBMITTED, now OOS** by the Aug-11
  live fix (PR #24 ReentrancyGuardTransient), grandfathered as pre-merge. Under **likelihood re-rating
  appeal** (Low vs Medium) — the one live lever. Report at submissions/H-01-*.md + APPEAL-likelihood.md.
- **In-Scope Impacts are NARROW (only two):** (A) funds to non-whitelisted / unnamed-by-whitelisted address;
  (B) funds permanently locked/unrecoverable. OOS: reentrancy (fixed), oracle/NAV/price manip, trusted-party
  misbehavior, reversible mis-amount-to-whitelisted, prior audits (Hexens ROYCO5-1..6, Olympix 4.1.1/4.2.x),
  "expected behaviors / accepted risks".

**Why NULL (both my full manual read + an 8-finder ultracode sweep converged):**
- **No whitelist in deployed code** (removed pre-commit; `_preTrancheBalanceUpdate` empty virtual, not
  overridden). Model = blacklist + Chainalysis sanctions only. ⇒ impact A = blacklist ESCAPE.
- Blacklist screening is COMPLETE: full sink×screen matrix has no unscreened cell. Every underlying-asset
  transfer has an explicit `_enforceNotBlacklisted(receiver)`; every tranche-share move hits the `_update`→
  `preTrancheBalanceUpdateHook` screen (fires on transfer AND mint AND burn).
- Impact B hardened: FIXED_TERM auto-exits (uint24-bounded, self-heals in redeemer's own sync); NAV
  conservation enforced every op; non-blacklisted users can always cancel to a clean receiver; venue removal
  is PROPORTIONAL+graceful (proven no-brick); a blacklisted user's frozen escrow = sanctions-by-design.
- Cross-market bleed closed by `RoycoAccessManager.wasEverConfigured` + gatekeeper one-shot `_requireNotConfigured`.

**The ONE real non-null mechanism found (accountant JT-IL grace erasure) is OOS + by-design → NOT payable:**
during the fixed-term GRACE window (condition 7, RoycoDayAccountant.sol:548) the market stays PERPETUAL, which
ERASES `jtImpermanentLoss` (:551-552). A JT-absorbed drawdown during grace is never repaid; the recovery
splits pro-rata (:453) instead of repaying JT first (:440) → value moves JT→ST permanently (100→90→100 on
S80/J20 gives S88.9/J11.1). REAL trace, but (1) neither impact A nor B (cross-tranche misattribution to
legitimate screened senior holders — a third class the brief doesn't list), (2) by-design: JT is first-loss
capital, IL-repayment is a FIXED_TERM-only protection, comment :550 states the invariant. Dies on scope +
"accepted risk". Low EV. [[feedback-findings-die-on-the-actor-not-the-mechanism]]

Related: [[feedback-report-count-distribution-picks-the-asset]] (44 findings, last-day dup risk),
[[feedback-diff-forward-to-head-not-just-scope-changelog]] (the PR#24 forward-fix OOS'd the finding).
