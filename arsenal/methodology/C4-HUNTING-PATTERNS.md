# C4 Vulnerability Patterns — Hunting Taxonomy

**Structure:** Protocol type → Entry point → Invariant violated → Detection signal → False positive signal

Each pattern sourced from a confirmed, paid C4 finding.

---

## 1. DEX / AMM

### P-DEX-001: Balance-vs-Reserve Asymmetry in Mint/Burn
- **Source:** GTE Launchpad H-03 (2025-08)
- **Severity:** HIGH (fund theft)
- **Entry point:** `mint()` and `burn()` in LP pair contract
- **Invariant violated:** Mint and burn must use the same source of truth for reserves. Mint uses `getReserves()` (excludes fees), burn uses `balanceOf()` (includes fees).
- **Detection:** `grep -rn "balanceOf\|getReserves\|_reserve" --include="*.sol"` in pair/pool contract. Compare the value source in mint() vs burn(). If mint reads reserves and burn reads balances → finding.
- **False positive:** Both mint AND burn use the same source (either both balanceOf or both reserves). Also safe if fees are synced (via `_mintFee`) before every balance-dependent operation.
- **Fix applied:** Sync fee state before both mint and burn, or use consistent balance source.

### P-DEX-002: Fee-Inclusive Input Inference in Swap
- **Source:** GTE Launchpad H-04 (2025-08)
- **Severity:** HIGH (fund theft)
- **Entry point:** `swap()` in AMM pair
- **Invariant violated:** Swap infers input amount as `currentBalance - (reserve - amountOut)`. When reserve < balance due to accrued fees, the fee gap is counted as free input.
- **Detection:** `grep -rn "amount.*In.*=.*balance.*-.*reserve\|balance.*reserve.*amount" --include="*.sol"` in swap function. Check if `reserve` can diverge from `balance` due to fees.
- **False positive:** Reserve is synced to balance after every fee accrual (no gap possible). Or swap uses explicit `transferFrom` with exact input instead of balance inference.
- **Fix applied:** Sync reserves to balances before swap input inference, or use explicit input tracking.

### P-DEX-003: Free Share Minting via Fee-Reserve Desync
- **Source:** GTE Launchpad H-05 (2025-08)
- **Severity:** HIGH (fund theft — LP dilution)
- **Entry point:** `mint()` when fees have accrued
- **Invariant violated:** LP share calculation uses reserves but actual token balance includes uncollected fees. Minter gets shares priced on reserves but backed by a larger balance.
- **Detection:** `grep -rn "_mintFee\|accruedFee\|kLast" --include="*.sol"` — check if `_mintFee()` updates `totalSupply` and `reserves` BEFORE the liquidity calculation in `mint()`. If fee sync happens AFTER → finding.
- **False positive:** `_mintFee()` called at the top of `mint()` before any liquidity math. UniswapV2 does this correctly.
- **Fix applied:** Call `_mintFee()` before liquidity calculation.

### P-DEX-004: Fee Calculated But Not Deducted from Transfer
- **Source:** GTE Launchpad H-10 (2025-08)
- **Severity:** HIGH (revenue loss)
- **Entry point:** `swap()` fee computation
- **Invariant violated:** Fee is computed in a local variable but never subtracted from the actual transfer amount.
- **Detection:** `grep -rn "fee.*=.*amount.*feePercent\|feeRate\|feeBps" --include="*.sol"` — trace the `fee` variable: is it subtracted from the transferred amount? Or just stored in an accounting variable?
- **False positive:** Fee variable is subtracted from `amountOut` before `safeTransfer`, or fee is collected via separate `collectFee()` with correct accounting.
- **Fix applied:** Subtract fee from transfer amount.

### P-DEX-005: Dust Orders Block Order Book
- **Source:** GTE Spot CLOB H-02 (2025-07)
- **Severity:** HIGH (DoS)
- **Entry point:** Partial fill logic in CLOB matching engine
- **Invariant violated:** Partial fills can reduce maker order amount below minimum threshold. Residual dust produces zero quote on match → revert.
- **Detection:** `grep -rn "amount.*-=.*fill\|remainingAmount\|partialFill" --include="*.sol"` — check if partial fill enforces minimum remaining. Also: `grep -rn "ZeroCostTrade\|zero.*amount\|minOrder" --include="*.sol"`
- **False positive:** Partial fill enforces `require(remaining >= minOrderSize || remaining == 0)`.
- **Fix applied:** Cancel dust orders when remaining falls below minimum.

### P-DEX-006: Amend Bypasses Rate Limit Counter
- **Source:** GTE Spot CLOB H-03 (2025-07)
- **Severity:** HIGH (DoS — orderbook spam)
- **Entry point:** `amend()` / `modifyOrder()` in CLOB
- **Invariant violated:** Order posting increments rate limit counter but amend (which can change price level = effectively new order) does not.
- **Detection:** `grep -rn "incrementLimits\|maxLimits\|limitsPlaced\|rateLimit" --include="*.sol"` — check if ALL functions that create or modify orders increment the same counter.
- **False positive:** Amend increments the same counter as place. Or amend cannot change price level.
- **Fix applied:** Increment rate limit counter in amend.

### P-DEX-007: Memory-vs-Storage in Linked List
- **Source:** GTE Spot CLOB H-01 (2025-07)
- **Severity:** HIGH (DoS — corrupted orderbook)
- **Entry point:** Order removal/insertion in linked list
- **Invariant violated:** Struct field modified on `memory` copy instead of `storage` reference. Backward link never persisted.
- **Detection:** `grep -rn "Order memory\|Position memory\|Node memory" --include="*.sol"` — check if fields on memory copies are expected to persist. Cross-reference with linked list ops.
- **False positive:** All mutations happen on `storage` references. Or struct is explicitly written back to storage after memory modification.
- **Fix applied:** Use `storage` reference for all linked list node mutations.

---

## 2. LENDING / BORROWING

### P-LEND-001: Stale State After Flash Loan
- **Source:** Blend V2 H-01 (2025-02)
- **Severity:** HIGH (fund theft)
- **Entry point:** `flash_loan()` → callback → state-dependent operations
- **Invariant violated:** Flash loan does not refresh interest/emission state before execution. Callback operates on stale rates.
- **Detection:** `grep -rn "flash_loan\|flashLoan\|flash.*borrow" --include="*.sol" --include="*.rs"` — check if interest/emission state is updated BEFORE the flash loan callback.
- **False positive:** `accrueInterest()` or `update_emissions()` called before flash loan disbursement.
- **Fix applied:** Sync all interest/emission state before flash loan.

### P-LEND-002: Emission Theft via Missing update_emissions
- **Source:** Blend V2 H-02 (2025-02)
- **Severity:** HIGH (fund theft — reward siphoning)
- **Entry point:** Any balance-mutating function (deposit, withdraw, borrow, repay)
- **Invariant violated:** Emission/reward state not synced before balance change. Attacker deposits, triggers emission sync, withdraws — claims rewards for period they weren't deposited.
- **Detection:** `grep -rn "update_emissions\|accrueReward\|_updateReward\|rewardPerToken" --include="*.sol" --include="*.rs"` — for EVERY function that changes a user's balance, verify emissions are synced BEFORE the balance change.
- **False positive:** Every balance-mutating path calls emission sync first. Or emissions are calculated per-block with snapshot, not per-interaction.
- **Fix applied:** Call `update_emissions()` before every balance mutation.

### P-LEND-003: Utilization Bypass on Withdrawal
- **Source:** Blend V2 H-03 (2025-02)
- **Severity:** HIGH (liquidity drain)
- **Entry point:** `withdraw()` in lending pool
- **Invariant violated:** Withdrawal does not check post-withdrawal utilization ratio. Lender can withdraw even when doing so would push utilization above safe threshold.
- **Detection:** `grep -rn "withdraw.*utilization\|maxUtilization\|utilizationRate" --include="*.sol"` — check if `withdraw()` validates that post-withdrawal utilization stays within bounds.
- **False positive:** Post-withdrawal utilization check exists and reverts on exceeding threshold.
- **Fix applied:** Add utilization check after withdrawal calculation.

### P-LEND-004: Reentrancy via receive() Resetting Guard
- **Source:** Wise Lending H-01 (2024-02)
- **Severity:** HIGH (fund theft)
- **Entry point:** `receive()` fallback in lending contract calling `_sendValue()`
- **Invariant violated:** Reentrancy guard (`sendingProgress` flag) must never be reset by an untrusted external call. The `_sendValue()` helper sets `sendingProgress=true` then `false`, allowing mid-withdrawal reentry.
- **Detection:** `grep -rn "sendingProgress\|_sendValue\|receive()\s*external\|\.call{value:" --include="*.sol"` — check if `receive()` invokes functions that toggle reentrancy flags.
- **False positive:** `receive()` has `_checkReentrancy()` at start, or guard uses counter (not boolean).
- **Fix applied:** Add reentrancy check at start of `_sendValue()`.

### P-LEND-005: Position Debt Erasure via Invalid Token Parameter
- **Source:** Wise Lending H-02 (2024-02)
- **Severity:** HIGH (fund theft — debt erasure)
- **Entry point:** `paybackBadDebtNoReward()` -> `_removePositionData()`
- **Invariant violated:** Position data removal must validate that the specified token exists in the user's borrow list. Without validation, passing a non-borrowed token removes the last (only) real borrowed token from the array by default index behavior.
- **Detection:** `grep -rn "_removePositionData\|positionBorrowTokenData\|hashMap.*remove\|delete.*borrow.*token" --include="*.sol"` — check if removal functions validate token membership before deletion.
- **False positive:** Removal function explicitly requires token presence in the position array.
- **Fix applied:** Validate token existence in position array before removal.

### P-LEND-006: Global Bad Debt Counter Inflation via Partial Liquidations
- **Source:** Wise Lending H-03 (2024-02)
- **Severity:** HIGH (DoS — fee distribution blocked)
- **Entry point:** `checkBadDebtLiquidation()` called during partial liquidations
- **Invariant violated:** `totalBadDebtETH` (global) must equal sum of all `badDebtPosition[nftId]` (per-position). Global counter increments additively but per-position counter is overwritten (set, not incremented). Multiple partial liquidations inflate the global counter permanently.
- **Detection:** `grep -rn "totalBadDebt.*+=\|badDebtPosition.*=\s" --include="*.sol"` — compare global bad debt operation (`+=`) vs per-position operation (`=`). If global uses `+=` and position uses `=` → finding.
- **False positive:** Both global and per-position use delta-based updates.
- **Fix applied:** Calculate delta between new and current position bad debt; apply only delta to global counter.

### P-LEND-007: Liquidator Underpays by Seizing Public + Private Collateral
- **Source:** Wise Lending H-04 (2024-02)
- **Severity:** HIGH (fund theft from lenders)
- **Entry point:** `_calculateReceiveAmount()` for uncollateralized (purely-private) positions
- **Invariant violated:** Liquidation percentage derived from private collateral must only be applied to private collateral. Code applies percentage to BOTH private and public lending shares, letting liquidator seize unrelated public deposits.
- **Detection:** `grep -rn "getFullCollateralETH\|_calculateReceiveAmount\|uncollateralized\|purelyPrivate\|publicShares" --include="*.sol"` — check if liquidation amount calculation distinguishes collateral types.
- **False positive:** Liquidation only touches the specific collateral type securing the loan.
- **Fix applied:** Restrict liquidation percentage application to private collateral only.

### P-LEND-008: Permit Token Validation Missing in Vault
- **Source:** Revert Lend H-01 (2024-03)
- **Severity:** HIGH (fund theft)
- **Entry point:** `permit2.permitTransferFrom()` in vault lending operations
- **Invariant violated:** Vault must validate that the token in the permit signature matches the vault's underlying asset. Without validation, attacker crafts permit for arbitrary ERC20 and vault accepts it as legitimate collateral.
- **Detection:** `grep -rn "permitTransferFrom\|permit2\|permit.*token\|signatureTransfer" --include="*.sol"` — check if `permit.permitted.token == asset` is validated.
- **False positive:** Token address in permit is validated against vault's asset before processing.
- **Fix applied:** Added `require(permit.permitted.token == asset)`.

### P-LEND-009: Reentrancy via onERC721Received Callback
- **Source:** Revert Lend H-02 (2024-03)
- **Severity:** HIGH (accounting corruption)
- **Entry point:** `safeTransferFrom()` of NFT positions triggering `onERC721Received()` callback
- **Invariant violated:** State updates (collateral tracking, debt shares) must complete before external calls. NFT safe transfer invokes receiver callback mid-state-update.
- **Detection:** `grep -rn "safeTransferFrom.*nft\|onERC721Received\|_updateAndCheckCollateral" --include="*.sol"` — check if NFT transfers occur before state finalization.
- **False positive:** All state updates complete before any NFT transfer, or reentrancy guard on all mutating functions.
- **Fix applied:** Reorder operations: update state before NFT transfer.

