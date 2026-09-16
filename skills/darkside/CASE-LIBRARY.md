# DARKSIDE — CASE LIBRARY (the evidence base, referenced by ID)

> Every worked example the skill relies on lives HERE, once. `SKILL.md` and `DARKSIDE-HUNT.md`
> cite a case by its `CASE-<id>` tag instead of re-narrating it — that is what keeps the two body
> docs short and stops the two copies from drifting. A case = **target · context · mechanism ·
> the REUSABLE pattern + grep-tell · the verdict/lesson.** When a new engagement teaches a
> transferable lesson, add a case here and cite its ID from the guard/step it justifies — do NOT
> inline the narration into the body docs.
>
> Index (door / guard that cites it → case):
> - Door A win → [[CASE-injective-voucher]] · Door B null → [[CASE-injective-s4]] · Door C win → [[CASE-f-stale-nav]]
> - Thief-inventory family-B / ATO → [[CASE-helix-134]] · axis-1 stated-assumption → [[CASE-helix-134]]
> - §0.5.1 fake-wall / §0.5.4 operator-pushed-4× → [[CASE-tokenize-it]]
> - §0.5.3 agent-fabrication / dead-code → [[CASE-boros]]
> - §0.5.5 deployed-layer read pass → [[CASE-mezo]] · [[CASE-august-deployed]]
> - §0.5.6 coverage ledger → [[CASE-mezo]]
> - §0.5.7 silent-no-op pivot → [[CASE-perena-bankineco]]
> - §0.5.8 pierce-the-gate → [[CASE-coinstore]]
> - §0.5.9 probably-unreachable / §0.5.10 understand-before-RE → [[CASE-mito]]
> - manual-loop PoC genuine-pair-first → [[CASE-okx-adapters]] · unbiased web-auth control → [[CASE-solv-297]]
> - chain-triage anti-inflation → [[CASE-zest-v2]] · exit drop-on-EV → [[CASE-dre-labs-1259]]
> - full-corner mirror-asymmetry → [[CASE-morpho-liquidation]]

---

## CASE-injective-voucher — Door A win (the only Critical of the engagement)

- **Target:** injective-core v1.20.0 (Cosmos-SDK chain node).
- **Context / door:** Door A (defensive-coverage matrix). `interchaintest/security/` held **4**
  adversarial tests — `wasm-evm-attack`, `wasm-auth-evm-attack`, `evm_permissions_reentrancy`,
  `cw-gas` — all targeting EVM-execution → halt / reentrancy. Executed each: every defense HELD.
- **The N cell:** **voucher accounting** (fresh v1.18+ code) had **no security test** — the untested
  sibling of "things that can halt the chain."
- **Mechanism:** KV key `denom ‖ 0x7c ‖ addr` parsed with a fixed `addrLen = 20`. Cosmos addresses
  are 20 OR 32 bytes; a 32-byte (CW-contract / module) address misparses → `sdk.NewCoin(garbageDenom)`
  → `GetAllVouchers` PANICS → auction `EndBlock` has no recover → **deterministic chain halt.**
- **Reusable pattern — VARIABLE-LENGTH-KEY MISPARSE.** Grep-tell: `addrLen = 20`, `k[len(k)-20:]`,
  `AccAddress(key[...])` with a literal length, `sdk.NewCoin(parsedDenom` inside an iterator.
- **Lesson:** severity from reading is a hypothesis. Reading alone scored this **Medium**
  (fund-misallocation); EXECUTING the PoC turned it into a panic-not-undercount → traced to EndBlock
  → **Critical chain-halt.** This is why the manual-loop PoC step is mandatory. Also: don't quit a
  candidate fast — the EVM↔Cosmos binding "looked solid" on surface; relentlessness past it found the
  voucher vein.

## CASE-injective-s4 — Door B null done right (the all-writers enumeration)

- **Target:** injective-core (auction module).
- **Context / door:** Door B (dev-paranoia-map). `WithdrawAllAuctionBalances` carried
  `// CRITICAL: transfer succeeded but deposit decrement failed — this should never happen since we
  only process denoms with sufficient balance`.
