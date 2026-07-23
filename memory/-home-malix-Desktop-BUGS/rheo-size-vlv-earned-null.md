---
name: rheo-size-vlv-earned-null
description: Rheo (Size fork + very-liquid-vaults) SC bounty — executed earned-null on the seam+vault; one verified-but-admin-gated governance note (not submitted)
metadata: 
  node_type: memory
  type: project
  originSessionId: 61439117-954c-497d-af2e-838e1dfc23d9
---

Rheo bug bounty (modest: Critical $50K/$10K, High $5K/$1K, **Med/Low UNPAID**), deployed Ethereum. Workspace `~/Desktop/BUGS/rheo-audit/`. Two in-scope repos:
- **rheo-solidity** @ b7714a2 = **Size v1.9** (rebrand of size.credit, imports `@rheo-fm/`=lib/rheo-fm). **~9 audits** (Spearbit/C4/Cantina×2/Custodia×3/Omniscia/Hashlock, all ≤v1.8) → **dup-fortress core**; HEAD=v1.9-rc.0 small post-audit delta.
- **very-liquid-vaults** @ e356a70 = FRESH ERC4626 multi-strategy meta-vault (v0.1.0, 2 audits Obsidian+OZ, by Antonio Viggiano/Size team), 1603 LOC.

**SEAM** = Size market's NonTransferrableRebasingTokenVault (borrow-token/cash vault) routes each lender's cash into a whitelisted ERC4626 (VeryLiquidVault) via ERC4626Adapter; market reads `balanceOf(user)=vault.convertToAssets(sharesOf[user])` as withdrawable cash.

**EXECUTED earned-null (thief-mode, not novel-read):** built a self-contained Foundry PoC `very-liquid-vaults/test/thief/Thief.t.sol` (deps: had to clone Recon-Fuzz/setup-helpers + crytic/properties + chimera; move test/recon+property fuzzer files aside to build). Results: value-conservation PASS (500→500); first-depositor inflation BLOCKED (dead-shares, `_firstDeposit`); donation to raw-cash CashStrategyVault shifts a lender's convertToAssets 1000→962k BUT is a gift (donor loses to holders) + **not weaponizable** — the shiftable borrow-token balance is used only for withdraw amount, NOT in `collateralRatio`/liquidation (RiskLibrary uses `collateralToken` = a PLAIN NonTransferrableToken, un-shiftable). AaveStrategy hardened (scaledBalance×index rounded down, cites a16z erc4626-tests#13). callMarket privilege-escalation DISCONFIRMED (factory grants roles only to `_owner`, no self-role; `isAuthorized(factory,victim)=false`). v1.9 rheo-fm delta LOW-EV (`_isRheoMarket` uses oracle()-return-length, off-chain-label-only; APR getters = audited Size refactor + IRheo cast type-consistent for all-rheo deployment).

**Governance note (operator found via deployed-state pass; I verified on-chain @block 25467807):** Auth 0xB5294A79 grants VAULT_MANAGER to a **no-timelock EOA 0x7cBb7bE2** (nonce 75) that ALSO holds GUARDIAN+STRATEGIST — bypassing the README-documented `VAULT_MANAGER=1d timelock` (0xcDB5, getMinDelay=86400). Three roles on one key compose into a no-delay drain of vlvCoreUSDC(0x3AdF08)/vlvFrontierUSDC(0x13dDa6) (both whitelisted in Size USDC market 0xe9637E): setRebalanceMaxSlippagePercent(1e18)[VM] + addStrategy(evil, passes asset()/auth() view checks)[VM] + rebalance(real,evil,all,1e18)[STRATEGIST] → slippage=amount → no revert → evil keeps USDC. ALL legs verified (on-chain roles, README doc, code: _addStrategy + rebalance min()-clamp + PERCENT cap + _rebalance math). BUT reachability = **admin-trust-gated (key must go bad)** → kill-gate for a paid theft finding; honest tier = governance/config-vs-documented-control disclosure (A25-class), Med(Impact-High×Likelihood-Low)=UNPAID in Rheo matrix. NOT submitted as a Critical (would be dismissed as centralization + burn credibility). Fix = revoke EOA roles / route through timelock.

VERDICT: executed earned-null on the code; the only real deviation is admin-gated governance, not a payable contract bug. Re-open only on new deployed code or if Rheo pays config-discrepancy governance notes.
