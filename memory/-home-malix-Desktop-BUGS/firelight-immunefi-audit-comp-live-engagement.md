---
name: firelight-immunefi-audit-comp-live-engagement
description: "Firelight (Immunefi audit-comp, $20K, LIVE till 25 Aug 2026) — fresh cover protocol on Flare; vault + allocator read-solid first-pass; IncidentManager waterfall + oracle UNREAD"
metadata: 
  node_type: memory
  type: project
  originSessionId: f1a1c109-bacb-4d9a-86f8-2aa9c53f2da9
  modified: 2026-08-15T16:27:53.809Z
---

**Firelight** — on-chain cover/insurance protocol on **Flare**. Immunefi **audit competition** ($14K primary + $4K allstars + $2K podium = $20K USDC), **LIVE 12–25 Aug 2026** (~9 days left as of 15 Aug), Runnable PoC required, triaged. Fresh (assets added 8 Aug), thin-audit (the comp IS the audit; Phase-1 vault already on Flare mainnet). 3,044 in-scope LOC.

**Repo:** `github.com/immunefi-team/audit-comp-firelight`, branch **`v1_audit_ready`** (@ 42f9ea5, 31 Jul 2026), **Hardhat** (`npm install && npm test`, default accounts, no .env). Clone at `~/Desktop/BUGS/audit-comp-firelight`. Docs: docs.firelight.finance.

**IN-SCOPE (14 assets) = `contracts/core/*` + `contracts/oracle/FtsoChainlinkAdapter.sol` ONLY:** FirelightVault(1133) + FirelightVaultStorage(88), CoverOrderAllocator(1012), IncidentManager(908), CoverNFT(174), VaultRewardDistributor(210), lib/{Checkpoints(403), PriceFeed(43), Decimals(31)}, oracle/FtsoChainlinkAdapter(251), + core/interfaces. **OOS = `contracts/fasset/*` (Flare FAsset third-party ifaces) + `contracts/legacy/*` (legacy vault, context only).**

**SCOPE ANGLE (the key):** heavily permissioned MVP (curator authors orders, roles settle/assess/payout) — but **"a role EXCEEDING its intended authority OR bypassing a protocol constraint = IN SCOPE"** (they say it twice). So double-settle / capacity-bypass / payout-misallocation / premium-under-collect are valid even though role-gated. Purchaser's only untrusted action = premium-token approval. Deposits blocked during incidents; withdrawals NOT.

**Dev confession map (unusual design points):** FirelightVault deviates from ERC4626 (withdraw/redeem = DELAYED request → `claimWithdraw` next period); matching off-chain, settlement on-chain via Merkle; settled order mints ERC721 receipt (NFT ≠ payout asset); first-loss buffer = EXTERNAL unescrowed wallet, USD-pegged token valued by decimal-convert (no oracle); "payout logic intentionally does not cap the first-loss-buffer leg by allowance before safeTransferFrom" (revert-as-misconfig); aggregate claims NOT capped on-chain vs total cover sold (curator responsibility, OOS).

**FIRST-PASS READ (2026-08-15, READ-LEVEL only, ZERO executed):**
- **FirelightVault (READ-SOLID):** period-bucketed delayed withdrawals (`_requestWithdraw` books into `currentPeriod()+1`); loss-socialization in `payout()` captures `withdrawAssets[capturePeriod+1]` (+`[+2]` if payout in capturePeriod+1) so in-flight withdrawers bear their share; holders bear via share-price (`_traceTotalAssets` reduced). Only "escape" = curator mis-times payout = operational/OOS. Per-period withdraw-pool is a mini-share-system (no external donation path → no inflation attack). Conversion uses OZ virtual-shares (`+10**offset`, `+1`).
- **CoverOrderAllocator (READ-SOLID):** `_settleCoverOrder` = double-settle blocked (PENDING→MATCHED), Merkle leaf binds `orderId+marketCoverAllocations` (double-hashed OZ std), `totalSettledCover ≤ totalDeclaredAllocated`, per-protocol concentration cap, premium recomputed pro-rata + charged before NFT mint. `cancelExpiredOrders` (permissionless) only hits EXPIRED+PENDING orders, no fund/capacity move → harmless.

