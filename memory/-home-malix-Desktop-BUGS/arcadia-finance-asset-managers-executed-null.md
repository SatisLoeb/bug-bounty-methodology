---
name: arcadia-finance-asset-managers-executed-null
description: "Arcadia Finance (Base/OP/Unichain, $5.37M TVL, 10 audits): asset-managers surface = executed null on payable impact; the ONE real edge is that Arcadia DEPLOYS POST-AUDIT CODE (live CowSwapper is unaudited + blanket-yes EIP-1271) but every path is solver-gated/zero-balance; accounts-v2 + lending-v2 core still untouched"
metadata: 
  node_type: memory
  type: project
  originSessionId: a2041349-3e84-4e85-9f34-7b467d6202d6
  modified: 2026-07-30T10:44:49.488Z
---

Program: 3 in-scope repos (`accounts-v2` 15.4K LOC, `lending-v2` 4.5K, `asset-managers` 6.8K), deployed Base+Optimism+Unichain. Workspace `~/Desktop/BUGS/arcadia-audit/`. Engaged 2026-07-30.

**EV frame (measured, not assumed):** TVL **$5.37M** total (Base $5.01M, OP $362K, Unichain $78) — DeFiLlama `arcadia-finance`. **10 audits** (Nethermind V1, Trust, Renascence x3, Pashov x2, Sherlock x4) in `github.com/arcadia-finance/arcadia-finance-audits/audits-v2`. The program's severity rules are the most capping I have read: single-user loss caps at High, treasury funds never above Medium, **recoverable/reversible is never Critical** (any admin `skim`/pause/rescue = "not permanent"), exposure-cap issues explicitly Low/OOS, trusted roles AND trusted third parties (Chainlink, **CoW settlement layer + bonded solvers**) OOS. The OOS list is a confession map — it names exactly where prior hunters landed (Dutch-auction frozen shares/startDebt, partial bids, capped LP fees during liquidation, senior tranche withdrawal, initiator fee configs).

**THE REUSABLE EDGE ON THIS TARGET: Arcadia deploys post-audit code.** Highest-yield first move here is the deployed-vs-audited DATING check, not code reading. Proven for CowSwapper (`0xc928013A219EC9F18dE7B2dee6A50Ba626811854`, Base only): Jan-2026 Sherlock final commit `df763279` = 2026-01-20; deployed code ≈ PR #107, `git merge-base --is-ancestor df763279 ce8be88` = YES ⇒ **live code no audit ever reviewed**. Verified source on Blockscout 2026-02-13, `VERSION()="1.0.0"` (≠ audited commit, ≠ repo HEAD 1.1.1 — a THIRD variant).

**CowSwapper live weaknesses (all executed, all capped):**
- `isValidSignature(0xdead…, "")` returns **`0x1626ba7e`** on mainnet — blanket EIP-1271 yes while idle (`if (account == address(0)) return MAGIC_VALUE`, deployed line 439). Plus standing `2^256-1` vaultRelayer approvals for USDC/WETH/AERO, via **permissionless** `approveToken()`.
- `messageHash = keccak256(abi.encode(account,swapFee,orderHash))` — no EIP-712 domain (no chainId/verifying contract). Team added EIP-712 Mar-2026: **not deployed**.
- No `beforeSwap` ordering guard; team added `SwapAlreadyExecuted` Jun-2026: **not deployed**.
- **Why it still doesn't pay:** every path to *user* funds runs through `FlashLoanRouter.flashLoanAndSettle` (solver-only) or `HooksTrampoline` — confirmed gated, a non-settlement caller reverts `0x0cd41ec0`. Solvers are an explicit trust assumption ⇒ OOS. Untrusted reach hits only the CowSwapper's OWN balance = **0**; pre-funding it is the OOS "users intentionally sending tokens." Lifetime volume **~11.46 USDC** (USDC allowance decrement), 0 `FeePaid`, 24 accounts configured. ⇒ Low/Info.

