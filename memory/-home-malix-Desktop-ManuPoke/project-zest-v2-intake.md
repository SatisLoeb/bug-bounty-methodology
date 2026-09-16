---
name: project-zest-v2-intake
description: "Zest Protocol V2 (Immunefi, Stacks/Clarity BTC-lending, $100k, NO-KYC, fresh 2026-01) — scope-checked, GO. 17 assets. P0 surface = v0-4-market (hub) + v0-egroup (novel eMode-like risk pricing) + rehypothecated-collateral valuation seam. TWO OOS walls pre-kill classes: flashloan-logic entirely OOS; DAO/egroup-config + off-chain-invariant-check clause → ESCAPED-guard only, absent-guard/bad-config DEAD."
metadata:
  node_type: memory
  type: project
  originSessionId: 3c399e15-ef33-40ad-abe1-f8688fee64f0
  modified: 2026-07-26T17:08:06.461Z
---

Re-source after StackingDAO delisted. Program: `immunefi.com/bug-bounty/zest-protocol-v2/information` +
`/scope`. Bitcoin lending on Stacks/Clarity. **Live 2026-01-15**, updated 2026-04-27. Max **$100k**
Crit / High max $20k. **NO KYC.** PoC required, local forks only. See [[reference-stacks-bugbounty-landscape-2026-07]].
Scope pulled 2026-07-26 (operator pasted the /scope tab — WebFetch can't reach it).

**V2 novel design (from the program blurb):** efficiency groups (egroup) for granular risk pricing per
asset combination (= Aave-eMode-like); **hub-spoke** architecture with `market.clar` (v0-4-market) as
central orchestrator; **collateral rehypothecation choice** — isolated (non-rehypothecated) vs
yield-bearing (rehypothecated). All three are NEW → under-audited relative to textbook lending → best EV.

**17 assets in scope (Clarity, mainnet, dates = when added):**
- CORE BRAIN (P0): `v0-4-market` (hub orchestrator, added 26 Feb 2026 = NEWEST), `v0-egroup` (efficiency
  groups, 28 Jan), `v0-assets` (asset registry, 28 Jan).
- VAULTS/spokes (P1): `v0-market-vault`, `v0-vault-sbtc`, `-ststx`, `-usdc`, `-stx`, **`-ststxbtc`**,
  `-usdh` (all 28 Jan). ststxbtc + usdh = yield-bearing → rehypothecation valuation seam candidates.
  (`v0-vault-ststxbtc` is the vault whose data-layer endpoint `SP1A27…v0-1-data get-user-ststxbtc-balances`
  I glimpsed during StackingDAO — ststxbtc-denominated 1:1. Modest head-start, not a surface map.)
- DAO/traits (mostly OOS-adjacent): `dao-treasury`, `dao-multisig`, `dao-executor`, `dao-traits`,
  `vault-traits`, `market-trait` (16 Jan). Traits = interfaces (low bug surface); DAO compromise is OOS.
- (16 enumerated from the paste; Immunefi counts 17 — one didn't paste, possibly an oracle/vault.)

**Impacts (8) — class-fit HIGH:** Crit = direct theft of funds (NOT yield) / permanent freeze of funds
/ **protocol insolvency**. High = **theft of unclaimed yield** / theft-of-royalties / perm-freeze of
unclaimed yield / perm-freeze-royalties / **temporary freezing of funds**. My StackingDAO seam class
(yield double-count → pool insolvency) maps here: yield-theft = High, insolvency = **Critical** (higher
ceiling than StackingDAO's framing).

**⚠ TWO OOS WALLS (front-loaded, xsurface Étape 6 — these decide payability):**
1. **"Any logic related to flashloans" is entirely OOS.** In a lending protocol this kills the whole
   flashloan-driven manipulation class. Note the tension: default rules say "not to exclude oracle
   manip/flashloan" but the Zest-SPECIFIC exclusion is more specific and wins → assume flashloan-triggered
   exploits are DEAD. A finding must reach its adverse state WITHOUT a flashloan.
2. **DAO/registry/egroup-config is intended-design OOS**, three clauses: "full control of asset & egroup
   registry by DAO is intended"; bugs requiring "DAO compromise / accidental registry update" OOS;
   **"invariants that require full knowledge of market and all position state are checked by the DAO
   off-chain before any egroup update is approved."** ⟹ This PRE-WRITES the Doppler/Morpho killer: any
   "DAO could set egroup param X wrong → breaks invariant" is DEAD (absent-guard = design-intent claim).
   **Hunt ESCAPED-guard ONLY** — a value/path that violates an invariant the code promises to hold in the
   EXISTING egroup config, where the USER creates the adverse state, not the DAO. This is exactly the
   StackingDAO-winning shape [[feedback-findings-die-on-the-actor-not-the-mechanism]].
- Also OOS: liquidation of DISABLED collateral / safety-design decisions; privileged-address abuse
  (unless privilege ACQUIRED, per becoming-the-actor); external-stablecoin depeg not caused by a code bug.

**ALLOCATION (xsurface-prioritize):** P0 = `v0-4-market` hub + `v0-egroup` risk-pricing + the
rehypothecation valuation seam (yield-bearing collateral valued at a stored/stale rate vs live — the
xseam bread-and-butter, and NEW in V2). Seam classes to hunt: (a) egroup risk-param applied wrong across
an asset-combo (eMode-class: LTV/liq-threshold mispriced when assets grouped), user-reachable in the
existing config; (b) rehypothecated-collateral value staleness (stored exchange-rate read by borrow/
liquidate without freshness); (c) hub-spoke cross-contract invariant gap (a spoke vault trusting the hub's
stored value, or a money-move that skips a freshness/solvency check its siblings enforce). Deployed==source
discipline: pull the Hiro-verified DEPLOYED source (key-free), not just the repo. [[project-stackingdao-stbtc-double-count]]

**FULL INTAKE DONE 2026-07-26** (dossier: `~/Desktop/BUGS/zest-v2-2026/TARGET-DOSSIER.md`; all 17 sources pulled key-free to `contracts/`, principal SP1A27KFY… confirmed). **Surface collapses to ~5 logic units, not 17:** `v0-4-market` (77KB hub, 84 priv, Pyth-priced GRADUATED liquidation) · `v0-vault-*` = ONE template ×6 (36KB, ERC4626-like deposit/redeem/**accrue**/socialize-debt/flashloan, 16 data-vars; sbtc↔ststxbtc diff=66 lines all config) · `v0-egroup` (eMode bitmask + superset invariant) · `v0-market-vault` · `v0-assets`. DAO/traits = OOS-adjacent. **`v0-vault-ststxbtc` UNDERLYING = SP4SZE…ststxbtc-token-v2 = StackingDAO's ststxbtc** (rehypothecation seam, cross-protocol).

**Corpus confirms the code:** lending, accounting #1 (n=405 H0.39) = StackingDAO F-01 class; liquidation #2 (n=324) = graduated-liq+socialize-debt. Killer HOW-tells: accounting "which balance-mutating paths call the checkpoint hook and which SKIP it" + liquidation "does the debt term include ACCRUED interest or only STORED principal?" = the accrue-staleness seam. Patterns hit: P-LEND-014(cap-miscalc)/006(partial-liq bad-debt)/007/025(rebase rehypo)/026/030.

**THE SEAM (ranked):** S1 PRIMARY = `accrue`-staleness across market↔vault (does every market money-move force accrue before reading vault supply/debt for health, or read STALE? liquidate uses accrued vs stored-principal debt? = StackingDAO F-01 shape transposed, user-reachable, ESCAPED-guard). S2 = graduated-liq value-math (extract → theft/insolvency). S3 = egroup health-read consistency (user-selectable egroup, NOT DAO-config). S4 = rehypothecation valuation (P2 cross-protocol).

**RECOMMENDATION (U-1, operator-gated, NOT launched): 1) /xseam on S1 accrue-staleness (+S3 egroup) — proven vein, same ecosystem/class, escaped-guard native, G3-Lieu-A. 2) /extract on S2 liq-math. 3) /mrrobbot if broad engagement. Avoid flashloan/oracle (OOS walls).**

