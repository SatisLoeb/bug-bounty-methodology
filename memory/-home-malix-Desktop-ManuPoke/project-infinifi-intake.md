---
name: project-infinifi-intake
description: "InfiniFi iUSD yield-stablecoin (Cantina bounty $100k) — heavily-swept fortress. 25-agent xseam hunt = 0 survivors. Crown-jewel loss-dodge = likely known/design. Only fresh payable-if-real surface = new Pareto/Morpho farm adapter valuation-desync, but external-dependency + high dedup risk (needs mainnet fork)."
metadata: 
  node_type: memory
  type: project
  originSessionId: 7156c583-7af7-4e92-807a-9f2dd26bbf35
---

# InfiniFi iUSD — Cantina bounty intake (heavily-swept fortress)

**Program:** Cantina BOUNTY (509e46d0…, assetGroup=2 "redefined core"), infinifi-protocol, LIVE, Cantina-Triaged.
$100k Critical / $15k High, $50 deposit, **348 findings submitted**. PoC MANDATORY for Crit/High. Bounty on
DEPLOYED verified contracts (deployer 0xdecaDAc8…). Repo github.com/InfiniFi-Labs/infinifi-protocol @ HEAD
352b5e0 (2026-06-03 update). Workspace ~/Desktop/BUGS/infinifi-2026/infinifi-protocol.
IN SCOPE: oracle manipulation + flash loans. OOS: prior Spearbit/Certora/Cantina/TestMachine/ThreeSigma
findings, CapFarm rounding, centralization/rogue-admin, design choices, extreme-market-only, theoretical-no-PoC,
**LLM-generated submissions** (writeup MUST pass chill).

## Saturation: HIGH. 5 reviews (all ≤ Jun 2025) + 348 findings + Certora FV.
Fresh surface = the 2026-06-03 delta (commit 122fc10: NEW farms ParetoFarm/MorphoUmbrellaFarm/CapFarm, ZERO
tests, post-all-audits) + the redefined V3 core (YieldSharingV3, InfiniFiGatewayV3, MigrationController).

## Crown-jewel valuation spine (hand-mapped)
`Accounting.totalAssetsValue() = Σ farm.assets() × oracle.price()` (LIVE, never stored, Accounting.sol:48-55).
`YieldSharingV3.unaccruedYield() = totalAssetsValue()/price(iUSD) − iUSD.totalSupply()` (YSV3:178-187), a LEVEL
fn settled ONLY by keeper-gated `accrue()` (ACCRUE_YIELD role — the V3 delta, was callable in V2). Profit→mint
& distribute to stakers/lockers (vested 8h via interpolation); loss→buffer→lockers→stakers→**lastly ratchet
DOWN the iUSD FixedPriceOracle** (YSV3:343-376). mint/redeem price off FLAT oracles (RedeemController
._getReceiptToAssetConvertRatio :173-178 reads price(iUSD)/price(asset), does NOT call accrue first), NOT live NAV.

## Verdict: 0 clean survivors. Near-fortress.
- **Crown-jewel LOSS-DODGE (my lead):** during an unaccrued loss (farm dropped, accrue not yet called), redeem
  pays at stale-high iUSD oracle → liquid holder dodges loss, dumps on others; V3 accrue-gating widens the
  (protocol-controlled) window. REAL mechanically BUT = fixed-peg-redemption + delayed-loss-realization, the
  central design property 5 audits + Certora FV certainly modeled → likely KNOWN/design + brushes extreme-market
  OOS. [[feedback-model-accounting-invariant-not-economic-ideal]] trap. NOT committed.
- **NAV-manip-for-profit:** REFUTED — redeem/mint use flat oracles not NAV; accrue payout diluted+vested+gated →
  a one-shot NAV spike has no direct permissionless payout.
- **25-agent xseam workflow (wf_86f6d96b) → 0 survivors / 4 refuted:** (1) MigrationController.migrate delta-credit
  = needs un-deployed farm + not-yet-existent syncAssets-hook config (trigger-reachability fail); (2) ParetoFarm
  .assets() hand-rolled apr0 interest + no maxWithdrawable reconcile = external-dependency lead; (3) MorphoUmbrella
  stale cachedTotalAssets = impact backwards (LEVEL fn self-corrects) + documented intentional; (4) LockingController
  .depositRewards 0/0 DoS = governance-gated (targetIlliquidRatio>0 on empty module), known/design.
- **ParetoFarm hand-read (ParetoFarm.sol:95-137):** assets() sums external Pareto reads (withdrawsRequests,
  apr0Users, virtualPrice, instantWithdrawsRequests) + lazy `apr0Principal×rate` interest + `shares×virtualPrice`.
  NO purely-structural over-report provable from repo; any desync depends on Pareto IdleCDOEpochVariant behavior
  (shares-burned-on-request? interest gross-vs-net? default transitions) → needs MAINNET FORK w/ real Pareto state.

## Sharper re-hunt of the 2 under-covered seams (operator asked) → BOTH CLEAN (my own read)
- **BeforeRedeemHook** (movement/BeforeRedeemHook.sol): fund-routing that pulls farm liquidity to fund a redeem.
  Benign `mulDivUp` per-farm rounding; assets()>liquidity() can revert a proportional redeem = griefing not theft;
  amount fixed by flat oracle, not manipulable by farm choice. Clean.
- **AfterMintHook** (movement/AfterMintHook.sol): deploys minted deposit into the allocation-weighted farm. Mint
  amount fixed by flat oracle BEFORE the hook; internal MintController→farm move, no extraction/reentrancy. Clean.
- **RedemptionPool + RedemptionQueue** (funding/RedemptionPool.sol): queue stores the iUSD RECEIPT amount, funded
  FIFO at the FUND-TIME convert ratio → queued redeemers correctly absorb post-enqueue price changes (NO stale-price
  dodge on the queued path; the loss-dodge only touches the empty-queue immediate path = the known design). All
  rounding protocol-favorable (mulWadDown asset out / divWadUp receipt burned); userPendingClaims only grows via
  real funding (no over-claim); assets()=balance−totalPendingClaims (no double-count). Clean.

## FINAL VERDICT: FORTRESS / NO-GO (RE-SOURCE)
0 workflow survivors + crown-jewel loss-dodge likely-known/design + all 3 re-hunted fresh seams hand-verified clean.
Only residual = Pareto/Morpho farm-adapter valuation-desync, but external-dependency (needs mainnet fork w/ real
Pareto/Morpho state) + HIGH dedup/design-choice reject risk → not worth the fork on a $100k bounty already 348-deep.
RE-SOURCE. [[feedback-check-prior-audits-and-competitions-at-intake]] [[feedback-today-impact-before-poc]]
