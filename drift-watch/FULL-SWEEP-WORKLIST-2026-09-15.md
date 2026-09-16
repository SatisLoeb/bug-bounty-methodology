# Full-sweep drift worklist — 2026-09-15 (fresh code on mapped targets)
Sweep: 121 dossier repos → 50 no-drift, 39 DRIFT*path, 25 drift(off-path), 14 FROZEN, 5 FETCHERR, 2 DRIFT+TRIG.
Actionable = new commits on the MONEY-PATH of a plausibly-live bounty (OSS-churn rows like vercel/nuxt/svelte/next.js/proconnect dropped).

## Highest-signal fresh drift (candidate pre-loaded engagements — verify bounty live + seam-relevance)
- **Euler v2** — euler-price-oracle +35 (NEW `ChainlinkInfrequentNanosecondOracle.sol`) ; evk-periphery +100 (EdgeFactory, HookTargetMarketStatus, IRM). Oracle adapter = high-value seam. Big live bounty.
- **Reserve trusted-fillers** — +10 on `fillers/cowswap/CowSwapFiller.sol`, GenericTokenJar, ImmutableTokenJar. Filler money-path.
- **Nado (perp DEX)** — +10 on Clearinghouse.sol, BaseEngine, BaseWithdrawPool. Core money-path.
- **Coinbase commerce-payments** — +5 on `AuthCaptureEscrow.sol` + reentrancy tests. Focused escrow drift.
- **OKX Web3-DEX-EVM-PMM** — +29 on OrderRFQLib, PmmProtocol, CallerAuth. RFQ/auth money-path.
- **Yield Basis** — +342 on AMM.vy, HybridVault.vy (Vyper). Big churn; core AMM.
- **Granite core-v1** — DRIFT+TRIG (already known: liquidator remediation of the live finding).

## Noise / lower priority
- Alchemix +9 (test churn, NO-GO 527-comp) · Stacks +14 (mempool/CI refactor, not the miner/signer consensus cluster) · ENS +15 (DNSSEC/resolver, #1 was dup) · Pendle +50 (triple-audited fortress) · sbtc +4 (signer test/metrics) · morpho sdks/bundler (huge SDK churn) · all vercel-recon.* / nuxt / svelte / proconnect / testcontainers / feign / shepherd = active OSS, not bounty money-path.

## Method
Per candidate: (1) confirm bounty is LIVE + in scope, (2) audit-competition filter (reports.immunefi.com), (3) diff baseline..tip for the SEAM, (4) only then engage. The drift told you WHERE new code landed; recevability + seam still gate.