### P-LEND-010: Transform Calldata Position ID Mismatch
- **Source:** Revert Lend H-03 (2024-03)
- **Severity:** HIGH (fund theft — cross-position manipulation)
- **Entry point:** `transform()` function with external calldata
- **Invariant violated:** Function validates ownership of the `tokenId` parameter but never verifies that `tokenId` encoded inside `data` (calldata) matches. Attacker passes own tokenId for auth check but targets victim's tokenId in calldata.
- **Detection:** `grep -rn "transform\|abi.decode.*tokenId\|calldata.*tokenId" --include="*.sol"` — check if the validated tokenId is the same one used in the delegated call.
- **False positive:** Transformer contract independently validates caller's ownership of the encoded tokenId.
- **Fix applied:** Validate tokenId consistency between function parameter and encoded calldata.

### P-LEND-011: TWAP Rounding Toward Zero on Negative Ticks
- **Source:** Revert Lend H-05 (2024-03)
- **Severity:** HIGH (oracle manipulation — stale/inflated prices)
- **Entry point:** `_getReferencePoolPriceX96()` TWAP calculation
- **Invariant violated:** When `tickCumulativesDelta < 0` and not evenly divisible by `secondsAgo`, division truncates toward zero (rounds UP for negative) instead of rounding DOWN. Inflated price delays liquidations.
- **Detection:** `grep -rn "tickCumulativesDelta\|secondsAgo\|observe\|tick.*=.*\/.*seconds" --include="*.sol"` — check if negative tick delta applies floor rounding.
- **False positive:** Code includes `if (tickCumulativesDelta < 0 && tickCumulativesDelta % secondsAgo != 0) tick--`.
- **Fix applied:** Added conditional `tick--` for negative non-divisible cases.

### P-LEND-012: Liquidation DoS via safeTransferFrom Rejection
- **Source:** Revert Lend H-06 (2024-03)
- **Severity:** HIGH (permanent DoS — bad debt accumulation)
- **Entry point:** `_cleanupLoan()` using `safeTransferFrom()` to return NFT to owner
- **Invariant violated:** Liquidation must be uncancelable. `safeTransferFrom` to a contract that rejects ERC721 reverts the entire liquidation, allowing borrower to permanently block liquidation and accumulate bad debt.
- **Detection:** `grep -rn "safeTransferFrom.*owner\|_cleanupLoan\|liquidat.*transfer" --include="*.sol"` — check if liquidation path uses `safeTransferFrom` to an untrusted address.
- **False positive:** Uses `transferFrom` (no callback) or pull pattern (approve, let user claim).
- **Fix applied:** Replaced `safeTransferFrom` with `approve` (pull pattern).

### P-LEND-013: Race Condition — Repay Front-run by LiquidateWithReplacement
- **Source:** Size H-02 (2024-06)
- **Severity:** HIGH (double loss to borrower)
- **Entry point:** `repay()` and `liquidateWithReplacement()` operating on same debt position
- **Invariant violated:** Repay assumes borrower identity is stable. `liquidateWithReplacement` changes borrower on existing position ID. Front-run causes repayer to pay replacement borrower's debt while original borrower also loses collateral to liquidation reward.
- **Detection:** `grep -rn "liquidateWithReplacement\|replac.*borrower\|debtPosition.*borrower" --include="*.sol"` — check if repay validates that position borrower hasn't changed since user's intent.
- **False positive:** Repay includes `require(debtPosition.borrower == params.borrower)` check.
- **Fix applied:** Added borrower parameter to RepayParams with validation.

### P-LEND-014: Liquidation Collateral Cap Miscalculation
- **Source:** Size H-03 (2024-06)
- **Severity:** HIGH (perverse incentive — higher CR penalized more)
- **Entry point:** `executeLiquidate()` collateral remainder cap
- **Invariant violated:** Collateral cap should represent EXCESS above 100% (i.e., crLiquidation - 100%), not the full liquidation ratio. Using full ratio penalizes users with higher collateral ratios disproportionately.
- **Detection:** `grep -rn "crLiquidation\|collateral.*cap\|mulDivDown.*PERCENT" --include="*.sol"` — check if liquidation cap formula subtracts 100% base.
- **False positive:** Cap formula uses `(crLiquidation - PERCENT)` correctly.
- **Fix applied:** Changed to `mulDivDown(debtInCollateralToken, crLiquidation - PERCENT, PERCENT)`.

### P-LEND-015: Liquidator Reward Decimal Mismatch
- **Source:** Size H-04 (2024-06)
- **Severity:** HIGH (liquidation incentive destruction)
- **Entry point:** `executeLiquidate()` reward calculation
- **Invariant violated:** Liquidation reward computed from `futureValue` (USDC, 6 decimals) but compared against `debtInCollateralToken` (WETH, 18 decimals). 1e12 factor error makes rewards negligible, killing liquidator participation.
- **Detection:** `grep -rn "liquidationReward.*futureValue\|mulDivUp.*futureValue\|reward.*Percent.*PERCENT" --include="*.sol"` — check if reward base uses consistent decimal denomination with comparison target.
- **False positive:** Reward computation converts to collateral token decimals before percentage application.
- **Fix applied:** Used `debtInCollateralToken` as reward base instead of `futureValue`.

### P-LEND-016: Swap Fee Formula Error in Credit Market
- **Source:** Size H-01 (2024-06)
- **Severity:** HIGH (protocol revenue loss)
- **Entry point:** `AccountingLibrary.getCreditAmountIn()` for credit fractionalization
- **Invariant violated:** Swap fee formula must account for fragmentation fee and use `PERCENT - swapFeePercent` as denominator. Incorrect formula collects ~1/1200th of expected fees.
- **Detection:** `grep -rn "swapFeePercent\|fragmentationFee\|getCreditAmountIn\|cashAmountOut.*swapFee" --include="*.sol"` — verify fee formula matches specification.
- **False positive:** Fee formula matches documented specification with correct denominator.
- **Fix applied:** Corrected formula to include fragmentation fee and proper percentage scaling.

### P-LEND-017: Incorrect blocksPerYear for Target Chain
- **Source:** Venus Isolated Pools H-01 (2023-05)
- **Severity:** HIGH (5x interest rate inflation)
- **Entry point:** `WhitePaperInterestRateModel` constructor / constant
- **Invariant violated:** `blocksPerYear` must match target chain block time. Ethereum's 2,102,400 (15s blocks) used on BNB Chain (3s blocks = 10,512,000). All rates inflated 5x.
- **Detection:** `grep -rn "blocksPerYear\|blocksPerDay\|BLOCKS_PER_YEAR\|2102400\|2628000" --include="*.sol"` — cross-reference constant with deployment chain's actual block time.
- **False positive:** Constant matches deployment chain, or protocol uses timestamp-based (not block-based) interest accrual.
- **Fix applied:** Changed constant to `10512000` for BNB Chain.

### P-LEND-018: Prime Token Claim Without Active Stake
- **Source:** Venus Prime H-01 (2023-09)
- **Severity:** HIGH (governance bypass)
- **Entry point:** `Prime.claim()` after `Prime.issue()` for irrevocable token
- **Invariant violated:** `stakedAt` timestamp not reset when irrevocable token issued. User can unstake XVS, get irrevocable burned by admin, then `claim()` bypasses 90-day requirement because stale `stakedAt` persists.
- **Detection:** `grep -rn "stakedAt\|irrevocable\|issue.*mint\|claim.*stake" --include="*.sol"` — check if `stakedAt` is reset on all token issuance/burn paths.
- **False positive:** All issuance paths reset staking timestamp.
- **Fix applied:** Added `delete stakedAt[users[i]]` in irrevocable issuance.

### P-LEND-019: Score Update Counter Manipulation via Mint/Burn
- **Source:** Venus Prime H-02 (2023-09)
- **Severity:** HIGH (reward theft via stale scores)
- **Entry point:** `Prime.updateScores()` with `pendingScoreUpdates` counter
- **Invariant violated:** `pendingScoreUpdates` decrements on burn but does NOT increment on mint. Attacker mint/burns to drain counter, preventing their own score update while keeping inflated pre-change score.
- **Detection:** `grep -rn "pendingScoreUpdates\|_mint.*pending\|_burn.*pending\|updateScores" --include="*.sol"` — check if mint increments and burn decrements the counter symmetrically.
- **False positive:** Counter increments on mint and decrements on burn symmetrically.
- **Fix applied:** Added `if (pendingScoreUpdates != 0) ++pendingScoreUpdates` in `_mint()`.

### P-LEND-020: vToken vs Underlying Decimal Confusion in Score
- **Source:** Venus Prime H-03 (2023-09)
- **Severity:** HIGH (reward calculation zeroed)
- **Entry point:** `_calculateScore()` in Prime contract
- **Invariant violated:** Score normalization uses `vToken.decimals()` (8) instead of `underlying.decimals()` (18). Capital scaled to 28 decimals instead of 18. Downstream division produces zero rewards.
- **Detection:** `grep -rn "vToken.*decimals\|capital.*10.*decimals\|calculateScore.*decimals" --include="*.sol"` — check if decimal normalization uses the correct source (underlying, not receipt token).
- **False positive:** Normalization explicitly uses `IERC20(underlying).decimals()`.
- **Fix applied:** Changed to use underlying token's decimals.

### P-LEND-021: Liquidation Prevention via Frontrunning Debt Share Update
- **Source:** INIT Capital H-01 (2023-12)
- **Severity:** HIGH (liquidation DoS)
- **Entry point:** `PosManager.updatePosDebtShares()` and liquidation flow
- **Invariant violated:** Code assumes `debtAmtCurrent >= lastDebtAmt` always (debt monotonically increases). Liquidation reduces debt, causing underflow revert. Attacker front-runs legitimate liquidation with 1-wei liquidation to trigger the revert.
- **Detection:** `grep -rn "updatePosDebtShares\|debtAmtCurrent\|lastDebtAmt\|totalInterest" --include="*.sol"` — check if debt tracking handles decreases (liquidations) without reverting.
- **False positive:** Interest tracking handles both increases and decreases gracefully.
- **Fix applied:** Only update `totalInterest` when `debtAmtCurrent > lastDebtAmt`.

### P-LEND-022: wLP Token Theft via Missing TokenId Ownership Check
- **Source:** INIT Capital H-02 (2023-12)
- **Severity:** HIGH (fund theft)
- **Entry point:** `PosManager.removeCollateralWLpTo()` / `decollateralizeWLp()`
- **Invariant violated:** Function allows specifying any `tokenId` without verifying it belongs to the caller's position. Attacker creates dust position, calls with victim's tokenId, steals LP tokens.
- **Detection:** `grep -rn "removeCollateralWLp\|decollateralizeWLp\|tokenId.*position\|_posCollInfos" --include="*.sol"` — check if NFT/LP token removal validates tokenId ownership against position.
- **False positive:** Explicit `require(posCollInfos[posId].ids[wlp].contains(tokenId))` check.
- **Fix applied:** Added tokenId containment check before removal.

### P-LEND-023: Repay Hook Ignores Actual Debt, Locks Excess Funds
- **Source:** INIT Capital H-03 (2023-12)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** `MoneyMarketHook._handleRepay()`
- **Invariant violated:** Hook transfers repay amount based on user-provided shares without checking actual position debt. If position was partially liquidated between intent and execution, excess funds remain permanently stuck in hook.
- **Detection:** `grep -rn "_handleRepay\|repay.*shares\|debtShares.*transfer\|min.*shares.*actual" --include="*.sol"` — check if repay hooks clamp input to actual debt.
- **False positive:** Hook uses `min(providedShares, actualDebtShares)` before transferring.
- **Fix applied:** Validate provided shares against actual position debt via position manager.

### P-LEND-024: Profit Index Not Initialized for New Stakers
- **Source:** Ethereum Credit Guild H-01 (2023-12)
- **Severity:** HIGH (reward theft)
- **Entry point:** `ProfitManager.claimGaugeRewards()` when user weight is zero
- **Invariant violated:** `userGaugeProfitIndex` must be initialized to current `gaugeProfitIndex` on first interaction. Early return when weight==0 skips initialization, leaving index at 0. User later stakes and claims all historical rewards.
- **Detection:** `grep -rn "userGaugeProfitIndex\|gaugeProfitIndex\|profitIndex.*==.*0\|claimGaugeRewards" --include="*.sol"` — check if profit index is initialized on first claim even when no active stake.
- **False positive:** Index initialized on every interaction regardless of balance/weight.
- **Fix applied:** Initialize `userGaugeProfitIndex` to current index on first `claimGaugeRewards()` call.

