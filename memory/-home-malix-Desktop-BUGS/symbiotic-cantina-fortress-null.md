---
name: symbiotic-cantina-fortress-null
description: Symbiotic Cantina $500K SC bounty audited 2026-06-29 = earned fortress-null; whole SC core conserved by internal-accounting design
metadata: 
  node_type: memory
  type: project
  originSessionId: c7de116e-6455-4791-b861-80ad7b777734
---

Symbiotic Cantina public bounty (`acca29a4-d405-4405-a3b3-8c3feb10d1e3`, $500K Crit / $100K High / $10K Med, KYC, live since 2 Feb 2026, **326 submissions ~95% noise per operator**, 22 in-repo audits = OOS). Audited 2026-06-29.

**Scope pinned to deployed commits** (worktrees in `~/Desktop/BUGS/symbiotic-fresh/`): core `3b6add2` · rewards-v1 `6cca0f6` · rewards-v2 `b5a1f5b` (v2==v1 logic, events-only diff) · burners `7e887e7` · hooks `71ea3ce` · periphery/migrator `9cc6d3b` (DefaultCollateralMigrator lives in **symbioticfi/periphery**, not collateral). sUSDe_Burner in-repo but NOT scoped.

**Verdict: earned fortress-null.** ~19 contracts hand-poked + cross-repo intersections traced + 24-agent apparatus (170-finding OOS dedup, 10 clusters) → **0 survivors**. Prior Jun-20 firmaudit (slashing-only, wrong commits on rewards/burners/hooks) was NOT trusted and redone fresh.

**Why it's a fortress (load-bearing facts, hand-verified):**
- Vault ERC4626 runs on **internal `_activeStake`/`_activeShares` checkpoints, never `balanceOf`** → donation/first-depositor/inflation attack structurally dead (offset 0 `+1` virtual is enough).
- `Vault._migrate` **reverts()** → vaults non-upgradeable → entire proxy-upgrade finding class impossible.
- Slashing conserved (prior-fortress Karak-mirrors hold): sequential clamp to `activeStake`, `cumulativeSlash` post-capture deduction, `latestSlashedCaptureTimestamp` monotonic, opt-in@capture required.
- Rewards pro-rata by `activeSharesOfAt/activeSharesAt` (reward token ≠ collateral → slash-independent); operator-rewards cumulative-merkle per `[network][token]` (no cross-network drain).
- Intersections all conserved: rewards↔vault checkpoints, burners↔slasher (atomic attribution in `executeSlash`, no front-run window in isBurnerHook=true), hooks↔delegator.onSlash (gas-swallowed stale-limit only), NetworkMiddlewareService network-isolated by msg.sender key, MigratablesFactory CREATE2-safe (monotonic totalEntities salt).

**The 3 candidates that surfaced are all Low/Info, NOT payable** (don't submit, $10 deposit + credibility): (1) resolver veto inception-window = design-intent (resolver has jurisdiction only over its tenure, self-heals 1 epoch, network self-rug); (2) BurnerRouter permissionless-onSlash misattribution = dup ChainSecurity Note 8.4(2), only between OWNER-configured receivers; (3) `setDelegator/setSlasher` missing access-control = griefing of empty/unconfigured vault only (configurator is atomic), likely acknowledged.

**Reinforces [[feedback-target-diet-is-the-binding-constraint]] + [[reserve-program-closed-dup-fortress]] + [[midas-program-closed-fortress-null]]:** heavily-audited Cantina DeFi/restaking cores close fortress-null; this is the wrong target diet regardless of $500K ceiling. Re-open ONLY on a NEW post-`3b6add2` version or a newly-scoped component (e.g. rewards-v2 repo proper, relay). Apparatus confirmed the manual read (coverage, not verdict) — [[feedback-workflow-agents-coverage-not-verdict]].
