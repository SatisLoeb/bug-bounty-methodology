---
name: project-morpho-intake
description: "Morpho Cantina public bounty ($2.5M max, live since Mar 2024, 1507 findings): SC core = 27-audit fortress, 2 prior operator findings BOTH WITHDRAWN, config-class explicitly OOS, only fresh surface = Midnight"
metadata: 
  node_type: memory
  type: project
  originSessionId: 1cddd5e1-a775-4c40-bc31-1244e19cbfd8
  modified: 2026-07-25T18:41:36.834Z
---

**Morpho / Morpho** — Cantina **public bounty** (NOT the competition), `35a5f0a1-2ffd-432c-8f3b-77d169add8c3`.
LIVE, Cantina-Triaged, no deposit. Live since **27 Mar 2024**, **1,507 findings submitted** (heavily farmed).
Rewards: **Critical $2.5M / High $50k / Medium $10k / Low $3k** (per-asset-group table is lower:
Crit $150k-$1.5M, High $10k-$50k, Med $3k-$10k, Low $1k-$3k).

## Operator's own prior submissions here: BOTH WITHDRAWN, $0
- **#446** (23 Mar 2026, Medium, **Withdrawn**) — "liquidation-sdk-viem: hex string conversion corrupts
  Paraswap slippage across all markets, wrong Curve pool in USD0++ swap path". This is the double SDK bug
  from `morpho-recon/MORPHO-RESULTS-BRIEF.md` (`swap/paraswap.ts:32` bps→hex→`NaN` at slippage≥200, and
  `LiquidationEncoder.ts:304` using `curvePools["usd0usd0++"]` where the sibling at :217 correctly uses
  `usd0usdc`).
- **#486** (29 Mar 2026, Medium, **Withdrawn**) — "Pendle liquidation handler hardcodes 4% slippage,
  ignoring caller-specified protection".
- **Likely cause of withdrawal: the OOS clause "Issues in testing/utilities packages"** — the
  liquidation SDK reads as a utilities package. **The off-chain-SDK vein has therefore been TRIED and
  PULLED. Do not re-run it without first resolving whether liquidation-sdk-viem counts as in-scope.**

## Prior recon (Mar 2026, ~4h full-stack, `~/Desktop/BUGS/morpho-*`, 11 dirs)
`morpho-recon/MORPHO-RESULTS-BRIEF.md` is the summary. SC core = **fortress**: 27 audits / 12 firms /
Certora, virtual shares correct, flash-loan timing safe (interest on `block.timestamp`), IRM too slow for
same-block extraction, callback reentrancy safe. 52 candidate findings across Vault V2 / Bundler3 /
Pre-Liquidation / MetaMorpho V1 all closed as documented-or-audited. Web: 70+ subdomains, GraphQL
introspection + CORS `*` but read-only on-chain data; matomo.morpho.org `API.getSettings` unauth. Bot
`amountOutMinimum: 0n` on UniV4 (sandwichable on Base, no Flashbots) but **separate repo, scope-doubtful**.
Governance: Sentora PYUSD $308M + RLUSD $146M on 1-of-1 Safes = curator config = OOS.

## ⚠ SCOPE: Morpho PRE-WRITES the exact clause that killed Doppler #784
> *"Issues resulting solely from deployer or curator parameter choices or configuration decisions.
> Researchers should notify the relevant deployer or curator via their security contact."*

Plus: *"Design choices of the protocols"*, *"Known issues, known limitations, documented risks and
behaviors"*, *"Every issue opened in the repo, closed PRs, previous contests and audits are out of
scope"* (enormous dup surface), *"Bugs in third party contracts or applications that use Morpho
contracts"*, *"Issues in testing/utilities packages"*, and for web: *"Any theoretical vulnerability for
which there is no demonstrated impact on Morpho users"*.

⇒ **The absent-guard / missing-cap / curator-misconfig class is EXPLICITLY unpayable here.** xseam's
sibling-non-gardé shortcut is structurally dead on this target. Hunt the ESCAPED-GUARD form only
(a guard that EXISTS, driven out of its own invariant by a permissionless action).
See [[feedback-findings-die-on-the-actor-not-the-mechanism]].

## Current scope, assetGroup=1 (the only genuinely FRESH surface)
**Midnight** — Morpho's new **fixed-rate lending** protocol, `github.com/morpho-org/midnight/tree/main`
(**unpinned main**, i.e. active development), plus **Midnight Bundles**
`github.com/morpho-org/bundles/tree/main/src/midnight`.
**Vault V2** (pinned commits): VaultV2Factory `0xA1D9…0405` @2f0c4a38, MorphoMarketV1AdapterV2Factory
`0x32BB…ccc1` @21910a00, MorphoVaultV1AdapterFactory `0xD1B8…3394` @2f0c4a38, Morpho Registry
`0x3696…364e` @d3b239ba (vault-v2-adapter-registries).
Other asset groups: **WebApps**, **Morpho Blue and Vault V1** (both covered by the Mar-2026 pass; Blue/V1
is the 27-audit fortress).

