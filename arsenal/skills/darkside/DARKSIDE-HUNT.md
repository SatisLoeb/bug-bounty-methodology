# DARKSIDE-HUNT — tactical catalogue (two-door coverage hunt, thief inventory, manual loop)

> This is the tactical catalogue for the **darkside** skill. The procedure + the A>B priority
> rule live in `SKILL.md`; this doc holds the full gate criteria (§0), the two-door catalogues
> with per-surface forms (§1 Door A primary, §2 Door B fallback), the 5-axes analyzer (§3), the
> delta-hunt reconstruction (§4), the manual loop (§5), the thief inventory + chain-triage (§6),
> and the exit gate (§7).
>
> **The germe (why this skill exists):** go read what the devs TESTED to validate their own
> security → list what they FORGOT to test or NEVER SAW → all of it with the mind of a thief who
> EMMAGASINE primitives to STEAL the protocol, not to bag one isolated bug. The skill keeps the
> germe BOUNDED: the entry point is finite (their test suite / their fear-annotations) and the
> admission criterion is concrete (chainable-to-a-theft). The 5 axes are an ANALYZER you point at
> a candidate the doors already handed you — they are NOT a generator (that was the failure mode:
> the contemplative "5-axes everywhere" found 5 nulls on injective-core; the germe found the only
> Critical).

---

## 0. THE GATE (run BEFORE any darkside descent — most important section)

A clean KILL pays $0. You are paid only when you LAND. Speculative depth on audited-stable code
is EV-negative when a queue exists. Gate hard before earning depth.

**Saturation score (Phase 0, before depth):**
- audit_count ≥ 2 → +heavy signal; **audit_count ≥ 3 = HIGH-saturation threshold** (especially if one is an in-repo internal audit)
- top-tier auditor (Spearbit/Cantina/Trail/OZ) → +
- large test suite (hundreds) + adversarial dev tests → + (note: this same suite is Door A's
  entry door — a fortress test suite is BOTH a NO-GO signal AND the richest coverage matrix)
- README saturated with trust assertions ("trusted", "X only", "always", "will receive") → +
- recent fix-review (thin residual) → +

HIGH saturation score → **do NOT dig the same saturated core to prove a null.** The theft that
survived the audits does not live deeper in the picked-clean core — it lives on a payable surface
(web/API/off-chain/fresh). **Default: RE-SOURCE to that surface; do not prove-null here.** Stay on
this target ONLY if it exposes a fresh sub-surface worth mining:
1. RE-SOURCE to a payable surface (web/API/off-chain/fresh) and redeploy to the queue — the default, OR
2. a strictly time-boxed **delta-only** pass (post-audit diff + internal-audit mining — §4) and
   nothing more unless the delta yields a concrete lead, OR
3. a **Door-A-only** pass: build the coverage matrix, take the highest-EV N-cell candidate, and
   stop if it gates to null. The matrix is cheap; a full descent on a saturated core predicts $0.

The alarm that means STOP: **N KILLs and 0 findings.** That ratio means you are certifying a
fortress, not hunting — proving the wall instead of piercing it. Clean corners are certificates of
impregnability; they do not pay rent. When it fires, RE-SOURCE to a payable surface, do not descend deeper.
Depth is the SCALPEL applied once the gate greenlights or a concrete lead exists — never the
default scan.

---

## 1. DOOR A — DEFENSIVE-COVERAGE MATRIX (PRIMARY, mandatory when an adversarial test suite exists)

**This is the germe, made surgical.** The devs' own security tests are the LITERAL MAP of their
paranoia. Each attack they wrote + patched marks the boundary of what they considered. **The bug
lives in the SIBLING they did NOT test at the same pattern.** Door A is PRIMARY: if an adversarial
test suite exists, you run this FIRST and Door B (§2) only activates after A is exhausted or where
A is empty.

### 1.1 Where the adversarial tests live (locate them per surface)

- **SC / Cosmos / blockchain node:**
  - `interchaintest/security/`, `*_security_test.go`, `*_attack_test.go`
  - `t.Run("attack...")` / `t.Run("exploit...")` / `t.Run("malicious...")` / `t.Run("reentrancy...")`
  - foundry: `test/invariant/`, `test/fuzz/`, `*.invariants.t.sol`, `InvariantTest`/`StdInvariant`
    handler suites, `testFuzz_`/`invariant_` prefixes
  - `grep -rn "t.Run(\"attack\|t.Run(\"exploit\|t.Run(\"malicious\|testFail\|test_Revert\|invariant_"` 
  - hardhat/echidna/medusa configs → the property files they fuzz