**MerklOperator** (`0x969F0251360b9Cf11c68f6Ce9587924c1B8b42C6`, all 3 chains, ACTIVELY used; docs mislabel it `MerklOperatorBase.sol`, deployed contract is `MerklOperator`): Merkl `Distributor.claim` is permissionless, so any third party can claim a victim account's rewards straight into this shared contract where they sit unforwarded — **1 DOG currently stranded on-chain is that mechanism's fingerprint**. But `skim()` is `onlyOwner` ⇒ trusted-role-recoverable ⇒ Low by the "recoverable is never permanent" rule. Audited Sept-2025 (0/0/0).

**cl-managers (Compounder/Rebalancer/YieldClaimer) = executed null:**
- All three entry points are **initiator-gated**: `accountToInitiator[IAccount(a).owner()][a] != msg.sender → revert`. Docs' "third parties can trigger" means the owner-designated initiator, NOT anybody ⇒ malicious-initiator angle OOS.
- Anti-manipulation defence: `isPoolBalanced()` before AND after the swap (pool sqrtPrice inside a band around an **initiator-supplied** `trustedSqrtPrice`) + `position.liquidity >= rebalanceParams.minLiquidity` after mint.
- Seam I chased: `minLiquidity` is computed from the **live** `position.sqrtPrice`, so the bar moves with a manipulated price — extraction is bounded by band width × minLiquidityRatio.
- **Killed by measurement:** live config is byte-identical on EVERY sampled account (10+ on CompSlipV1, both Rebalancer accounts): `maxClaimFee 1e17` · `maxSwapFee 5e14` · `upperSqrtPriceDeviation 1.002496882788171067e18` · `lowerSqrtPriceDeviation 0.997496867163000166e18` · `minLiquidityRatio 9.9e17`. That is ±0.25% on sqrtPrice ⇒ **~±0.5% price band** with a **99%** min-liquidity floor, while the sandwicher pays round-trip pool fees on the whole manipulation ⇒ dust. Program rule "live on-chain state is the sole reference" makes any wider-band hypothetical OOS.
- Deployed cl-managers are VERSION 2.1.0/2.1.1 and ARE inside the audit lineage (v2.1.0 tag 2025-10-01 predates the audited commit); repo has moved to v2.2.0.
- False alarm I caught by tracing to the leaf: `git diff df763279..HEAD` appears to DELETE `account = account_;` (the reentrancy guard) from `rebalance()`. It was **moved**, not removed (`219529a` set-after-reentrance-check, `c3f1a83` removed the duplicate). HEAD line 310 is correct. Reading a cumulative diff hunk as a removal = the error; `git log -S` settled it.

**Still untouched (where the $5M actually is):** `accounts-v2` core (Account/Registry/Factory/asset-modules/oracle-modules) and `lending-v2` (LendingPool/Liquidator/Tranche). Any payable High/Critical must come from there, and it is 10 audits deep. Suspicious fresh spot: `accounts-v2` HEAD 2026-07-10 PR #349 `refactor/cap-per-liquidity-deltas` (20 days old) — and the program pre-emptively declares exposure-cap issues Low/OOS.

**Tooling note that unblocked day-0:** GitBook docs render address tables only in the `.md` sub-pages — `curl docs.arcadia.finance/developers/contract-addresses/{smart-contracts,creditors,asset-managers}.md` (found via `llms.txt`); the summarizing WebFetch returned nothing twice. **Blockscout** (`base.blockscout.com/api/v2/...`) gives verified source + logs + counters + token-balances with NO API key, replacing Etherscan-with-key entirely.

Related: [[feedback-depth-is-an-edge-only-where-ore-remains]] (post-audit deployed delta = the ore here), [[feedback-target-diet-is-the-binding-constraint]] ($5.4M TVL + capping rules = weak EV), [[doctrine-defense-shadow-confession]] (the OOS list and the team's own later commits are the confession), [[feedback-refuted-by-tracing-the-guard-is-novel-reading]], [[feedback-apparatus-is-packaging-not-discovery]] (the raw-curl poke beat the fetcher).
