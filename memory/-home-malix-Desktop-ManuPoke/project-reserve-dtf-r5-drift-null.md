---
name: project-reserve-dtf-r5-drift-null
description: "Reserve Index DTF (Folio) rc-5.0.0 / r5.0.0 — full r4->r5 post-audit-drift audit = EXECUTED-NULL. Mega-saturated ($10M-class, multi-audit). Drift concentrated on RebalancingLib auction math + StakingVault reward-streaming+votes; both dug deep (one fork-PoC burned, refuted the theft). No payable primitive on any drift surface. RE-SOURCE."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

**Reserve Index DTF (Folio) `reserve-protocol/reserve-index-dtf` @ r5.0.0** (operator wrote "rc-5.0.0"; the tag is
`r5.0.0`, base `r4.0.0`). EVM/Foundry, verified. Scope: Folio, FolioDAOFeeRegistry, FolioDeployer, FolioProxy,
FolioVersionRegistry, FolioGovernor, GovernanceDeployer, StakingVault, UnstakingManager, Versioned, RebalancingLib,
MathLib. Impact rubric: **Critical = governance-voting-result manipulation / direct theft / permanent freeze**; High =
theft-of-unclaimed-yield / insolvency; Medium = temp-freeze / griefing. `~/Desktop/BUGS/reserve-index-dtf`. Pairs
[[project-reserve-dtf-filler-seam-null]] (prior $10M-Cantina filler-seam null).

**Approach = NUKE diff r4.0.0 (post-audit-drift focus, the ONLY edge on a mega-saturated core).** Drift concentrated:
RebalancingLib +133/-63, Folio +89/-60, StakingVault +59/-16, FolioDeployer +56/-28, FeeRegistry +34/-6,
GovernanceDeployer +5/-2. NUKE barrage: slither/aderyn failed compile (node_modules not installed at barrage time),
semgrep only → 9 in-diff signals ALL `basic-arithmetic-underflow` in RebalancingLib (0.8 noise, but marked the drift math).

**EXECUTED-NULL — register of killed theft-paths (2026-07-22/23):**
- **RebalancingLib getBid/bid/_price (auction Dutch-price math) — /extract G1 KILL by reading.** Every rounding is
  protocol-favorable: bidAmount = **Ceil**(sellAmount×price) (bidder pays more), sellLimitBal **Ceil** + buyLimitBal
  **Floor** (availability reduced), _price start/end/decay all **Ceil**, floored at endPrice. Price is a governed Dutch
  auction (sellPrices/buyPrices set by AUCTION_LAUNCHER within rebalance initialPrices bounds) — no unprivileged manip.
- **maxAuctionSize cap (new r5) — Door A KILL.** `auction.traded[tok]` per-auction vs maxAuctionSize per-rebalance:
  the per-auction reset is TESTED + intended (`test_maxAuctionSizeSellSide/BuySide`, "bid up to max again in new auction").
  createTrustedFill sizes via _getBid (capped); price delegated to the trusted filler (`@reserve-protocol/trusted-fillers`
  = **OOS repo**, `filler.initialize(...,buyAmount)` enforces it) — trusted-by-design, not an in-scope theft.
- **StakingVault governance vote-manipulation (Critical ceiling) — READ-BLOCKED ×3 + PoC-confirmed.** (1) getPastVotes
  (past-block snapshot) blocks flash-vote; (2) unstaking delay (UnstakingManager.createLock) locks shares; (3) pps can
  never go below fair (`rewardsBalance = balanceOf(asset)-totalDeposited ≥ 0`, native rewards only ADD) → cannot mint
  cheap shares=votes. PoC confirmed pps only rises.
- **StakingVault reward-streaming theft (High) — FORK-PoC REFUTED (the one burned PoC).** r5 turned the 1:1 wrapper into
  a reward-streaming ERC4626 (native asset() rewards → totalDeposited → pps, alongside token-index rewards). Attack:
  Bob deposits AFTER a reward is sent (only Alice staked) to capture it. `test/StakingVaultAttack.t.sol` (real StakingVault,
  their harness, HL=3d): NATIVE front-run Bob out=1250 (+250) == TOKEN front-run (+250) == FLAT-capital (+250). Two
  disconfirmers: native≡token (no native-specific asymmetry) AND front-run==flat (joining after the reward gives NO edge
  — Bob earns his fair streaming share for holding 50% during the stream; Alice's "loss" is streaming dilution, the
  Synthetix/MasterChef model, intended). Pivot verified moved (1000→1250, not a no-op).
- **FolioDeployer / GovernanceDeployer / FeeRegistry (small deltas) — config/refactor, clean.** Deployer restructured
  (deploy Folio w/ temp admin → grantRole timelocks → renounce; new self-govern path) — ATOMIC, salt=keccak(msg.sender,
  nonce) bound-to-caller, roles land on gov timelocks. GovDeployer = pure refactor (`new StakingVault{salt}` →
  StakingVaultDeployLib), self-govern transfers stToken ownership to timelock atomically. Only angle = CREATE2 address
  front-run = griefing Low, retryable. FeeRegistry = MAX_DAO_FEE/FLOOR const→immutable, now chain-specific
  (BNB 33.33%/10bps, else 50%/15bps) — benign parameterization, no fee-logic change.

**VERDICT: RE-SOURCE.** Mega-saturated core, full r4→r5 drift audited, value-moving surfaces read+PoC clean, ONE PoC
burned that REFUTED the theft (not proved a fortress). Cheap-gate discipline held. Don't re-audit this delta. LESSON:
post-audit-drift on a mega-audited protocol CAN be a real fresh surface (concentrated, meaningful — reward-model rewrite +
new auction cap), worth the delta-dig; here it resolved clean. [[feedback-tool-complete-stop-polishing]]
[[feedback-check-prior-audits-and-competitions-at-intake]] [[project-stbl-fortress-executed-null]].
