---
name: injective-exchange-firmaudit-parked
description: "AUDITED 2026-06-24: Injective exchange module v1.20.0 firmaudit = earned fortress-null on single-margin; 1 dormant Medium (BO reward-farming); live EV only in OOS cross-margin (re-audit when enabled)"
metadata:
  node_type: memory
  type: project
  originSessionId: 676ee768-18be-4105-b623-333fd6940088
---

The Injective `exchange` module (injective-core **v1.20.0, commit 3ade14d = EXACT mainnet**) firmaudit is **DONE =
EARNED FORTRESS-NULL** on the in-scope single-margin surface (2026-06-24). 3 deep workflow passes (~2.5M tokens, all
hand-verified) + operator-owned direct reads on the residuals. Full record: `~/Desktop/BUGS/injective-exchange-2026-06-24/`
(VERDICT.md, PASS1/2/3-RESULT.md, recon/GROUND-TRUTH-v120.md). OUTCOMES id `injective-exchange-2026-06-24`.

**SCOPE FIX (load-bearing):** the parked dossier said v1.20.0 but the repo was checked out at **v1.19.0**; mainnet runs
**v1.20.0/3ade14d** (verified LCD node_info). Re-anchored to the exact mainnet commit (+19,380 LOC delta incl the new
risk system). Always verify git_commit vs LCD node_info before auditing — clone default-checkout ≠ deployed.

**WHAT HELD (all hand-verified):** the SEAM thesis was structurally TRUE (the data-integrity invariants in
metadata_invariants_check.go ARE test-only, 0 prod callers) but UNEXPLOITABLE — every desync path reconciles, so the
un-enforced gap has nothing to amplify. Pass-1 invariants reconcile; Pass-2 economic pools guarded (fee floor nets
≥0.005% even on self-made markets; insurance strictly per-market; fee-discount stake+volume AND-gate at $1B tier);
Pass-3 fund-conservation null (FBA clearing clamped, single uniform price = no pro-rata split, position-PnL conserves via
EXECUTED Go harness, spot ledger reconciles); wasm PrivilegedExecuteContract authz constrained to {contract,origin}.

**ONLY FINDING = BO trading-rewards wash-farming (Medium-CONDITIONAL, DORMANT, NOT submitted):** MsgInstantBinaryOptions
MarketLaunch is unauthenticated + lets creator set near-floor fees (spot hardcodes, perp admin-gates) + auto-qualifies +
points=notional → net-positive wash at the fee floor. DORMANT: on-chain no active/pending reward campaign (2026-06-24);
known class; reactive DisqualifiedMarketIds mitigation; subsidy-pool not user-funds. **HOLD** — re-eval IF Injective
launches a campaign with R/V_real materially net-positive → then a Medium direct-to-Injective.

**LIVE EV remaining (re-engage triggers):** (1) CROSS-MARGIN risk system (v1.20 fresh code, currently OOS/not-enabled) —
re-audit WHEN Injective enables it; (2) the dormant BO finding on campaign activation. Also informational:
CalculateMarketBalance solvency-recompute is DEAD CODE (0 prod callers) — a leak would persist undetected, but none found.

Methodology lesson this session: [[feedback-workflow-agents-coverage-not-verdict]] — agents are reliable on mechanism,
NOT on verdict (labeled the BO finding High; hand-verification → Medium-dormant). Relates to [[boros-tooling-calibration]].
