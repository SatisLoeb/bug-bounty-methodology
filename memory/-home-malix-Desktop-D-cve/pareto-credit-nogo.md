---
name: pareto-credit-nogo
description: "Pareto Credit (Immunefi, Idle epoch credit vaults) = measured NO-GO 2026-09-16; re-arm on impl upgrade"
metadata: 
  node_type: memory
  type: project
  originSessionId: c639357a-aca4-4017-84b4-5a00b153de69
  modified: 2026-09-16T23:44:31.749Z
---

Pareto Credit (Immunefi https://immunefi.com/bug-bounty/pareto/scope/, Ethereum, Idle-Labs/idle-tranches). 3 in-scope epoch credit vaults, senior AA tranche only, USDC: Fasanara (CDO 0xf6223C, impl 0xdd5962, $11.9M), Bastion (0x4462eD, impl 0xf70e98 OLDER, $11.0M), Adaptive (0x14B8E9, impl 0xdd5962, $2.18M). Critical up to $50k (10% funds-at-risk cap NON-binding at these TVLs), High $20k, Med $5k; NO fee, NO KYC, PoC required. Primacy of Impact.

**VERDICT: NO-GO (measured cul-de-sac, hand-verified, 0 fee spent).** Manual bracket + gated fanout (6 finders, executed dirty-number sims). Every unprivileged in-scope money-path in the DEPLOYED bytecode proven fair. Full dossier: ~/Desktop/BUGS/pareto-audit-dossier/ (CANDIDATES.md, deployed/ verified source). Repo clone: ~/Desktop/BUGS/pareto-audit.

**Why (the decisive, hand-verified facts):**
- **All 3 vaults are MONOTRANCHE** — lastNAVBB=0, trancheAPRSplitRatio=100000 (cast-verified). No junior buffer → the entire AA/BB split + loss-socialization code is degenerate → NO misallocation surface. This collapses C1 and the senior/junior class.
- **depositDuringEpoch** enabled only on Bastion (older impl): executed Solidity-exact sim on real chain values, amounts 1wei..5M USDC → existing-holder NAV delta = 0; depositor loses ≤1 atomic unit to floor (protocol-favorable). expectedEpochInterest matches _calcInterest(lastNAVAA) to 1 unit → projection accurate, no dilution. (kills T2/T3.)
- **APR0 flow** (Fasanara live unscaledApr=0): conservation sim holds, each requester ≤ fair pro-rata, dust retained, no theft from stayers, no double-accrual. Devs explicitly test these edges.
- **PR#111 post-default vein (finalizeDefault / IdleCreditVaultWriteOffEscrow / IdleCreditVaultImpliedPrice): HEAD-only, REVERTS on the deployed proxies (cast-verified finalizeDefault → revert), absent from the 939L deployed impl (HEAD=1009L).** Out of DEPLOYED scope (deployed-code-not-head), AND post-default recovery = OOS "borrower default → freezing of funds".
- Structural hardening confirmed: _skimDonatedAssets neutralizes donation/first-depositor inflation; strategy-token _transfer locked unless manager+post-default; strat tokens minted only by CDO 1:1. Contest-farmed (Sherlock 2025-04) + heavily dev-tested; post-contest delta = correctness ADDITIONS, not regressions.
- Prior kills C1 (withdrawal-receipt-vs-default: by-design+OOS), T2, T3 all re-confirmed.

**RE-ARM conditions (this is an ON-CHAIN impl-upgrade watch, NOT the repo drift-watch — the repo already moves; the real trigger is the deployed impl swap on the proxies):**
1. A NEW impl deployed to the in-scope proxies that ADDS finalizeDefault / WriteOffEscrow / ImpliedPrice on-chain (the PR#111 recovery/haircut logic goes live) → re-audit the redistribution math.
2. A junior (BB) tranche funded (lastNAVBB > 0, splitRatio < 100000) → the senior/junior loss-split surface activates → C1/misallocation re-open.
Check via `cast call <proxy> 'lastNAVBB()(uint256)'` + EIP-1967 impl slot (tools/evm-anchor.sh). Applies [[feedback-dedup-per-sink-not-per-class]] + [[feedback-test-in-dirty-numbers]] (both baked into the fanout that ran).