**READ: Midnight is the only surface not covered by the Mar-2026 recon and not yet 27-audited.
Fixed-rate lending = new invariant class (rate/maturity accounting) = where an escaped-guard can live.**
Vault V2 was already swept in March. Everything else is farmed or fortress.

## MIDNIGHT INTAKE (2026-07-25, cloned to ~/Desktop/ManuPoke/morpho-midnight/{midnight,bundles})
HEAD **b864533 (2026-07-24, i.e. daily-moving, PR #1069+)**. **1,560 LOC total**, core `src/Midnight.sol` = 665.
Design (novel invariant class): fixed-rate, isolated **immutable permissionlessly-created markets with fixed
MATURITY**; lending/borrowing = trading **credit/debt units** (zero-coupon payoff, settle at maturity);
**offers do NOT lock capital, liquidity sourced only at settlement**; multi-collateral; `gates` for access
control; `ratifiers` authorize offers; TickLib for offer ticks; loss-factor for bad debt.

**SATURATION = HIGH despite being pre-launch.** `audits/`: Spearbit 2026-04-07 (DRAFT), **Blackthorn
2026-07-02**, **TrustSec 2026-07-02** (both final). Plus ~20 **Certora CVL specs** (Solvency,
OnlyExplicitPayerCanLoseTokens, Healthiness, Liquidate/LIF bounds, Consume, Ratification, ContinuousFee,
SettlementFeeSpread/Boundaries, Role, Reverts, BalanceEffects, CreatedMarkets, LossFactor…) + a **Rocq/Coq
proof** (`rocq/maxRepaidHealthy.v`). The Certora README is effectively a MAP OF EXISTING GUARDS → use it to
hunt ESCAPED-guard (where a proven property's assumptions/harness don't cover reality), never absent-guard.

**NOT DEPLOYED**: no address in the repo and **no asset address in the Cantina scope table** (Vault V2 rows
have addresses, Midnight rows have only a GitHub link). Payability = pre-launch severity call, no live TVL.

**POST-AUDIT DELTA (the whole vein): only 15 commits since 2026-07-02, and `src/Midnight.sol` is UNTOUCHED.**
The ONLY `src/` changes are a brand-new periphery contract:
- `#1067` **BlueBuyCallback added 2026-07-22** (90 LOC) + Factory (20) + interfaces
- `#1073` "callback max buyer assets" (07-23) and `#1074` "**Cap buyerAssetsBound by Blue's real loan token
  balance**" (07-23) = the bound retrofitted TWICE within 24h of landing
⇒ post-all-3-audits, **ZERO Certora coverage** (grep: no spec mentions BlueBuyCallback), 4 test files exist.
It bridges **Midnight ↔ Morpho Blue** (cross-protocol composition) and sits on the PAYER path (Certora:
"in `take` the payer can only be the `buyerCallback` if it is passed").

**⚠ BUT the headline pull-risk is PRE-DOCUMENTED by the devs** (`BlueBuyCallback.sol:21-22`):
*"Anyone authorized by the owner on Midnight can pull from the Blue position held by this callback contract
by making the owner buy dummy credit on Midnight."* Reachability confirms it: `Midnight.sol:453/482`
`buyerCallback = offer.buy ? offer.callback : takerCallback` — maker-controlled on a buy offer, TAKER-
controlled on a sell offer; but `onBuy` requires `buyer == OWNER` and `take` requires msg.sender == taker or
authorized-by-taker ⇒ reaching it needs owner-authorization = exactly the documented risk. **Do NOT submit
that** (the Circle-xReserve mistake: documented-intentional = known-issue reject, and Morpho OOS lists
"known issues… documented risks and behaviors").
**Residual un-documented angles on the callback**: hand-rolled EIP-712 in `setAuthorizationWithSig`
(:48-62, own nonce, domain = keccak(DOMAIN_TYPEHASH, chainid, address(this)), reuses Blue's typehashes);
`forceApproveMax` :106 skip-threshold `>= type(uint96).max/2` (COMP/UNI uint96 cap rationale);
`buyerAssetsBound` :90 — but its docstring pre-accepts imprecision ("other buy callbacks might not take all
constraints into account… this is fine") ⇒ advisory/DoS-only, weak.

## CALLBACK/BUNDLER ANGLE PASS (2026-07-25) — 5 REFUTATIONS, interim NULL on this surface
Also cloned `morpho-org/bundles` (HEAD d5dc4c6, 2026-07-24). In-scope midnight path = `src/midnight/MidnightBundlesV1.sol` (295 LOC) + interface (36). Bundles has its OWN audits: Blackthorn + TrustSec **2026-07-06**, plus a certora/ dir. Post-audit delta on bundles NOT yet measured (unshallow fetch died on network; shallow clone ⇒ `git log --since` is meaningless there).

**Refuted, each with the reason (do not re-derive):**
1. **BlueBuyCallback main pull path = DOCUMENTED ⇒ OOS.** `BlueBuyCallback.sol:21-22` states the owner-authorized pull outright. Reachability re-confirmed: `Midnight.sol:453/482` `buyerCallback = offer.buy ? offer.callback : takerCallback` (taker-controlled on a SELL offer), but `onBuy` needs `buyer == OWNER` and `take` needs msg.sender==taker or authorized-by-taker ⇒ lands inside the documented risk.
2. **ConsumableUnitsLib unit/asset precedence — REFUTED.** Looked like a real bug: `Midnight.take` branches on `if (offer.maxAssets > 0)` (:398, consumed accrues ASSETS) while `ConsumableUnitsLib` branches on `if (offer.maxUnits > 0)` (:16, treats consumed as UNITS) ⇒ inverted precedence for an offer with BOTH set. **Killed by `Midnight.sol:376`: `require((offer.maxAssets == 0) != (offer.maxUnits == 0), InvalidOfferCaps())` — XOR, exactly one nonzero, enforced in take.** The both-set state is unreachable ⇒ the two branches are equivalent. (Triangle branch 3 failure: the state cannot exist.)
3. **MidnightBundlesV1 fund accounting = BALANCED in all 5 externals.** Hand-traced in/out per function; each nets to zero and none reads `balanceOf`, so a pre-existing/donated bundler balance is neither drainable by a caller nor accidentally spent. Refunds are parameter-derived (`maxBuyerAssets - filled - fee`), not balance-derived.
4. **`repay` leaves no bundler dust.** `Midnight.repay` ends `safeTransferFrom(loanToken, payer, address(this), units)` — pulls EXACTLY `units`, matching the bundler's `units = assets - referralFeeAssets`.
5. **`BlueBuyCallbackFactory.createBlueBuyCallback(owner)` permissionless = harmless.** CREATE2 `salt: bytes32(0)` but `owner` is in the initcode ⇒ address differs per owner; anyone may deploy for anyone but the artifact is byte-identical and owner-controlled, so no front-run advantage. Second call for the same owner just reverts (CREATE2 collision).

**Also noted (DOCUMENTED ⇒ OOS, don't submit):** `Midnight.sol:101-102` — *"Fully consumed assets-based offers can still be taken for nonzero units when the asset amount added to consumed is zero"* = a free-units rounding edge the devs already wrote down. Same for :100 (no-op take can call an offer's callback even at consumed==max) and :103 (consumed manually increasable).

**Un-exhausted on this surface:** `TakeAmountsLib` (33 LOC) rounding in `buyerAssetsToUnits`/`sellerAssetsToUnits` — feeds the bundler's EXACT-equality requires (`filledBuyerAssets == targetFilledBuyerAssets`), so an overshoot = bundle-wide revert (liveness, likely Low); `setAuthorizationWithSig` EIP-712 details (mirrors Blue's, domain over `address(this)`+chainid, single global nonce but signer must == OWNER); `forceApproveMax` `>= type(uint96).max/2` skip threshold; and the bundles post-audit delta once network allows.

## ⭐ CERTORA ASSUMPTION-GAP MAP (2026-07-25) — the escaped-guard vein, BOUNDED to 3-16 collaterals
**The specs document their own limits. This is the highest-value artifact of the engagement.**

**Systemic knobs** (`certora/confs/*.conf`): `optimistic_loop: true` in ~33 confs, `loop_iter: 2` in ~28
(a few at 3). `optimistic_loop` ASSUMES the loop exits within the bound ⇒ anything needing more iterations
is outside EVERY proof.

**Explicit written assumptions (quote them, they're the project's own words):**
- `Healthiness.spec` (added #1020, 2026-07-07): `persistent ghost uint256 globalMarketCollateralLength { axiom globalMarketCollateralLength <= 2; }` with comment **"Limit the number of collateralParams for performance reasons."** ⇒ the whole "healthy stays healthy" guarantee is axiomatically ≤2 collaterals.
- `NoDebtWithoutCollateral.spec:72`: `require market.collateralParams.length <= 10, "assume less than 10 collaterals so that the loop can be bounded"`.
- `LossFactor.spec:188`: `require position[id][borrower].collateralBitmap == 0, "Assumption: no active collaterals: skip loop and maximize badDebt"` ⇒ the loss-factor no-revert proof SKIPS the collateral loop entirely.
- `OnlyAuthorizedCanChange.spec:21` + `NotCreatedMarket.spec:22`: `function UtilsLib.countBits(uint128) internal returns (uint256) => NONDET;` ⇒ **the very function enforcing the 16-collateral cap is summarized nondeterministic**.

**The reachable-vs-proven band:** contract allows `MAX_COLLATERALS = 128` per market and
`MAX_COLLATERALS_PER_BORROWER = 16` active per borrower (ConstantsLib), market creation is PERMISSIONLESS.
Proofs cover ≤2. ⇒ **the 3-16 active-collateral band is reachable by ordinary `supplyCollateral` and is
outside the formal envelope.** State is REACHED (not constructed) ⇒ satisfies the PoC tell + triangle b3.

**The money math inside the unproven loops** (both call an EXTERNAL ORACLE per iteration):
- `isHealthy` `Midnight.sol:902-912` — `while (_collateralBitmap != 0)` accumulating
  `maxDebt += collateral_i.mulDivDown(price, ORACLE_PRICE_SCALE).mulDivDown(lltv_i, WAD)`, returns `maxDebt >= debt`. The protocol's solvency gate.
- `liquidate` `Midnight.sol:644-657` — same walk, accumulating `maxDebt` AND
  `badDebt = badDebt.zeroFloorSub(collateral_i.mulDivUp(price,SCALE).mulDivUp(WAD, maxLif_i))`, then gates
  `NotLiquidatable` and realizes bad debt into `lossFactor` (loss socialization).

**REFUTED here (don't re-derive):** the "escape the 16-cap ⇒ loop grows to 128 ⇒ gas-DoS ⇒ permanently
unliquidatable" hypothesis. `setBit` has EXACTLY ONE call site (`Midnight.sol:572`) and it IS guarded by
`require(countBits(newBitmap) <= MAX_COLLATERALS_PER_BORROWER)` (:574-576); every other bitmap write is
`clearBit` (only reduces). Cap holds.

**STATUS: gap MAPPED and BOUNDED, no violation demonstrated yet.** An unproven region is where to LOOK,
not a finding — and Morpho OOS explicitly kills "any theoretical vulnerability for which there is no
demonstrated impact". Rounding candidates inside the band look like dust (per-collateral `mulDivDown`×2 in
isHealthy understates maxDebt by ≤1 wei each ⇒ ≤16 wei; `mulDivUp`×2 in liquidate understates badDebt
similarly) and pure gas cost is OOS ("attacks with crazy high gas consumption").
**NEXT: executed invariant harness driving 3-16 ACTIVE collaterals** (reached via ordinary supplyCollateral),
asserting the properties Certora proved only for ≤2: Solvency, healthy-stays-healthy, liquidation bounded by
maxLif, badDebt realization. Build kicked off (`forge build`, submodules init'd).

## EXECUTED PROBE #1 in the 3-16 band (2026-07-25) — NULL, drift 0
Build works: `git submodule update --init --recursive --depth 1 && forge build` (solc 0.8.34, ~10min first run; morpho-blue submodule pulled for the periphery). Harness = `test/MultiCollateralGapTest.sol` (extends BaseTest; deploys N ERC20Permit + N Oracle, address-sorted collateralParams as the protocol requires; Oracle defaults to price 1e36 so no setPrice needed).
**Result — borrowing-power differential, same total collateral value (16e18) split 1/2/3/8/16 ways:**
`@1 = @2 = @8 = @16 = 12_320_000_000_000_000_000`, `@3 = ...998`, **drift 1→16 = 0 wei**. The 2-wei at n=3 is MY harness's `total/n` truncation (16e18/3*3 = 16e18-2), NOT protocol behaviour. ⇒ splitting collateral across the unproven band neither mints nor destroys borrowing power. **NULL.**
Also confirmed executable: 16 collaterals activate via the ordinary path and the **17th reverts** (`test_gap_activeCollateralCapBinds`), so the loop bound really is 16 and it's reachable.
**⚠ LIMITATION of probe #1 (fix before trusting it further):** `_healthyAt()` RE-IMPLEMENTS the contract's maxDebt formula instead of calling `midnight.isHealthy(market,id,borrower)` — so it tested my reimplementation, not the contract. Bisecting on the real `isHealthy` requires actually creating debt (offer + take), which is the next probe anyway.
**NEXT PROBE (where the value is):** drive REAL debt via `setupMarket`/`take`, then exercise the **liquidate** loop at 3-16 active collaterals — that is where `badDebt` accumulates through 16 `zeroFloorSub(mulDivUp∘mulDivUp)` terms and gets socialised into `lossFactor`, and where `LossFactor.spec` assumes `collateralBitmap == 0` (loop skipped entirely). Assert: solvency (balance ≥ Σcollateral + withdrawable + fees), liquidation bounded by maxLif, and badDebt realisation vs an independent recomputation.
