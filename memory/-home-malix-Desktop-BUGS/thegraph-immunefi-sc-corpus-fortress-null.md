---
name: thegraph-immunefi-sc-corpus-fortress-null
description: "The Graph SC (Immunefi, $50K cap) — corpus-backed executed fortress-null; 3 top corpus classes applied, all handled"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0d683fbc-0da4-4fc4-96ca-4ba883ca4500
  modified: 2026-08-27T21:19:14.959Z
---

**The Graph — Immunefi SC bounty**, 36 assets (ETH+Arbitrum), **$50K max cap**, KYC required, Immunefi-triaged, $1.5M paid. Impacts = **>$1M theft directly from protocol SC only** (+ private-info + impersonation). Verdict 2026-08-27: **CORPUS-BACKED executed FORTRESS-NULL → RE-SOURCE.** Workspace `~/Desktop/BUGS/thegraph-audit/` (src = graphprotocol/contracts monorepo; SYNTHESIS in PROGRESS.md).

**Saturation (verified, HIGH):** 42+ audit docs — legacy core 29 (ConsenSys/OZ/Trust), Horizon 6, issuance 6, token-dist 1. **ZERO post-audit mainnet delta**: "Last Updated 27 Aug 2026" = a **testnet** gip-0089 deploy (arbitrumSepolia, OOS); last mainnet CONTRACT change was 2026-05-29 (`508c01e5`), before the last audit (2026-06-05). Deployed in-scope code = exactly as audited. Known audit issues explicitly OOS.

**Scope nuance:** REO (RewardsEligibilityOracle) in scope; but `IssuanceAllocator` + `RecurringAgreementManager` (issuance pkg) NOT in the 36. SubgraphService, HorizonStaking, GraphPayments, PaymentsEscrow, GraphTallyCollector, RecurringCollector ARE (Arbitrum).

**The corpus method — the reusable win (per [[feedback-corpus-match-pull-the-discovery-how]]):** no Graph dup in immunefi/solodit/c4, but 3 top high-value CLASSES matched; pulled each discovery_how and APPLIED it to the code (executed, not label-matching). All 3 handled:
1. **Reward double-collect / stale-snapshot** (#60426 off-by-one; solodit "trace storage writes around accrual, check R-M-W ordering") → `AllocationHandler.presentPOI/_resizeAllocation/_closeAllocation` → HANDLED (508c01e5 fix re-reads storage; close-strand = loss-to-indexer not theft).
2. **Exit-accrual / thaw reward** (the STRONGEST signal: 7× High @ vechain-stargate #60019/#60081/#60154/#60431/#59776/#60150/#60028; method = trace claim-window exit clamp; solodit "enumerate balance-mutating paths, which call the reward-checkpoint hook") → `HorizonStaking._undelegate/_withdrawDelegated` → HANDLED BY DESIGN: undelegate snapshots FIXED tokens into a separate thawing bucket; `addToDelegationPool` grows only `pool.tokens` not `tokensThawing`; the `pool.tokens - pool.tokensThawing` share-price base IS the audited defense vs this exact class; slash symmetric.
3. **Signature-replay voucher** (belong Medium cluster #57800/#57373/#57283; method = nonce/deadline/domain-separator/malleability/cumulative-double-collect) → `GraphTallyCollector._collect` (RAV) → HANDLED (cumulative valueAggregate delta, `require(tokensRAV>alreadyCollected)`, `dataService==msg.sender`, all domain fields EIP-712-signed, partial-collect capped, signer authorized-by-payer).

**Lesson (reinforces the session's binding constraint):** heavily-audited SC core + low cap + zero delta = the wrong-diet fortress the session keeps hitting ([[feedback-target-diet-is-the-binding-constraint]], [[protocol-fortress-null-hunt]], [[symbiotic-cantina-fortress-null]], [[stakewise-immunefi-sc-v2-legacy-null]]). The corpus backstop here CONFIRMED the fortress efficiently — it hands you the exact classes that pay elsewhere, and when a mature protocol handles all of them by design, that IS the measured null. RE-SOURCE to a fresh <2-audit module / off-chain seam / higher live ceiling, not another audited SC core.
