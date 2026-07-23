---
name: injective-downtime-postonly-earned-null
description: "Injective injective-core downtime-detector -> exchange post-only-mode seam AUDITED 2026-07-01 (/intake -> /darkside) = earned null on untrusted theft; feature untested but correct incl all intersections; only residual = bounded >=1/3-validator DoS"
metadata:
  node_type: memory
  type: project
  originSessionId: d5b2185c-f48f-4556-bf43-911375bdb403
---

Target ① of the "Injective untouched surfaces" map (`INJECTIVE-MASTER-COVERAGE-MAP.md`). The `downtime-detector`
module's ONLY consumer is the exchange **post-only mode** (`processDowntimePostOnlyMode`, exchange/abci.go:705).
Full `/darkside` descent 2026-07-01 → **EARNED NULL on untrusted-reachable theft.** Record:
`~/Desktop/BUGS/injective-untouched-2026-07-01/DARKSIDE-TARGET1-VERDICT.md`, OUTCOMES `INJ-DOWNTIME-POSTONLY-2026-07-01`.

**Door A:** the feature is UNTESTED (0 adversarial tests; confirmed upstream via `gh search code` — `processDowntimePostOnlyMode`
only in abci.go, no `_test.go`; only an interchaintest genesis helper touches the param). Prime germe-shape, but the
descent held.

**Why null (all EXECUTED reads, not reasoning):** arm is reliable (downtime→exchange→oracle BeginBlocker order app.go:1712-14
+ same-block `ctx.BlockTime()` on both sides + `sdk.SortableTimeFormat` = ns precision → the `Equal()` string round-trip is
EXACT); cache-coherent (`SetParams`→`SetCachedParams`, `IsPostOnlyMode` reads fresh); enforcement COMPLETE (all 5 sites incl
crossing-limit spot/orders.go:111 + derivative/orders.go:1830, conditional-skip :113, synthetic/position-transfer); msg
arm/disarm (`ActivatePostOnlyMode`/`CancelPostOnlyMode`) gov-authority-or-admin gated, `ExchangeAdmins` default `[]` gov-set
→ no permissionless become-actor. **Intersections (operator's "vulns live in intersections" nudge) all closed:** liquidations
PROCEED during post-only (internal `ExecuteDerivativeMarketOrderImmediately`, not gated) AND are bounded by
`GetLiquidationMarketOrderWorstPrice` = mark/bankruptcy (position.go:201) → no blocked-liq bad-debt, no thin-book capture;
FBA/EndBlocker matching not post-only-gated = intended (makers cancel stale, takers blocked). Only surviving primitive =
≥⅓-validator force/suppress the block-time-derived downtime signal (CometBFT median/PBTS bounds a single proposer) = DoS-tier
bounded adversary → likely OOS/Low.

**DORMANT re-triggers (re-open ONLY on these):** (1) cross-margin enabled on mainnet (fresh v1.20 risk code changes the
consumer; ties to [[injective-exchange-firmaudit-parked]] cross-margin lead); (2) gov sets a weak/permissionless `ExchangeAdmins`
→ msg arm/disarm becomes untrusted-reachable; (3) a new injective-core version edits `processDowntimePostOnlyMode` or adds a
downtime consumer. Deployed-param read was blocked (7 LCD endpoints 502/503/Not-Implemented) but the verdict doesn't depend on it.

Remaining UNTOUCHED injective-core surfaces (higher EV than re-hunting this): **oracle WRITE/aggregation side** (only the
read/liquidation lens was audited) → next; then **txfees** (EIP-1559 base-fee) and the **cosmos-sdk authz fork delta**.
Related: [[feedback-apparatus-is-packaging-not-discovery]] (poke-first held — hand-read the code, no workflow), [[doctrine-seam-rattachement-is-the-value]].
