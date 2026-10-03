# TARGET: Exactly protocol | PLATFORM: Immunefi | DATE: 2026-10-03

SCOPE: `github.com/exactly/protocol` — core (Market, Auditor, InterestRateModel,
RewardsController, StakedEXA, MarketETHRouter) + periphery (DebtManager, Swapper,
InstallmentsRouter, FlashLoanAdapter, EscrowedEXA, DebtRoller, previewers).
Deployed on Optimism, Ethereum, Base (proxies, timelock-gated). `verified/` family
(Firewall, VerifiedMarket, VerifiedAuditor) deployed ONLY on Base.
Reward: max $100k; critical = 10% economic damage, floor $25k. KYC + code PoC required.

Method: xsurface-prioritize (top-down threat model, go/no-go BEFORE deep audit).
Reachability verified by reading access control in-code at /home/user/exactly/protocol.

---

## ASSETS (terminal value, high -> low)
- A1: Market LP principal + borrower collateral (direct theft / drain) — up to TVL per market.
- A2: Protocol solvency (bad debt / forced undercollateralization).
- A3: Oracle/price integrity (financially exploitable).
- A4: Fund-lock DoS (withdraw/repay bricked).
- A5: Reward tokens (EXA/OP distribution).

## ENTRY POINTS / TRUST BOUNDARIES (confirmed in code)
- Market deposit/mint/borrow/withdraw/repay/liquidate/seize — validated by ERC4626 math,
  FixedLib.checkPoolState, Auditor callbacks.
- Auditor solvency root: checkBorrow/checkShortfall/checkLiquidation + Chainlink assetPrice + adjustFactor.
- Allowance boundary: borrow()/borrowAtMaturity()/withdrawAtMaturity() share the SAME
  allowance mapping as ERC4626 transfer (spendAllowance, Market.sol:857).
- Accounting: totalAssets() from internal floatingAssets, NOT balanceOf (MarketBase.sol:179).
- Periphery: flashloan callbacks (Balancer V2/V3), permit flows, Swapper socket call.
- verified/: Firewall allowlist gates VerifiedMarket/VerifiedAuditor on Base.

## ACTORS
- anonymous caller | allowed: deposit/repay/liquidate/flashloan | boundary cross gives: nothing clean (see gate).
- borrower/LP | allowed: own position ops | cross gives: value extraction only via standing allowance (by-design).
- liquidator (permissionless) | bounded by checkLiquidation shortfall + seize cap.
- admin/timelock | param setters, setFrozen, upgrades, market listing, Firewall allow.
- cross-contract peer (listed Market) | only caller of seize; EOA fails checkSeize.

## AUDIT DENSITY (dup calibration) — exactly/audits repo, 30+ reports, 6 firms since 2021
Core: Coinspect x5, Chainsafe x2, ABDK x2. RewardsController: Coinspect x3 + ABDK (Mar-25).
IRM v2: ABDK+Chainsafe+Hashlock (Mar-24). Staking: Chainsafe+Sherlock (Aug-24).
Non-Collateral Markets: ABDK (Sep-26, newest). EXA cross-chain: ABDK (Mar-26).
=> Any textbook lending/ERC4626/oracle bug = HIGH dup. Even the fresh surfaces are freshly audited.

---

## CANDIDATE PATHS (reachability verified; gate applied)

P-01 [ALLOWANCE-CONFLATION] borrow(receiver=attacker, borrower=victim) drains an over-approving victim.
  reachability: conditional(victim granted a STANDING eToken allowance)
  scope-exclusion: DURE (documented by-design; requires victim over-approval = user error)
  dup: High | edge: Med | value: Med
  -> DROP (by-design footgun, not a protocol bug)

P-02 [LIQUIDATION-ILLIQUIDITY-DOS] same-market seize reverts InsufficientProtocolLiquidity at ~100% util.
  reachability: conditional(sustained ~100% util + single-market collateral)
  scope-exclusion: molle (accepted design trade-off; liquidator has workarounds)
  dup: High | edge: Med | value: Med
  -> DROP / P2-watch (not borrower-forceable, well-trodden tension)

P-03 [ORACLE-STALENESS] latestAnswer() consumed with no updatedAt/round/sequencer check.
  reachability: conditional(external oracle/L2 sequencer fault) — NOT attacker-triggerable in-contract
  scope-exclusion: DURE (explicit in-code accepted-risk Auditor.sol:349; commodity; not attacker-controllable)
  dup: High | edge: Low | value: High(if it fired)
  -> DROP (known/accepted + not reachable by attacker)

P-04 [FIXEDPOOL-YIELD-SANDWICH] front-run depositAtMaturity to capture unassignedEarnings slice.
  reachability: reachable
  scope-exclusion: DURE (MEV-only; redistribution among fixed-pool suppliers, no protocol principal)
  dup: Med | edge: Low | value: Low
  -> DROP (MEV exclusion)

P-05 [REWARDS-REENTRANCY] _claimSender persists across reentry; a hooked reward token pays attacker.
  reachability: UNREACHABLE today (EXA=ERC20Votes, OP/shares no callback; no hooked reward token listed)
  scope-exclusion: precondition = admin lists a hooked token (admin action)
  dup: Med | edge: High | value: Med
  -> DROP now / WATCH (latent; only if a non-standard reward token is ever added)