### P-LEND-025: Self-Transfer Extracts Unminted Rebase Rewards
- **Source:** Ethereum Credit Guild H-02 (2023-12)
- **Severity:** HIGH (fund theft — all unminted rewards)
- **Entry point:** `ERC20RebaseDistributor._transfer()` with `from == to`
- **Invariant violated:** Function caches sender and receiver rebase state. Self-transfer updates storage for sender (reducing shares) while receiver computation uses stale cached shares, minting excess tokens equal to all unminted rebase rewards.
- **Detection:** `grep -rn "_transfer.*rebase\|rebasingState.*cache\|self.*transfer\|from.*==.*to" --include="*.sol"` — check if `_transfer` handles `from == to` edge case.
- **False positive:** Self-transfers explicitly blocked or handled via early return.
- **Fix applied:** Prevent self-transfers entirely.

### P-LEND-026: Cascading Bad Debt via Stale Auction Snapshots
- **Source:** Ethereum Credit Guild H-03 (2023-12)
- **Severity:** HIGH (cascading insolvency)
- **Entry point:** `AuctionHouse.getBidDetail()` using `callDebt` snapshot, `LendingTerm.onBid()`
- **Invariant violated:** `callDebt` captured at auction start becomes stale when credit multiplier changes from subsequent bad debt events. Stale debt is lower than true debt, forcing auctions into loss scenarios, creating cascading bad debt across simultaneous auctions.
- **Detection:** `grep -rn "callDebt\|creditMultiplier\|snapshot.*debt\|getBidDetail" --include="*.sol"` — check if auction debt is dynamic or snapshotted.
- **False positive:** Debt recalculated dynamically at bid time using current credit multiplier.
- **Fix applied:** Calculate loan debt dynamically during bidding with current `creditMultiplier`.

### P-LEND-027: Immediate Slashing of Stakers in Re-onboarded Gauges
- **Source:** Ethereum Credit Guild H-04 (2023-12)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** `SurplusGuildMinter.getRewards()` and `stake()`
- **Invariant violated:** `lastGaugeLoss` compared against freshly-initialized memory struct (all zeros) instead of stored stake record. Any gauge with historical loss triggers immediate slash of new stakers, even if gauge was re-onboarded after the loss.
- **Detection:** `grep -rn "lastGaugeLoss\|userStake.*memory\|getRewards.*slashed\|SurplusGuildMinter" --include="*.sol"` — check if loss comparison uses stored vs default-initialized values.
- **False positive:** `userStake.lastGaugeLoss` initialized to `block.timestamp` at stake creation.
- **Fix applied:** Initialize `lastGaugeLoss` to `block.timestamp` at stake creation.

### P-LEND-028: Bad Debt Liquidation Allows Repeat Drain
- **Source:** Fraxlend H-01 (2022-08)
- **Severity:** HIGH (fund lock / lender loss)
- **Entry point:** `FraxlendPairCore.liquidateClean()`
- **Invariant violated:** Leftover bad debt shares subtracted from pair totals but NOT from borrower's shares. Same insolvent position can be liquidated repeatedly, draining pair totals to zero while lenders' shares become worthless.
- **Detection:** `grep -rn "liquidateClean\|_sharesToAdjust\|totalBorrow.*shares\|leftover.*shares" --include="*.sol"` — check if bad debt adjustment reduces BOTH global and per-borrower shares.
- **False positive:** Both global totals and borrower shares reduced by same adjustment.
- **Fix applied:** Added `_sharesToLiquidate += _sharesToAdjust` to clear borrower shares.

### P-LEND-029: Bad Debt Not Written Off in Standard Liquidation
- **Source:** Fraxlend H-02 (2022-08)
- **Severity:** HIGH (last-lender-loses)
- **Entry point:** `FraxlendPairCore.liquidate()` (standard, not clean)
- **Invariant violated:** Standard liquidation does not subtract bad debt from `totalAssets.amount` when collateral is depleted. `totalAssets` stays inflated. Early redeemers get full value; last redeemer absorbs all bad debt.
- **Detection:** `grep -rn "liquidate.*totalAssets\|badDebt.*totalAsset\|collateral.*==.*0.*bad" --include="*.sol"` — check if liquidation recognizes and socializes bad debt immediately.
- **False positive:** Bad debt recognized immediately and deducted from total assets.
- **Fix applied:** Mark off bad debt immediately when collateral depleted.

### P-LEND-030: Liquidation Penalty Bypass via Self-Liquidation
- **Source:** LoopFi H-02 (2024-07)
- **Severity:** HIGH (profitable self-liquidation)
- **Entry point:** `CDPVault.liquidatePosition()`
- **Invariant violated:** Collateral received calculated from `repayAmount / discountedPrice` WITHOUT subtracting penalty. Attacker borrows, waits for unsafe threshold, self-liquidates: pays `repayAmount - penalty` toward debt but receives collateral worth full `repayAmount`.
- **Detection:** `grep -rn "liquidatePosition\|takeCollateral.*=.*wdiv\|repayAmount.*penalty\|discountedPrice" --include="*.sol"` — check if penalty is subtracted from collateral calculation.
- **False positive:** Penalty deducted before collateral calculation.
- **Fix applied:** Apply penalty reduction before collateral computation.

### P-LEND-031: Zero Interest Rate Window on New Quota Tokens
- **Source:** LoopFi H-03 (2024-07)
- **Severity:** HIGH (risk-free borrowing)
- **Entry point:** `PoolQuotaKeeperV3.addQuotaToken()`
- **Invariant violated:** New quota tokens have zero rate until next epoch's `updateRates()`. Attacker requests maximum quota at zero interest during this window.
- **Detection:** `grep -rn "addQuotaToken\|updateRates\|quotaRate.*==.*0\|rate.*epoch" --include="*.sol"` — check if newly added tokens have immediate non-zero rates.
- **False positive:** Rate atomically set during `addQuotaToken()`.
- **Fix applied:** Atomically update rates when adding quota tokens.

### P-LEND-032: Interest Compounding Model Mismatch Between Debt and Pool
- **Source:** LoopFi H-10 (2024-07)
- **Severity:** HIGH (accounting divergence / insolvency)
- **Entry point:** `CDPVault` debt calculation vs `PoolV3` liquidity calculation
- **Invariant violated:** Debt positions use compound interest while pool uses simple interest. Over time, total debt exceeds total liquidity, making pool insolvent.
- **Detection:** `grep -rn "compound.*interest\|simple.*interest\|calcAccruedInterest\|expectedLiquidity" --include="*.sol"` — compare interest models between position-level and pool-level accounting.
- **False positive:** Both use identical compounding model.
- **Fix applied:** Harmonize interest calculation methodology across contracts.

### P-LEND-033: Bad Debt Liquidation Sets Profit to Zero
- **Source:** LoopFi H-12 (2024-07)
- **Severity:** HIGH (protocol revenue loss)
- **Entry point:** `CDPVault.liquidatePositionBadDebt()`
- **Invariant violated:** Function forces `profit = 0` when calling `pool.repayCreditAccount()`, discarding legitimately accrued interest that should go to lenders.
- **Detection:** `grep -rn "liquidatePositionBadDebt\|repayCreditAccount.*profit.*0\|profit.*=.*0" --include="*.sol"` — check if bad debt liquidation preserves accrued interest.
- **False positive:** Profit is preserved and distributed during bad debt resolution.
- **Fix applied:** Preserve calculated profit value in bad debt repayment.

### P-LEND-034: slot0 Price Manipulation in Reallocation
- **Source:** Predy H-01 (2024-05)
- **Severity:** HIGH (LP position losses)
- **Entry point:** `Perp.reallocate()` using Uniswap `slot0` price
- **Invariant violated:** Reallocation uses manipulable spot price (`slot0`) instead of TWAP. Attacker flash-manipulates price, triggers unnecessary reallocation at unfavorable tick, profits from the displacement.
- **Detection:** `grep -rn "slot0\|sqrtPriceX96\|reallocate\|rebalance.*slot0" --include="*.sol"` — check if rebalancing/reallocation reads `slot0` directly.
- **False positive:** Uses TWAP oracle or reallocation restricted to authorized keeper.
- **Fix applied:** Use TWAP instead of slot0 for reallocation decisions.

### P-LEND-035: Partial Liquidation Bypass Leaves Bad Debt Uncompensated
- **Source:** Predy H-02 (2024-05)
- **Severity:** HIGH (protocol absorbs losses)
- **Entry point:** `LiquidationLogic.liquidate()` — negative margin check
- **Invariant violated:** Negative margin compensation check only executes when position is FULLY closed (`!hasPosition`). Liquidator closes 99.99% of position, leaving residual + negative margin. Protocol absorbs the loss.
- **Detection:** `grep -rn "hasPosition\|remainingMargin.*<.*0\|compensate.*margin\|liquidat.*partial" --include="*.sol"` — check if negative margin check applies to ALL liquidation paths, not just full closure.
- **False positive:** Negative margin check applies regardless of position closure completeness.
- **Fix applied:** Move check outside `if (!hasPosition)` block.

### P-LEND-036: Cross-Pair Liquidity Theft via Shared Tick Range
- **Source:** Predy H-03 (2024-05)
- **Severity:** HIGH (fund theft between pairs)
- **Entry point:** `Perp.reallocate()` with multiple pairs on same Uniswap pool
- **Invariant violated:** Reallocation withdraws ALL liquidity in a tick range without checking per-pair ownership. If two pairs share the same pool and tick range, pair B's reallocation steals pair A's liquidity.
- **Detection:** `grep -rn "reallocate\|decreaseLiquidity\|tickLower.*tickUpper\|pairId.*pool" --include="*.sol"` — check if per-pair liquidity is tracked independently within shared Uniswap positions.
- **False positive:** Per-pair liquidity accounting exists and withdrawal capped to pair's own contribution.
- **Fix applied:** Track per-pair liquidity contributions independently.

### P-LEND-037: Unhandled Bad Debt Creates Insolvency
- **Source:** BendDAO V2 H-05 (2024-07)
- **Severity:** HIGH (permanent DoS of withdrawals)
- **Entry point:** ERC20/ERC721 liquidation paths when collateral value < debt
- **Invariant violated:** No mechanism to socialize or write off bad debt. When collateral doesn't cover debt, outstanding debt reduces pool liquidity permanently. Eventually no user can withdraw.
- **Detection:** `grep -rn "badDebt\|socialize\|writeOff\|collateral.*<.*debt\|deficit" --include="*.sol"` — check if protocol has explicit bad debt handling (reserve fund, socialization, or treasury coverage).
- **False positive:** Protocol has explicit bad debt handling: insurance fund, socialization mechanism, or admin intervention path.
- **Fix applied:** Acknowledged; recommended Treasury intervention via `crossRepayERC20()`.

### P-LEND-038: Auction Winner Bypass — Anyone Claims Liquidated NFT
- **Source:** BendDAO V2 H-07 (2024-07)
- **Severity:** HIGH (fund theft — auction bypass)
- **Entry point:** `IsolateLogic.executeIsolateLiquidate()` NFT transfer
- **Invariant violated:** Liquidation transfers NFT to `params.msgSender` without verifying they are `lastBidder`. After auction expires, anyone can call and receive the NFT without having bid.
- **Detection:** `grep -rn "executeIsolateLiquidate\|lastBidder\|msgSender.*transfer\|nft.*liquidat" --include="*.sol"` — check if NFT transfer validates caller == winning bidder.
- **False positive:** Explicit `require(msg.sender == lastBidder)` before transfer.
- **Fix applied:** Added bidder verification check.

### P-LEND-039: Yield Share vs Asset Confusion in Multi-NFT Staking
- **Source:** BendDAO V2 H-01 (2024-07)
- **Severity:** HIGH (accounting mismatch)
- **Entry point:** `YieldStakingBase.stake()` and yield protocol integration
- **Invariant violated:** Yield protocols (Etherfi/Lido) return minted SHARES, not 1:1 assets. Code records returned shares as if they were assets. For shared `YieldAccount` across multiple NFTs, this creates divergent yield tracking — early stakers show inflated yields.
- **Detection:** `grep -rn "stake.*yield\|yieldAccount\|deposit.*shares\|mint.*shares.*return" --include="*.sol"` — check if yield deposit return value is treated as shares or assets.
- **False positive:** Return value explicitly converted to assets before recording.
- **Fix applied:** Use actual assets deposited instead of returned shares.