**UNREAD (the richest remaining, where a fresh finding likely is):**
1. **IncidentManager (908 LOC)** — incident creation/confirmation/assessment rounds/approval-rejection-cancel, FIFO ordering, **payout waterfall** (first-loss-buffer leg + vault leg). The insolvency/over-pay surface. TOP PRIORITY.
2. **VaultRewardDistributor (210)** — pulls vault assets from authorized distributors, forwards rewards, checkpointing. Accounting drift.
3. **FtsoChainlinkAdapter (251) + lib/PriceFeed** — Flare FTSO v2 → Chainlink AggregatorV3 adapter; freshness/positivity. Oracle-manipulation IN scope (oracle-bad-data OOS). Flare-specific.
4. **lib/Checkpoints (403)** — historical vault accounting (balanceOfAt/totalAssetsAt/totalSupplyAt used by payout exposure cap). Off-by-one / checkpoint-lookup at period boundaries could break the payout exposure cap `totalAssetsAt(capturePeriodStart)`.
5. **createCoverOrder / commitAllocation capacity math** — `_computeAvailableCapacity` from first-loss buffer + vault; recommit path.

**FULL FIRST-PASS READ COMPLETE (2026-08-15, all 6 core contracts, READ-LEVEL, ZERO executed):**
- **IncidentManager (READ-SOLID):** `_executePayout` waterfall = FLB stablecoin leg (decimal-convert $1-peg, Floor/Floor dust only) → vault leg (priced via FtsoChainlinkAdapter). `approveCurrentAssessment` enforces FIFO (`incidentId == _earliestPayableIncidentId`) + nonReentrant. Payout is 100% role-gated (curator/approver) — NO untrusted path. Over-pay-beyond-exposure = OOS (curator responsibility).
- **FtsoChainlinkAdapter + PriceFeed (READ-SOLID):** reads live Flare FTSO v2 over STATICCALL (decentralized multi-provider feed — NOT a manipulable AMM pool, so no flash-loan oracle-manip). PriceFeed guards positivity/updatedAt≠0/answeredInRound≥roundId/freshness. `answeredInRound==roundId` always here (both=ftsoTs) → that check is a no-op but not a bug.
- **Checkpoints (READ-SOLID, faithful OZ fork):** wraps OZ Trace208 + a parallel `_values[]` uint256 array (trace stores the index into _values; `_values[0]=0` sentinel so `idx>0` = found). Index-mgmt verified correct across same-key-overwrite/pop. `totalAssetsAt` returns the right value → payout exposure cap holds.
- **VaultRewardDistributor (READ-SOLID):** role-gated (DISTRIBUTOR); transfer-to-vault + `checkpointTotalAssets()` ATOMIC → no reward-capture front-run window. `totalAssets()=super.totalAssets()−pendingWithdrawAssets` (LIVE=real balance) so deposits price on real balance incl. just-forwarded rewards; donation = harmless gift (OZ virtual-shares handle first-depositor inflation).

**VERDICT: comprehensive first-pass READ = all-solid, thin untrusted surface (only vault deposit/withdraw/claim/transfer + cancelExpiredOrders + donation are untrusted-reachable, all solid). Heavily-permissioned MVP shrinks the surface; IncidentManager (biggest seam) has NO untrusted path. NO finding. NOT executed (read-null, not executed-null).** EV modest ($20K competitive pay-per-share). Well-engineered codebase for v1_audit_ready.

**IF RESUMED:** either (a) execute ONE Hardhat disconfirmer on the vault loss-socialization / claim-timing (convert read→executed per anti-predict-null discipline — the only untrusted money-path worth a PoC), or (b) RE-SOURCE to higher-EV live leads ([[xterio-web-app-engagement]] TOP LEAD stored-XSS→ATO; [[livepeer-l1migrator-fresh-scope-engagement]] ACTIVE). Related: [[feedback-predicting-executed-null-before-executing-is-a-negative-posture]], [[feedback-depth-is-an-edge-only-where-ore-remains]].
