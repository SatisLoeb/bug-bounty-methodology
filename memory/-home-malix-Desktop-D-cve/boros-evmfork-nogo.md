---
name: boros-evmfork-nogo
description: Pendle Boros Cantina bounty = NO-GO for evmfork (triple-audited fortress, no unprivileged fund-loss)
metadata:
  type: project
---

Pendle Boros (Cantina bounty aa966ff2-4740-49da-af4a-40f85e2e82a3, $500k Crit / $100k High, Arbitrum funding-rate IRS DEX). Audited 2026-09-10 with evmfork (Arbitrum fork substrate) + 13-agent adversarial workflow + local audit-report dup-check + hand-poke. **VERDICT: NO-GO, do not file.** 0 survivors / 14 candidates.

Why: (1) liquidation/deleverage theft-math is onlyAuthorized + registered-liquidator; FIndexOracle onlyKeeper → not unprivileged-reachable; (2) mark-rate manipulation (all 30 markets markRateOracle==0 MEASURED → implied-rate/last-traded-tick path) is RISK-ACCEPTED (ChainSecurity Router&AMM §5.1 + WatchPug WP-I5); (3) funding-sandwich = same §5.1 risk-accepted; (4) unprivileged AMM/OTC/deposit surface clean (_MINIMUM_LIQUIDITY=1e6 blocks inflation, exact scaling, protocol-favorable rounding, Solady kernels). Triple-audited (ChainSecurity/Spearbit/WatchPug — reports in repo audits/, extracted to audits/_txt/).

**Why:** second consecutive evmfork no-go (after [[infinifi-delta-nogo]]). Pattern: the fresh/forkable/payable EVM targets available 2026-09 are hardened fortresses or saturated. The EVM sweep ([[_evmfork-target-sweep]] in ~/Desktop/BUGS) ranked Boros #1-eligible (least-picked @112 findings); everything below it (Symbiotic 373, Makina 326, Kinetiq 410) is MORE saturated → lower EV. Confirms: establish payable+fresh+UNPICKED before deep validation (see [[cosmos-evm-no-payable-venue]], [[strata-immunefi-resource-only-critical-pays]]).

**How to apply:** do NOT re-audit Boros as-is. Re-check trigger: a market configured with non-zero markRateOracle (re-opens Spearbit 6.4.8 staleness). Strategic: the current fresh-EVM well is thin; higher-EV pivot is StackingDAO (Stacks/Clarity, $100k, no KYC, operator's edge surface) even though it parks evmfork. Dossier: ~/Desktop/BUGS/pendle-boros-evmfork/VERDICT.md.