- **Real reasoning-gap:** the withdraw-list is built from `TotalBalance.TruncateInt()` but
  `DecrementDeposit` fails on `AvailableBalance.LT(amount)` — **Total vs Available.** If
  `Available < Total` for that subaccount, the "impossible" fires. The comment conflates Total with
  Available — a genuine gap in the dev's stated reasoning.
- **The disconfirmer that decided it:** enumerate EVERY writer to that subaccount's deposit across the
  whole module. Every credit was `ApplyUniformDelta` / `NewUniformDepositDelta` (available and total
  move together); zero non-uniform deltas targeted it; the keyless system-subaccount can't be a
  transfer source → `Available == Total` is an INVARIANT → the check can never fire → **honest null.**
- **Reusable pattern:** a defensive comment is a LEAD, not a finding; on a fortress the dev is usually
  right, more precisely than they stated. The disconfirmer for an invariant = **ENUMERATE EVERY
  WRITER of the guarded state**, never "by inspection." The all-writers enumeration is what separates
  the lead from a finding.
- **Severity gate:** most violated invariants just PAUSE / skip / log = fail-safe = DoS-not-theft =
  often Info. Check the consequence before spending sessions on reachability.

## CASE-f-stale-nav — Door C win (4 audits + a catalogue-mode pipeline all missed it)

- **Target:** August Oraclized vaults (coreUSDC / upGAMMA, TokenizedAccount impl).
- **Context / door:** Door C (unwritten-invariant map). Invisible to A by construction — no tested
  sibling to place it beside.
- **Step 1 canonical:** a normal vault derives NAV continuously from an on-chain read.
- **Step 2 deviations:** (a) `externalAssets` posted by hand by a single operator, discrete + laggy
  (mean 2.7d, up to 12.1d; upGAMMA 9.5d stale live); (b) `requestRedeem` with `lagDuration>0` *parks*
  shares and *freezes* the claim at request-time pps (`_receiverAmounts[cluster][rcv]=assetsAfterFee`),
  paid verbatim at `_claim` (`safeTransfer(rcv, claimableAssets)`, NO re-price); (c) the real strategy
  value (Gamma LP) moves continuously, public on-chain.
- **Step 3 unwritten invariant:** *"the queue's price-lock is symmetric."* Proof the devs believed it
  by construction is their OWN comment at `_registerRedeemRequest`: *"we transfer the shares to the
  liquidity pool to avoid fluctuations on the token price"* — they defended ONLY the request-instant
  pps, **silent on whether the frozen amount stays faithful to real value during the lag.** One side
  written, the other never. (This is the tell of a real unwritten invariant.)
- **Step 4 attack:** the lock is symmetric *in theory*, one-directional *in the hands of anyone who
  reads the chain*. Read on-chain that real value dropped below posted NAV → `requestRedeem` to freeze
  the stale-high exit BEFORE the operator posts the drop → loss lands on holders who didn't exit. Fork
  PoC (real upGAMMA/operator): thief +99,999 over fair, passive victim −38,604 under fair.
- **Disconfirmer that BOUNDS it:** flat-capital deposit-then-queue = net ZERO (enter and exit at the
  same stale pps) → requires a PRE-EXISTING position → honest **Medium**, informed-redemption
  arbitrage (passive→informed socialization), NOT "anyone drains the vault."
- **Reusable pattern:** the composition of 2–3 audited-alone-and-accepted deviations is the bug, and
  the composition has no name. Closest prior finding (F-14334, stale subaccount valuation, *Accepted*)
  saw the staleness but read it as "owner re-values as needed," never as "the lag IS an exit-arb window
  via the queue."
- **Shared-root frame:** one root (discrete hand-posted single-operator NAV, no real-price bound, no
  breaker) spawned three findings — sandwich-the-post (A, fee-bypass), brick-the-post (B, `gcp(0)=0`),
  arbitrage-the-stale-gap (C). Report the root + each consequence; A/B are catalogue-mode (real but
  named), C is the thief-mode discovery.

## CASE-helix-134 — thief-inventory family-B ATO (axis-1 stated-assumption; harness+suspend; prove-by-equivalence)