- **Web / API:**
  - integration/e2e auth suites (`*.e2e.spec.ts`, `cypress/`, `playwright/`, `tests/integration/auth`)
  - the **pentest report's tested-endpoint list** (the report IS the coverage matrix already
    written — what's NOT on its list is the N column)
  - the authz/tenant-isolation test fixtures, the rate-limit/CSRF test cases
- **Off-chain / keeper / relayer:**
  - keeper/relayer test fixtures, replay/nonce regression tests, the event→signature test cases,
    the webhook-signature verification tests

### 1.2 Build the {money-path × covered-by-adversarial-test?} matrix

1. Enumerate every **money-path function / invariant** on the target (fund-moving, share-price,
   accounting, redemption, mint/burn, voucher/claim, settlement, role-grant). These are the rows.
2. For each row, ask: **is there an adversarial test that targets THIS exact function/invariant?**
   Y / N. That's the column.
3. **The N column IS the bounded worklist.** Not "audit everything" — audit the cells the devs'
   own paranoia did not cover.
4. **Key pattern — sibling-they-did-not-test:** when a row has a Y, look for its STRUCTURAL
   SIBLING (same pattern, adjacent function, same KV-key shape, same accounting primitive applied
   to a different denom/asset/role). The tested one held; the untested sibling is the candidate.
   `tested sibling A at pattern P → B is the same P, untested → B is the lead.`

### 1.3 Worked example — injective-core v1.20.0 voucher (the only Critical of the engagement)

- `interchaintest/security/` held **4** adversarial tests: `wasm-evm-attack`,
  `wasm-auth-evm-attack`, `evm_permissions_reentrancy`, `cw-gas`. All 4 targeted
  **EVM-execution → halt / reentrancy.** Executing each: every defense **HELD**.
- The N column: **voucher accounting** (fresh v1.18+ code) had **no security test**. That is the
  untested sibling of "things that can halt the chain."
- Pattern: KV key `denom || 0x7c || addr` parsed with a fixed `addrLen=20`. Cosmos addresses are
  20 OR 32 bytes; a 32-byte (CW-contract/module) address misparses → `sdk.NewCoin(garbageDenom)`
  → `GetAllVouchers` PANICS → auction `EndBlock` has no recover → **deterministic chain halt**.
- Reading alone scored this **Medium** (fund-misallocation). EXECUTING the PoC turned it into a
  panic-not-undercount → traced to EndBlock → **Critical chain-halt.** Severity from reading is a
  hypothesis; only execution gives the real impact (this is why §5 step-5 PoC is mandatory).
- Grep for the reusable pattern (VARIABLE-LENGTH-KEY MISPARSE): `addrLen = 20`, `k[len(k)-20:]`,
  `AccAddress(key[...])` with a literal length, `sdk.NewCoin(parsedDenom` inside an iterator.

### 1.4 Door A discipline notes

- **Execute their tests, don't re-read them.** Run the suite; a defense that "looks solid" on
  read may be the one that the sibling bypasses. The point of running their tests is to confirm
  the BOUNDARY of their paranoia, then step one sibling past it.
- **Don't quit a candidate fast** (thief mindset): when a binding "looks solid," reverse-engineer,
  bypass, get creative — past the surface check. (Injective: closed the EVM↔Cosmos binding as
  "solid" on surface; the relentlessness past it found the voucher vein.)
- Every Door A candidate enters the **thief inventory** (§6) — it is not a finding until it
  chains to a theft and survives the manual loop.

---

## 2. DOOR B — DEV-PARANOIA-MAP (FALLBACK: only when Door A is empty/absent, OR as post-A complement)

**Activate Door B ONLY when there is no adversarial test suite to mine (A is absent/empty), or
AFTER Door A is exhausted as a complement.** Never instead of A when A is available. When the devs
wrote no attack tests, they still ANNOTATE their own fear — read it off a different surface.

### 2.1 The grep set + the invariant readers

- **Defensive comments** (the devs declaring a state impossible and stopping verification):
  ```
  grep -rn "CRITICAL\|should never\|must never\|defensive programming\|impossible\|\
  this should not\|INCONSISTENT STATE\|can't happen\|unreachable\|sanity" <money-path dirs>   # skip tests
  ```
  Each hit = a max-trust × min-verification point. The dev DECLARED it true and stopped checking.
- **Runtime invariant files:** `*_invariants_check.go`, property/assertion files
  (available ≤ total, OI ≥ 0, cumulative-monotone, index-consistency, snapshot-arithmetic). Each
  invariant IS the hypothesis to attack: *"can an untrusted actor reach the state this invariant
  forbids?"*
- **CHANGELOG / fix-commits:** each "fixed X" confesses X was a real bug → hunt the **adjacent
  unfixed sibling** of X (feeds §4 delta-hunt + §3 temporal-upgrade axis).