### P-LEND-040: Missing onBehalf Validation in Isolate Repay
- **Source:** BendDAO V2 H-02 (2024-07)
- **Severity:** HIGH (accounting manipulation)
- **Entry point:** `ValidateLogic.validateIsolateRepayBasic()` / `IsolateLogic.executeIsolateRepay()`
- **Invariant violated:** `onBehalf` parameter not validated against NFT owner. Attacker specifies arbitrary `onBehalf` to reduce their `userScaledIsolateBorrow`, causing underflow during legitimate liquidation.
- **Detection:** `grep -rn "onBehalf\|isolateRepay\|userScaledIsolateBorrow\|nftOwner" --include="*.sol"` — check if repay-on-behalf validates that target address owns the specified collateral.
- **False positive:** `require(onBehalf == nftOwner)` validation exists.
- **Fix applied:** Added `onBehalf == nftOwner` validation.

### P-LEND-041: Stale lockerAddr After Liquidation Blocks Re-deposit
- **Source:** BendDAO V2 H-03 (2024-07)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** `VaultLogic.erc721DecreaseIsolateSupplyOnLiquidate()`
- **Invariant violated:** Liquidation clears `owner` and `supplyMode` but leaves `lockerAddr` set. User re-deposits NFT in cross-collateral mode. Stale `lockerAddr` causes withdrawal validation (`lockerAddr must be zero`) to fail permanently.
- **Detection:** `grep -rn "lockerAddr\|erc721Decrease.*Liquidate\|supplyMode.*=.*0\|owner.*=.*address(0)" --include="*.sol"` — check if ALL state fields are reset on liquidation/removal.
- **False positive:** All NFT state fields (owner, supplyMode, lockerAddr) cleared together.
- **Fix applied:** Added `tokenData.lockerAddr = address(0)` in liquidation cleanup.

### P-LEND-042: Auction Bid Amount Underflow from Interest Compounding
- **Source:** BendDAO V2 H-04 (2024-07)
- **Severity:** HIGH (NFT permanently locked)
- **Entry point:** `IsolateLogic.executeIsolateLiquidate()` and `VaultLogic.erc20TransferOutBidAmountToLiqudity()`
- **Invariant violated:** Auction stores original `bidAmount` in `totalBidAmount`. Liquidation deducts current `borrowAmount` (which grew due to interest compounding). `borrowAmount > bidAmount` causes arithmetic underflow revert, permanently locking the NFT.
- **Detection:** `grep -rn "totalBidAmount\|bidAmount.*borrow\|erc20TransferOutBidAmount\|totalBorrow.*compoun" --include="*.sol"` — check if liquidation uses original bid amount or current (compounded) debt for deduction.
- **False positive:** Deduction uses stored original bid amount, not current debt.
- **Fix applied:** Deduct original `bidAmount` instead of `totalBorrowAmount`.

### P-LEND-043: Bot Cannot Manage Risky Yield Positions (msg.sender Lookup)
- **Source:** BendDAO V2 H-08 (2024-07)
- **Severity:** HIGH (DoS of risk management)
- **Entry point:** `YieldStakingBase._unstake()` and `_repay()` using `yieldAccounts[msg.sender]`
- **Invariant violated:** Bot/keeper calls these functions, but `msg.sender` is the bot address which has no yieldAccount. Code should accept explicit `user` parameter for delegated management.
- **Detection:** `grep -rn "yieldAccounts\[msg.sender\]\|botAdmin\|keeper.*unstake\|msg.sender.*account" --include="*.sol"` — check if delegated/keeper functions use `msg.sender` for account lookup.
- **False positive:** Functions accept explicit user parameter with proper authorization check.
- **Fix applied:** Modified functions to accept explicit `user` parameter with caller authorization.

### P-LEND-044: ERC4626 Redeem Without Share-to-Asset Conversion
- **Source:** LoopFi H-05 (2024-07)
- **Severity:** HIGH (user loss on redemption)
- **Entry point:** `AuraVault.redeem()` in vault wrapper
- **Invariant violated:** ERC4626 `redeem()` must convert shares to assets before passing to underlying. Code passes raw share count to reward pool's `redeem()`, which operates 1:1. When ratio differs, users receive fewer assets.
- **Detection:** `grep -rn "redeem.*rewardPool\|\.redeem(shares\|previewRedeem.*=.*0" --include="*.sol"` — check if vault `redeem()` calls `previewRedeem(shares)` before interacting with underlying.
- **False positive:** Shares properly converted to assets via `previewRedeem()` before underlying call.
- **Fix applied:** Convert shares to assets using `previewRedeem()` first.

### P-LEND-045: Fee Not Deducted from Reward Transfer
- **Source:** LoopFi H-01 (2024-07)
- **Severity:** HIGH (vault insolvency / DoS)
- **Entry point:** `AuraVault.claim()` reward distribution
- **Invariant violated:** Fee sent to `lockerRewards` but full `amounts[0]` also sent to caller. Total outflow = amount + fee, exceeding available balance. Either reverts (DoS) or overpays from other depositors' funds.
- **Detection:** `grep -rn "claim.*reward\|lockerRewards\|lockerIncentive\|fee.*transfer.*amount" --include="*.sol"` — check if fee is subtracted from amount before user transfer.
- **False positive:** Fee explicitly deducted: `amount = amounts[0] - fee`.
- **Fix applied:** Calculate and subtract fee before user transfer.

### P-LEND-046: Liquidation Debt Repayment Evasion via Partial Amounts
- **Source:** LoopFi H-06 (2024-07)
- **Severity:** HIGH (debt avoidance)
- **Entry point:** `CDPVault.liquidatePosition()` — partial repay path
- **Invariant violated:** Borrower calls liquidation with small repay amount, bringing position back to safe range without full settlement. Repeated partial liquidations allow indefinite debt avoidance.
- **Detection:** `grep -rn "liquidatePosition\|isUnsafe\|repayAmount.*partial\|safetyRatio.*after" --include="*.sol"` — check if post-liquidation validation ensures position either fully closed or remains liquidatable.
- **False positive:** Post-liquidation check ensures remaining position is healthy or fully closed.
- **Fix applied:** Validate full resolution or remaining unhealthiness.

### P-LEND-047: Wildcat Borrower Escapes Delinquency Penalties via Market Close
- **Source:** Wildcat Protocol H-01 (2023-10)
- **Severity:** HIGH (lender loss)
- **Entry point:** `WildcatMarket.closeMarket()` while delinquent
- **Invariant violated:** Delinquency timer counts UP during delinquency and DOWN after cure. Borrower closes market during countdown phase, paying only the UP-phase penalties while the DOWN-phase penalties remain uncompensated. Last lender absorbs shortfall.
- **Detection:** `grep -rn "closeMarket\|timeDelinquent\|delinquency.*timer\|scaleFactor.*penalty" --include="*.sol"` — check if market closure forces settlement of all pending penalty fees.
- **False positive:** Market closure zeros delinquency timer and settles all penalties.
- **Fix applied:** Zero `timeDelinquent` on market closure.

### P-LEND-048: codehash Check Fails on Non-empty Addresses (1 Wei)
- **Source:** Wildcat Protocol H-02 (2023-10)
- **Severity:** HIGH (permanent DoS of deployment)
- **Entry point:** `deployController()`, `deployMarket()`, `createEscrow()` via CREATE2
- **Invariant violated:** Per EIP-1052, empty address returns `0x0` codehash but non-empty (has ETH) with no code returns `keccak256("")`. Sending 1 wei to pre-computed CREATE2 address makes `codehash != bytes32(0)` check pass, falsely indicating contract exists. Permanently blocks deployment.
- **Detection:** `grep -rn "codehash\|extcodehash\|bytes32(0)\|code.length" --include="*.sol"` — check if deployment guard uses `codehash != 0` (vulnerable) or `code.length != 0` (safe).
- **False positive:** Uses `code.length != 0` instead of codehash comparison.
- **Fix applied:** Changed to `code.length != 0`.

### P-LEND-049: Zero Batch Duration Enables Over-Withdrawal
- **Source:** Wildcat Protocol H-04 (2023-10)
- **Severity:** HIGH (vault insolvency)
- **Entry point:** `queueWithdrawal()` + `executeWithdrawal()` when `withdrawalBatchDuration == 0`
- **Invariant violated:** Multiple lenders queue and execute withdrawals in same block. Pro-rata calculation uses stale denominator as new lenders join batch. Aggregate withdrawals exceed available assets.
- **Detection:** `grep -rn "withdrawalBatchDuration\|expiry.*block.timestamp\|scaledTotalAmount\|queueWithdrawal" --include="*.sol"` — check if same-block queue+execute is possible when duration is zero.
- **False positive:** `executeWithdrawal` requires `expiry >= block.timestamp` (not just `>`), preventing same-block execution.
- **Fix applied:** Changed validation from `expiry > block.timestamp` to `expiry >= block.timestamp`.

### P-LEND-050: Argument Swap in Escrow Creation Grants Borrower Control of Lender Funds
- **Source:** Wildcat Protocol H-06 (2023-10)
- **Severity:** HIGH (fund theft)
- **Entry point:** `WildcatMarketBase._blockAccount()` -> `WildcatSanctionsSentinel.createEscrow()`
- **Invariant violated:** `createEscrow(borrower, account, asset)` called with arguments swapped as `createEscrow(accountAddress, borrower, asset)`. Lender address placed in borrower parameter. Actual borrower gains authority over escrowed lender funds.
- **Detection:** `grep -rn "createEscrow\|_blockAccount.*escrow\|sentinel.*create" --include="*.sol"` — verify argument order matches function signature. Manual: check if sanctioned lender's funds end up in escrow controlled by the correct party.
- **False positive:** Argument order matches expected signature.
- **Fix applied:** Corrected argument order.

### P-LEND-051: Deposit Fee Accounting Error Causes Total Token Loss
- **Source:** Good Entry H-01 (2023-08)
- **Severity:** HIGH (complete deposit loss)
- **Entry point:** `TokenisableRange.deposit()` when price moves outside position range
- **Invariant violated:** When one token's `amount` returns zero from Uniswap, fee calculation incorrectly charges entire remaining input as fee (`newFee = n1` instead of proportional).
- **Detection:** `grep -rn "TokenisableRange\|deposit.*fee\|token.*Amount.*==.*0\|newFee.*=.*n" --include="*.sol"` — check if fee calculation handles zero-amount tokens correctly.
- **False positive:** Fee clawing logic correctly handles edge cases or is removed entirely.
- **Fix applied:** Removed complex fee-clawing strategy.

### P-LEND-052: Unused Deposit Tokens Not Counted in TVL
- **Source:** Good Entry H-02 (2023-08)
- **Severity:** HIGH (withdrawal shortfall)
- **Entry point:** `GeVault.deposit()`, `GeVault.getTVL()` after Uniswap V3 `increaseLiquidity()`
- **Invariant violated:** Uniswap returns unused tokens to GeVault, but `getTVL()` only counts tokens deployed to ranges. Unused tokens invisible to accounting, causing withdrawal failures.
- **Detection:** `grep -rn "getTVL\|totalAssets\|increaseLiquidity.*unused\|balanceOf.*this\)" --include="*.sol"` — check if TVL/totalAssets includes contract's own token balances.
- **False positive:** TVL calculation includes `balanceOf(address(this))` for all tracked tokens.
- **Fix applied:** Added contract balance to TVL calculation.

### P-LEND-053: Flash Loan Fee Theft via Deposit/Withdraw Cycle
- **Source:** Good Entry H-04 (2023-08)
- **Severity:** HIGH (accumulated fee theft)
- **Entry point:** `TokenisableRange.deposit()` with accumulated trading fees
- **Invariant violated:** Minted LP tokens not scaled down to account for accumulated but undistributed fees. Attacker flash-deposits small amount (bypassing fee deduction threshold), receives shares, immediately withdraws capturing accumulated fees.
- **Detection:** `grep -rn "deposit.*fee\|accumulatedFees\|unclaimedFees\|_mintFee\|fee.*LP" --include="*.sol"` — check if deposit function accounts for accumulated fees in share calculation.
- **False positive:** Fees collected and distributed before share calculation, or shares scaled by fee factor.
- **Fix applied:** Eliminated fee-clawing strategy; restructured fee distribution.