- **Target:** Injective web / Helix DEX front + BFF (2026-06-10/11).
- **Context:** web target, no adversarial unit suite → Door A empty → Door B + axes carry, and the
  **thief-inventory admission gate is the primary bound.** Axis-1 (stated-assumption) surfaced P-W9:
  the BFF issues a JWT for `granterAddress` but may only verify the signature proves possession of
  `sender` → authz impersonation / **ATO**.
- **Why it survived triage:** it chains to a concrete **family-B** payable capability (ATO), NOT to
  fund-movement. Under a fund-movement-only gate it dies — this is the exact miss the family-B
  correction closes. Became the operator's triaged **High #134**.
- **Reusable pattern — HARNESS + SUSPEND.** The branch first shelved as "needs an external wallet →
  unreachable" was FALSE: `sender` = any throwaway key + a good-type grant = direct-API-reachable. When
  the deciding leg needs a signature / broadcast / wallet-drive you cannot run, do NOT convert "I can't
  execute this leg" into "this leg is dead." Do everything keyless first, then deliver (1) the exact
  runnable harness, (2) the precise instruction, (3) `VERDICT: SUSPENDED — pending [exact action]`.
- **Reusable pattern — PROVE ATO BY EQUIVALENCE, not by faking content.** A PoC on an empty test
  account proves only the MECHANISM. Mint two sessions for the SAME victim — one the legit way (victim
  signs their own challenge), one the attacker way (fresh attacker credential) — and hit the same
  routes with each. Byte-identical responses prove a functionally identical copy of the victim's
  session, content-independent. #134: 6/6 routes byte-identical, `/user/me` identical to the ms. Show
  one FULL body-pair, never `200 {...}` both sides.

## CASE-tokenize-it — the hunter's own dark side (operator pushed 4×, all 4 real)

- **Target:** tokenize.it (2026-06-11).
- **Context:** origin of §0.5. The operator's framing: *"tu agis exactement comme les devs qu'on chasse
  — on devrait appliquer un darkside sur toi."* A hunter who audits like a defensive dev is exactly as
  blind as the dev who codes like one.
- **Lesson:** the operator pushed FOUR times and was right four times — four fake walls that would have
  been accepted. Re-open velocity is the real metric: if the operator pushing once surfaces something
  real, you closed too early. Also the concrete miss: read 120/545 lines of a file, never opened the
  audit PDF that was in git history → an un-attacked surface is exactly where the missed theft lives.
  Memory is necessary, not sufficient — `prove-the-null` was in memory the whole session and a biased
  PoC still shipped; the guards live in the SKILL (loaded whole) for that reason.

## CASE-boros — Workflow is coverage, not finding (dead-code refutation → find the live path)

- **Target:** Pendle Boros (2026-06-24).
- **Context:** three workflows produced 86+ candidates at ~10:1 false. Every agent "REAL/Critical"
  refuted on hand-read: BOLA cluster ×12 missed the signed-intent auth; margin-insolvency ×3 missed the
  `timeToMat.max(tThresh)` floor; mark-rate-manip missed the Notional smoothing.
- **Reusable pattern — hand-re-derive EVERY verdict, the REFUTED ones too.** A wrong refutation buries
  a real bug; a right refutation can hide a coverage insight. Budget it: a workflow returning N
  candidates = N hand-reads queued, not N findings.
- **Reusable pattern — GREP THE CALLERS on any "never called / unreachable / unused."** The agents
  refuted 5 orderbook bugs as "`_bookMatch` is never called" and were RIGHT (0 callers) — the insight
  they missed is that `_bookMatch` (the entire on-chain matcher) is **dead code** → matching is
  OFF-CHAIN → a whole workflow dissected code that never runs and the LIVE path was elsewhere. A
  dead-code refutation is a signal to FIND THE LIVE FUNCTION, never a clean close.
- **Reusable pattern — cheapest economic disconfirmer BEFORE the fork PoC.** On an "is this
  economically exploitable?" lead, run magnitude(gain) vs magnitude(cost) from on-chain reads + the
  deployed fee/rate formulas first. It refuted F-FIDX-STALE-ARB in minutes (0.31 bps funding << trading
  cost), saving the multi-hour fork build.