### 2.2 The discipline — a comment is a LEAD, not a finding

On a fortress the dev is usually RIGHT. Pointing at the comment and calling it a bug is the
failure mode. Per annotated point:
1. Find the **REAL gap** between the dev's stated rationale and the actual code. No gap → move on.
2. If there's a gap, the disconfirmer is almost always **ENUMERATE EVERY WRITER / CALLER of the
   guarded state** (or every reacher of the forbidden transition) and prove the invariant holds —
   or find the ONE writer/path that breaks it (that's the bug). **NEVER conclude reachable /
   unreachable "by inspection."**
3. **Classify by WHO reaches the breaking writer:** only trusted/admin/gov/uniform-internal
   writes reach it → null/OOS; an untrusted msg reaches it → live finding.

### 2.3 Severity gate (apply BEFORE investing in reachability)

Many violated invariants just **PAUSE the market / skip the op / log-and-continue** — that is
fail-safe = DoS-not-theft = often **Informational**, design-intended. Check the CONSEQUENCE of the
violation (pause vs fund-move) before spending sessions on the reachability disconfirmer.

### 2.4 Worked example — injective-core S4 triple-fault (the technique in one bug)

- `WithdrawAllAuctionBalances` carried `// CRITICAL: transfer succeeded but deposit decrement
  failed - this should never happen since we only process denoms with sufficient balance`.
- **Real reasoning-gap:** the withdraw-list is built from `TotalBalance.TruncateInt()` but
  `DecrementDeposit` fails on `AvailableBalance.LT(amount)` — **Total vs Available.** If
  `Available < Total` for that subaccount, the "impossible" fires. The comment's "sufficient
  balance" conflates Total with Available — a genuine gap in the dev's stated reasoning.
- **The disconfirmer that decided it:** enumerate EVERY writer to that subaccount's deposit across
  the whole module. Every credit was `ApplyUniformDelta` / `NewUniformDepositDelta` (available and
  total move together); zero non-uniform deltas targeted it; the keyless system-subaccount can't
  be a transfer source → `Available == Total` is an INVARIANT → the check can never fire → honest
  null. The dev was right, more precisely than they stated.
- **Fortress signature:** real-looking annotated gaps that gate to null on the all-writers
  enumeration. The enumeration is what separates the LEAD from a finding.

---

## 2C. DOOR C — UNWRITTEN-INVARIANT MAP (thief-mode, PARALLEL to A/B, no fan-out)

**Door A mines their tests, Door B mines their fear-comments — both bounded by what the devs
CONCEIVED. Door C mines what they NEVER WROTE because they believe it holds by construction.** On a
multi-audit fortress every NAMED class is already swept; the remaining bug is the *composition* of
this protocol's specific design deviations that has no CWE, no test, no comment. This is the only
door that does NOT fan-out to agents — a model that pattern-matches suppresses the *surprise* that
seeing a singularity requires. Run it by hand, in parallel to A/B, on any target whose design
deviates from the canonical form of its type (almost every high-value target).

### 2C.1 The 4-step mechanic (in order)

1. **Canonical form.** Write down what a NORMAL instance of this protocol-type looks like. The
   reference shape is the baseline you diff against.
2. **Diff → list every DEVIATION.** Each non-standard choice is a candidate. Singularity ≠ complexity
   — the complex named mechanisms are the most-lit; the dark place is the *bizarre-but-trivial-looking*
   thing every reviewer waved past. A **dead check** (a guard that proves nothing, e.g. `require(allowance
   == 0)` masked by an earlier `safeApprove(0)`) is a fossil of an abandoned fear — dig it.
3. **Make the UNWRITTEN INVARIANT explicit.** For each deviation, state the belief that makes it
   *safe in the dev's mind* — the invariant they never wrote because they believe it by construction.
   **The tell you found a real one: the dev's own comment defends ONE side of the belief and is
   silent on the other.**
4. **Attack the belief, by an UNTRUSTED actor.** Find the reachable state where the unwritten
   invariant is FALSE — usually a COMPOSITION of 2-3 deviations no review whole-viewed. Then run the
   normal conveyor (thief-inventory §6 → manual loop §5 → unbiased PoC loss=$X → kill-gate).

### 2C.2 Per-surface deviation catalogues (where the singularities live)

- **SC / DeFi:** NAV is *posted by hand* (operator `updateTotalAssets`) instead of derived from an
  on-chain read · a redeem queue *parks/freezes* a price instead of burning at request · a *bespoke*
  fee/tax instead of the standard one · a *cash-basis* accounting term where peers use accrual · a
  custom share-price formula · any "we do X differently because of our specific design" in the docs.
  The richest are where a posted/frozen/cached value is trusted by BOTH the entry-price AND the
  exit-price AND the solvency check (one stale number, three consumers).
- **Web / API:** a bespoke auth/session model (a JWT minted for one identity but only proving
  possession of another) · a hand-rolled idempotency/nonce scheme · a custom tenant-isolation key
  instead of the framework default · an in-house rate-limit · any "we built our own X" where the
  framework ships a standard.
- **Off-chain / keeper:** a backend that signs on-chain in response to an off-chain event it trusts
  without re-reading the chain · a cron/keeper that snapshots a value and acts on it later · a custom
  reconciliation between an off-chain DB and on-chain state (the desync IS the deviation).

### 2C.3 Discipline (same spirit as A/B)

- **A deviation is a LEAD, not a finding.** Most non-standard choices are deliberate and safe. Prove
  the reachable state where the *unwritten* invariant breaks; run the disconfirmer that BOUNDS it.
- **Classify by WHO reaches it.** The attacker must reach the broken state as an untrusted actor —
  for F-STALE the down-move is an EXOGENOUS, on-chain-readable strategy loss and `requestRedeem` is
  permissionless, so the attacker front-runs the *recognition*, does not *cause* it. If only the
  operator/admin can reach it → OOS unless a role boundary is exceeded.
- **Anti-inflation both ways.** The composition bug is real but usually bounded — run the kill
  disconfirmer (F-STALE: flat-capital deposit-then-queue nets ZERO → requires a pre-existing
  position → honest **Medium** informed-arbitrage, not "anyone drains").

### 2C.4 Worked example — F-STALE-NAV-REDEMPTION-ARB (the Door C win, 4 audits + a catalogue pipeline missed it)

- **Step 1 canonical:** a normal vault derives NAV continuously from an on-chain read.
- **Step 2 deviations (August Oraclized vaults, coreUSDC/upGAMMA):** (a) `externalAssets` posted by
  hand by a single operator, discrete + laggy (mean 2.7d, up to 12.1d; upGAMMA 9.5d stale live);
  (b) `requestRedeem` lag>0 *parks* shares and *freezes* the claim at request-time pps
  (`_receiverAmounts[cluster][rcv]=assetsAfterFee`), paid verbatim at `_claim` (`safeTransfer(rcv,
  claimableAssets)`, NO re-price); (c) the real strategy value (Gamma LP) moves continuously, public
  on-chain.
- **Step 3 unwritten invariant:** *"the queue's price-lock is symmetric."* Proof the devs believed it
  by construction is their OWN comment at `_registerRedeemRequest`: *"we transfer the shares to the
  liquidity pool to avoid fluctuations on the token price"* — they defended ONLY the request-instant
  pps, silent on whether the frozen amount stays faithful to real value during the lag. One side
  written, the other never.
- **Step 4 attack:** the lock is symmetric *in theory*, one-directional *in the hands of anyone who
  reads the chain*. Read on-chain that real value dropped below posted NAV → `requestRedeem` to
  freeze the stale-high exit BEFORE the operator posts the drop → loss lands on holders who didn't
  exit. Fork PoC (real upGAMMA/operator): thief +99,999 over fair, passive victim −38,604 under fair.
  Disconfirmer: flat-capital deposit-then-queue = net ZERO → needs a pre-existing position → honest
  **Medium**. The closest prior finding (F-14334, stale subaccount valuation, *Accepted*) saw the
  staleness but read it as "owner re-values as needed," never as "the lag IS an exit-arb window via
  the queue" — **the composition is the bug, and the composition has no name.**
- **Shared-root frame:** one root (discrete hand-posted single-operator NAV, no real-price bound, no
  breaker) spawned three independent findings — sandwich-the-post (A, fee-bypass), brick-the-post (B,
  `gcp(0)=0`), arbitrage-the-stale-gap (C). Report the root + each consequence; A and B are
  catalogue-mode (real but named), C is the thief-mode discovery.

---

## 3. THE 5 AXES — as ANALYZER, not generator (how to READ a candidate the doors handed you)

**Re-framed:** Door A/B hand you a BOUNDED candidate. The 5 axes are how you understand WHY that
candidate is dark and HOW to attack it. They do NOT spray candidates — that unbounded use is the
exact failure mode this skill reverses. Point all five at the ONE artifact a door gave you.

Obscure ≠ mechanism-complex. The complex named mechanisms (reentrancy / compose / oracle-math /
share-price; login flow / OWASP-top-10; signer-key handling / deploy pipeline) are the MOST-LIT —
every prior review plowed them. The dark place is the trivial-looking thing waved past. Read the
candidate under each axis (each with SC / web-API / off-chain forms):

1. **STATED ASSUMPTIONS** — the declared model, unverified *because* declared. Is the candidate's
   guarantee false/bypassable at runtime?
   - SC: "X only", "trusted", "always", "all tokens use N decimals", "will receive role".
   - Web/API: "this endpoint requires auth", "rate-limited", "input validated server-side",
     "internal only / not exposed", "tenant-isolated", "token scoped to one resource",
     "webhook signature verified".
   - Off-chain: "the keeper signs only valid events", "the relayer is trusted", "the backend never
     sends amount X".
2. **INTER-REVIEW / INTER-COMPONENT BOUNDARY** — each review covered its own scope in isolation;
   the seam where one's assumptions ≠ another's is whole-viewed by NO ONE. (This is also where a
   Door-A "tested sibling A, not B" frequently sits — B is across a review boundary.)
   - SC: manager↔NFT↔vault↔distributor handoffs; audited-contract ↔ deployed-config.
   - Web/API: frontend↔shared-API ("app OOS but the API host is in scope"); identity-provider↔
     per-property token (cross-property authz on a federated/acquired estate);
     order-service↔payment-rail↔confirmation.
   - Off-chain: on-chain contract ↔ off-chain signer/keeper/SDK (the upshift seam — backend signs
     on-chain in response to off-chain events; the read-path the SDK does with an audited value).
3. **UNQUESTIONED SURFACE** — no model traced at all. (Feeds from / into §4 delta-hunt: the
   VERIFIED scope-delta IS this axis made mechanical.)
   - SC: contest_scope − audit_scope_file_lists (files no audit opened); rank by what it GUARDS
     not by line count — a thin "wrapper" guarding an explicit invariant is the bullseye, not the
     biggest file.
   - Web/API: hosts/subdomains the pentest report never listed; the lowest-resolved-count host on
     an H1 program (a 0%-resolved payment/API host = virgin); a redeployed JS bundle (new hashes =
     new in-scope client code) vs the prior engagement's saved bundles.
   - Off-chain: the keeper/cron/webhook handler nobody put in an audit because "it's just glue".
4. **ABSENCE** — the model assumes a guard is present. You cannot grep an absence; grep the
   PRESENCE of the guard on N−1 parallel paths and find the Nth that lacks it. (This is the
   mechanical form of Door A's sibling-pattern: guard present on tested sibling, absent on the
   untested one.)
   - SC: re-quote at fill, sig-cancel, `_validateAddress`, slippage, nonReentrant on N−1 paths →
     find the bare Nth.
   - Web/API: the authz check / tenant-id filter / rate-limit / CSRF token on N−1 endpoints,
     absent on the Nth (authorization-consistency matrix). The webhook verifying the signature on
     N−1 event types, not the Nth.
   - Off-chain: the input-validation / replay-nonce / amount-bound present on N−1 message handlers,
     missing on the Nth.
5. **TEMPORAL** — the model is steady-state; reality includes edge states it never occupies.
   Enumerate and sit in each.
   - SC: deploy → init → first-deposit (ERC-4626 inflation at totalSupply==0) →
     first-reward-before-first-staker → steady → **UPGRADE** (UUPS storage-layout: audited-impl vs
     new impl — a post-audit "fix" that moved a slot collides on upgrade — the highest-value
     temporal × diff × unquestioned crossing) → migration.
   - Web/API: signup-before-verification, password-reset token lifetime, session at role-change,
     the moment between OAuth callback and account-link, first-request-after-deploy, the redeploy
     delta itself.
   - Off-chain: first-event-before-config, the retry/replay window, the gap between off-chain
     confirmation and on-chain settlement.

**Convergence note:** the filon is usually the CONVERGENCE of multiple axes on ONE artifact: the
in-scope thing prior reviews never opened (axis 3), that guards an explicit invariant/promise (the
Door B comment), full of tacit assumptions (axis 1), where a guard is absent (axis 4). When a
single candidate lights up under three or four axes at once, that's the bullseye — open it first.

**FAIL-MODE lens:** read the candidate for fail-OPEN vs fail-CLOSED on a dependency error/revert,
not only the bypass lens. A guard that fails-closed (pauses/reverts) on the error you found is a
DoS at most (§2.3 severity gate); a guard that fails-open is where the theft lives.

---

## 4. DELTA-HUNT (post-audit diff as terrain — feeds Door A axis-3 + the temporal-upgrade axis)

"Changes since the last audit fix-review are the primary focus" — treat the post-audit diff as the
HUNTING GROUND ("what changed and what did the change break?"), never as a filter ("is this corner
in the diff?"). Bugs that survive 2+ audits live overwhelmingly in code TOUCHED after:
**fix-regressions** and **post-audit features.** (The CHANGELOG / fix-commit grep in §2.1 is the
Door B entry into this same terrain.)

If you can `git diff` (source repo accessible): diff `<audit-fix-commit>..<contest-commit>` and
read every changed line. Regressions jump out.

If the source repo is PRIVATE (common on Sherlock — contest repo squashed to "Initial commit"):
reconstruct the delta functionally —
- (a) **Fix-map:** each audit finding's fix-commit names a function changed post-audit. Hunt each
  fix for a REGRESSION (the fix introduced a new bug). Strongest leads: fixes that touched
  fund-moving / share-price logic, and CLUSTERS where multiple fixes stacked on the same code.
- (b) **Verified scope delta:** `contest_scope_files − audit_scope_file_lists` (pull the actual
  file lists from the audit PDFs). This is the set no audit opened — VERIFIED, not assumed. It is
  axis-3 (unquestioned surface) made mechanical.
- (c) **Internal-audit mining:** if the repo contains an in-repo `internal audit/report.md` (or
  similar) — READ IT (it is the obscure doc by definition: in-scope, never opened). It is often
  run on a PRE-REFACTOR version, so its strong findings being DEAD on contest code is itself the
  **map of the post-audit refactor** = the regression terrain. Mine it for: findings NOT tagged
  fixed, line-ranges that don't match current code (= refactor markers), and residual comments
  referencing removed logic.

---

## 5. THE MANUAL LOOP (per candidate, once the gate greenlights and a door handed you a lead)

Operator + Claude, by hand. One place to the bottom, then move on. **A place that RESISTS gets a
quick note (the closest-to-break precondition) and you MOVE ON — the full rig is for findings you
SUBMIT, not for corners you close.**

1. **GATE #0 — trusted-reachable?** FIRST, always. On Sherlock a finding whose TRIGGER is a
   trusted role is OOS unless a role exceeds its boundary into another role's functions. This + a
   couple of atomicity facts kills ~half any inventory at near-zero cost. Run it before reading
   deeply.
2. **SCOPE-SPLIT** — which half is the INTEGRATED/TRUSTED layer's job (OOS, assumable: LayerZero
   composeQueue, Chainlink returning a bool, Aave honoring redemptions) vs the AUDITED CONTRACT's
   job (in-scope)? Decide BEFORE building a PoC. Two tells you inverted scope: (a) your PoC must
   PRANK/bypass the trusted layer's guard to make the bug appear → OOS or impossible; (b) the
   proof needs a full simnet/cross-chain rig instead of a focused single-contract test. The
   in-scope half is almost always a FOCUSED PoC.
3. **TRACE** — read every line, quote it, map who reaches it. Mindset is **attack-to-BREAK**
   (assume a vuln exists, find the trigger), not attack-to-verify. The deliverable is a payable
   Med/High, not a clean KILL.
4. **HYPOTHESIS + DISCONFIRMER** — name the invariant + the breaking mechanism, AND aim the
   disconfirmer at the LOAD-BEARING leg, not a dead adjacent one (e.g. a transient-reentrancy
   guard is per-ADDRESS → it does NOT protect SIBLING contracts; the threat is the unguarded
   sibling, not intra-contract reentry).
5. **POC** — fork/real-contract; config-parity with deployed (real rates/decimals/oracle/roles via
   cast); zero mocks on the tested leg; baseline + honest victim; attacker pays full freight; run
   the disconfirmer too; mandatory **loss=$X**. CERTIFY the dangerous path was REACHED (a
   disconfirmer can PASS via the wrong path — vacuity trap: assert the prep step actually executed,
   e.g. snapshot-paired success-vs-fail, not a flag the revert rolls back). Make EVERY term of the
   invariant LIVE. Never sweep a small delta ("1 wei, rounding") — trace it to its cause. Drive the
   REAL attack path (real `MsgCreateDenom`→…→EndBlock, not an internal `SetVoucher` setter shortcut
   — verify shortcut and real path produce the SAME state if you must scaffold). ANTI-BIAS your own
   PoC before signing: verify via `-vvvv` the action really executes (real events, real state, no
   underfunding); for code-property verdicts a local deploy of real contracts is OK, but for
   live-state verdicts (oracle-at-boundary, real balances/prices) you MUST fork. **Severity from
   reading is a hypothesis; only the executed PoC gives the real impact** (injective: Medium on
   read → Critical on execution).
   **GENUINE-PAIR-FIRST (the deployed-stand-in twin of the voucher setter-shortcut; OKX adapters 2026-06-11):**
   when the target is DEPLOYED, run the WHOLE chain ONCE on the real deployed contract + its real
   counterparty + real production params, BEFORE drafting. A two-halves PoC bridged by `deal()` + a
   stand-in reads 5/5 PASS while the end-to-end never happens in prod. OKX "unguarded callback → scoop
   stranded surplus": the *stranding* half was on a REFUND adapter (suffix omitted), the *drain* half on
   a different adapter from a `deal()`-ed balance; on the actual routed pair production sends `sqrtX96=0`
   (full-consume) → residue = 0 → the precondition never arises → theoretical → KILL. Tells you took a
   stand-in: "I picked adapter X because its selector matches the pool I fork" (a real adapter is called
   only by ITS OWN dex's pool); stranding and drain on different contracts; precondition `deal()`-ed not
   produced by a real routed call; deployed code ≠ repo-main (deployed adapter reverted `SafeTransferFailed`
   where repo-main drained). Liveness + genuine-precondition are reachability gates — FIRST, never deferred
   to "the team can balanceOf-sweep" (that deferral is impact-outsourcing a triager downgrades for).
6. **KILL-GATE Q1-Q10 + dup-check vs all prior findings + platform-validity + CHAIN-TRIAGE** (§6 —
   score pairs, not isolation; every hop executed + attacker net-positive or it's
   LLM-garbage-in-reverse). Check the platform severity doc + OOS list here (a demonstrated impact
   moves a finding from OOS-DoS to Critical; lead with the demonstrated leg).
7. **FULL-CORNER closure** — a PoC exercises ONE slice; the signed verdict must cover the WHOLE
   place or you re-dig in 3 months. Close: parallel/sibling paths that generalize, every other
   reachable sibling shown inert, and the MOCK-residual (a mock proves the mocked contract harmless
   only if you verified it is truly off-path — verify reads AND hooks like burn/_update).
8. **SIGNED VERDICT** — LIVE / DOWNGRADE / KILL to `findings/F-<place>.md`. If KILL, document why
   (never re-dig).

**Effort calibration:** a place dead by ATOMICITY (single external frame, no inner try/catch) or by
TRUSTED-role gets a SHORT PoC confirming the fact (10 lines), not the full rig. Reinvest the saved
sessions into untrusted-reachable places — or into the next target.

**Fail-fast DIRECTS effort, it does not RETAIN it:** a gated branch (a disconfirmer that kills one
hypothesis on a surface) REDIRECTS the day to the SIBLING branch of the SAME surface — it never
condemns the surface. The corrosive tell is "skip / fortress / not-worth-the-day / move-on" about a
SURFACE before executing its branches; the pro version is "branch X gated by [executed read],
redirecting to branch Y of the same surface."

---

## 6. THE THIEF INVENTORY + CHAIN-TRIAGE (the admission gate — this is the validator)

The doors LOCALIZE (they find the untested/dark place); the thief inventory VALIDATES (does the
place give me something I can steal with?). This is what answers "the 5-axes volet localized but
never validated" — the inventory is the validator, fused with chain-triage.

### 6.1 Admission gate (run on EVERY candidate from Door A or Door B)

Every candidate enters an inventory of primitives `Pn` (keep a `CHAIN-TRIAGE-<target>.md`).
**ADMISSION GATE:** *"Does this untested/dark place give me a primitive I can STORE toward a
concrete THEFT path?"*
- Chains to fund-movement (directly OR via a chain in §6.2) → admit it, spend a PoC.
- Chains to NO fund-movement even via chain-triage → **note it, spend ZERO PoC.** A dark place
  that moves no money is documented, not investigated. (This is the money-flow prefilter at Phase
  0, not at submission.)

### 6.2 Hunt PAIRS — primitives chain, CVSS scores them alone

CVSS scores a vuln in isolation; adversaries chain. A 5.0 + a 6.0 chained correctly = Critical —
$500 → $5K. At SEVERITY-COMMIT, AFTER the kill-gate, as an AMPLIFIER (never a resurrector of a
KILLed finding):
- **Inventory:** every weak / OOS / Acknowledged / Low / refuted-alone item from the doors is a
  primitive `Pn`. The ones that died alone are the chain fuel.
- **Hunt pairs:** does `Pa` supply the trigger / reachability / window / amplification `Pb`
  lacked? SC/DeFi critical-pairs: oracle-blindness + liquidation path · bad-debt-socialization +
  supplier-exit/dust-lingering · share-math edge (div-0 / totalSupply==0) + withdraw · dedup/replay
  + signed financial action · a fix that closed ONE path while a SIBLING path reaches the same
  impact un-mitigated.
- **The prize is usually a shared ROOT, not a magic Critical:** many weak primitives feeding ONE
  root = one coherent higher-severity thesis, far more defensible than any alone. Report
  `STANDALONE: x / CHAINED: y` + the explicit CHAIN PATH + the chained loss=$X (show both scores).
- **Scope governs every hop:** an OOS hop (oracle-issue, DAO-action) participates only if a later
  in-scope, untrusted-reachable hop carries the impact.

### 6.3 ANTI-INFLATION (mandatory — symmetric to the executed-disconfirmer)

A chain is real ONLY if EVERY hop is executed/proven AND the attacker nets positive.
`severity = min(evidence, chain_completeness, impact)` — a chain is only as strong as its weakest
PROVEN link. **NO ARROW SURVIVES WITHOUT CODE THAT WALKS IT** — every pivot is an EXECUTED A→B
test (one PoC that runs A, then B, observes the composed state-delta / loss line). A CHAIN PATH
drawn as arrows with no tx/test traversing it = hypothesis, not finding. Dismantle your own chain
before believing it: does a hop secretly need a crash / DAO / exogenous trigger? Does creating `Pa`
cost the attacker more than chaining to `Pb` yields? An over-inflated chain is LLM-garbage in the
opposite direction of a shallow dismissal — equally banned.

### 6.4 Worked example — Zest v2 (proof it works + proof anti-inflation matters)

Chain-triage reframed 4 weak/OOS isolated items (bank-run Medium, interest-insolvency slow,
dust-no-min-borrow griefing, self-liq Resolved) into ONE thesis: *"bad-debt socialization is
exploitable supplier-side, and the audit's same-block fix closes only the borrower-self-liq door,
not the supplier-exit (bank-run) nor the dust-lingering amplifier."* BUT the anti-inflation
self-dismantle killed the tempting "CHAIN-A = free money": dust can't open underwater (is-healthy),
creating bad debt still burns the attacker's OWN collateral → it's a TIMING-AID, honest verdict
Medium/High, NOT Critical. The discipline keeps the chain honest in both directions.

---

## 7. EXIT — and the DROP-ON-EV ≠ DROP-ON-FATIGUE gate (run before any NO-GO)

**A NO-GO is legal only after every IDENTIFIED lead is EXECUTED — not after enough KILLs
accumulate.** After a run of clean KILLs the mind builds a slope toward "this won't pay," and that
slope arrives exactly when, on a fortress, the real filon is finally in view. Before writing NO-GO:
grep your own notes/ledger for leads marked "WATCH / conditional / probably / didn't pull /
low-surface / skip / OOS-assumed" — EACH must have an executed disconfirmer or it is NOT yet a
NO-GO. The tell you're drop-on-fatigue masquerading as drop-on-EV: you're about to NO-GO and
there's a named lead in your own notes (an N-cell in the Door A matrix, an un-enumerated Door B
invariant) with no executed artifact against it.

(dre-labs/dreUSD Sherlock #1259: was about to NO-GO on "5 dry sessions" while the
wrapper-fail-mode + prior-audit scope-delta lead — ~1 session — had never been pulled. Pulled, it
came up dry [wrapper fail-closed not fail-open; the custodianVault forwarder a pure pass-through]
— but the verdict was only EARNED once executed; could not be known without pulling it.) This is the
downstream twin of NO-SHALLOW: NO-SHALLOW stops dismissing a surface un-executed mid-hunt; this
stops dismissing the WHOLE TARGET un-executed at the exit.

When the gate's two doors + delta-hunt come up dry with executed artifacts (not "by inspection")
AND the drop-on-fatigue gate above passes, the target is a fortress: **bank any defensible finding
at honest severity (or NO-GO if only Low-probable remains — submitting Low on a fortress burns
triager credibility for ~$0), document the NO-GO with the executed artifact per door/axis, and
REDEPLOY.** Do not fabricate depth. Triager credibility and the contest queue are the scarce
resources, not tokens.

---

Related: [[feedback_test_dont_read_dev_attack_tests_method]] (Door A — mine their attack TESTS),
[[feedback_dev_paranoia_map_comments_invariants]] (Door B — mine their defensive COMMENTS +
invariants), [[feedback_gravedigger_manual_darkcorner_method]] (the manual loop + every method-trap
caught), [[feedback_chain_triage_score_pairs_not_isolation]] (the thief inventory / pair-hunt /
anti-inflation), [[feedback_fortress_target_selection_ev_gate]] (the upstream gate),
[[feedback_no_shallow_dismissal_go_to_bottom]], [[feedback_unbiased_fork_poc]],
[[feedback_fail_fast_directs_effort_not_retains]], [[firm-grade-operating-standard]].