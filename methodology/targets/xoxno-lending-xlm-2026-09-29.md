# XOXNO Lending (rs-lending-xlm, Stellar Soroban) — intake dossier, 2026-09-29

Skill: `xsurface-prioritize` (threat model → reachability → receivability → tiering), executed generate-first
(every hypothesis written before its guard was sought; kills carry the executed artifact). No PoC, no exploit
procedures in this file by design — verdicts, guards, and design observations only.

## Phase 0
- Platform: Immunefi, added 2026-09-18, Primacy of Impact. Named assets: controller, pool, governance, position NFT,
  price aggregator, shared math. Not named: swap-aggregator, xoxno-oracle, defindex-strategy, keeper/exporter services.
- Impacts (verbatim tiers): C theft of user funds / permanent freeze / insolvency; H theft or permanent freeze of
  unclaimed yield, temporary freeze; M contract unable to operate for lack of token funds.
- Economics: max ≈ $50k (search snippet; immunefi.com egress-blocked here → tiers/floors/KYC UNVERIFIED). TVL ≈ $719k
  (DefiLlama via search). Critical = 10% of funds-at-risk ⇒ real ceiling tracks per-market TVL, far below $50k for
  most single-market paths (LP markets are capped at 500 LP tokens).
- Code state: HEAD c50f25a == tag v1.0.1 on contracts/common/interfaces (README-only diff). Mainnet declared on
  v1.0.1 (#187). On-chain wasm-hash match NOT re-verified (RPC/Horizon/stellar.expert egress-blocked).
- Hardening signal: Certora Sunbeam specs in-crate, cargo-fuzz + proptest + mutants, 26k contract LoC / 152k total,
  an unnamed "2026-09-26 upgrade audit" (F-xx/R-xx ids, artifacts never committed; looks like an in-house LLM-judge
  pipeline, not a firm), 6 fix commits 2026-09-22..27 (bypass-the-fix surface examined).
- SECURITY.md exclusions: compromised governance/operator/keeper keys, third-party oracle providers, theoretical.

## Assets, entry points, actors — see `docs/reference/architecture.md`, `docs/explanation/threat-model.md`,
`scripts/permissionless_entrypoints.txt` (CI-enforced list of caller-auth / permissionless entrypoints). Actors that
matter: anonymous address, borrower on own account, liquidator, supplier, delegate (economic control by design),
NFT operator (whole-account transfer by design). Governance, guardian, oracle role, keeper, token issuers: OOS.

## Hypothesis register (class → guard → verdict)
Solo + 5 agents (pool accounting, liquidation engine, oracle+deployed config, authority/NFT/Blend/router,
rounding model). ~70 hypotheses generated across all surface classes; artifacts in the session scratchpad
(`rounding/*.py`, `xoxno_model.py`, `xoxno_fuzz*.py`, `liq_model.py`, `scenarios.py`).

| # | class | guard / artifact | verdict |
|---|---|---|---|
| 1 | third-party supply restamps a foreign account's liquidation tuple | `risk/params.rs:68-119` liquidator-favouring tuple applied only if hypothetical HF ≥ 1.05, on every caller path; siblings (LTV-only, per-leg ordering, mixed changes, debt-free) swept | DROP |
| 2 | LP collateral valuation moved within a callback | prices cached before callbacks (`strategies/flash_position.rs:117`, `context.rs`), fair-value 2√(Va·Vb)/S on stored reserves (`common/src/oracle/lp.rs`), stable D·min(P)/S; swap/deposit/donation neutral | DROP |
| 3 | callback re-entry desyncs the in-memory account vs pool totals (INV-ACCT-10) | host `soroban-env-host 28.0.2 src/host/frame.rs:1150-1180` forbids any call to a contract already on the stack; temporary flash flag as second layer | DROP |
| 4 | duplicate keys / stale positions in batches (11 batch builders) | `payments.rs` Map merge; every builder iterates a Map; pool reloads each leg (`pool/src/ops/mod.rs`) | DROP |
| 5 | credit-mode share move inflates receiver | sum assert debit+credit+fee (`liquidation/apply.rs:170-174`), same-spoke + Normal-mode + live position `checked_sub`; 0/20 000 fuzz | DROP |
| 6 | rounding extraction at every sink (supply, withdraw partial/all, borrow, repay, net-settle, revenue, write-down, accrual chunking, index floor/ceiling) | exact integer models, ~1.6M + 20 written hypotheses in dirty numbers: every closed loop ≤ 0 for the actor (pool-favoured), backing slack never negative, cadence = 1e-27-token redistribution | DROP (executed null with numbers) |
| 7 | shared token custody across hubs desyncs a market's cash book | every credit = measured delta around its own transfer; every debit paired with transfer_out; flash loan balance-equality checks | DROP (and form-null: no token listed in two hubs on mainnet) |
| 8 | spoke cap bypass via credit/strategies | every entry leg → `apply_leg_usage(Entry)`; credit is same-spoke by assertion | DROP |
| 9 | split liquidation across the C = D boundary | cap floors keep C'/D' non-decreasing; band whole-BPS ratchet ≤ min(C−D, 1 bps of D), documented in formulas.md and Certora `liquidation_rules.rs:610` | DROP (documented, bounded) |
| 10 | under-delivery / per-leg rounding for the liquidator | all fields floored against the liquidator (`apply.rs:68-72`, `math.rs:578-604`); Credit ≡ Transfer within 1 unit/leg | DROP |
| 11 | post-fix siblings of #155/#160/#176/#154 | repayment path mode-agnostic; Credit fee ≤ bonus ≤ seized; whole-unit arms inert (no <3-dec listing on mainnet); relisting needs zero usage | DROP |
| 12 | authority after NFT transfer / delegate revival / approvals / creation race | owner never stored, live `owner_of` on every load (`storage/account.rs:35-44`); grants stamped by grantor; OZ approvals cleared on transfer; composition tests cover transfer-between-legs | DROP (revival documented, no third-party victim) |
| 13 | controller residue sweep, router auth tree, Blend migration leftovers | delta-only refunds from same-call baselines; single-use exact-args invoker entry (`common/src/token.rs:36-52`, host auth.rs); Blend refund measured and re-paid to hub debt | DROP |
| 14 | become-the-actor on privileged sinks (controller admin, NFT mint/burn/upgrade, governance execute_self, pool mutators, adapter) | `__constructor` non-invokable; owner set once; NFT deploy once + deterministic; pool only_owner (= controller); adapter keyed by `from` | DROP |
| 15 | TTL / archival of account, delegate, usage, NFT owner entries | archived persistent entries are auto-restored in the RW footprint or abort (never read as absent); temporary storage only carries approvals/flash flag (fail-safe) | DROP |
| 16 | oracle composition / decimals / staleness on every deployed config row (33 markets, Scaled, Ref, LP, Xoxno) | provider decimals attested at admission; WAD×WAD/WAD product; `attest_base`; future skew 60 s; dual-source needs both legs (no fallback); accepted deviation ≤ tolerance/2 ⇒ max L·u = 0.902 (USDC, Stables & FX spoke) < 1 | DROP as manipulation; see D-2 as design note |
| 17 | governance `execute` ordering / timing | op content hash-bound, non-replayable; timing = Info.3 | DROP |
| 18 | fee asymmetry (flash_position 0 vs multiply fee vs borrow 0) | ADR-0020, own-collateral only | DROP (design) |
| 19 | market with zero suppliers and orphan rounding cash can be borrowed | utilization gate short-circuits at supplied == 0 (`pool/src/guards.rs:20`); consequence = dust loan + `require_supply_for_debt` on a supplier-less dust market until any supply | DROP (dust; the one "author did not consider" pattern found) |

## Availability dependencies (fail-closed valuation, ADR-0005) — written as findings, gated, not payable as found
- A-1 A supply leg whose price becomes unavailable blocks liquidation, cleanup and force-socialization of that
  account (`risk/totals.rs:404` → `context.rs:142` → strict `prices`). Supply of a leg needs no price. Documented as
  DoS.1 in the threat model. Governance recovery: `set_oracle` may re-source the key or lower the LP floor;
  min delay 12 ledgers ≈ 1 min. ⇒ conditional on a pool-value state + bounded by governance reaction ⇒ P2/WATCH,
  and a known issue on the dup axis.
- A-2 Dual-source keys whose factor is a Reflector Stellar-DEX feed (USTRY, CETES, AQUA and the four LPs built on
  them) become unusable on ≥5 %/10 % disagreement with the fundamental leg; the DEX feed's manipulation resistance
  is undocumented (Reflector docs egress-blocked; C4 2025-10 README gives no method). External premise OPEN ⇒
  NOT READY at any tier (reachability is a kill-gate). Same governance re-sourcing bound as A-1. Tamper.1 framing in
  the threat model ⇒ dup-risk High.
- A-3 Fixed USD sanity bands equal to factor bounds on accruing/FX-denominated RWA (USTRY top 1.1556, CETES ±8 %
  around a MXN NAV) will be crossed by drift, not by an adversary; fail-closed until a timelocked reconfiguration.
  Advisory (M "unable to operate" at best, self-resolving by governance in minutes).
- A-4 Resource budget: an account at the position limit holding LP legs needs ~10 cross-contract calls per LP
  plus nested legs per valuation; the repo's own benches and the testnet frontier cover plain legs only and the
  stress script disclaims LP costs. Measurement pending (harness agent) — see addendum below.

## Design observations (non-payable, worth a private note to the team)
- D-1 R-23 payoff jump at C = D is larger on spoke 1 than the memo's 500-bps figures (blended base 699 bps:
  0.435 % → 5.77 % of D; lenders socialize ≈ 7 % of D just below C = D). Open decision, documented.