### P-LEND-054: Solidity 0.8 Unchecked Math Breaks Uniswap V3 Fee Calculation
- **Source:** Good Entry H-06 (2023-08)
- **Severity:** HIGH (permanent fund freeze)
- **Entry point:** `FullMath.sol` compiled with Solidity 0.8.x but designed for pre-0.8
- **Invariant violated:** Uniswap V3's fee growth mechanism relies on unsigned integer wraparound (intentional overflow/underflow). Solidity 0.8's default overflow checks break this arithmetic, causing reverts when pool price exits range. User deposits permanently frozen.
- **Detection:** `grep -rn "FullMath\|LiquidityAmounts\|pragma solidity.*0\.8\|feeGrowthInside\|unchecked" --include="*.sol"` — check if Uniswap V3 math libraries are compiled with correct Solidity version or wrapped in `unchecked`.
- **False positive:** Math libraries use `unchecked` blocks or compiled with Solidity < 0.8.
- **Fix applied:** Replaced with Solidity 0.8-compatible Uniswap V3 libraries.

### P-LEND-055: Reentrancy in Lending Token Withdraw (CEI Violation)
- **Source:** Amphora Protocol H-01 (2023-07)
- **Severity:** HIGH (total fund drain)
- **Entry point:** `USDA._withdraw()` — transfer before burn
- **Invariant violated:** `sUSD.transfer()` executed BEFORE `_burn()`. Attacker receives tokens, reenters `withdraw()` in callback, repeats until contract drained.
- **Detection:** `grep -rn "transfer.*\n.*_burn\|transferFrom.*\n.*_burn\|_withdraw.*transfer.*burn" --include="*.sol"` — check if token transfer precedes balance/share burning.
- **False positive:** Burn executes before transfer, or nonReentrant modifier present.
- **Fix applied:** Reorder to burn before transfer, or add nonReentrant.

### P-LEND-056: External Reward Claim Front-running Breaks Vault Accounting
- **Source:** Amphora Protocol H-02 (2023-07)
- **Severity:** HIGH (reward loss)
- **Entry point:** `Vault.claimRewards()` and Convex's `BaseRewardPool.getReward()`
- **Invariant violated:** Convex allows `getReward()` to be called by ANYONE on behalf of any address. Attacker front-runs vault's `claimRewards()` by calling `getReward(vault)` directly, draining rewards to vault without AMPH token calculation. Vault's claim then finds zero rewards.
- **Detection:** `grep -rn "getReward\|claimRewards\|crvRewardsContract\|BaseRewardPool" --include="*.sol"` — check if external reward contract allows third-party claiming.
- **False positive:** Vault uses internal balance delta for reward calculation, not external claim amount.
- **Fix applied:** Use internal CVX/CRV balance delta for AMPH calculation.

### P-LEND-057: Wrapped Token Rounding Exploitable via Flash Loan Inflation
- **Source:** Amphora Protocol H-03 (2023-07)
- **Severity:** HIGH (fund theft via exchange rate manipulation)
- **Entry point:** `WUSDA._usdaToWUSDA()` — `amount * MAX_SUPPLY / totalSupply`
- **Invariant violated:** Floor division causes small deposits to round to zero WUSDA. Attacker inflates `totalSupply` 4x via flash-loaned sUSD deposit, causing victim's deposit to yield 1/4 expected WUSDA. Attacker withdraws at manipulated rate.
- **Detection:** `grep -rn "wUSDA\|_usdaToWUSDA\|MAX.*SUPPLY.*totalSupply\|wrap.*round" --include="*.sol"` — check if wrap/unwrap has minimum output or manipulation resistance.
- **False positive:** Zero-output reverted, or multi-block delay prevents same-block inflation.
- **Fix applied:** Revert on zero conversion; implement multi-block delay.

### P-LEND-058: Stale Fee Growth Values in Position Opening
- **Source:** Particle H-02 (2023-12)
- **Severity:** HIGH (borrower overpays fees)
- **Entry point:** `openPosition()` calling `prepareLeverage()` before `collect()`
- **Invariant violated:** `feeGrowthInside` values from `positions()` only update when Uniswap methods like `collect()` are called. Reading before collection returns stale values. During closure, larger-than-actual fee delta charged to borrower.
- **Detection:** `grep -rn "feeGrowthInside\|prepareLeverage\|positions()\|collect.*before\|openPosition" --include="*.sol"` — check if fee snapshots are taken AFTER fee collection.
- **False positive:** `decreaseLiquidity()` and `collect()` called before snapshot capture.
- **Fix applied:** Reorder: collect first, then capture fee growth values.

### P-LEND-059: Malicious Swap Data in Liquidation Enables Profit Theft
- **Source:** Particle H-03 (2023-12)
- **Severity:** HIGH (profit theft from borrower)
- **Entry point:** `liquidatePosition()` with attacker-controlled `data` parameter for swap routing
- **Invariant violated:** Liquidator constructs arbitrary swap data routing through custom token/pool. Reentrancy via ERC20 hook deposits required repayment while swap sends collateral to attacker-controlled pool.
- **Detection:** `grep -rn "liquidatePosition.*data\|swap.*data.*arbitrary\|abi.decode.*swap\|exactInput.*path" --include="*.sol"` — check if liquidation swap path is constrained to trusted routers/pools.
- **False positive:** Swap data restricted to direct Uniswap Router calls with validated token pairs.
- **Fix applied:** Construct swap internally; removed arbitrary routing parameter.

### P-LEND-060: Solidity 0.8 Breaks Uniswap V3 Fee Wraparound Arithmetic
- **Source:** Particle H-04 (2023-12)
- **Severity:** HIGH (operation revert / fund lock)
- **Entry point:** `Base.getFeeGrowthInside()` fee growth subtraction
- **Invariant violated:** Uniswap V3 fee growth relies on unsigned wraparound arithmetic. Solidity 0.8 default overflow checks revert on `feeGrowthGlobal - feeGrowthOutside` when the subtraction would wrap. Blocks liquidations and position closures.
- **Detection:** `grep -rn "feeGrowthInside.*=.*feeGrowthGlobal.*-\|feeGrowthOutside\|unchecked.*feeGrowth" --include="*.sol"` — check if fee growth subtraction uses `unchecked` block.
- **False positive:** Subtraction wrapped in `unchecked {}`.
- **Fix applied:** Added `unchecked` blocks around fee growth arithmetic.

### P-LEND-061: Blacklisted Borrower Blocks Position Closure
- **Source:** Particle H-01 (2023-12)
- **Severity:** HIGH (permanent LP fund lock)
- **Entry point:** `_closePosition()` -> `refundWithCheck()` transfer to borrower
- **Invariant violated:** Position closure transfers excess to borrower. If borrower enters token blacklist (e.g. USDC), transfer reverts, blocking entire closure. LP liquidity permanently locked.
- **Detection:** `grep -rn "refundWithCheck\|transfer.*borrower\|closePosition.*transfer\|blacklist" --include="*.sol"` — check if position closure can be blocked by recipient-side transfer failure.
- **False positive:** Uses claims/escrow pattern where failed transfers accrue to claimable balance.
- **Fix applied:** Implemented claims mechanism for failed transfers.

### P-LEND-062: Redemption totalBurned Not Updated Between Batches
- **Source:** Ondo Finance H-01 (2023-01)
- **Severity:** HIGH (user fund loss)
- **Entry point:** `CashManager.completeRedemptions()` across multiple calls per epoch
- **Invariant violated:** `totalBurned` storage not updated after processing refunds. Subsequent calls for same epoch use stale `totalBurned`, miscalculating `quantityBurned`, causing later redeemers to receive less collateral.
- **Detection:** `grep -rn "totalBurned\|completeRedemptions\|quantityBurned\|epochToService" --include="*.sol"` — check if batch processing updates persistent state between iterations.
- **False positive:** `totalBurned` updated in storage after each batch calculation.
- **Fix applied:** Added `redemptionInfoPerEpoch[epochToService].totalBurned = quantityBurned` after calculation.

### P-LEND-063: PositionManager Tracks Removed Position (Partial Move)
- **Source:** Ajna H-01 (2023-05)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** `PositionManager.moveLiquidity()` with partial removal
- **Invariant violated:** Function unconditionally removes source position index even when `moveQuoteToken()` only partially removes liquidity. Remaining LP shares become inaccessible.
- **Detection:** `grep -rn "moveLiquidity\|positionIndex.*remove\|fromPosition.*lps" --include="*.sol"` — check if position removal is conditional on full depletion.
- **False positive:** Index removal conditional on `fromPosition.lps == 0`.
- **Fix applied:** Only remove index if LP balance reaches zero.

### P-LEND-064: Position Spam Inflates Array Until Gas DoS
- **Source:** Ajna H-03 (2023-05)
- **Severity:** HIGH (permanent reward DoS)
- **Entry point:** `PositionManager.memorializePositions()` — callable by any address on any NFT
- **Invariant violated:** No access control on position memorialization. Attacker creates thousands of minimal positions on victim's NFT. `getPositionIndexesFiltered()` exceeds block gas limit, blocking reward claims and NFT burns.
- **Detection:** `grep -rn "memorializePositions\|positionIndexes\|getPositionIndexes.*Filtered\|push.*index" --include="*.sol"` — check if position array is unbounded and writable by non-owners.
- **False positive:** `memorializePositions` restricted to NFT owner/approved, or minimum position size enforced.
- **Fix applied:** Restrict memorialization to NFT owner or enforce minimum position size.

### P-LEND-065: Exponential Position Inflation via Approved LP Mismatch
- **Source:** Ajna H-07 (2023-05)
- **Severity:** HIGH (reward theft — 450x position inflation)
- **Entry point:** `PositionManager.memorializePositions()` with insufficient approval
- **Invariant violated:** Function records user's FULL pool LP balance but Pool only transfers the approved amount. Repeated calls with 1-token approvals multiply tracked position by actual balance each time. 450x amplification possible.
- **Detection:** `grep -rn "memorializePositions\|approve.*LP\|transferLP\|positionLPs" --include="*.sol"` — check if tracked position matches actually transferred LP.
- **False positive:** Tracked LP equals min(approved, balance), or tracked only what was transferred.
- **Fix applied:** Validate approved >= balance, or track only transferred amount.

---

## 3. LIQUID STAKING

### P-STAKE-001: Incomplete State Rollback on Withdrawal Cancellation
- **Source:** Kinetiq H-01 (2025-04)
- **Severity:** HIGH (fund lock)
- **Entry point:** `cancelWithdrawal()`
- **Invariant violated:** Cancellation restores the withdrawal amount but does not restore the buffer/capacity that was consumed when the withdrawal was initiated.
- **Detection:** `grep -rn "cancel.*Withdraw\|cancelRequest\|rollback" --include="*.sol"` — check if ALL state changes from the original operation are reversed on cancellation (not just the balance).
- **False positive:** Cancellation explicitly restores buffer, capacity, and all derived state.
- **Fix applied:** Restore buffer allocation on cancellation.

### P-STAKE-002: Exchange Rate Locked at Queue Time
- **Source:** Kinetiq H-02 (2025-04)
- **Severity:** HIGH (unfair distribution after slashing)
- **Entry point:** Withdrawal queue processing
- **Invariant violated:** Exchange rate (shares→assets) is captured at request time but should reflect the rate at confirmation time. If slashing occurs between request and confirmation, early requesters get pre-slash rates.
- **Detection:** `grep -rn "exchangeRate\|sharePrice\|assetsPerShare" --include="*.sol"` in withdrawal request. Check if the rate is stored at request time or computed at confirmation time.
- **False positive:** Rate is computed at confirmation/execution time, not cached at request time.
- **Fix applied:** Compute exchange rate at confirmation, not at request.

### P-STAKE-003: receive() Auto-Restakes Withdrawal Funds
- **Source:** Kinetiq H-03 (2025-04)
- **Severity:** HIGH (fund lock/inflation)
- **Entry point:** `receive()` fallback in staking contract
- **Invariant violated:** ETH received via `receive()` is automatically restaked. When withdrawal confirmations send ETH to the staking contract, the funds are re-staked instead of being distributed.
- **Detection:** `grep -rn "receive()\|fallback()" --include="*.sol"` in staking contracts — check if incoming ETH is auto-processed (staked/deposited) without distinguishing the source.
- **False positive:** `receive()` has source discrimination (checks `msg.sender`), or withdrawal uses a dedicated `completeWithdrawal()` that doesn't trigger fallback.
- **Fix applied:** Add sender check in `receive()` or route withdrawals through a dedicated function.

### P-STAKE-004: Pending Undelegation in Share Ratio
- **Source:** Cabal LST H-01 (2025-04)
- **Severity:** HIGH (share price manipulation)
- **Entry point:** Share price / exchange rate calculation
- **Invariant violated:** Pending undelegation (assets in transit from validator) is counted in total assets when computing share price, but these assets are not liquid and may be slashed.
- **Detection:** `grep -rn "totalAssets\|totalStaked\|getPooledEth" --include="*.sol"` — check if pending/queued/undelegating amounts are included in total assets for share price calculation.
- **False positive:** Pending undelegation explicitly excluded from share price computation.
- **Fix applied:** Exclude pending undelegation from total assets.

