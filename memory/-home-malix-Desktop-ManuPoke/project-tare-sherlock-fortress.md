---
name: project-tare-sherlock-fortress
description: "Tare (Sherlock 2026-07, RWA consumer-loan vault, Avalanche/USDC) — vault darkside hunt = EXECUTED NULL across 8 sub-surfaces; whole untrusted surface walled/pre-disclosed. Fortress for solo → RE-SOURCE."
metadata:
  node_type: memory
  type: project
  originSessionId: 399efac4-1073-4669-9c21-60111c4ae1a6
---

**Tare** = Sherlock audit contest (2026-07), RWA consumer-loan protocol, Avalanche C-Chain, USDC-only. Repo ~/Desktop/BUGS/tare-2026/tare-io__tare-contracts, scope commit c0b2ab9 (fork HEAD 93c64b9). ~2000 nSLOC. Crowns: PortfolioVault.sol (601, ERC-7540 async + on-chain NAV) + Loans.sol (559, per-loan double-entry ledger). Sherlock = Medium/High only, loss-based.

**TRUST MODEL is the wall (defines scope):** trusted = Guardian/Admin/Servicer/Originator/PortfolioManager/InvestorManager/CalculatingAgent (setters have NO economic bounds by design). Untrusted = loan-NFT owner (Investor/shareholder), Borrower, arbitrary caller. Borrower/Investor/Servicer "trusted within own loan" — valid ONLY if they hurt OTHER loans/users.

**VERDICT (2026-07-20): EXECUTED NULL / fortress for solo → RE-SOURCE.** Operator chose vault darkside hunt. Ran an 8-agent darkside workflow (construct→adversarial-verify, refute-by-default) across vault sub-surfaces: nav-freshness-ledger, async-deposit-lifecycle, async-redeem-lifecycle, counter-desync-donation, nav-curated-list, vault-exchange-seam, ownershipnonce-nft, migration-config-setters → **0 survivors**, each killed by a concrete grep-verified mechanism (cross-controller isolation, lockstep counter pairing totalPending/Claimable==Σ per-controller, floor-toward-vault rounding, ownershipNonce funnels through single LoansNFT._update, idleLiquidity≥reserves inv, DEAD_SHARES 1e18 infeasibility). Matches my own solo read.

**Loans ledger walled MECHANICALLY:** LoansLedger `_getBalanceKey=(uint72(loanId)<<8)|account` is injective → loan A acct X never aliases loan B acct Y; ACC_CASH≥amount floor (only sign rule enforced); from!=to/amount>0 guards. Untrusted fund/pay/investorWithdraw confined to own loan. Cross-loan cash contamination is servicer-fee-inflation only (SECURITY.md item 5, trusted). Exchange tight (anti-frontrun lock: locked-loan investorWithdraw routes to unlocker, seller can't drain a listed loan). TrustedSpender/TrustedCalls delegate-gated (delegate=trusted hot-signer T-10; nuke's "arbitrary-from" HIGH = false positive). SmartAccountFactory untrusted action = deploySmartAccount (Pashov F3 nonce-strand, known).

**DEDUP is huge — everything pre-disclosed:** in-repo audits/pashov-ai-audit-report-20260429.md (4 findings F1 NAV-double-count-mid-batch-acceptOffer / F2 lock-drain≡transfer / F3 factory-nonce / F4 servicer-borrower-pull + 14 leads) AND SECURITY.md (31 known issues + T-1..T-10 trust assumptions + D-1..D-9 design tradeoffs, README-linked=OOS). **D-9 explicitly declares the "master freshness" NAV-lag gap (ownershipNonce covers NFT-set churn only, not per-loan ledger mutation) as an accepted tradeoff** → killed my best lead (a servicer charge-off/waterfall changes a vault-held loan's value without bumping nonce/version, only maxNavAge backstops → but trusted-trigger + manager-gated capture + D-9-disclosed). Previous human audits in a Google Drive (unread, more dedup).

**Sole real-but-NON-PAYABLE residual:** PortfolioVault.sol:1088 `_requireFreshNav` docstring claims "a donation" bumps ownershipNonce, but a raw USDC ERC20 donation does NOT (only loansNFT transfers bump it) → lastNav stays stale-low yet freshness passes. Impact = self-defeating gift (donor net-loses, existing holders+DEAD_SHARES net-gain, zero-sum over real added value) → below Medium → not Sherlock-submittable. Code-vs-comment gap only.

DON'T re-audit the vault/ledger core. If revisiting: only a fresh angle on an un-hunted seam (the Google-Drive human audits could reveal an un-disclosed surface; SmartAccountFactory configureSmartAccount delegatecall/one-shot beyond F3). Pattern confirms [[feedback-hunt-dont-narrate-ev]] (RE-SOURCE off fortresses for solo) + [[feedback-trigger-reachability-is-payability-gate]] (freshness gap real but no untrusted trigger/capture) + [[feedback-payable-impact-not-just-theft]] (ran full non-theft impact-ledger: brick/unfair-distribution/accounting all executed-null).