- D-2 Stables & FX spoke (USDC LTV 88 / LT 92, PYUSD 86/90, USST/USDY 80/85) violates the authors' own lender-safety
  condition LT < 1/u (u = sanity-band ratio): genuine-depeg exposure, not an attack surface.
- D-3 Every Reflector-paired RedStone leg is labelled `Fundamental`, so the two-leg age-spread guard never fires on
  mainnet; effective freshness asymmetry up to 13 h on XLM/BTC, bounded by tolerance.
- D-4 Permissionless `update_account_threshold` renews any account's controller entries (threat-model DoS.6 says
  owner-only); benign.
- D-5 Self-liquidation in Transfer mode skips the utilization ceiling (by design); exit-liquidity priority at ≈1.2 %
  of collateral in fees plus race risk.

## Decision
NO-GO on the named SC surface as of v1.0.1, with kill-list (this file + notes). Rationale: theft/insolvency
classes died on executed guards or executed numeric nulls at every sink; the only live items are availability
dependencies that are (a) documented by the target, (b) conditional on external state, and (c) bounded by a
one-minute governance timelock. Flip conditions: A-4 measurement shows a max-position LP account exceeds mainnet
tx limits (→ re-open as un-liquidatable-account, High/Critical by insolvency); a Reflector DEX methodology source
proves cheap movability (→ A-2 becomes reachable); a new deployed commit touching liquidation/oracle; a <3-decimal
listing or a token listed in two hubs appearing on mainnet (form-null rows 7 and 11 re-arm).
Time spent: ~2.5 h wall, 5 agents. Remaining EV on this program: low; watch list only.