---

## 4. ERC4626 VAULTS / STAKING

### P-VAULT-001: First Depositor Share Inflation via Donation
- **Source:** Kelp DAO rsETH H-03 (2023-11), BakerFi H-02 (2024-05), GoGoPool #209 (2022-12)
- **Severity:** HIGH (fund theft)
- **Entry point:** `deposit()` when `totalSupply == 0`
- **Invariant violated:** First depositor deposits 1 wei, donates large amount to inflate `totalAssets` without minting shares. Subsequent depositors get 0 shares via integer rounding.
- **Detection:** `grep -rn "totalSupply.*==.*0\|_mint.*==.*0\|totalAssets.*balanceOf" --include="*.sol"` — check if totalAssets reads balanceOf directly (donatable) vs internal accounting.
- **False positive:** Vault uses OZ virtual shares (_decimalsOffset), burns initial dead shares to address(0), or protocol seeds vault before public deposits.
- **Fix applied:** Virtual shares, dead shares to zero address, minimum first deposit.

### P-VAULT-002: Rounding Direction Violation in Preview Functions
- **Source:** Notional x Index Coop H-01 (2022-06)
- **Severity:** HIGH (vault insolvency)
- **Entry point:** `previewWithdraw()` / `previewMint()` / `convertToShares()`
- **Invariant violated:** previewWithdraw must round UP (shares required) per ERC4626 spec but calls convertToShares which rounds DOWN.
- **Detection:** `grep -rn "previewWithdraw\|previewMint\|convertToShares\|convertToAssets\|mulDivUp\|mulDivDown" --include="*.sol"` — verify: deposit/redeem preview rounds DOWN, withdraw/mint preview rounds UP.
- **False positive:** Rounding directions match OZ reference implementation.
- **Fix applied:** Use mulDivUp in previewWithdraw/previewMint.

### P-VAULT-003: Rebasing Token Vault Accounting Theft
- **Source:** Thorchain H-01 (2024-06)
- **Severity:** HIGH (fund theft)
- **Entry point:** `transferAllowance()` / `transferOut()` with rebasing token
- **Invariant violated:** Protocol assumes token balances are static between operations. Rebasing tokens change balances post-approval, making stale allowances exploitable.
- **Detection:** `grep -rn "approve\|allowance\|transferFrom" --include="*.sol"` — cross-reference with supported token list for rebasing tokens (AMPL, stETH, aTokens).
- **False positive:** Protocol explicitly blocks rebasing tokens, uses before/after balance delta, or wraps rebasing tokens.
- **Fix applied:** Use before/after balanceOf delta pattern.

### P-VAULT-004: Fee-on-Transfer Accounting Mismatch
- **Source:** Astaria #254 (2023-01), PoolTogether (2023-07)
- **Severity:** HIGH (last withdrawer loss)
- **Entry point:** `deposit()` / `mint()` with fee-on-transfer token
- **Invariant violated:** Vault records input `amount` as deposited but actual received is less due to transfer fee. Share-to-asset ratio inflated.
- **Detection:** `grep -rn "transferFrom.*amount\);\s*\n.*_mint\|safeTransferFrom.*amount\);\s*\n.*shares" --include="*.sol"` — check if deposit uses input amount vs balance delta.
- **False positive:** Vault uses before/after balance delta: `received = balanceOf(address(this)) - balanceBefore`.
- **Fix applied:** Use balance delta pattern for all deposits.

### P-VAULT-005: Reward Timing Exploit — First Staker Claims All
- **Source:** Salty.IO H-02 (2024-01)
- **Severity:** HIGH (reward theft)
- **Entry point:** `_increaseUserShare()` when rewards accumulated with zero stakers
- **Invariant violated:** Rewards accumulate while totalShares == 0. First staker gets shares with zero reward debt, claiming ALL accumulated rewards.
- **Detection:** `grep -rn "totalRewards.*totalShares.*==.*0\|rewardPerShare\|rewardPerToken" --include="*.sol"` — check if rewards accumulate when totalShares/totalSupply is zero.
- **False positive:** Rewards only begin accumulating after first deposit, or performUpkeep resets accumulators.
- **Fix applied:** Reset emission timers before first stake.

### P-VAULT-006: Reward Variable Overflow from Donation
- **Source:** Salty.IO H-04 (2024-01)
- **Severity:** HIGH (permanent accounting corruption)
- **Entry point:** Reward calculation with type narrowing (uint256 → uint128)
- **Invariant violated:** Attacker donates to inflate rewards-to-shares ratio. ceilDiv produces value exceeding uint128 max. Silent overflow corrupts all future accounting.
- **Detection:** `grep -rn "uint128\|uint96\|type(uint128).max\|ceilDiv.*totalRewards" --include="*.sol"` — check all reward variables for type narrowing.
- **False positive:** Reward variables use uint256, or donation to reward pool is restricted.
- **Fix applied:** Changed reward tracking from uint128 to uint256.

### P-VAULT-007: Withdrawal Burns Full Shares Despite Illiquidity
- **Source:** Ethos Reserve H-02 (2023-02)
- **Severity:** HIGH (forced loss)
- **Entry point:** `_withdraw()` when strategy funds temporarily locked
- **Invariant violated:** Vault resets withdrawal value to available balance but burns ALL requested shares. User loses claim on locked funds.
- **Detection:** `grep -rn "_withdraw\|burn.*shares\|value.*=.*available\|withdrawMaxLoss" --include="*.sol"` — check if share burn is proportional to actual received, not requested.
- **False positive:** Share burn is proportional to actual assets received, or vault queues illiquid portion.
- **Fix applied:** Calculate loss before adjustment, burn proportional shares.

### P-VAULT-008: Strategy Migration Leaves Residual Tokens
- **Source:** prePO H-01 (2022-03)
- **Severity:** HIGH (share price manipulation)
- **Entry point:** `migrate()` / `setStrategy()` / `switchStrategy()`
- **Invariant violated:** Migration calls withdraw(fullBalance) but yield protocol may return less. Residual tokens invisible to totalValue, inflating new depositors' shares.
- **Detection:** `grep -rn "migrate\|setStrategy\|switchStrategy\|withdraw.*totalAssets" --include="*.sol"` — check for post-withdrawal balance assertion.
- **False positive:** Migration includes `require(oldStrategy.totalValue() == 0)` after withdrawal.
- **Fix applied:** Assert zero remaining balance after migration.

### P-VAULT-009: Price Function Ignores Pending Withdrawals
- **Source:** Asymmetry afEth H-04 (2023-09)
- **Severity:** HIGH (share dilution)
- **Entry point:** `price()` = totalAssets / totalSupply
- **Invariant violated:** requestWithdraw transfers tokens to contract but totalSupply still includes them. Price deflated, new depositors mint excessive shares.
- **Detection:** `grep -rn "price.*totalSupply\|totalAssets.*\/.*totalSupply\|pendingWithdraw\|requestWithdraw" --include="*.sol"` — check if pending withdrawal tokens excluded from supply.
- **False positive:** requestWithdraw burns tokens (removes from supply), or pending amounts subtracted in price calculation.
- **Fix applied:** Burn tokens on requestWithdraw.

### P-VAULT-010: Missing Slippage on Vault Interactions
- **Source:** Asymmetry H-05 (2023-09), LoopFi (2024-07)
- **Severity:** HIGH (sandwich attack)
- **Entry point:** `deposit()` / `withdraw()` calling external ERC4626 vault
- **Invariant violated:** Vault interaction executes without minimum output. Exchange rate manipulation causes user to receive fewer shares/assets.
- **Detection:** `grep -rn "\.deposit(.*address(this))\|\.redeem(.*address(this))\|minOut.*=.*0" --include="*.sol"` — check for hardcoded 0 minimums.
- **False positive:** User-specified minShares/minAssets parameter exists and reverts if output < minimum.
- **Fix applied:** Add user-configurable slippage tolerance.

### P-VAULT-011: Strategy Returns Shares Instead of Assets (Unit Confusion)
- **Source:** BakerFi Invitational H-01 (2024-12)
- **Severity:** HIGH (systematic miscalculation)
- **Entry point:** `_deploy()` / `_undeploy()` / `_getBalance()` in strategy
- **Invariant violated:** Functions return ERC4626 share quantities instead of underlying asset amounts. Vault accounting tracks shares as assets.
- **Detection:** `grep -rn "_deploy\|_undeploy\|_getBalance\|balanceOf.*vault\|convertToAssets" --include="*.sol"` — check if strategy balance functions return raw shares without conversion.
- **False positive:** All strategy interfaces documented and enforced to return asset-denominated values with convertToAssets wrapper.
- **Fix applied:** Return asset amounts via convertToAssets().

### P-VAULT-012: Unrestricted Harvest Enables Fee Evasion
- **Source:** BakerFi Invitational H-02 (2024-12)
- **Severity:** HIGH (fee evasion)
- **Entry point:** `harvest()` — publicly callable
- **Invariant violated:** harvest() updates _deployedAmount baseline. Attacker front-runs rebalance with harvest() to reset profit tracker, evading performance fees.
- **Detection:** `grep -rn "harvest\|_deployedAmount\|performanceFee\|public.*harvest\|external.*harvest" --include="*.sol"` — check if harvest has access control.
- **False positive:** harvest() restricted to onlyOwner/onlyKeeper.
- **Fix applied:** Add onlyOwner modifier.

### P-VAULT-013: Self-Transfer Duplicates Staking Shares
- **Source:** Acala H-01 (2024-03)
- **Severity:** HIGH (infinite share minting)
- **Entry point:** `transfer_share()` with from == to
- **Invariant violated:** Self-transfer adds shares without removing, duplicating infinitely.
- **Detection:** `grep -rn "transfer_share\|transferShare\|_transfer.*share" --include="*.sol" --include="*.rs"` — check for from != to validation.
- **False positive:** Explicit require(from != to) or balance delta nets to zero on self-transfer.
- **Fix applied:** Early return on from == to.

### P-VAULT-014: Rounding in Share Transfer Enables Reward Double-Claim
- **Source:** Acala H-03 (2024-03)
- **Severity:** HIGH (reward theft)
- **Entry point:** `transfer_share_and_rewards()` with reward debt calculation
- **Invariant violated:** Reward debt rounded DOWN on transfer. Receiver gets shares with zero debt, claims rewards already withdrawn by sender.
- **Detection:** `grep -rn "rewardDebt\|reward_debt\|virtualRewards.*=.*\*.*\/" --include="*.sol" --include="*.rs"` — check if reward debt transfer uses ceiling division.
- **False positive:** Reward debt uses ceiling division (round UP) on transfer.
- **Fix applied:** Saturated round UP for reward debt.

### P-VAULT-015: Deflation Attack via Insufficient Virtual Offset
- **Source:** Silo Finance M-06 (2025-03)
- **Severity:** MEDIUM (first depositor attack variant)
- **Entry point:** First deposit with offset=1
- **Invariant violated:** Virtual offset is 1 instead of 10^decimals. Share inflation still viable at ~10^decimals cost.
- **Detection:** `grep -rn "virtual.*offset\|_decimalsOffset\|OFFSET\|10\*\*" --include="*.sol"` — if offset < 10^(decimals/2) → vulnerable.
- **False positive:** Offset >= 10^(decimals/2), or minimum deposit exceeds attack cost.
- **Fix applied:** Increase virtual offset.

### P-VAULT-016: Oracle Decimal Mismatch (8 vs 18)
- **Source:** BakerFi H-01 (2024-05)
- **Severity:** HIGH (systematic miscalculation)
- **Entry point:** `ETHOracle.getLatestPrice()` consuming Chainlink feed
- **Invariant violated:** Contract defines `_PRECISION = 10**18` but Chainlink ETH/USD returns 8-decimal prices. No conversion applied. All downstream calculations (collateral valuation, health factor) off by 10^10.
- **Detection:** `grep -rn "getLatestPrice\|latestRoundData\|_PRECISION.*18\|decimals.*8\|10\*\*18.*price" --include="*.sol"` — cross-reference oracle feed decimals with internal precision constant.
- **False positive:** Price explicitly scaled: `price * 10**(18 - feedDecimals)`.
- **Fix applied:** Convert 8-decimal oracle price to 18 decimals.

