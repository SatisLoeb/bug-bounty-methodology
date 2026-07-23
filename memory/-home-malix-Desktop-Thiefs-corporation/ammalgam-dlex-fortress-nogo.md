---
name: ammalgam-dlex-fortress-nogo
description: "2026-07-10 /gravedigger on Ammalgam DLEX (Cantina b5e376ee, Crit $25k/High $10k, on-chain-loss-only) → fortress, executed NO-GO; 17/17 fork PoCs refute every vein incl. the saturation $10k bull's-eye."
metadata: 
  node_type: memory
  type: project
  originSessionId: 914bc620-9c67-4278-a39f-ed4329452173
---

# Ammalgam DLEX — executed NO-GO (fortress)

Cantina bounty `b5e376ee-2fe9-47eb-a667-df98d3d201ae` = **Ammalgam DLEX** (NOT Injective/Upshift — the gravedigger
skill text has a stale ref to this URL). Uni-V2 fork + fused lending, oracle-free, 6 tokens/pair, mid-call
`IAmmalgamCallee` callback with the reentrancy lock RELEASED around it. 18 deployed mainnet contracts.
Payable = **on-chain loss of funds only**, Crit $25k / High $10k. OOS carve-out: loss needing >33%/−25% in a
single block/8s. 3 prior reviews (ChainSecurity + 0xMacro + 476-submission Cantina comp, $10k earmarked Saturation).

**Workspace:** `~/Desktop/Thiefs-corporation/ammalgam-audit/` (isolated from BUGS per operator; init-target.sh
hardcodes BUGS — had to `mv` it out). Deployed source via Etherscan API (core-v1 repo now private) →
`src-merged/`. **Fork harness `fork-tests/` = 17 tests, all green, deployed bytecode is the arbiter.**
One live pool only: USDC/WETH `0x728fD0A966B993fe518B00122D51e494F99aBd6a`, ~$85-90k, lending active.

## Verdict: FORTRESS. Every vein refuted by EXECUTED fork PoC (operator rule: "no likely — hand-verify by PoC").
- **Saturation-liquidation uncapped premium** (main branch no `min(·,2000)` cap the straddle sibling has) — the
  $10k bull's-eye. REFUTED: `newSat` is **price-independent** (in-band swap → `LiquidationZeroPremium`); a SOLVENT
  victim's max seizure ≈1.7% (fair "cover-gas" penalty); 20% needs ~19yr interest + deep insolvency; no LP
  socialization (`isBadDebt=false`). `DriftPoC.t.sol`.
- **Callback-seam debt-shed** (#1 predicted vein): `ERC20Base._update`→`validateOnUpdate` checks the
  risk-increasing party on EVERY transfer and fires inside the released lock → shed-to-uncollateralized-mule
  reverts `AmmalgamDepositIsNotStrictlyBigger`.
- swap→borrow→liquidate 1tx (attacker self-loses 16,933 USDC; worst-corner TWAP valuation); borrowLiquidity
  flash window (LP per-share non-decreasing); first-depositor/donation (costs attacker ~1000×); PeripheralLending
  (all pulls `from=msg.sender`); hard-liq over-seize (reverts `NotEnoughRepaidForLiquidation`). All executed.

**Door-C (darkside, manual, no fan-out) also FORTRESS:** diffed the fused canonical form (Uni-V2 ⊕ Compound),
attacked every deviation's unwritten invariant with an executed PoC. Freshest: **staged-burn park** (parking
DEPOSIT_L to fake-shallow the pool moved victim capacity 0.035%, reserves identical — slippage term is
collateral-dominated, so it's DoS-at-most); **borrow-L directional round-trip** (attacker left with residual
debt, LP per-share rose). Shared saturation-state is msg.sender-keyed (no cross-pair write). Only residual =
quadratic-fee stale-referenceReserve = fee-revenue foregone, not principal (OOS). See findings/DOORC-CLOSED.md.

