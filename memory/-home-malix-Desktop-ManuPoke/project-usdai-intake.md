---
name: project-usdai-intake
description: "USDai/sUSDai (MetaStreet RWA yield-stablecoin) Cantina bounty — bigger/more-saturated than hoped (14k LOC/3 repos, 2-3 audits, 640 findings); async-timing vein EXCLUDED; fresh angle = cross-repo composition seam."
metadata: 
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
---

USDai/sUSDai — MetaStreet RWA yield-stablecoin. Cantina bounty `32e64f2e-5f01-4a0b-bbe3-76f32c17b99f` ACTIVE, fixed-tier
**Crit $100k / High $50k / Med $10k**, Arbitrum. Chosen as RE-SOURCE #3 (EVM toolkit-fit + ERC-7540 async composition seam).
Repos+dossier ~/Desktop/BUGS/usdai-2026 (3 repos cloned at scope commits):
- usdai-contracts @5ef4905 (~8670 LOC): USDaiQueuedDepositor(1090), StakedUSDai(808), USDai(702), OUSDaiUtility(542),
  LoanRouterPositionManager(490)+Logic(430), RedemptionLogic(411), UniswapV3SwapAdapter, ChainlinkPriceOracle, PredepositVault.
- usdai-loan-router-contracts @59adf3e (devel, ~4147 LOC): LoanRouter(1179), DepositTimelock(542), BundleCollateralWrapper, rate models.
- usdai-governance-contracts @d5281d9 (main, ~1405 LOC): StakedChip, Chip, ChipGovernor, omnichain OAdapter/OToken/OLockAdapter. Has KTL+Quantstamp audits in-repo.

**SATURATION REALITY (scope-check caught this before depth):** 14k LOC / 3 repos = NOT compact; 2-3 audits (Cantina+KTL+Quantstamp);
**640 findings already submitted** → single-contract surface heavily worked. **KEY EXCLUSIONS gut the picked vein:** async-redemption
"admin-processing-timing" desync EXCLUDED, deposit-timing-vs-share-price arb EXCLUDED, bad-oracle-DATA EXCLUDED, borrower-not-via-
LoanRouter EXCLUDED, non-Arbitrum blacklisting + bridging-subsidy EXCLUDED.

**FRESH ANGLE (un-gutted):** the CROSS-REPO composition seam LoanRouterPositionManager (usdai-contracts) ↔ LoanRouter (loan-router)
— vault NAV vs loan-state on repay/default/liquidation, a NON-admin-timing accounting desync no single-repo audit owns. Secondary:
USDaiQueuedDepositor(1090) share math, RedemptionLogic value-conservation (non-timing), omnichain OToken/OAdapter replay/desync.
Vein = /darkside Door-C + upshift on the cross-repo join, /extract on queued-deposit/redemption math, /nuke barrage for negative-space.
Apply [[feedback-trigger-reachability-is-payability-gate]] + [[feedback-hunt-dont-narrate-ev]]. A finding reducing to admin-timing or
bad-oracle-data is DEAD (excluded). See [[reference-landscape-scan-2026-07-20]].

**FIND C1 (hand-verified end-to-end 2026-07-20) — REDIRECTED-REPAYMENT PHANTOM NAV → permanent insolvency, the first real find of the RE-SOURCE.**
The cross-repo moat: StakedUSDai prices deposits OPTIMISTIC / redemptions CONSERVATIVE, redemptions value-locked at admin serviceRedemptions
→ every unprivileged mispricing funnels to the EXCLUDED admin-timing class (that's why the exclusions ring admin-timing). C1 escapes it:
`LoanRouter._repayLenders` (loan-router LoanRouter.sol:531-548) transfers repayment to the tranche-NFT owner (the vault); if transfer
reverts OR returns false → `_redirectRepayment` sends tokens to the FEE RECIPIENT (:626-639) — but STILL calls `onLoanRepayment` on the
vault. The vault hook `loanRepayment` (usdai-contracts LoanRouterPositionManagerLogic.sol:319) UNCONDITIONALLY books
`repaymentBalances[ct].repayment += principal+interest-adminFee` (no receipt check) + decrements pending (:323). Same for
`_repayLendersLiquidation`→`loanCollateralLiquidated` (:415). repaymentBalances feeds NAV (`_value` at :169 → StakedUSDai._assets
:254-255 → _sharePrice). NO RECOVERY: depositLoanRepayment (LoanRouterPositionManager.sol:422, STRATEGY_ADMIN) must HOLD the tokens to
swap→USDai, but they're at the fee recipient → reverts; phantom NAV stuck forever. Net: sUSDai over-valued → redeemers over-serviced →
shortfall socialized to remaining holders = permanent insolvency. UNTESTED both repos (loan-router tests blacklisted EOA lenders never a
hook-vault lender; vault tests a vault lender never a failing transfer).
TRIGGER (honest, per reachable-trigger lesson): NOT an unprivileged attacker — the transfer-fail is a USDC/PYUSD blacklist of the vault on
Arbitrum (Circle/Paxos/OFAC) or a false-returning currency token. BUT the program's exclusions only exclude "blacklisting on non-Arbitrum
chain" → implies Arbitrum(source-chain) blacklisting IS an in-scope threat, so this is in the program's threat model (unlike the Symbiotic
hardening). STRONGER than Symbiotic: realized INSOLVENCY (not conditional freeze) + ACTIVE double-count mis-accounting (not missing handling)
+ trigger in-scope + no recovery + untested. Severity: **Medium, arguably High** (external trigger caps it below attacker-Critical; let
triager score). NEXT: Foundry PoC (vault-lender + blacklisting mock currency → assert phantom repaymentBalances/NAV + depositLoanRepayment
revert + redeemer over-service), confirm the blacklisting-on-Arbitrum scope reading, then report (report-nerve+chill). C2 (swallowed-hook
desync) = latent, no unprivileged trigger, DO NOT submit.