### P-VAULT-017: Harvest Leftover Collateral Locked Due to Fee Tier Mismatch
- **Source:** BakerFi H-03 (2024-05)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** `StrategyLeverage._payDebt()` and `UseSwapper._swap()`
- **Invariant violated:** UniQuoter uses hardcoded 0.05% fee tier (500) but swap executes with configured `_swapFeeTier`. If actual fee < quoted fee, less collateral consumed than withdrawn. Leftover tokens permanently stranded in contract.
- **Detection:** `grep -rn "swapFeeTier\|feeTier.*500\|quoter.*fee\|leftover.*collateral" --include="*.sol"` — check if quoting and execution use same fee tier.
- **False positive:** Same fee tier used in both quoter and swap execution.
- **Fix applied:** Use actual `swapFeeTier` in quoter calls; redeposit leftover.

### P-VAULT-018: Zero Slippage Protection on Swaps
- **Source:** BakerFi H-04 (2024-05), Multiple lending protocols
- **Severity:** HIGH (MEV extraction)
- **Entry point:** `_swap()` / `_convertFromWETH()` with `amountOutMinimum: 0`
- **Invariant violated:** Swaps executed with zero minimum output. Sandwich attackers extract maximum value from every swap.
- **Detection:** `grep -rn "amountOutMinimum.*=.*0\|minAmountOut.*=.*0\|amountOut.*0\)" --include="*.sol"` — check all swap calls for zero slippage.
- **False positive:** Non-zero slippage from user parameter or calculated from oracle price.
- **Fix applied:** Calculate minimum output from oracle price minus tolerance.

### P-VAULT-019: Missing onERC721Received Blocks Yield Unstaking
- **Source:** BendDAO V2 H-06 (2024-07)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** `YieldAccount` contract receiving NFT via `_safeMint()`
- **Invariant violated:** Yield protocol (Etherfi) uses `_safeMint()` for withdrawal NFTs. Recipient contract must implement `onERC721Received()`. `YieldAccount` lacks this, causing all unstaking operations to revert.
- **Detection:** `grep -rn "onERC721Received\|_safeMint\|safeTransferFrom\|IERC721Receiver" --include="*.sol"` — check if contracts receiving NFTs implement the receiver interface.
- **False positive:** Contract implements `IERC721Receiver` or uses `transferFrom` (no callback).
- **Fix applied:** Added `onERC721Received` to `YieldAccount`.

---

## 5. GOVERNANCE / veTokenomics

### P-GOV-001: Deposit Before Share Calculation
- **Source:** Hybra Finance H-01 (2025-10)
- **Severity:** HIGH (fund theft — dilution)
- **Entry point:** `deposit()` in staking/governance contract
- **Invariant violated:** User's deposit is added to the pool BEFORE their share is calculated, inflating the denominator and giving them fewer shares.
- **Detection:** `grep -rn "totalStaked.*+=\|totalDeposited.*+=" --include="*.sol"` — check if total is incremented BEFORE or AFTER the share calculation.
- **False positive:** Share calculation happens BEFORE total is incremented (standard pattern: `shares = amount * totalShares / totalAssets; totalAssets += amount`).
- **Fix applied:** Calculate shares before incrementing total.

### P-GOV-002: Dust Vote Griefing via Minimum Threshold
- **Source:** Hybra Finance M-03 (2025-10)
- **Severity:** MEDIUM (governance griefing)
- **Entry point:** `vote()` or `allocate()` in governance
- **Invariant violated:** No minimum vote amount allows attacker to cast dust votes on all proposals, blocking quorum mechanisms or diluting vote weight calculations.
- **Detection:** `grep -rn "function vote\|function allocate\|votingPower" --include="*.sol"` — check if there's a minimum vote amount.
- **False positive:** Minimum vote threshold enforced.
- **Fix applied:** Add minimum vote/allocation threshold.

---

## 6. OPTIONS / DERIVATIVES

### P-DERIV-001: Unprotected Initializer Sweep
- **Source:** Panoptic H-01 (2025-12)
- **Severity:** HIGH (fund theft — total drain)
- **Entry point:** `init()` function without access control
- **Invariant violated:** `init()` can be called by anyone, overwriting admin address. Attacker calls `init()` then `sweep()`.
- **Detection:** `grep -rn "function init\b\|function initialize\b" --include="*.sol"` — check for `initializer` modifier or `initialized` state. If neither → finding.
- **False positive:** `initializer` modifier (OZ) or `require(!initialized)` check present.
- **Fix applied:** Add initializer guard.

### P-DERIV-002: Cross-Contract Reentrancy via Sequential Revocation
- **Source:** Panoptic H-02 (2025-12)
- **Severity:** HIGH (fund theft — vault drain)
- **Entry point:** `liquidate()` with multi-collateral
- **Invariant violated:** Phantom shares delegated to two collateral trackers, revoked sequentially. ETH refund between revocations creates callback window to transfer phantom shares out.
- **Detection:** `grep -rn "safeTransferETH\|\.call\{value\|\.transfer(" --include="*.sol"` — check if ETH transfer occurs BETWEEN two state changes on different contracts. Also: `grep -rn "phantom\|delegat\|revoke"`.
- **False positive:** All state changes completed before any external call (strict CEI). Or single-step revocation.
- **Fix applied:** Complete all revocations before ETH transfer.

### P-DERIV-003: Commission Bypass via Zero-Notional Settlement
- **Source:** Panoptic H-03 (2025-12)
- **Severity:** HIGH (revenue loss)
- **Entry point:** `settleBurn()` with `longAmount=0, shortAmount=0`
- **Invariant violated:** Commission = min(premiumFee, notionalFee). Zero-amount settlement produces notionalFee=0, collapsing min to zero.
- **Detection:** `grep -rn "Math.min.*fee\|min.*commission\|commission.*notional" --include="*.sol"` — check if any settlement path can produce zero for one operand of a min/max fee formula.
- **False positive:** All settlement paths enforce non-zero amounts, or fee calculation doesn't use min() with a potentially-zero operand.
- **Fix applied:** Charge fee based on premium even when notional is zero.

---

## 7. MATH LIBRARIES

### P-MATH-001: sqrt Exponent Ordering Error
- **Source:** Forte Float128 H-01 (2025-04)
- **Severity:** HIGH (silent wrong results)
- **Entry point:** `sqrt()` in fixed-point library
- **Invariant violated:** Exponent halving applied before mantissa normalization, producing wrong results for specific input ranges.
- **Detection:** When auditing custom math libraries: verify sqrt, ln, exp, pow with edge case inputs (0, 1, MAX, powers of 2, values near representation boundaries).
- **False positive:** Library uses well-tested reference implementation (PRBMath, Solmate, OZ Math).
- **Fix applied:** Correct operation ordering.

### P-MATH-002: Function Accepts Invalid Domain Input
- **Source:** Forte Float128 H-03 (2025-04)
- **Severity:** HIGH (silent wrong results)
- **Entry point:** `ln()` accepting negative inputs
- **Invariant violated:** `ln(x)` is undefined for x≤0 but function doesn't revert, returns garbage.
- **Detection:** `grep -rn "function ln\|function log\|function sqrt" --include="*.sol"` — check if domain validation (input > 0 for ln/log, input >= 0 for sqrt) exists.
- **False positive:** Input validation at function entry (`require(x > 0)`).
- **Fix applied:** Add domain validation.

---

## 8. LAUNCHPAD / TOKEN LAUNCH

### P-LAUNCH-001: Graduation Blocked by Dust Donation
- **Source:** GTE Launchpad H-09 (2025-08)
- **Severity:** HIGH (DoS — permanent fund lock)
- **Entry point:** `graduate()` / `migrate()` function
- **Invariant violated:** Graduation check passes with minimal amount but pair initialization needs meaningful reserves. Dust donation front-runs and stalls the process.
- **Detection:** `grep -rn "graduate\|migrate\|launch.*pair\|addLiquidity" --include="*.sol"` — check if there's a minimum threshold on graduation/migration.
- **False positive:** Minimum liquidity threshold enforced on graduation.
- **Fix applied:** Enforce minimum liquidity on graduation.

### P-LAUNCH-002: Unvalidated Token in Reward Distribution
- **Source:** GTE Launchpad H-06 (2025-08)
- **Severity:** HIGH (fund theft)
- **Entry point:** `donate()` / `notifyRewardAmount()` with token parameter
- **Invariant violated:** Function accepts arbitrary token address without validating against canonical reward token.
- **Detection:** `grep -rn "function donate\|function notifyReward.*address.*token" --include="*.sol"` — check if reward/donation functions validate token address.
- **False positive:** Token address hardcoded or validated against stored canonical address.
- **Fix applied:** Validate token matches canonical reward token.

---

## META-PATTERNS (cross-category)

### META-001: Emission Sync Gap (11 occurrences across 4 protocols)
Every balance-mutating function MUST sync emission/reward state for ALL affected addresses BEFORE the mutation. This is the #1 most common vulnerability class.
- **Detection:** For every function that changes `balanceOf`, `totalSupply`, `shares`, or `debt`: verify that `updateReward(user)` or equivalent is called BEFORE the balance change.

### META-002: Inconsistent Data Source Between Paired Operations (10 occurrences)
Two operations that should mirror each other (mint/burn, deposit/withdraw, enter/exit) use different data sources for the same value.
- **Detection:** Check matrix. List all paired operations. For each pair, compare what values they read and from where. Divergence = finding.

### META-003: Memory vs Storage Mutation (2 occurrences)
Struct fields modified on `memory` copy but expected to persist in `storage`.
- **Detection:** `grep -rn "memory.*=.*storage\|struct.*memory" --include="*.sol"` — trace modifications to memory copies.

---

## 9. BRIDGE / CROSS-CHAIN

### P-BRIDGE-001: Duplicate Signature Acceptance in Quorum
- **Source:** Recall H-01 (2025-02)
- **Severity:** HIGH (consensus bypass)
- **Entry point:** Checkpoint/oracle signature validation loop
- **Invariant violated:** Signature loop does not check for duplicate signers. One entity can meet quorum alone by submitting the same signature N times.
- **Detection:** `grep -rn "signatories\|validators\|votes\|quorum" --include="*.sol" --include="*.go"` — check if loops that validate multi-sig track already-seen addresses.
- **False positive:** Duplicate signer tracking exists (mapping or sorted-uniqueness check).
- **Fix applied:** Track seen signers in mapping, revert on duplicate.

### P-BRIDGE-002: Message Type Filtering Excludes Value-Carrying Messages
- **Source:** Recall H-02 (2025-02)
- **Severity:** HIGH (supply inflation — fund theft)
- **Entry point:** Cross-chain message processing with type filter
- **Invariant violated:** "Call" type messages carry value but are filtered out of supply accounting. Child chain supply inflates beyond locked collateral.
- **Detection:** `grep -rn "msg.kind\|msgType\|IpcMsgKind\|skipSupply\|totalValue" --include="*.sol"` — check if ANY value-carrying message type is excluded from supply/balance accounting.
- **False positive:** All value-carrying message types are accounted for, regardless of type classification.
- **Fix applied:** Include all value-carrying types in supply accounting.

### P-BRIDGE-003: Hash Mismatch Between Message Storage and Receipt Lookup
- **Source:** Recall H-03 (2025-02)
- **Severity:** HIGH (permanent fund lock)
- **Entry point:** Cross-chain receipt processing
- **Invariant violated:** Messages stored with hash(fields+nonce), receipts lookup with hash(fields-nonce). Receipt can never find its original message.
- **Detection:** `grep -rn "toHash\|toTracingId\|hashMessage\|messageHash\|receiptHash" --include="*.sol"` — compare field sets in storage hash vs lookup hash.
- **False positive:** Same hash function used for both storage and lookup.
- **Fix applied:** Use identical hash function for storage and lookup.

### P-BRIDGE-004: Wrong Fund Source in Withdrawal
- **Source:** Recall H-05 (2025-02)
- **Severity:** HIGH (fund theft — drain collateral)
- **Entry point:** `leave()` / `withdraw()` in bridge
- **Invariant violated:** Withdrawal transfers from collateral pool instead of deposit pool.
- **Detection:** `grep -rn "collateralSource\|supplySource\|transferFunds\|leave()\|withdraw()" --include="*.sol"` — verify withdrawal source matches the correct pool.
- **False positive:** Source pool is explicitly validated before transfer.
- **Fix applied:** Use correct source pool.