**XSEAM PASS 1 DONE 2026-07-26 — accrue-staleness/valuation/health axis = NULL-COÛTEUX, HARDENED (7 executed kills, registre in notes/XSEAM-PASS-1.md).** Read: v0-4-market (borrow/repay/collateral-remove±redeem/liquidate/accrual+cache/notional/health/liq-math/oracle), v0-vault template (accrue/deposit/redeem/system-borrow±repay/socialize/index-math), v0-egroup (resolve/find/subset/superset-invariant), v0-market-vault (auth/get-position). Kills: T1 every money-move accrues debt+coll before health, debt valued fresh mul-div-up; T2 socialize-cache-staleness PATCHED (explicit refresh market:893-895); T3 zToken-collateral lindex-vs-ta/ts decoupling REAL but live dir SAFE (on-chain read all 6 vaults lindex/1e12<ta/ts −0.003..−0.05%) + socialize PRESERVES the ratio (both drop by 1−debt-reduction/old-ta) → no overval path, residual = liquidator dust <$1; T4 graduated-liq rounds protocol-favoring + same-block guard(1431); T5 egroup find returns genuine tightest superset, invariant enforced at insert, mask un-fakeable; T6 debt counted with MAX-U128 (market-vault:331); T7 state impl-gated. Verify tool: notes/read_vault_indexes.py (Hiro call-read key-free). **Genuinely careful V2 — did NOT manufacture.** UN-HUNTED residual (payable-surface, DIFFERENT vein): **native-STX/wSTX-wrapper + as-contract? handling (supply-collateral-add:1191, market-vault send-tokens:259) → /power or /extract, highest residual EV**; oracle confidence/staleness LOGIC (narrow, walled); liquidate-multi/redeem variants. **/POWER+/EXTRACT PASS (native-STX/as-contract/user-ft) DONE 2026-07-26 = SOUND/NULL.** `.wstx` pulled = thin native-STX facade (transfer=stx-transfer?, stx-transfer? enforces tx-sender==sender built-in). Allowances MATCH asset moved (with-stx only for .wstx native, with-ft for SIP-010) — my mismatch hyp REFUTED; scoped to exact amount. Donation-resistant (tracks `assets` var not balanceOf; ubalance only in flashloan-OOS); no transfer hooks→no reentrancy. User-supplied `<ft-trait>` validated via get-asset (registered-only); actual transfers route by asset-id to HARDCODED vault tokens (vault-system-borrow/repay ignore the ft); liquidator can't seize an asset borrower lacks. stSTX ratio = external StackingDAO oracle (SP4SZE…block-info-nakamoto-ststx-ratio-v2) + DAO-gated confidence = OOS-walled.

**FINAL VERDICT: Zest V2 core = HARDENED FORTRESS on every PAYABLE axis (2 focused passes, ~12 executed kills, notes/XSEAM-PASS-1.md).** accrue-staleness (StackingDAO transfer), valuation/lindex-decoupling, graduated-liq math, egroup LTV, state-authz, native-STX/as-contract, malicious-ft — all NULL with artifacts. Genuinely careful V2. Remaining surfaces OOS-walled (oracle/ratio) or DAO-config. → **RE-SOURCE.** Next Stacks options: Granite ($100k but KYC-WALL, OPSEC blocker) or back to landscape. Clarity+Hiro tooling + this Zest map retained for any future re-engagement (e.g., new V2 module deployed). Workspace ~/Desktop/BUGS/zest-v2-2026 (17 sources + wstx in contracts/, notes/read_vault_indexes.py reusable).