**PoC STATUS (2026-07-20):** written at usdai-contracts/test/probe/C1_PhantomNAV.t.sol — extends BaseLoanRouterTest
(real StakedUSDai + real LoanRouter, vault as lender), blacklists the vault on real Arbitrum USDC
(vm.prank(IFiatToken(USDC).blacklister()); blacklist(vault)) before repay, asserts: (1) vault receives NO USDC
(redirected), (2) repaymentBalance still booked (phantom), (3) nav steady = overstated, (4) depositLoanRepayment
reverts (no recovery). **PoC GREEN (2026-07-20) — PASSES on real Arbitrum fork.** Ran via operator's Infura key in usdai-contracts/.env
(ARBITRUM_RPC_URL, .gitignored, key NOT stored here). Result [PASS] gas 1.8M: vault USDC received=0, phantom
repaymentBalance booked=1,008,240e18 (for a 1M USDC loan), nav before==after (10,008,140e18) i.e. NAV overstated by
~1.008M = ~10% of the 10M test vault (scales with blacklisted-loan size), and depositLoanRepayment reverts (no recovery)
— all 4 assertions hold. Chain executed-proven end-to-end with real USDC blacklist + real StakedUSDai + real LoanRouter.
Submodule note: init individually skipping the broken lib/usdai-contracts self-ref in .gitmodules; compile 191 files Solc 0.8.29.
HARDENED + REPORTED (2026-07-20). Added test_C1b (also GREEN): an honest LP holds sUSDai, phantom event runs, and
redemptionSharePrice() (CONSERVATIVE, what serviceRedemptions pays at) is NOT marked down (1.000000003333→1.000000003336,
holds/rises) despite the ~1M real-backing loss, and paid-per-share > fair-per-share(real). This is the key strengthener:
the over-service is DETERMINISTIC at every timestamp → it does NOT reduce to the excluded "admin processing timing" class
(kills that dedup). Socialized-loss ceiling = phantom ≈ blacklisted-loan size. Report DONE at
~/Desktop/BUGS/usdai-2026/REPORT-C1-phantom-nav.md (116 lines, report-nerve+chill, closing-gate clean, killshot PoC-backed,
honest external-trigger framing). Both tests: `forge test --match-path test/probe/C1_PhantomNAV.t.sol` (needs .env Infura RPC).
STATUS: **DO NOT SUBMIT — OUT OF SCOPE (operator scope-check, correct).** The exclusion reads verbatim
"Any blacklisting inconsistency or blacklisting on non-source chain (non-Arbitrum chain)" = TWO exclusions via "or".
Clause 1 "Any blacklisting inconsistency" is CHAIN-INDEPENDENT and swallows this finding: the phantom NAV is precisely an
inconsistency between the blacklist state (vault doesn't receive) and the repayment accounting (hook books as if received).
On the real whitelisted tokens (USDC/PYUSD) the only reachable transfer-failure is a blacklist, and the PoC/killshot ARE a
blacklist, so there's no reframing that removes it. I mis-read the exclusion — anchored on clause 2 ("non-Arbitrum" → inferred
"Arbitrum in-scope") and missed clause 1's breadth. C1b (timing-exclusion bypass) is moot: the finding dies upstream on
clause 1, before any timing consideration. Same verdict class as F1 / Symbiotic-hardening / Rheo-NULL, cleanest reason yet
(named exclusion on the whole class). Report marked DO-NOT-SUBMIT. OPTIONAL: disclose as out-of-bounty HARDENING (the two-repo
seam producing permanent unrecoverable insolvency on an Arbitrum blacklist is real and fix-worthy; frame honestly as
OOS-per-blacklisting-inconsistency-exclusion, no reward claim). The session's payable find is the dYdX chain-halt
[[project-dydx-pml-zeroprice-chainhalt]] (reachable trigger, in-scope, no exclusion), NOT this. Fix (for the disclosure): gate
onLoanRepayment booking on actual receipt / add a credit path from the fee recipient. See [[feedback-read-both-or-clauses-in-exclusions]].
