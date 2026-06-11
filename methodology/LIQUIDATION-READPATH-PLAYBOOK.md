# LIQUIDATION READ-PATH PLAYBOOK

**Class:** off-chain liquidation/keeper engine of a lending protocol (the SDK/bot that READS on-chain prices/oracles and turns them into liquidation swap + repay decisions).
**Loaded by:** `firmaudit` Phase S when the target is a lending protocol whose liquidation-SDK / keeper / bot is in scope. The seam-catalogue row "Audited on-chain protocol ↔ off-chain liquidation/keeper engine (READ-path)" points here.
**Proven on:** Morpho `liquidation-sdk-viem` (2026-06-08) — 7 hand-verified sibling bugs in one read-path, one report. Validated the thesis. NOT yet run on a second target.

## The thesis (why this surface is rich and un-competed)

The oracle WRITE-path (signature, replay, staleness, quorum) is over-audited — every SC audit and contest ratifies it. **Nobody finishes the READ-path: what the off-chain liquidation engine DOES with the price after reading it.** The SC auditors don't read the off-chain TS; the web/API auditors read auth, not liquidation math. The handoff (audited-oracle → off-chain SDK → swap calldata → on-chain execution) is owned by neither review. That's the seam.

**The tell — MIRROR-ASYMMETRY across collateral handlers.** Each exotic-collateral handler (Pendle / Spectra / Midas / Sky / native) re-implements the price→min-out→profit translation, and they DIFFER. When you find one handler doing slippage/oracle/decimals one way and the sibling doing it another, one of them is wrong. Find one bug → grep the siblings → you usually find a nest, not a one-off.

## The hard severity cap (internalize this BEFORE digging, it governs EV)

On a well-built lending protocol the on-chain contracts RECOMPUTE everything with the correct oracle and enforce their own invariants. So a wrong number in the off-chain SDK does NOT steal protocol/user funds — the worst case is the bot getting sandwiched, reverting, or making a bad estimate. **Victim = the bot operator** (which includes the protocol team if they run the bot in prod — check the README, and integrators of the exported lib). This is an **efficiency / liveness** class, NOT fund-theft. Almost everything here is **Medium or Low**, bot-side. Frame it honestly as such from the summary (the money-flow / fund-only-rubric filter will downgrade any overclaim — see `feedback_polymarket_triager_money_flow_only`). The value is the CONSISTENCY (N siblings, one un-finished read-path), not any single bug. Package as ONE report with a shared root, never N separate Mediums (self-dup risk).

## The 7 proven bug classes (grep + check each, per handler)

1. **Unit-conversion corruption** — a value in one unit (bps / WAD / percent / decimal) consumed as another. The killer instance: `Number(x.toString(16))` (hex round-trip). Also `/100` vs `/10000` vs `/1e14`, and the SAME variable consumed in two units at two sites.
   `grep -nE 'toString\(16\)|/ ?100\b|/ ?10000|10n ?\*\* ?14|wadMul.*slippage|WAD \+ |WAD - '`
   PROVE the correct unit from the external SDK's own type def / the on-chain getter's return unit / the sibling that does it right. Never assert it.

2. **Missing / cosmetic slippage** — a handler that never applies the computed market slippage, or bakes a near-zero buffer as min-out. Morpho Spectra: `min_dy = get_dy * 0.9999999` (0.0000001% — a revert-avoider, not protection). Check: does the handler's signature even TAKE the slippage param the caller computed? Does the call site pass it?
   `grep -nE 'get_dy|get_dx|min_dy|minReceive|minOut|0\.999|parseEther\("0\.99'`