## CASE-mezo — deployed-layer read pass + coverage ledger (fortress, proven null)

- **Target:** Mezo (2026-06-11) — 5×-audited Liquity-derivative, Thesis team, DEV-NOTES anticipating
  their own DoS. Textbook fortress; ~15 surfaces deep-beasted, 2 PoC'd, both honest-dropped, $0.
- **Reusable pattern — DEPLOYED-LAYER READ PASS (§0.5.5).** Proving the CODE sound does NOT clear the
  deployed state — two separate surfaces. Three read-only reads per fund-moving deployed contract:
  (1) upgrade authority (EIP-1967 admin → ProxyAdmin → owner → EOA single-key = Critical, or Safe →
  threshold/owners); (2) deployed-impl ≠ repo (EIP-1967 impl slot → fetch VERIFIED SOURCE
  `/api/v2/smart-contracts/<impl>` and diff repo HEAD — **NEVER bytecode-grep for revert strings**, the
  compiler compresses them → false positive; Mezo bytecode-grep said BorrowerOps "lacks all guards",
  verified source was 1404 lines = repo line-for-line); (3) live oracle vs audit conditions (decode
  `latestRoundData()`, compare staleness/MCR/CCR to what the audit accepted). On Mezo all three sound
  (Safe 5-of-9, 6/6 impl=repo, oracle sane) → null PROVEN by reads, not assumed.
- **Reusable pattern — COVERAGE LEDGER (§0.5.6).** 8 surfaces named + proven sound → close, but
  `find *.sol` showed 20 contracts, 8 NEVER listed (~1631 LOC), skipped by "no seam" + "canonical-
  Liquity-dup." Operator's statistical tell: if a 279-submission cohort finds things and you find
  nothing, the cause is "I didn't search everywhere," not "I searched my surfaces badly." Ledger-driven
  sweep of the 8 returned 0 valid — but the null is now PROVEN complete.

## CASE-august-deployed — the deployed layer is where the money-exit lived (39 findings)

- **Target:** August (same protocol family as [[CASE-f-stale-nav]]).
- **Lesson:** August's 39 findings (several Critical) lived on the DEPLOYED layer that code-review never
  reads: single-key Safe authority (A20/A34), a violated audit-condition (A25), deployed-impl drift.
  This is the evidence that the deployed-layer read pass ([[CASE-mezo]] pattern) is mandatory before any
  costly-null close on an audited on-chain target.

## CASE-perena-bankineco — the silent no-op is a biased null in disguise

- **Target:** Perena Bankineco (2026-06-16, Solana/Anchor). Operator: *"le poc ne doit jamais être
  biaisé."*
