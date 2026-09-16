---
name: decentraland-offchain-marketplace-xseam-delta
description: Decentraland Immunefi SC scope (5 assets) — xseam audit→deployed delta fully executed → NULL-COÛTEUX; RE-SOURCE to Web&App
metadata:
  type: project
---

Decentraland Immunefi ($500K, PoC+KYC). SC scope = 5 assets: Marketplace V4 (ETH 0x1b67, Polygon 0xa40b), CouponManager 0x3fd3, CollectionDiscountCoupon 0xc914, CreditsManager 0x8b3a. All from `decentraland/offchain-marketplace-contract` (signed-order EIP-712 marketplace + DAO credits). Legacy 2022 contracts = saturated fortress.

**xseam temporal engagement (2026-09-04) — EXECUTED NULL-COÛTEUX.** Deployed commits pinned via Sourcify exact_match (not assumed): marketplaces+coupon = v2.0==HEAD; CreditsManager 0x8b3a = commit edeceb1 (Oct 2025, ~5mo post OZ audit). Ledger:
- Marketplace signature/uses/cancel: post-audit signer-keying (`keccak(signer,keccak(sig))`, commit 17918d6/bacbfdb Sept 2025, 1yr after v1.0.0 audit) = DEFENDED (namespacing closes cross-signer cancel-griefing; signer pinned by SignatureChecker). My "cancel-asymmetry" hypothesis disconfirmed at READ.
- ERC-1271 multi-encoding uses/cancel bypass = KNOWN (smart-contract-audits/smart_contracts_well_known_issues.md L25/31): SC wallets unsupported/un-indexed, fix "in development". No SC-wallet users → not exploitable.
- Marketplace value pipeline (fee/royalty/USD-pegged-MANA convert, order = discount→convert→fee/royalty→net): CONSERVING (full _transferAsset/FeeCollector/RoyaltiesManager read).
- Coupon callerData forge: DEFENDED (discount type/amount/root SIGNED; callerData = only Merkle proofs vs signed root; leaf=keccak(real collectionAddress)). Hypothesis disconfirmed at READ.
- CreditsManager cash-out (spend-only credit→liquid MANA via 2-wallet self-deal; SenderBalanceChanged only checks sender) = **OZ audit M-01 "Acknowledged, not resolved"** (OZ verbatim "the same entity can use many different addresses"). DUP FOSSIL. allowedRoot bypass = **OZ M-02 acknowledged**. Post-audit delta = admin multi-marketplace allowlist (OOS). Custom-external-call = trusted-role gated.

**RE-SOURCE:** payable Decentraland ore = Web & App scope (off-chain, session-gated). Operator already landed Confirmed Critical there ([[decentraland-critical-decodeauthchain-confirmed]] #87537). SC-core saturated. Dossier: `~/Desktop/BUGS/decentraland/XSEAM-DELTA-FRAME.md`. Discipline wins: deployed≠source pin ([[gmtrade-gmx-solana-deployed-build-baseline]]) killed a fixed-on-chain false positive; audit-ack check ([[feedback-audit-acknowledgment-is-a-liability-not-an-asset]]) killed the cash-out dup.