3. **Wrong oracle / wrong pool / wrong index** — the off-chain quote reads a different oracle than the on-chain contract uses (Morpho pre-liq: `.market.price` = main oracle vs contract's `PRE_LIQUIDATION_ORACLE`). Or a Curve `get_dx/get_dy` with the wrong pool address / i / j / input denomination. Build the matrix (call site → pool → i → j → input-token) and flag every mismatch against on-chain coin ordering.

4. **Decimals / day-index / maturity / time** — `Math.round` vs `Math.floor` on a day index where on-chain uses integer division (Morpho Midas: `Math.round(Date.now()/1000/86400)` reads `dailyLimits[day+1]=0` for half of every UTC day → tx reverts on the limit check). Also ms-vs-seconds on maturity, oracle-decimals vs token-decimals scaling. CONFIRM the on-chain unit before claiming.

5. **Return-value not updated (mirror-asymmetry)** — a branch that does the work but never reassigns the returned amount, while the sibling branch does (Morpho Pendle expired-redeem keeps the PT count instead of the redeemed-underlying; the swap branch correctly sets `srcAmount = amountOut`).

6. **Dropped-validated-path / phantom return** — a branch that abandons the validated swap and executes a different path, while returning the abandoned path's number for profit accounting (Morpho Sky conversion branch drops `bestSwap`, returns its stale `dstAmount`).

7. **Fee mis-accounting** — under/over-subtracting redeem fees, or feeding a post-fee amount to an on-chain check that uses pre-fee (verify against the deployed vault source).

## Discipline (the three traps that bit — Morpho ×2, Injective ×1)

- **TEST the behavior, don't assume it (UNBIASED-PoC).** A corrupted value that the downstream API/contract REJECTS is fail-safe, not a finding. Morpho NaN case ($512M tier) looked like the biggest impact; the real Velora API throws on NaN → 1inch wins → benign. I almost headlined it. Run the real (read-only) `buildTx`/`getRate`/`cast call` and observe accept-vs-reject per corruption mode. See `feedback_unbiased_fork_poc`.
- **Re-verify at the DEPLOYED HEAD.** Morpho #446's Curve leg was real at submission (March) but DELETED by the deployed tag (June). Submitting dead code burns the whole report. Clone the deployed tag, grep every cited line exists, before writing. See `feedback_state_verify_at_submit_block`.
- **🚫 GATE on loss=$X-PRESENT — the read-path OVER-EVALUATES (Injective F-1, 2026-06-08).** The read-path thesis finds REAL code-defects (a consumer ignores a risk-signal it stored; `pyth_pro.go:35` documented-intent is a genuine anchor) but SEDUCES you into a severity the evidence doesn't carry. The defect is provable by READING; the EXPLOIT is not, and the severity rides on the exploit. Three sub-traps: **(1) tautological PoC** — feeding two prices either side of a threshold proves the comparison is MONOTONE, not the bug; a position CONSTRUCTED to fall between the bounds is circular. **(2) biased-by-construction** — de-biasing the price INPUT while the SCENARIO is engineered for the outcome is still biased (UNBIASED applies to the whole scenario). **(3) over-generous fix-hypothesis** — choosing the "correct behavior" that maximizes the demonstrated gap; "proven" then presumes YOUR fix-definition, which a triager can contest. **The killer = reachability/simultaneity:** the exploit needs ALL preconditions on the SAME market at the SAME instant on CURRENT state. F-1 had 3 ingredients (wide conf-band, tight maintenance, a position at the threshold) on 3 different markets/moments; the executed cross-check (read-only LCD/cast) found ZERO live market with conf>maint, the headline 5.26% feed UNUSED by any market, and the "stale" GLD feed's on-chain price ≈ true current Pyth (source-stale, 0.002% gap = nothing to exploit). **THE GATE:** a read-path / missing-validation finding earns Med+ ONLY if it produces `loss=$X` on the CURRENT on-chain snapshot (observed delta, executed). If the loss needs a FUTURE/conditional state that doesn't exist now (volatility window, a feed that might widen, a position that might exist, a fresh pool) → Low/Info/SKIP design-finding, NOT a payable exploit. **Self-tell: the word "PROVEN" in your own summary = distrust it + re-run this gate.** See `feedback_readpath_overeval_present_loss_gate` (the meta-lesson) + `feedback_polymarket_triager_money_flow_only` + `feedback_f_t233_rejected_organic_reachability_2026_05_26`.

## Targets to port the thesis to (after monetizing the first)

Every lending protocol with an off-chain liquidation bot/SDK/keeper in scope. Confirm the off-chain layer is IN SCOPE first (a contract-only bounty excludes it). Candidates with liquidation SDKs/keepers: Aave, Compound, Euler, Spark, Morpho (done), dYdX (keeper). Check each program's scope for the SDK/keeper repo before committing depth.

## Report shape

report-nerve + chill (human triager). One report, root = "the liquidation SDK read-path mishandles price→decision translation inconsistently across N collateral handlers; nobody finished it." Lead with the cleanest unit bug + its proven-unit evidence, then the siblings as a list, each with file:line + mechanism + one-line fix. "Where this stops" = honest bot-side cap. Recommended fix = one level up (a shared `(seizedAssets, marketSlippage, oracle) → minOut` helper that all handlers use, which would have made all N impossible). All Medium/Low; the consistency is the argument.