- **Mechanism of the false null:** a fork chain mint→stake→keeper-yield-push→unstake netted the
  attacker −9.46 USDC → "D3 REFUTED." Anti-bias re-read: the keeper's `update_yielding_info` returned
  OK while tranche `share_price` delta = **0** — the push was a NO-OP (needed a multi-reporter consensus
  the harness didn't supply). The attacker netted negative because NO yield was ever distributed, not
  because the protocol defended. Null retracted.
- **Reusable pattern — READ-BACK THE PIVOT.** After the pivotal action (price-push, oracle-update,
  deposit, slash, state-transition), RE-READ the exact state variable it should change and ASSERT it
  moved by the expected magnitude. `state_after == state_before` → the step no-op'd → the result is NOT
  evidence, whatever the tx receipt says. A green receipt proves no-revert, not effect. Anchor/Solana
  instructions routinely succeed-as-no-op when a gate/consensus/staleness/`if needed` guard is unmet.
  Bake `require(state_after != state_before)` (or a logged delta) at the pivot.
- **Corollary:** when a faithful pivot is genuinely un-drivable (real yield CPIs into a live external
  protocol a static clone can't satisfy), do NOT fake the pivot's return to force the chain through.
  Report the executed GATES you hit + state plainly "clean end-to-end NOT achieved." Gates-proven +
  biased-null-retracted is honest; a forced green chain over a faked pivot is not.

## CASE-coinstore — don't respect the gate, pierce it (401 is not a verdict)

- **Target:** Coinstore (2026-06-17, web/API). Operator directive.
- **Lesson:** a gate names a control's EXISTENCE, never its STRENGTH; a 401 is a sign something valuable
  is HERE. On every gated surface run the 4 bypass angles before writing "blocked": **(A) AUTHN≠AUTHZ**
  (highest value — a resource-id with no ownership bind = IDOR/BFLA; a global pre-routing authn filter,
  e.g. Coinstore returning 401 even on `/api/v1/doesnotexist`, is solid vs unauth probing but moves
  100% of value to the post-filter authz it does NOT test); **(B) UNGUARDED SIBLING** (v1/v2 drift,
  REST/WS/GraphQL, on-chain/keeper, web/mobile, staging); **(C) GATE SATISFIABLE** (token issued before
  2FA completes, replayable/forgeable sig, sig covering payload-but-not-actor); **(D) DIFFERENTIAL LEAK**
  (401 vs 403 vs 404 vs timing).
- **Anti-inflation half:** piercing has two honest outcomes — find the window, OR prove the gate holds
  against THIS angle → value moves to the NEXT angle, never to "done." A recon-only probe that can't
  reach the authz layer does not prove a bypass; it scopes the suspended harness that would.

## CASE-mito — "probably unreachable" is not a verdict; understand before you RE

- **Target:** Mito Finance (2026-06-17, closed-source CosmWasm/WASM). Operator: *"on ne l'abandonne pas
  sur du probablement, on creuse chaque recoin, même si ça prend deux mois"* / *"est-ce que tu comprends
  exactement comment ça marche?"*
- **Reusable pattern — MAKE IT REACHABLE (§0.5.9).** You PROVED a high-impact defect and only
  reachability stands between it and a payable Critical. Reachability is a SURFACE to exhaust
  recoin-by-recoin, each leg an executed artifact: (a) become-X cheaply; (b) does ANY blessed instance
  reach the sink via ANY handler (grep every call-site/reply/submsg); (c) owner-controlled config makes
  blessed code emit the sink; (d) the upgrade path; (e) **the REACHABLE SIBLING with the same weak
  root** — every `market_make` routed through the SAME trust-boundary the unreachable
  `execute_messages_for_vault` hits, so PIVOT the finding to the sibling; (f) cross-instance binding;
  (g) compose with a cheaper bug. Only when ALL recoins are executed-null does "non-reachable" stand —
  and even then it's a real LATENT defect to catalogue.
- **Reusable pattern — UNDERSTAND BEFORE RE (§0.5.10).** Blind byte-tracing builds on sand: one wrong
  guess hangs the whole analysis (traced `m+648`=config.owner from WASM; it was the `vaults[caller]` Map
  key, and the entire reachability verdict rested on that error). Exhaust cheap ground-truth IN ORDER:
  (1) the public AUDIT REPORT (SCV/Oak/Zellic/Halborn/C4/Sherlock — file:line + bug class + STATUS; the
  Mito SCV #2 "malicious vault drains master via forward-reply" was EXACTLY the target bug, a known
  acknowledged SEVERE finding); (2) the source crate via the static CDN
  `https://static.crates.io/crates/<n>/<n>-<ver>.crate` (`.cargo_vcs_info.json` = commit sha + layout);
  (3) embedded paths `strings <wasm> | grep -oE 'contracts/[a-z/_-]+\.rs'`; (4) global commit-sha search;
  (5) the deployed contract's own enum (trigger a parse error `{"__x__":{}}` to list deployed variants,
  which often differ from the published crate). The SCV report turned 6h of WASM-guessing into an
  understood system in 20min.

## CASE-okx-adapters — genuine-pair-first (the deployed stand-in kills a finished report)

- **Target:** OKX DEX adapters (2026-06-11).
- **Mechanism of the false Medium:** "unguarded callback → scoop stranded surplus" reached a finished
  Medium report, then died on the genuine pair. The *stranding* half was proven on a REFUND adapter with
  the suffix omitted; the *drain* half on a DIFFERENT adapter from a `deal()`-ed balance. On the actual
  routed pair with real params, production sends `sqrtX96=0` (full-consume) → residue = 0 → the
  precondition NEVER occurs → theoretical → KILL.
- **Reusable pattern — GENUINE-PAIR-FIRST.** When the target is DEPLOYED, run the WHOLE chain ONCE on
  the real deployed contract + its real counterparty + real production params/routing BEFORE drafting.
  A two-halves PoC bridged by `deal()` + a stand-in reads 5/5 PASS while the end-to-end never happens in
  prod. Tells you took a stand-in: "I picked adapter X because its selector matches the pool I fork" (a
  real adapter is called ONLY by its own dex's pool); stranding and drain on different contracts;
  precondition `deal()`-ed not produced by a real routed call; deployed code ≠ repo-main. Liveness +
  genuine-precondition are reachability gates — FIRST, never deferred to "the team can balanceOf-sweep."

## CASE-solv-297 — the unbiased control for a web-auth finding

- **Target:** Solv (SOLVPR-297).
- **Reusable pattern:** the unbiased control for a web-auth BFLA is proving the SAME token returns 200
  on a benign resolver (`stats`) → the token is VALID, so the 401 on the target resource is a *targeted*
  auth refusal, not a dead token. Without that control a skeptic dismisses the gap. (Twin of the
  baseline+contrast requirement in the manual-loop PoC step.)

## CASE-zest-v2 — chain-triage that works + why anti-inflation matters

- **Target:** Zest v2 (lending).
- **The chain:** chain-triage reframed 4 weak/OOS isolated items (bank-run Medium, interest-insolvency
  slow, dust-no-min-borrow griefing, self-liq Resolved) into ONE thesis: *"bad-debt socialization is
  exploitable supplier-side, and the audit's same-block fix closes only the borrower-self-liq door, not
  the supplier-exit (bank-run) nor the dust-lingering amplifier."*
- **Reusable pattern — ANTI-INFLATION self-dismantle.** The tempting "CHAIN-A = free money" was KILLED:
  dust can't open underwater (is-healthy), and creating bad debt still burns the attacker's OWN
  collateral → the dust primitive is a TIMING-AID, not free money → honest **Medium/High, NOT Critical.**
  A chain is real only if every hop is executed AND the attacker nets positive (for the extraction
  class). An over-inflated chain is LLM-garbage in the opposite direction of a shallow dismissal.

## CASE-dre-labs-1259 — the exit gate done right (drop-on-EV, not drop-on-fatigue)

- **Target:** dre-labs / dreUSD (Sherlock #1259).
- **Exit lesson:** was about to NO-GO on "5 dry sessions" while the wrapper-fail-mode + prior-audit
  scope-delta lead (~1 session) had NEVER been pulled. Pulled, it came up dry (wrapper fail-CLOSED not
  fail-open; the custodianVault forwarder a pure pass-through) — but the verdict was only EARNED once
  executed. A NO-GO is legal only after every IDENTIFIED lead is executed, not after enough KILLs
  accumulate.
- **PoC lesson:** the load-bearing leg was re-entering the SIBLING vault via `onERC721Received` (not
  intra-manager — the transient ReentrancyGuard slot is per-ADDRESS), executed under `-vvvv` to confirm
  the in-callback action really fired (real Transfer events, real entry, no underfunding); a 1-wei drift
  was traced to a sequencing artifact and fixed, not ignored. Aim the disconfirmer at the load-bearing
  leg, not an adjacent dead one.

## CASE-morpho-liquidation — full-corner closure (the value is the mirror-asymmetry)

- **Target:** Morpho (liquidation path across collateral handlers).
- **Reusable pattern:** the value was the *consistency* across sibling collateral handlers, not any
  single bug — a guard/behavior present on N−1 handlers, asymmetric on the Nth. One report, shared root.
  A PoC exercises ONE slice; the signed verdict must cover the WHOLE place (every sibling shown
  inert/asymmetric) or you re-dig in 3 months. This is the mechanical form of axis-4 (ABSENCE): grep the
  guard's PRESENCE on the siblings, find the bare one.