P-06 [REWARDS-ROUNDING-UNDERFLOW -> MARKET DoS] signed->uint cast of subtraction without >=0 check
     (RewardsController.previewAllocation, :562 and :581) can wrap to ~2**256, bypass the rewards==0
     guard (:583), overflow borrowIndex/depositIndex (:627/:632) -> IndexOverflow revert on the hot
     path shared by every deposit/withdraw/borrow/repay = market-wide permanent fund-lock.
  reachability: conditional(a fixed-point rounding boundary in the general branch) — UNCONFIRMED, low confidence
  scope-exclusion: none if real (permanent freezing of funds = in-scope High/Critical)
  dup: Med (bespoke Exactly integral math, novel) | edge: Med | value: High(if confirmed)
  -> P2 / the ONE lead worth a time-boxed PoC spike
  caveat: mulWadUp on the undistributed term biases conservatively (undistributed UP => rewards DOWN
          toward 0), and target->0 collapses rewards->0; this likely defuses it. Needs numeric fuzz to settle.

P-07 [FLASHLOANADAPTER SHARES/ASSETS DoS] shares (previewWithdraw, rounds up) reused as asset amount;
     redeem rounds down; deposit of amounts[0]+fees from a balance funded only by the recipient's
     repayment -> settle reverts -> leverage/roll path bricked.
  reachability: conditional(admin set a wToken for the asset + vault low liquidity + ERC4626 rounding)
  scope-exclusion: none (periphery DoS), but value is low
  dup: Low (newest/least-audited, Balancer V3 wrapper) | edge: High | value: Low (DoS of convenience path, no drain)
  -> P2 (low value caps it even if real)

P-08 [DEBTMANAGER _msgSenderSet ASYMMETRY] permit modifier sets _msgSender but not _msgSenderSet,
     so a reentrant msgSender-gated call passes assert(!_msgSenderSet) with stale victim identity.
  reachability: UNREACHABLE today (no listed market re-enters DebtManager; standard ERC20 underlyings)
  dup: Low | edge: High | value: Med(if reachable)
  -> DROP now / WATCH (latent; only if a hooked token is ever listed)

P-09 [VERIFIED/FIREWALL lock + liquidate] lock() forfeits a disallowed account's early-withdraw discount;
     VerifiedAuditor liquidate skips shortfall + double round-up dust over-seize on disallowed borrowers.
  reachability: conditional(admin removes victim from Firewall allowlist)
  scope-exclusion: DURE (admin-trust precondition; deliberate sanctioned-account wind-down)
  dup: Low | edge: Med | value: Low (griefing-with-loss / dust; no attacker profit)
  -> DROP (admin precondition + by-design)

P-10 [STAKEDEXA 1-UNIT ROUNDING] principal unstake coupled to reward settlement can revert at a 1-unit deficit.
  reachability: conditional(aggregate rounding edge) — KNOWN/TESTED/ACCEPTED at ==1 unit (StakedEXA.t.sol)
  dup: High | edge: Low | value: Low (self-healing/recoverable)
  -> DROP (acknowledged + tested; informational dup)

### Confirmed-dead (UNREACHABLE, verified in code) — do not spend time here
ERC4626 inflation/donation/first-depositor; token-callback reentrancy for listed assets; debt escaping
the solvency bitmap; premature handleBadDebt clearing; checkSeize unauthorized seize; uninitialized-proxy
front-run; unauthorized upgrade (transparent proxy, timelock ProxyAdmin); IRM base-rate underflow;
close-factor denominator underflow; >256-market index overflow (admin-only); self-liquidation/over-repay;
PriceFeedPool reserve manipulation (EXA-display-only, not a collateral feed); composed-feed malformed value
(fails closed); RewardsController fake-market/duplicate double-claim, first-touch over-accrual, permit
replay/redirect, keeper redirect; DebtManager fake-market (Aug-2023 class), userData injection, permit
front-run; InstallmentsRouter/DebtRoller force-borrow; Swapper arbitrary-call drain; EscrowedEXA
redeem-without-vesting.

---

## DECISION GLOBALE: NO-GO as a broad target. Narrow WATCH on P-06 only.

Rationale (no theatre):
- One of the most-audited lending protocols in DeFi; the hardening is real and verified in code,
  not assumed. Every classic vector is closed.
- The only non-dup, non-by-design, non-admin-gated lead with real value is P-06 (RewardsController
  rounding underflow -> market DoS), and it is UNCONFIRMED with a conservative-rounding argument
  against it. P-07 is novel but low value (periphery DoS, no drain).
- Add KYC friction + $100k cap. Expected value of a broad audit is low.

## TEMPS ALLOUE (honest):
- 4-6h MAX spike, scoped to P-06: Foundry fuzz of the two uint casts in RewardsController.previewAllocation
  (:562, :581) with tiny deltaTime and target near the distributionFactor>0/==0 seam, on the general
  (non-target->0) branch, with a deployed market's params.
  - If an underflow wraps negative and reaches IndexOverflow on the hot path => escalate to a real
    High/Critical permanent-fund-freeze report (then xchain-triage + chill for the writeup). GO-narrow.
  - If conservative rounding holds (likely) => full DROP, close the target.
- Secondary, only if time left and P-06 dies: ~2h on P-07 ERC4626 rounding of a configured wToken
  (Low value, do not over-invest).
- Do NOT commit a multi-day deep audit of the core. It will produce dups.