**Structural fortress roots:** per-transfer `validateOnUpdate` (self-heals the intra-callback seam) · worst-corner
TWAP-bounded valuation (spot manip only hurts attacker) · saturation price-independent + single-shot baseline ·
reserves in storage not balanceOf. Full record: `CLOSEOUT-ammalgam.md`. Related: [[metric-omm-extract-fortress]],
[[rheo-size-fork-fortress]] (same shape: thin/no payable vein on an oracle-anchored/AMM-lending fortress).

## UPDATE 2026-07-11 — multi-stage thief methodology found ONE payable finding the fortress passes MISSED
**F1 (HIGH): leverage-liquidation socializes an UNCAPPED premium to LPs.** `verifyHardLiquidation` caps its premium
(`checkHardPremiums`, Liquidation.sol:157); `liquidateLeverage`/`liquidateLeverageCalcDeltaAndPremium` has NO cap →
a badDebt leverage-liq burns `shortfall + uncapped premium` from DEPOSIT_L (passive LPs). `P-SELFLEV`: self-liq
(allowed outside a callback, `activeBorrower==0`) makes the collateral seizure a no-op (from==to) → borrower keeps
collateral + wipes debt (subverts first-loss); attacker in DEPOSIT_X/Y collateral eats 0 of the DEPOSIT_L burn.
EXECUTED on deployed bytecode, pure-INTEREST drift (in-band): r=1.37 → LP per-share −2.76%, excess-over-shortfall
+2,648e18, attacker +1,296e18 (fork-tests/test/Exit4Lev.t.sol, LevPremiumUncapped.t.sol). Ceiling = HIGH (premium
bounded; deployed pool ~$85k; the burnBadDebt L-branch double-sub amplifier is a no-op/revert via updateAssets
line 131, executed-refuted DoubleSubProbe.t.sol).
FOUND VIA: Stage-1 fortress-to-thief pierce (inventory) → seam trace PX-1..7 → **Stage-2 impact-decomposition**
(9 agents by TERMINAL IMPACT not component; exit "bad-debt socialization" surfaced it) → **Stage-3 solo** cross-module
verification. Methodology lesson (operator's thesis, validated): the class-based fan-out (3 fortress passes) MISSED
it because the bug is a COMPOSITION between two audited functions that no per-component agent owns; decomposing by
impact + solo synthesis found it. PX-5 (borrow-moves-oracle) + P-SATCONFIG both EXECUTED-DEAD (DoorC_PX5/DepleteLiq/
SatConfig). No standalone Critical exists. Findings: findings/F1-*.md, STAGE3-SOLO-RESULTS.md, INVENTORY.md, SEAM-TRACE.md.

## UPDATE 2026-07-11b — mandatory apparatus-OFF cold poke of the DEPLOYED LAYER (darkside §0.5.5) = SOLID, read not mapped
Operator's final discipline: manual-impro poke is a MANDATORY bracket, apparatus OFF first (subtractive), follow the
one weird thing one input at a time, zero corpus/schema/workflow; the apparatus fires only AFTER. I had SKIPPED the
deployed layer (mapped it "admin/trusted"). Executed it with pure `cast` reads (read-only ≠ live testing):
- **Engine upgrade authority** (shared SaturationAndGeometricTWAPState `0xaac0…d9fc`): EIP-1967 admin → ProxyAdmin
  `0x7e5b…09ae` → `owner()` = TimelockController `0x59eC…eef8`, `getMinDelay()=604800` (**7-day timelock**). SOLID.
- **Fee/param setter** (`feeTo==feeToSetter`=`0x74EB…6E64`): a **Gnosis Safe, 7 owners / threshold 4** (bytecode =
  Safe minimal proxy; `getOwners()`/`getThreshold()=4`). Not takeable. Beacon impl = normal AmmalgamPair. SOLID.
- **The one genuinely-weird thread — `externalLiquidity` = 1.186e17 on the live USDC/WETH pair vs activeLiquidity
  L≈3.81e14 = ~312×.** It is added to `activeLiquidityAssets` in EVERY solvency/liquidation check (Validation.sol:94,
  AmmalgamPair.sol:1163) but NOT in liquidation EXECUTION → a solvency-only input that nukes the `increaseForSlippage`
  buffer. FOLLOWED to exhaustion, gate HOLDS: (value) 312× ≈ ~$10M represented on a ~$32k pool = *conservative* vs
  real USDC/WETH external depth (~$100M+), sane not misconfig; (writer) `grep` = EXACTLY ONE assignment
  (TokenController.sol:160) inside `updateExternalLiquidity`, no ungated sibling; (gate) `onlyFeeToSetter` =
  `if(msg.sender!=factory.feeToSetter()) revert` — direct msg.sender, no authn≠authz, feeToSetter=the 4-of-7 Safe,
  `setFeeToSetter` itself onlyFeeToSetter + constructor-set (no init-gap); runs OUTSIDE the timelock but needs 4/7
  keys. Full State-gate pierce-list (ungated-sibling/become-the-actor/intra-block-transient/composed-arrival/
  edge-math) all executed-null. **The diamond is not in this wall.**
Net: the deployed layer (nobody's audit scope — audits read CODE not on-chain state) is now PROVEN solid by reads,
not assumed. NO-GO stands, backed by BOTH the code-layer fortress AND the deployed-layer read. Lesson kept: the
cold poke is mandatory even when the surface "looks admin" — but here it came back solid, and the discipline is to
conclude honestly, not answer a clean poke with more machinery.

## UPDATE 2026-07-11c — operator "pourquoi les autres trouvent des findings ?" → re-opened the 2 surfaces I under-ran
Two honest gaps the challenge exposed: (1) **F1 self-rejection** — the literal scope is "on-chain loss of funds";
F1 is an EXECUTED on-chain LP loss (DEPOSIT_L −2.76%, no price move, not a design choice, not the >33%/−25% carve-out)
→ it QUALIFIES. I killed it on a stricter SELF-IMPOSED "attacker beats risk-free ROI" bar (CHECKPOINT-8 economics),
which is NOT the bounty's gate. Honest status = coin-flip High (real risk it's judged Medium=no-tier=$0, + unresolved
dup vs the 476-sub competition), NOT a kill. Concede-a-gate error. (2) I had NEVER read the **post-audit-delta**
contracts (the scope's own EV-flag, audit-immune) nor deeply dissected **Saturation.sol** ($10k earmark).
- **Post-audit-delta read (PairFrozen/LockedLoans/BlockLendingFundRemoval/BeaconController/HookRegistry/Peripheral):**
  all admin-gated. BeaconController = std OZ AccessControl, `upgradeTo`→7d-timelock, `upgradeToAllowed`(instant emergency
  swap to Frozen/Locked impls)→MULTISIG_ROLE(4-of-7 Safe); no become-the-actor. HookRegistry: 1inch ERC20Hooks wired
  into ERC20Base, 500k-gas hook callback fires on every transfer BEFORE validateOnUpdate and STILL fires during
  liquidation (validateOnUpdate skipped) — real callback surface BUT `addHook` is registry-gated (`isHookAllowed`,
  owner=the 4-of-7 Safe); attacker can't self-register → dormant/admin. Not attacker-reachable.
- **Saturation.sol dissection (8 terminal-impact hypotheses, hybrid: my hand-trace + an 8-agent workflow, I
  hand-verified every verdict):** FORTRESS. Penalty subsystem enforces settle-before-refresh everywhere (the load-
  bearing one: `mintPenalties(update,0)` at AmmalgamPair:1084 settles the `update` party before the tree delete at
  removeSatFromTranche:778) → no wipe escape. tranche-move `tranchePenaltyAdjustment` bridges `effective=leafPen+adj`
  continuously (monotonic, no underflow). double-round-up = conservation dust (Math.min balances, unconditional mint).
  timestamp throttle = duration-integrated. balanced-straddle membership loops to F1.
- **H8 (completeness-critic) — the one NEEDS_POC lead — maxLeaf BRICK, REFUTED BY EXECUTED PoC:** hypothesis was
  `AmmalgamPair.burn` is an UNGUARDED sibling writer of activeLiquidity that lowers maxLeaf=satToLeaf(activeL) without
  update(), pushing maxLeaf < highestSetLeaf+3 (SATURATION_MAX_BUFFER_TRANCHES) → then every borrower `update()`
  incl. finalizeLiquidation:998 reverts MaxTrancheOverSaturated → underwater positions un-liquidatable → LP bad-debt.
  `fork-tests/test/MaxLeafBrick.t.sol` (deployed bytecode): pool 200k, C=75,786e18 netX pins highestSetLeaf near top;
  the pool PERMITS burning only 20k of the attacker's 160k (activeL 200k→180k, ~10%) — any larger burn reverts at the
  STAGING TRANSFER, because transferring DEPOSIT_L to the pair triggers validateOnUpdate and `getInputParams` subtracts
  `stagedBurnAssets` (AmmalgamPair:1150-1157) so the maxLeaf guard sees POST-burn liquidity and fires. burn is NOT
  unguarded — `stagedBurnAssets` is the exact defense (a mechanism neither the agent nor my first trace saw; found by
  BUILDING the PoC and reading the revert). Post-max-burn the pool is still healthy. REFUTED.
Conclusion: re-open RAISED confidence in the NO-GO (the $10k surface + delta contracts are proven-robust, not assumed).
Method win: the workflow maps coverage, the hand-built PoC decides — H8 looked live until the executed artifact surfaced stagedBurnAssets.

## UPDATE 2026-07-11d — F1 SCOPE-FIT SETTLED by measurement: OOS-hardening, NOT a bounty (operator corrected me, again right)
I re-worked the F1 report's bug-vs-design argument (2-of-3 premium-cap invariant + the "extreme, unlikely case" comment
tell + NatSpec silence — genuinely stronger) and almost re-submitted. Operator caught it: I strengthened the WRONG link.
Bug-vs-design was never the blocker — SCOPE-FIT is, and it's decided by two NUMBERS (CHECKPOINT-8 case 3), not an argument,
and I'd reformulated instead of measured. Re-ran the deciding artifacts on deployed bytecode (fork-tests:
DriftEconomics/MaxUtilDrift/MaxUtilAttack):
- **Real drift time to r=1.37 = ~360 days (~1 year)** at high util (NOT 20 years — the F1 PoC's `240` is a loop CAP; it
  `break`s at ~12 iters=360d). At r=1.37 the ANNUALIZED GROSS extraction is **3.85%** — below the risk-free rate, before costs.
- **Self-dealing attacker net = NEGATIVE.** MaxUtilAttack (attacker drives util + holds the drifting position, self-liq,
  minimal-repay clean-exit): IN 392,379e18 / OUT 253,906e18 → **NET −138,473e18** (loses outright). The simple self-dealer
  earns 3.85% annualized gross < risk-free → net-negative after capital opportunity cost + 1yr lockup.
- The ONLY positive-extraction path (+7,413e18 third-party liquidator) needs a NATURAL victim to sit un-liquidated for ~1yr
  (liquidator absence = market condition, not attacker capability); no such position exists on the live pool.
VERDICT: no loss of funds a RATIONAL ATTACKER realizes → fails exclusion #1 (result not mechanism) + #2 (design gap producing
a loss only in a 1-yr economically-losing scenario). F1 = honest HARDENING, disclosable to the team OUT-of-bounty as goodwill,
NOT a bounty claim. DID NOT submit. LESSON (operator's, keep): on a money-path finding, the scope-fit is decided by MEASURED
economics (real-time drift + attacker net after capital cost), not by strengthening the bug-vs-design framing; a triager
dismisses an argument, never a fact, and here the fact (no realized/rational-realizable loss) is on THEIR side. Don't polish
the strong link to avoid measuring the weak one.
