---
name: injective-funding-selfcross-345-submitted
description: Injective funding-rate manipulation finding submitted to Cantina as
metadata: 
  node_type: memory
  type: project
  originSessionId: d5b2185c-f48f-4556-bf43-911375bdb403
---

**Injective injective-core Cantina #345 — SUBMITTED 2026-07-01, Medium, pending triage.** Found via [[injective-exchange-firmaudit-parked]]-adjacent untouched-surfaces map → /intake → /darkside.

**The finding (a seam composition, not a class):** three separable facts compose — (1) the perpetual funding accumulator is a LEFT-attributed step integral (`order_matching.go:1221`: `CumulativePrice += (blockTime − LastTimestamp) × (VWAP.Price − mark)/mark`, LastTimestamp = last *trade* block → funding_contribution = idle_time × deviation); (2) a normal derivative limit order has NO mark-price band (the `ErrExceedsTopOfBookPrice` band in `orders.go` fires only for post-only); (3) NO self-trade prevention. So a self-crossed dust trade on an empty-book quiet perp pins the market-wide funding to its cap; a PRE-EXISTING-position holder on a thin-but-with-OI perp extracts a deterministic transfer (312.5 USDT/hr observed on a 10-BTC victim) from honest holders on the other side.

**Scope:** the NORMAL-TRADE variant is in-scope (no CosmWasm, no privileged exec, no cross-margin). The SYNTHETIC variant (MsgPrivilegedExecuteContract) is OOS — mainnet `cosmwasm/wasm/v1/codes/params` = `code_upload_access: AnyOfAddresses` (whitelist), a fresh attacker can't upload the contract.

**Mainnet-verified (live LCD):** cap 0.000625/hr, interval 3600s; ~240 of ~283 active perps fully empty-book (drifts by a few — live snapshot); **30 empty-book perps carry open interest = the extraction set** (measured on-chain via `positions`, NOT assumed). Deployed = v1.20.0/3ade14d.

**Severity Medium (honest floor):** transfer core is real but cap-bounded per interval + tiny OI pool per market (2-8 positions). The "1.5%/day deterministic delta-neutral" headline was RETRACTED as dishonest (it ignored the round-trip spread + assumed victims on empty books). Empty-book-no-OI = griefing not theft; build-for-occasion = conditional (break-even N > spread/cap). Pre-existing-holder on thin-with-OI = the real deterministic transfer.

**Verification lessons (each cost a near-miss the operator caught):**
- **mark price = PURE ORACLE** (`market.go:230 GetReferencePrice`) → the self-cross does NOT move mark → no liquidation-manipulation reinforcement (the big-lot, ruled out).
- **OI ≠ resting orders** — a perp can have holders (OI) with a thin/empty book; those two conditions are independent, and the extraction targets have BOTH.
- **`injapp.Setup()` locks a shared wasmvm dir** → tests pass individually (separate processes) but the PACKAGE panics on the 2nd Setup. "all pass individually" was a false verifiability claim until a `setupApp(t)` helper gave each test a unique `t.TempDir()` home. Always run `go test ./pkg/` (whole package), not just per-test.
- **scale-factor inflates OI dollar figures** (indexer said DYDX = $56B for 8 positions) → cite the COUNT, never the raw dollar OI.
- Prove the inline PoC by EXTRACTING the code blocks from the exact posted markdown and compiling in a fresh dir (not just the working copies).

5 Go PoCs (`pocfba`/`poc8`/`pocextract`/`pocbook`/`helpers`), 4 terminal screenshots embedded. Follow-up: post chain-of-custody + inline-PoC-code comments; watch triage per [[injective-cantina-web-bounty-rugpull-signal]] (Injective can concede-then-reject).