### P-BRIDGE-005: Reentrancy During State Transition
- **Source:** Recall H-06 (2025-02)
- **Severity:** HIGH (bridge halt)
- **Entry point:** ETH transfer before state machine finalization
- **Invariant violated:** External call (ETH send) before state transition completion allows reentrant trigger of bootstrap/mode change.
- **Detection:** `grep -rn "\.call\{value\|\.transfer(\|sendValue" --include="*.sol"` — check if state machine transitions can be triggered from ETH receive callback.
- **False positive:** Strict CEI pattern — all state changes before external calls. Or nonReentrant on all transition functions.
- **Fix applied:** Complete state transitions before external calls.

### P-BRIDGE-006: Arbitrary External Call via User-Controlled Bridge Data
- **Source:** Megapot H-01 (2025-11)
- **Severity:** HIGH (NFT/token theft)
- **Entry point:** Bridge relay with user-supplied target + calldata
- **Invariant violated:** Bridge function allows user to control both `.call` target and calldata on a contract holding custody assets.
- **Detection:** `grep -rn "_to\.call\|bridgeData\|RelayTxData\|arbitraryCall" --include="*.sol"` — check if user controls both target address and calldata in any `.call()`.
- **False positive:** Target is validated against whitelist. Or contract holds no assets.
- **Fix applied:** Whitelist bridge relay targets.

### P-BRIDGE-007: Cross-Layer Message Size Amplification
- **Source:** Initia-Rollup H-02 (2025-01)
- **Severity:** HIGH (permanent bridge DoS)
- **Entry point:** L1 deposit message with unbounded data field
- **Invariant violated:** L1 message has fewer fields than L2 finalization message. Unrestricted data field on L1 produces oversized L2 message exceeding mempool limits.
- **Detection:** `grep -rn "data.*field\|MsgInitiate\|MsgFinalize\|maxTxSize\|mempool.*limit" --include="*.go"` — compare L1 vs L2 message structures for size amplification.
- **False positive:** L1 message data field has explicit size limit.
- **Fix applied:** Enforce max data size on L1 deposit.

### P-BRIDGE-008: Permissionless Registration Drains Gateway
- **Source:** Recall H-08 (2025-02)
- **Severity:** HIGH (fund theft)
- **Entry point:** `register()` in bridge gateway
- **Invariant violated:** No access control on subnet/bridge creation. Attacker creates bridge with controlled params, drains gateway reserves.
- **Detection:** `grep -rn "function register\|createSubnet\|createBridge" --include="*.sol"` — check for missing access control on creation functions that interact with fund pools.
- **False positive:** Access control present (onlyOwner/onlyAdmin/onlyGovernance).
- **Fix applied:** Restrict registration to authorized callers.

---

## 10. L1/L2 CONSENSUS

### P-CONSENSUS-001: Consensus vs Execution Validation Mismatch
- **Source:** Monad H-01, H-02 (2025-09)
- **Severity:** HIGH (chain halt)
- **Entry point:** Transaction validation in consensus layer vs execution layer
- **Invariant violated:** Consensus and execution apply different rules to the same tx type (legacy gas pricing, EIP-7702 auth ordering, base fee). Blocks accepted by consensus fail execution.
- **Detection:** `grep -rn "validate_block\|compute_txn_max_gas_cost\|max_fee.*base_fee\|legacy.*transaction" --include="*.rs" --include="*.go"` — compare validation logic across layers for each tx type.
- **False positive:** Both layers use identical validation functions or share a common validation library.
- **Fix applied:** Unify validation logic.

### P-CONSENSUS-002: Mempool Admission vs Block Proposal Divergence
- **Source:** Monad H-03 (2025-09)
- **Severity:** HIGH (chain DoS — empty blocks)
- **Entry point:** Mempool insertion affordability check
- **Invariant violated:** Mempool uses weaker check (base fee only), proposal uses stronger (full gas bid). Txs pass admission but fail proposal, creating permanently unevictable invalid pool entries.
- **Detection:** `grep -rn "balance.*base_fee\|affordability\|insert.*balance\|proposal.*balance" --include="*.rs"` — compare balance checks between admission and proposal.
- **False positive:** Both paths use identical affordability calculation.
- **Fix applied:** Unify affordability check.

### P-CONSENSUS-003: Error Path Returns Without Charging Gas
- **Source:** Initia-Cosmos H-07, H-08 (2025-02)
- **Severity:** HIGH (network DoS — free execution)
- **Entry point:** EVM error handling (stack overflow, invalid opcode, precompile input parse)
- **Invariant violated:** Non-OOG error paths return without consuming remaining gas, enabling infinite free execution loops.
- **Detection:** `grep -rn "gasRemaining.*== 0\|ErrOutOfGas\|ErrStackOverflow\|RunPrecompiledContract" --include="*.go"` — verify ALL error paths consume gas.
- **False positive:** All error paths explicitly consume remaining gas before returning.
- **Fix applied:** Consume remaining gas on all error types.

### P-CONSENSUS-004: Full Amount Instead of Per-Item in Loop
- **Source:** Initia-Cosmos H-01 (2025-02)
- **Severity:** HIGH (fund loss — user overcharged)
- **Entry point:** Loop processing coins/items
- **Invariant violated:** Loop body uses full collection amount instead of current iteration item. User charged N times intended.
- **Detection:** `grep -rn "for.*range.*coins\|for.*amount\|transferAmount" --include="*.go"` — verify loop body uses individual item, not collection.
- **False positive:** Loop body uses indexed element (coins[i], not coins).
- **Fix applied:** Use per-item variable in loop body.

---

## 11. WALLETS (ERC-4337)

### P-WALLET-001: Checkpoint Bypass via Uninitialized Signature Flag
- **Source:** Sequence H-01 (2025-10)
- **Severity:** HIGH (auth bypass)
- **Entry point:** Signature validation with checkpoint flag
- **Invariant violated:** Unset flag bit leaves checkpoint variables at zero/default. Downstream checks against zero pass, allowing evicted signers to operate.
- **Detection:** `grep -rn "signatureFlag\|checkpointer\|imageHash.*0\|bytes32(0)" --include="*.sol"` — check if unset flags leave security variables uninitialized.
- **False positive:** Default values are treated as invalid (explicit != 0 check).
- **Fix applied:** Treat zero/default as invalid in checkpoint validation.

### P-WALLET-002: Partial Signature Replay from Reverted Multi-Call
- **Source:** Sequence H-02 (2025-10)
- **Severity:** HIGH (fund theft)
- **Entry point:** Multi-call session with revert-on-error
- **Invariant violated:** Nonce rollback on revert but per-call signatures remain valid. Attacker replays subset of calls from reverted tx.
- **Detection:** `grep -rn "REVERT_ON_ERROR\|consumeNonce.*revert\|hashCall.*Replay\|session.*signature" --include="*.sol"` — check if nonce rollback leaves individual call signatures replayable.
- **False positive:** Signatures bind to the FULL payload hash (including all calls), not individual calls.
- **Fix applied:** Bind signatures to complete payload.

---

## META-PATTERNS (updated)

### META-004: Inconsistent Validation Between Entry Points (bridge/L2)
The same message/transaction can enter the system through multiple paths (mempool, RPC, internal dispatch, hook). Each path MUST apply identical validation. Divergence = finding.
- **Detection:** For each message type, trace ALL entry points and compare validation.

### META-005: Cross-Layer Semantic Mismatch
When a system has multiple layers (consensus/execution, L1/L2, sender/receiver), identical concepts (gas, value, identity) must have identical semantics. Any divergence = finding.
- **Detection:** For each shared concept, compare implementation across layers.

### META-006: Accrue-Before-Mutate (Lending-Specific)
Every function that changes a user's balance, debt, or collateral MUST accrue interest/rewards BEFORE the mutation. Missing accrual before ANY of: deposit, withdraw, borrow, repay, liquidate, transfer = finding. This is the #1 root cause across all lending HIGHs.
- **Detection:** For each balance-mutating function, verify `accrueInterest()` / `updateRewards()` / `syncState()` is called BEFORE the balance change. Trace ALL paths.
- **Examples:** P-LEND-001, P-LEND-002, P-LEND-006, P-LEND-024, P-LEND-039.

### META-007: Decimal Consistency Across Token Layers (Lending-Specific)
Lending protocols wrap tokens in receipt tokens (cTokens, vTokens, aTokens). These have different decimals than underlying. Any calculation mixing receipt-token decimals with underlying-token decimals = finding.
- **Detection:** `grep -rn "\.decimals()" --include="*.sol"` — map every `decimals()` call to its source. If a calculation uses decimals from TWO different sources → verify scaling.
- **Examples:** P-LEND-015, P-LEND-020, P-VAULT-016.

### META-008: Liquidation Must Be Unstoppable (Lending-Specific)
If ANY user action can prevent their own liquidation, the protocol accumulates bad debt. Common blockers: `safeTransferFrom` rejection, `onERC721Received` rejection, front-running with dust repay, token blacklisting, approval revocation.
- **Detection:** Trace entire liquidation path. For each external call, check if the target (borrower) can cause revert.
- **Examples:** P-LEND-012, P-LEND-021, P-LEND-061, P-LEND-037.

### META-009: Global Counter Must Match Sum of Per-Entity Counters
Any global accumulator (totalDebt, totalBadDebt, totalBidAmount, totalRewards) must equal the sum of its per-entity components. If global uses `+=` but per-entity uses `=` (overwrite), or vice versa → finding. Most insidious when the asymmetry only manifests under partial operations (partial liquidation, partial repay).
- **Detection:** For each global counter, find ALL sites that modify it. Verify each site applies the same delta to both global and per-entity.
- **Examples:** P-LEND-006, P-LEND-028, P-LEND-042.

### META-010: Chain-Specific Constants (Cross-Chain Deployment)
Any hardcoded chain assumption (block time, block gas limit, block number, address format) that differs between deployment chains = finding. Most common: Ethereum block time (12-15s) used on L2/alt-L1 with different block times.
- **Detection:** `grep -rn "blocksPerYear\|blocksPerDay\|BLOCKS_PER\|block.number.*assume\|2102400\|2628000\|10512000" --include="*.sol"` — cross-reference with actual deployment chain.
- **Examples:** P-LEND-017.

### META-011: Partial State Commitment in Batch/Settlement Systems (Dexalot DXLTOVDD-336)
When a protocol uses a hash commitment (stateHash) to lock state between two operations (finalize and settle), verify ALL variables used in settlement math are in the committed hash. If numerator inputs (balances) are committed but the denominator (totalSupply) is read live, any mechanism that changes the denominator between commit and execution creates a TOCTOU fund theft.
- **Detection:** Find the stateHash computation. List all variables in settlement math. For each: committed or live-read? If any live-read variable can be externally modified between commit and execution, vulnerable.
- **Amplifier:** Cross-chain share tokens (OFT, xERC20) make totalSupply manipulable via bridge burn.
- **Examples:** Dexalot OmniVault DXLTOVDD-336 ($8,333 stolen on $100K vault via OFT bridge between finalize and settle).

### META-012: Cross-Market Routing Payout Mismatch (GMTrade #45)
In multi-market DEXes with shared vaults, the swap routing engine and payout engine may resolve the "responsible market" differently. If routing credits Market A but payout debits Market B, Market A retains a phantom balance withdrawable via LP exit.
- **Detection:** Trace full swap lifecycle: routing credits market X, payout resolves from market Y. If X != Y, accounting is split. Look for `SwapDirection::Into(current_market)` vs `find_last_market(swap_path)` divergence.
- **Impact:** Double extraction from shared vault. First via swap payout, second via LP withdrawal.
- **Examples:** GMTrade #45, one of 2 accepted out of ~25.

### META-013: Silent Type Truncation in Price Calculations (GMTrade #31)
Price or amount calculations cast to smaller integer types (`as u32`, `uint128` to `uint64`). The cast silently wraps if value exceeds target max. Dangerous for high-value assets with high precision.
- **Detection:** `grep -rn "as u32\|as u64\|uint128.*uint64\|uint256.*uint128" --include="*.rs" --include="*.sol"` -- compute max possible input, compare to target type max.
- **Note:** Solidity 0.8.x reverts on overflow casts. Rust `as` SILENTLY truncates. Primarily Rust/C/Go risk.
- **Examples:** GMTrade #31, `value as u32` in Decimal::try_from_price.

### META-014: "Feature Request" Dismissal -- Fork/Port Submission Decision Rule
Fork/port targets that omit a parent feature classify it as "feature request, not vulnerability" unless the finding demonstrates CONCRETE fund theft with a working PoC. Before reporting missing features on forks: can you write a PoC that steals funds using ONLY the code that EXISTS? If the PoC depends on what DOESN'T exist, it's a feature request.
- **Lesson:** GMTrade pendingImpactAmount: valid HIGH, rejected as "feature request." Same program accepted 2 findings with direct fund theft PoCs. Design divergences lose. Implementation bugs win.
