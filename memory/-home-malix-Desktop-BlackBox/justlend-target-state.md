---
name: justlend-target-state
description: "JustLend DAO (Immunefi justlenddao, Tron Compound-v2 fork) — measured fortress, RE-SOURCE"
metadata: 
  node_type: memory
  type: project
  originSessionId: bc465f84-7337-4d09-aead-c6f01b71fc91
  modified: 2026-08-22T02:58:38.661Z
---

JustLend DAO — Immunefi `justlenddao`, Smart Contract, TRON (TVM), **Compound v2 fork**, max $50k but only **$20k paid in 4 years** (live since 2022) = heavily farmed, low-yield (cf [[farmed-program-dup-baserate]]).

2026-08-22: fan-out 5 agents (ran on **claude-opus-4-8** — the offensive-sec content downgraded from the opus-5 pin at req#1, cf [[subagent-model-routing]]). **MEASURED FORTRESS, 0 payable.**

**KEY LESSON — scope date ≠ code age:** the "13 April 2026" dates on the Immunefi scope are LISTING/UPDATE dates, NOT deployment. On-chain `date_created`: wstUSDT 2023-08-03, sTRX 2023-06-21, USDD 2025-01-22. The "fresh surface" premise (new markets = new bugs) that justified the CONDITIONAL-GO was a **scope-date mirage** — contracts are 1-3yr old, fully farmed (same trap as [[decentraland-target-state]]; verify on-chain date_created, cf [[deployed-code-not-head]]).

5 slices, each closed by EXECUTED disconfirmer:
- **Accounting**: sTRX/wstUSDT are FIXED-BALANCE appreciating wrappers (wstETH/rETH-like, NOT rebasing) — exactly what a Compound cToken assumes → standard accounting correct. `getCash()==underlying.balanceOf(cToken)` proven on-chain both markets. Deployed Delegate = standard CErc20Delegate + only benign additions (reserveAdmin role, 8-arg initialize, USDT-branch doTransferOut skip). cToken only moves wrapper tokens, never unwraps (no 14-day-unbond freeze). nonReentrant + no TRC20 hooks.
- **Oracle (DECISIVE)**: Comptroller.oracle()=PriceOracleProxy `TGnYnSn4G9PgWFj7QQemh4YMZKp3fkympJ` → v1 poster oracle `TMiNCmvD3zdsv6mk7niBU6NPBzVNjYMQTV`. getUnderlyingPrice = passthrough to `assetPrices(underlying)` = POSTED scalar `_assetPrices`, `readers[]=0x0` for sTRX/wstUSDT/USDD. NO on-chain/DEX/exchangeRate read. Proof: posted sTRX price 1.312039e15 LAGS live sTRX.exchangeRate 1.312040e18 = stale off-chain snapshot ⇒ contract never reads on-chain rate ⇒ flash-manip moves nothing. Poster=`TBPtNVdgkB8QPRHAJeZok6D9pqsFdALv9w`, capped ±10%/600blk, privileged=OOS. Price-manip Critical structurally impossible.
- **Donation/empty-market**: all 24 markets (getAllMarkets) seeded, totalSupply 1e12-1e22, totalReserves>0 (long-lived accrual), exchangeRate un-manipulated (0.003-2.5% of initial mantissa). Window closed. Dup/by-design maximal (team's Apr-2022 audit documented + mitigated it).
- **Tron semantics**: all 7 underlyings REVERT on failed transfer (simulated on-chain); none fee-on-transfer/rebasing; doTransferIn=balance-delta (fee-safe). USD1(freeze+pause)/WBTC(pause) = issuer-owner-gated OOS listing-risk.
- **V2 drift**: money path byte-identical Compound v2 (mint/redeem/borrow/repay/liquidate/seize/accrue/exchangeRate); seizeInternal NO protocolSeizeShare; deployed==HEAD (verify_status=2, code_hash wstUSDT≡sTRX, USDD differs only in CBOR metadata word). Storage-collision from mid-layout reserveAdmin insertion DISPROVEN by live sane storage getters.

Real delegators: wstUSDT `TD5SdLw5scR6mXgyMK2xKrFJpauDjpKqrW`, sTRX `TJQ9rbVe9ei3nNtyGgBL22Fuu2xYjZaLAQ`, USDD `TKFRELGGoRgiayhwJTNNLqCNjFoLBh3Mnf`. Unitroller `TGjYzgCyPobsNS9n6WcbdLVR9dH7mWqFx7`. (The 3 scope-listed "delegate" addrs TUx4…/TCyN…/TLrE… are IMPLEMENTATION logic contracts, empty storage.)

**Practical**: tronscan serves NO verified source-text via REST/API (all 404/403); agents anchored on deployed-ABI + code_hash + live on-chain state + GitHub HEAD match (verify_status=2). Sound for go/no-go; a final submission would want the exact deployed source (needs authed tronscan key or manual /code paste).

VERDICT: RE-SOURCE. Reopen triggers: governance wires an ON-CHAIN oracle reader (DSValue from a manipulable source, or migrates price to on-chain exchangeRate/DEX) → re-audit that reader; OR the "SBM V2" module/oracles (exist as contracts, currently NOT wired — readers[]=0) enter the scoped assets = the likely real v2.0 novelty but presently OOS.
