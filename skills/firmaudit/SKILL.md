---
name: firmaudit
description: Firm-grade deep security audit in immortal mode — no time limit, no token limit, audit-firm quality, zero LLM garbage. Runs Phase 0 Target Intelligence (scripted via phase0-intel.sh) → Phase S Seam Thesis (name the boundary nobody owns: audited-code↔deployed-config / contract↔Safe-topology / on-chain↔off-chain-operator / spec↔impl / lang-A↔lang-B binding — the region where vulns accumulate because no review covers the handoff; biases triage) → Phase T top-down Triage (threat-model → path graph → reachability → recevability scope/dup/edge-fit/loss=$X → T6d FORTRESS GATE → GO/NO-GO; kills unwinnable targets day-1) → Phase A Audit-Conditions Extraction (read audit PDFs as a map of accepted conditions, fuse threshold, on-chain⇒cast_call) → Phase R Active-Recon Execution (RUN every probe, never note) → adaptive plan executed as the 4-PASS fan-out (Pass 1 primary on seam paths → Pass 2 expansion authority-chain/secrets/shadow-surface → Pass 3 mirror-invariant V_in-vs-V_out [the Critical-forming pass] → Pass 4 chain construction) with dig→adversarial-verify→operator-hand-verify per pass. The single skill for any new high-value target/contest (Cantina/C4/Sherlock/HackerOne/HackenProof/direct). Use when the user wants a deep professional engagement and does NOT want a fast pass — and ALSO whenever the question is "is this target worth my time / where do I start / which surface first". Reads exploit-primitive-mindset + gravedigger + mrrobbot + upshift/upshift2 as REFERENCE; does NOT auto-orchestrate them. Trigger on "/firmaudit", "firm-grade audit", "audit digne des grandes firms", "mode immortel", "vaut le coup / par où commencer / quelle surface", or when the user pastes the FIRM-AUDIT-PROMPT.
---

# /firmaudit — Firm-Grade Deep Audit, Immortal Mode

You are running an audit at the standard of a top-tier audit firm (Trail of Bits / Spearbit / Cantina lead level). The deliverable is firm-grade. **Not LLM garbage.** The operator (#1 Transak leaderboard) deploys this consciously when a target deserves depth — not for a fast pass.

This skill is the encoded form of `~/Desktop/BUGS/FIRM-AUDIT-PROMPT.md`. Both are equivalent; the raw text exists for manual-paste mode.

---

## Operating mode (non-negotiable, read first every invocation)

- **IMMORTAL MODE.** No time limit. No token limit. Deep on every detail. The only legal stop conditions are the measured ones (§7). "I think the code is solid" is NOT a stop condition — it's a measurement to earn with forge-lint green + internal-consistency 100% + mirror-coverage exhaustive, all logged. A null vector on a right-profile target = "I didn't dig deep enough," logged to `_negative-results.md`, never "the protocol is solid."
- **Rule 40 holds throughout.** Never filter a surface by "too hard / slow / expensive / cycle too long / filter too high." Highest-floor surfaces (ZK, MPC, compiler, cross-chain crypto) have the thinnest competition *because* of that filter. Encode every surface with a cadence, never a skip.
- **NO auto-orchestration.** Explicit operator instruction. You may READ `exploit-primitive-mindset`, `gravedigger`, `mrrobbot`, `upshift` companion files as **reference methodology**. You must NOT auto-invoke them as skills, NOT spawn their disclosure flows, NOT let one skill's "auto-orchestrates X" line fire X. You orchestrate by hand (see §Fan-out harness); the operator stays in the loop between phases.

> **The floor is inherited, not restated.** The CLAUDE.md `OPERATING STANDARD` (the conveyor; KILL-GATE Q1-Q10; PoC = observed state delta, fork-based, zero mocks; D7 Chain-Proof / D8 Weight-Card / D9 Adversarial-Rebuttal; mirror invariant Rule 41; PREFLIGHT 22/24; money-flow `loss=$X`-or-KILL prefilter; anti-LLM-garbage discipline; no-self-concede) is **always loaded and always governs what survives to submission.** This skill governs the *shape, depth, and orchestration* of the engagement — it does not re-state the floor. When in doubt on what makes a finding submittable, read the floor, not this file.

---

## 🛑 NO-SHALLOW-DISMISSAL — the deepest rule, gating (read every invocation)

**This is the operator's livelihood. Bug bounty is the job that pays the bills. On a target audited by 4 top firms, the bug is NEVER in the low-hanging fruit — it is precisely in what gets waved away "because it's probably fine." Dismissing a surface WITHOUT EXECUTION is how you guarantee you never find anything. The difference between us and everyone else is that we go to the BOTTOM of every surface; everyone else stops at the easy layer. Forget the low-hanging fruit — it was picked by the 4 audits already. Our money is at the bottom.**

When ultracode is on and the operator has paid for max tokens, the WHOLE POINT is that you do NOT move past anything fast. Token cost is not a constraint — a missed vuln is. There is no "this is probably OK, skip." There is only "I executed a disconfirmer and HERE is the observed result."

**The four banned dismissal moves (each one has cost a real finding):**
1. **"OOS because oracle/DAO/admin"** — STOP. Re-read the scope literally. Oracle *manipulation* is usually in-scope even when "oracle issues" are OOS — and manipulation can be *intra-protocol* (callcode/staleness/cache priming/decimals), not "move Pyth." A DAO-set parameter consumed by an *untrusted-actor* path (borrower-forged mask, keeper-controlled input) is NOT admin-rug. Classify by WHO reaches the bug, not by who configured the value.
2. **"REFUTED by reasoning"** — a refutation you did not EXECUTE is a hypothesis, not a refutation. Every "this is fine" on a money-path must be a passing simnet/fork PoC or a live `cast`/read-only call with the observed numbers pasted in. "I reasoned it's conservative" → write the test that tries to break it. (Reserve / Circle: ~9 agent "Criticals" overturned by hand AND ~real bugs only surfaced by executing the disconfirmer.)
3. **"Acknowledged in audit, so dead"** — Acknowledged means the bug is STILL LIVE in deployed code. Re-derive whether the *accepted condition* still holds at current on-chain state/TVL, and whether a DIFFERENT impact (not the one the auditor priced) is now reachable. Dup-as-class re-opens on new IMPACT, not new mechanism.
4. **"Agents over-report, so I'll trust my read and skip their flag"** — agents over-report 10:1 AND occasionally surface the one real seam. You hand-verify EVERY agent flag by execution before discarding — discarding by reading is the same shallow move.

**The mechanical gate (a NO-GO / null is illegal until this passes):**
- Every surface in the path graph (Phase T) has either (a) a passing PoC proving the attacker extracts nothing, or (b) a live on-chain read showing the precondition is absent, or (c) a written line naming the *executed* disconfirmer and its observed output. "Looks solid" / "probably fine" / "conservative rounding" without an executed artifact = NOT swept.
- Before writing any NO-GO or `_negative-results.md`: list every surface you dismissed and, for each, the EXECUTED artifact that justifies the dismissal. If any row says "by inspection" / "by reasoning" / "likely" — that row is NOT done. Go back and execute it.
- The bottom-of-the-surface pass is mandatory: for each money-mover, do NOT stop at "the happy path rounds correctly." Push the extreme inputs (0, 1, max-u128, dust, decimals mismatch, expo extremes, empty-set, single-element, cache-cold, same-block, cross-asset). The bug lives at the boundary, not the center.

**When you catch yourself about to write "OOS" / "REFUTED" / "probably" / "likely fine" / "solid" / "skip" on a surface you have not executed against — that is the signal to dig, not to conclude.** This rule overrides any instinct to "close cleanly." A clean close on an un-executed surface is the failure mode this entire skill exists to prevent.

**Audits have blind spots INSIDE their own scope — mine them (this is the core of the rule, not an addendum).** The post-audit delta is the obvious gap; the deeper, less-competed gap is the code the auditors *covered shallowly*:
- **Every "Acknowledged" finding is a still-live bug + a one-angle dismissal.** The author stamped ONE label (black-swan / low / design / informational) and stopped. Re-derive: does the SAME mechanism produce a DIFFERENT, payable impact at a different TVL, via a different actor, or down a different path the label never considered? (Zest M-07: auditor saw "vault bricks = DoS"; the un-asked angle is "does a positioned supplier EXTRACT value in the window before the brick / via a bank-run on the lagging lindex?" — DoS-angle ≠ extraction-angle.)
- **Fix-on-X, blind-on-adjacent-Y.** A finding resolved on function X means that area was under pressure; the sibling function Y with the same pattern is often unreviewed (Rule: C4-pipeline adjacency).
- **One-lens mechanisms.** Socialization was audited for rounding (M-13), front-running (H-07), brick (M-07) — re-run it under lenses none of them used.
For every Acknowledged/Low/Informational in Phase A's extracted set, the re-derivation (new impact? new actor? new TVL? un-considered angle?) is MANDATORY, and each surviving angle gets an EXECUTED PoC. The auditor's label is a hypothesis to attack, never your conclusion.

## 🌑 DARKSIDE — where the surfaces that pay actually are (MANDATORY, every engagement)

Twin of NO-SHALLOW: NO-SHALLOW says *go to the bottom of every surface*; DARKSIDE says *here is WHERE the surfaces that pay are buried* — a lens applied on every target, not a target route.

**The germe (this volet's whole reason to exist):** mine the devs' OWN tests/invariants for the SIBLING they forgot to cover, and store every dark place as a primitive in a THIEF INVENTORY chained toward a concrete theft — never a contemplative "where did attention flee" spray (the abstraction found 5 nulls on injective; the germe found the only Critical).

**Priority rule (A>B mine the EXPRESSED, C mines the UNWRITTEN):** Door A — DEFENSIVE-COVERAGE MATRIX (`{money-path fn/invariant} × {covered by an adversarial test? Y/N}`; the N column is the bounded worklist; the sibling they tested at A but not at B is the candidate) is PRIMARY and mandatory whenever an adversarial test suite exists. Door B — DEV-PARANOIA-MAP (grep `CRITICAL|should never|must never|impossible|INCONSISTENT STATE` + read `*_invariants_check.go` + CHANGELOG adjacents) is FALLBACK only — when A is empty/absent, or as a post-A complement, NEVER instead of A. **Door C — UNWRITTEN-INVARIANT MAP runs in PARALLEL to A/B and is MANDATORY on any multi-audit fortress** (where A/B in catalogue-mode return only named-class noise): diff the target against the canonical form of its type → list every design DEVIATION (hand-posted NAV vs derived, park-not-burn queue vs burn-at-request, bespoke fee, dead check) → make explicit the invariant the devs never wrote because they believe it by construction (tell: their comment defends ONE side of the belief, silent on the other) → attack that belief by an untrusted actor (usually a composition of 2-3 deviations no review whole-viewed). This is the THIEF-mode entry that finds the no-CWE bug a catalogue-mode pass structurally cannot (the F-STALE-NAV stale-redemption-arb win: 4 audits + a full catalogue-mode agent pipeline missed it). It does NOT fan-out — run it by hand.

The full procedure — the three door catalogues (A defensive-coverage matrix, B dev-paranoia map, C unwritten-invariant map), the THIEF-INVENTORY admission gate (chains-to-fund-movement-or-note-and-spend-no-PoC, fused with chain-triage pair-hunting + anti-inflation), the 5 axes demoted to per-candidate ANALYZER, the manual loop (GATE#0 trusted-reachable → SCOPE-SPLIT → TRACE-to-BREAK → HYPOTHESIS+DISCONFIRMER on the load-bearing leg → unbiased PoC loss=$X → KILL-GATE → FULL-CORNER → SIGNED VERDICT) and the exit gate (drop-on-EV ≠ drop-on-fatigue) — now lives in the standalone **darkside** skill. Invoke it at Pass-1 on any audited target. Reference: `~/.claude/skills/darkside/`.

Depth is EARNED not spent; N KILLs + 0 findings = STOP. FAIL-FAST DIRECTS effort, never RETAINS it — a gated branch redirects to the sibling branch of the SAME surface, never condemns the surface.

## 🧪 UNBIASED PoC — the self-contained fork/simnet PoC must not be biased
A PoC that passes because the HARNESS made it pass (not the protocol) is worse than no PoC: it manufactures false confidence either way — a biased PASS becomes a false-positive submission (credibility burned), a biased setup that suppresses the bug becomes a false-negative (vuln missed). Before trusting ANY PoC result (yours or an agent's), audit the setup for bias:
- **Config parity with the DEPLOYED chain (general rule).** Any protocol with init-time parameters may have those params at ZERO/default in a clean fork or fresh test harness, NOT at production values — so the behavior under test (interest accrual, fees, liquidation thresholds, caps) silently can't fire. Pull the params the claim depends on from on-chain (`cast call`/read) and ASSERT the harness matches BEFORE concluding anything — especially before declaring a null. **A null on a mis-configured harness is not a null.** (Concrete: Zest "interest-insolvency" read REFUTED only because the harness left rate-points at ZERO — the prod rate-proposal hadn't run; with real rates the index accrues. Also: my $308K-$926K bank-run figures were on the TEST egroups (85/95) not mainnet (70/75) — wrong by config.)
- **Config parity IMPOSSIBLE (edge case).** When the deployed state can't be replicated exactly (months of accumulated state, non-replayable past events, oracle history): do NOT silently approximate. Explicitly LIST the deltas between harness and mainnet, and for each delta state whether it could change the conclusion. If a delta is conclusion-relevant and un-replicable, the result is "indicative, pending on-chain confirmation," not proof — and you say so in the report.
- **No mocks on the leg under test.** Real deployed contracts on the path you're proving; mocks only for off-path scaffolding, declared explicitly.
- **Baseline + honest victim in the same PoC.** Always run the no-attack baseline and diff — "bad state" counts only if WORSE than inaction; an extraction must show real funds leaving a real party.
- **Attacker pays full freight.** Put the attacker's own cost / locked capital / lost collateral in the PoC ledger; never headline a gross number that ignores it (this session: nearly logged "+$160k" that was really ~$80k net once the attacker's own dodged-LP-share was the right frame). Re-derive what the number MEANS, net.
- **Drive price/time through the REAL mechanism.** Need a price move or accrual? push a real Pyth update / mine real blocks so `block-time`/index actually advance — never poke a storage var the protocol wouldn't let you set.
- **Verify selectors/addresses/slots/fork-block** against on-chain reality; re-read state at the submit-block, not just the anchor.
- **PRESENT-LOSS GATE — a seductive thesis must produce `loss=$X` on the CURRENT on-chain snapshot, and a cheap LIVE probe usually kills it before any PoC.** The symmetric twin of NO-SHALLOW (which stops you scoring too LOW): this stops you scoring too HIGH. A read-path / missing-check / design-mismatch finding earns Med+ ONLY with an observed extraction on the state that exists NOW — future/conditional state (a feed *might* go stale, a position *might* exist, volatility *might* widen) = Low/Info design-finding, never a headline. Before building the PoC for an attractive thesis, run the cheapest live disconfirmer that could refute it: read the actual on-chain values the thesis depends on (`cast`/LCD), sample a feed twice seconds apart, check the at-risk market's open-interest/positions. (Injective-core v1.20.0 S1: the "22 RWA stock-perps trade 24/7 vs a NYSE-hours oracle → frozen-mark bad-debt" thesis LOOKED like a Critical; killed in ~30s by sampling the Provider feed twice 22s apart with NYSE closed — prices MOVED → relayer is 24/7, no frozen window — and the one genuinely-frozen feed had 0 open positions = `$0` at risk = dormant = SKIP.) The self-tell: the word "PROVEN/Critical" in your own summary on a not-yet-extracted thesis = distrust it and re-run the present-loss gate. Vault/market `$0` = dormant = SKIP regardless of how clean the mechanism is.
- **Run the disconfirmer too**, not only the confirmer — a PoC that only confirms your hypothesis, never attacks it, is half-done. Concrete form per probe type: **Foundry/simnet** → add the `require`/guard you claim is missing, the exploit test must now revert; **`cast call`/read** → read the bug-relevant value in the BENIGN state too, confirm it differs from the exploit state (not constant); **`curl`/web** → send the request WITH and WITHOUT the claimed-missing auth token/header, the protected one must behave differently.
- **WEB/API AUTH (BFLA/IDOR/broken-access) PoC — the asymmetry is proof ONLY with three anti-bias controls IN the PoC (Solv SOLVPR-297, 2026-06-08).** An "X reachable, Y refused with the same credential" claim is biased-into-passing unless the 401/403 on Y is a *targeted authorization* refusal, not an artifact. Bake all three into the script: (1) **credential-valid-globally control** — the same token must return 200 on a benign endpoint (e.g. `stats`, a public read); then `stats 200` + `Y 401` + `X 200` with ONE token proves the refusal is per-resolver, not a dead/invalid token (this is the rung a skeptic dismisses if it's missing). (2) **field-exists control** — the refused operation EXISTS in the schema and takes the SAME args as the reachable one (introspection), so the refusal isn't a malformed-query / `FieldUndefined`. (3) **error-class control** — the refusal is the auth layer's error (`UnauthorizedException` / 401 from the authorizer), NOT a `WrongType` / validation 400. Without (1)–(3) the asymmetry isn't yet evidence. Smell test (web form): "did the protocol refuse this, or my setup?" = token proven valid + field proven real + error proven auth-class.
- **The cited PoC/test must EXIST and have RUN — hand-verify EVIDENCE, not just CONCLUSIONS.** Agents (and you, under pressure) fabricate executed-proof: a dig once cited a 256-run fuzz test as the basis of its kill that DID NOT EXIST in the repo (grep = 0). A finding OR a kill "proven" by a phantom test is fabricated evidence. So before trusting ANY verdict that rests on a PoC/number/line: grep that the cited test file+function actually exists, re-run it yourself to see the number reproduce, and confirm every cited `file:line` points at the claimed code. Applies SYMMETRICALLY — a REAL leaning on a phantom PoC is un-submittable; a KILL/NULL leaning on a phantom test is un-verified (re-derive on real code).
- **GENUINE-PAIR-FIRST — on deployed targets, run the exploit on the REAL deployed contract + its REAL counterparty + the REAL production params, BEFORE drafting. A two-halves PoC bridged by `deal()` + a stand-in manufactures a precondition prod never produces (OKX DEX adapters, 2026-06-11).** This is the plant-shortcut from the voucher case, in its most seductive form: each half of the chain passes on a convenient harness, so the suite reads 5/5 PASS while the end-to-end never happens in prod. The OKX adapter finding (unguarded callback → scoop stranded surplus) reached a chill-styled Medium report with an inline PoC — then died on the genuine pair: (1) the *stranding* half (partial-fill leaves surplus) was proven on UniV3Adapter (a REFUND adapter, with the refund suffix deliberately OMITTED), while the *drain* half was proven on FireFlyV3Adapter from a `deal()`-ed balance — two different adapters, neither carrying the full chain. (2) Run on the actual routed pair (deployed adapter `0x6747BcaF` + its real Pancake-V3 pool, params copied from a real tx): production routes with `sqrtX96=0` (no price limit → full consume) → residue = **0**, the surplus the whole finding depends on NEVER occurs. (3) The deployed adapter's callback even reverts `SafeTransferFailed` where repo-main's ungated transfer would have drained — **deployed code ≠ repo-main**. The tells you took a stand-in: "I used adapter X because its selector matches the pool I'm forking" (a genuine adapter is only ever called by ITS OWN dex's pool — borrowing another adapter's selector = you are NOT on the real path); the stranding and the drain live on different contracts; the precondition is `deal()`-ed not produced by a real routed call. The fix is mechanical: **before any draft, execute the full chain ONCE on (real deployed contract, its real counterparty, real production params/routing) and read the observed state — if the precondition (residue / stale feed / open position) does not arise under REAL params, it is theoretical → KILL (program scope excludes "theoretical exploits without a practical reproducible PoC").** Liveness + genuine-precondition are reachability gates: run them FIRST, not as a footnote deferred to "the team can do a balanceOf sweep" (that deferral IS the impact-confirmation-outsourcing triagers downgrade for).
Smell test before any PoC counts as evidence: **"did the protocol let this happen, or did my setup?"** If the parity checks above don't answer that, the result is not yet evidence — for a PASS or a null.
**This section is gating but its WORK lives in Phase R / post-Pass-1 — apply these checks to every PoC you generate there.** It is stated here (with the operating principles) so it's read before any phase; the execution point is Phase R.

## 🔗 CHAIN-TRIAGE — score the pairs, not the isolation (runs at SEVERITY-COMMIT, after kill-gate)
NO-SHALLOW-DISMISSAL stops you scoring too LOW by closing a surface early; CHAIN-TRIAGE stops you scoring too low by judging a finding ALONE. They are twins. Adversaries chain; a 5.0 + a 6.0 chained is a Critical. Before committing severity on ANY finding:
- **Inventory the primitives.** Every weak/OOS/Acknowledged/Low/refuted-alone item is a primitive Pn (keep them in a `CHAIN-TRIAGE-<target>.md`). The ones that died alone are exactly the chain fuel.
- **Hunt the pairs:** does Pa supply the *trigger / reachability / window / amplification* that Pb lacked? Critical-pair heuristics: oracle-blindness + liquidation path · bad-debt-socialization + supplier-exit/dust-lingering · share-math edge (div-0/totalSupply==0) + withdraw · dedup/replay + signed financial action · a fix that closed ONE path while a SIBLING path reaches the same impact un-mitigated (Zest: same-block self-liq fix doesn't cover the supplier-side multi-block bank-run).
- **The prize is usually a shared ROOT**, not a magic Critical: many weak primitives feeding one root = a single coherent higher-severity thesis. Frame the report on the root + the un-mitigated sibling path. Report `STANDALONE: x / CHAINED: y` + explicit CHAIN PATH + the chained loss=$X.
- **ANTI-INFLATION (the discipline that keeps it honest, symmetric to executed-disconfirmer):** a chain is real only if EVERY hop is executed/proven AND the attacker nets positive. Dismantle your own chain first: does a hop secretly need a crash/DAO/exogenous trigger? does creating Pa cost more than chaining to Pb yields? (Zest CHAIN-A self-check: dust can't open underwater via is-healthy, creating bad debt still burns the attacker's collateral → timing-aid, NOT free money → honest Medium/High, not Critical.) An over-inflated chain is LLM-garbage in the opposite direction of a shallow dismissal — equally banned.
- **Scope governs every hop.** An OOS hop (oracle-issue, DAO-action) only participates if a later in-scope, untrusted-reachable hop carries the impact; otherwise the chain breaks there.
- Web/AI/N-day chain packs (MCP-no-auth, vector-DB exfil, viem/ethers N-day ABI-parse, bundle-JS secrets) are for WEB/API targets — route in for HackerOne/HackenProof web, skip for contract-only/Clarity programs.

---

## PHASE 0 — Target Intelligence (NOW, before ANY plan)

**Run the script first, then fill the human points.** The mechanical points (1-5, 8) are scripted:

```bash
~/arsenal/audit-lifecycle/bin/phase0-intel.sh <repo-path> [owner/repo] [audit-base-commit] > PHASE0-INTEL.md
```

It auto-fills: (1) repo recon — languages/LOC/sub-packages/deps, (2) audit reports in repo, (3) post-audit commit delta (pass the audit-base commit), (4) AI-bot check, (5) GHSA/issue history, (8) cross-chain surface, plus grepped CANDIDATES for (6) crypto primitives. Then **the operator + you fill the judgment points by reading code**:

6. **Crypto primitives** — confirm the grepped candidates: which curves (secp256k1 / ed25519 / BLS12-381 / BN254 / Ristretto), schemes (ECDSA / EdDSA / Schnorr BIP-340 / FROST), HD derivations (BIP-32/39/44, SLIP-0010), multisig/MPC (2-of-3, threshold, TSS). Strip the node_modules/test-dep noise the grep surfaces.
7. **Implicit threat model** — pure non-custodial? client-side key derivation? RPC interaction? operator/keeper EOA that signs on-chain in response to off-chain events (the upshift seam)? Who can move funds, under what trust assumption. (A finding whose only actor is the trusted owner/governance = OOS owner-rug — decide this here, not at Week 8.)
9. **Money-flow prefilter (the OKX F-007 gate, at Phase 0):** for EVERY fund-mover, can a candidate produce a `loss=$X` PoC line? A surface that can never produce loss=$X (signature-hygiene / state-misrepresentation) is deprioritized NOW, not after weeks of drafting.

**Verify mechanical output by hand** where it matters: point 3's `git tag --contains` is insufficient — read the DEPLOYED source directly (fixes backport under different SHAs, Rule 4). Point 2's audit count is PER-IN-SCOPE-COMPONENT, not protocol-total (exploit-primitive-mindset Step 0) — the script lists reports; you count coverage.

**Phase 0 output:** `PHASE0-INTEL.md` (8+1 points all answered or explicit n/a) + a target-profile classification that decides the plan path.

> **Phase 0 is the highest-value part of this skill.** On the Reserve engagement, point 2 (audits ON SCOPE vs protocol-total) + point 3 (post-audit delta) produced the decisive reframe — "scope is v4.2.0, not the heavily-audited v3.4.0 → 289 un-reviewed .sol files" — which re-ranked the entire EV plan and stopped a dead-code hunt. Point 8 surfaced the live Solana port (the freshest surface). Do not shortcut Phase 0.

---

## PHASE S — Seam Thesis (NOW, after Phase 0, BEFORE Phase T — names where the bug HAS to be)

> **Why this exists (the August blind-hunt lesson, 2026-06-02).** A genuinely-blind un-directed hunt on the August LendingPool (2-audit core) produced ~30 candidates and the adversarial layer killed ~all of them as textbook noise — because it was VECTOR-FIRST ("look for reentrancy / rounding / oracle"). Vector-first hunting structurally finds only what the kit was tuned for, which is exactly what the auditors also targeted — so on an audited surface it returns refuted noise. The 8 findings that DID land on August (A20/A34 Safe-topology, A25 lagDuration, A33 NAV) were not vector hits — they lived in a SEAM the audits structurally could not see: **audited-contract-code ↔ deployed-config / Safe-topology / off-chain-operator**. The seam thesis (from upshift2) is the fix: name the boundary nobody owns FIRST, then point depth at it. Without it, the fan-out wanders; with it, it aims.

**The definition.** A seam exists wherever two distinct review regimes meet such that: (1) each side has its own audit/review discipline, (2) each discipline's scope STOPS at the boundary, (3) the boundary — the translation / trust-handoff / data crossing — is owned by NEITHER review. The bug is almost never inside either regime (those are audited). It is in the **handoff**: the assumption one side makes about the other that the other does not actually guarantee.

**The seam catalogue (start here; this is where firmaudit's own wins came from):**
| Seam | Unowned assumption | Where it breaks (firmaudit precedent) |
|---|---|---|
| Audited code ↔ deployed config | "the config honors what the audit assumed" | `lagDuration()=0` vs audit-mandated >24h (A25). **= Phase A is this seam, mechanized.** |
| Contract code ↔ on-chain governance/Safe topology | "the audit reviewed the signer set" | one 2-key pair signs N Safes / a 1-of-1 on an uncatalogued vault (A20/A34) |
| On-chain ↔ off-chain operator/keeper | "the backend only signs validated events" | the upshift seam — backend signs on-chain in response to an off-chain trigger nobody re-checks |
| Spec MUST ↔ implementation | "the impl follows the RFC/EIP" | a MUST silently downgraded (SIWE 1-of-8 fields; EIP edge skipped) |
| Language-A ↔ language-B binding | "all bindings behave identically" | one binding mishandles zero/identity/malformed-length (cross-lang line-ref class) |
| Serialize ↔ deserialize | "round-trip is validated" | deserializer accepts inputs the serializer never makes (malleability, canonicalization) |
| Audited sample ↔ full deployed set | "the 16 audited vaults represent the 59" | per-vault config drift on the 43 un-sampled (A37) |
| Cross-chain peer A ↔ peer B | "the remote peer is the trusted one" | source-domain / peer-trust / DVN config gap (SC-P-03/04) |
| Audited on-chain protocol ↔ off-chain liquidation/keeper engine (READ-path) | "the bot/SDK that reads our audited oracle handles the price correctly downstream" | the oracle WRITE-path (signature/replay/staleness) is over-audited; nobody finishes the READ-path — what the keeper/liquidation SDK DOES with the price (slippage unit-conversion, swap-routing, profitability gating, per-collateral handler math). Morpho liquidation-sdk: 3 sibling bugs in one file — paraswap hex-slippage corruption (#446), pendle hardcoded-4% ignoring computed slippage (#486), spectra Curve swap with 0.0000001% cosmetic min-out ignoring market slippage (SPECTRA-1). Mirror-asymmetry across token handlers is the tell: each exotic-collateral handler re-implements the price→min-out translation and they DIFFER. Generalizes to every lending protocol's off-chain liquidation bot/SDK/keeper (dYdX/Aave/Compound/Euler/Spark). **Tactical playbook: `LIQUIDATION-READPATH-PLAYBOOK.md`** (7 proven bug classes + grep + the hard bot-side severity cap). |

**The procedure (30-60 min, before Phase T):**
1. **Map the disciplines** — for each component, who reviewed it and where did that scope STOP? Read each audit's scope section: the seam is just past that line. Separate repos / vendors / languages / "platform vs product team" = discipline boundaries. Write `recon/DISCIPLINES-MAP.md`.
2. **Enumerate boundaries** — for each adjacent component pair, name the trust-handoff. Use the catalogue as the prompt list. Don't filter yet. Write `recon/SEAM-CANDIDATES.md`.
3. **Score unowned-ness** — per candidate: is side A audited? side B? does EITHER audit's scope cover the HANDOFF? If a bug lived exactly in the handoff, which review would have caught it? Answer "none" = high-value seam.
4. **Write the seam statement** (`recon/SEAM-STATEMENT.md`, load-bearing — it becomes the report's internal-consistency argument):
   ```
   The seam on <target> is between <discipline A> and <discipline B>.
   <A> is reviewed by <process, scope stops at X>. <B> by <process, scope stops at Y>.
   The handoff — <the specific crossing> — is owned by neither.
   A bug here would look like <hypothesis>. Phase T scores paths through THIS seam first.
   ```

**Output → feeds Phase T:** the seam statement BIASES T1-T7 — the highest-value seam's paths get scored first, and the fan-out's Pass 1 dig is pointed AT the seam, not at a fresh undirected scan. **`Phase A` (audit-conditions) is formally the first seam in the catalogue** (audited-code ↔ deployed-config), already mechanized — Phase S generalizes it to the other seven.

> **A SEAM IS A HYPOTHESIS, NOT A FINDING — it rides the SAME harness as a Pass-1-4 candidate (the Aurora re-run lesson, 2026-06-02).** Phase S enumeration OVER-REPORTS exactly like the dig agents (~10:1). On the Aurora 0.7.1 re-run, a bare seam-map produced 3 "untrusted-reachable" seams; operator hand-verify killed ALL three — 2 were config-trusted-OOS (the discount-`%` and token-handoff seams are real handoffs but the `Controller` sets the config/token, so an untrusted actor cannot reach them), and 1 was a status-disjoint false race (re-making the already-killed C2 claim/withdraw-cannot-co-exist error). **Therefore: every seam from Phase S MUST pass `dig → adversarial-verify → operator-hand-verify` before it counts** — never trust the enumeration's own `reachable_untrusted` flag. Hand-verify the **`untrusted-reachable` leg FIRST** (it is the leg the enumeration gets wrong most): is the handoff genuinely reachable/influenceable by an UNTRUSTED actor, or is the crossing parameter set by a trusted role (config / token / admin) = centralization-OOS? A seam whose only actor is the trusted side is OOS, not an un-swept seam. Run Phase S seams through the fan-out harness (one adversarial skeptic per seam, default REFUTED, must cite the access-control that makes it trusted-or-untrusted), then operator hand-read — identical to the §Fan-out three-stage pattern. The degenerate-verdict guard applies.

**The "no-seam" verdict (measured, not felt):** a boundary only counts as an un-swept seam if it survives the hand-verify above — i.e. it has "none" review coverage AND is genuinely untrusted-reachable. If EVERY boundary in `SEAM-CANDIDATES.md` either has a named review process OR is reachable only by a trusted role (config/token/admin-set = centralization-OOS), it's a genuine fortress — route to T6d NO-GO. A seam that the enumeration flagged "untrusted" but hand-verify downgraded to trusted-OOS does NOT block the NO-GO (else Phase S's over-report would falsely keep a hardened target alive — the Aurora case: 3 flagged, 0 survived, NO-GO correctly held). Only a HAND-VERIFIED un-swept seam (none-review + truly-untrusted-reachable) defeats a no-seam verdict. (This is the §7 Guard-4 measurement applied at the seam level.)

---

## PHASE T — Top-Down Triage & Go/No-Go (BEFORE the deep plan, the ROI gate)

> **The #1 ROI of this skill is NOT finding more chains — it's not burning weeks on unwinnable targets.** Findings rarely die of a technical defect; they die of scope-exclusion (admin-trust, cross-chain-arb), dup, or absent reachability. Phase T filters those deaths BEFORE deep code reading. You do not read 35 contracts to discover at the end that no path is receivable. Model first, filter, THEN engage depth only on what survives.
>
> Phase 0 answered "is this the right code, what's fresh?". Phase T answers "is this target WINNABLE, and which exact paths are receivable?". Run it top-down. Output is a written triage card + a GO / NO-GO / WATCH verdict.

### T1 — Assets & terminal value (the scoring numerator)
Sort the surface by what gets stolen or broken, and how much — not by trendy endpoint. DeFi hierarchy, high→low: direct fund theft (vault/pool drain) · protocol insolvency (bad debt) · price/oracle integrity (financially exploitable) · fund DoS (locked funds, broken withdrawals) · governance capture · information (low in SC; higher in web2 if PII). Per asset note **max loss** ($ or criticality), anchored on real exposed TVL / role value — no invented number.

### T2 — Trust boundaries & entry points
Where untrusted input crosses trusted execution. List ALL: external/public fns · privileged-but-actually-reachable fns (read the REAL access control, not assumed) · cross-chain message handlers (`lzReceive`, CCIP receive, `onMessage`) · oracle reads (Chainlink/TWAP/Uniswap spot) · callback/hook surfaces (`afterSwap`/`beforeSwap`, ERC777/721 hooks, flashloan callbacks) · `initialize`/upgrade/proxy-admin · fee/share/NAV math (`totalSupply==0`, division, rounding) · signature verification (`permit`, EIP-712, SIWE, threshold). (Web2/API target → enumerate per `~/arsenal/methodology/H1-HUNTING-PATTERNS.md`, then apply this wrapper on top.)

### T3 — Actors & capabilities
Per actor note: AUTHORIZED capability | what crossing a boundary would grant. Actors: anon/external caller · token holder/LP · keeper/relayer/bot · admin/owner/governance · cross-chain peer (remote contract assumed trusted) · MEV searcher · third-party composing protocol. **A "trusted" actor is a boundary, not a guarantee** — but see the departure criterion in T6a before scoring it.

### T4 — Path graph (the system-derived form of chaining)
Model the system as a graph: **nodes** = states/capabilities ("anon attacker", "holds role X", "funds in vault", "price corrupted"); **edges** = functions/messages that move between nodes. A candidate finding = a PATH from an attacker-reachable node to an asset node (T1). Source the candidate edges from the SC pattern DB: **`~/arsenal/methodology/SC-PATH-PATTERNS.md`** (SC-P-01..16 — the real, encoded edges; e.g. SC-P-03 bridge-peer-trust, SC-P-10 library-vs-custom drift, SC-P-15 incomplete-fix sibling) + `H1-HUNTING-PATTERNS.md` (M-H1-* for web2/API). Write each path as `P-NN: [entry] →(SC-P-xx edge)→ [pivot] →→ [asset]`. The NEGATIVE patterns (SC-P-12 disjoint-sets, SC-P-13 saturating/checked-math, SC-P-16 non-prod/dormant) are KILL-FIRST — apply them to drop dead paths before investing.

### T5 — Reachability gate (KILL-GATE Q2, run by hand)
For EVERY edge of EVERY candidate path, answer explicitly: (1) is this edge callable by the assumed actor given the REAL access control (read in code, not assumed)? (2) is the edge's precondition state reachable by a sequence of authorized calls? Verdict per path: **`reachable`** (every edge confirmed callable + preconditions reachable) · **`conditional(state X)`** (only if an unconfirmed state exists — verify passively, cast call / read-only) · **`unreachable`** (≥1 edge blocked by access control or impossible precondition). `unreachable` → DROP immediately, stop scoring. `conditional` → cannot be P0 until the state is confirmed on-chain.

> **STATE-reachability, not just EDGE-reachability — the panic/state-machine trap (dYdX F-T233 #407, REJECTED "theoretical").** For a panic / chain-halt / invariant-break / corrupted-state finding, the function being callable is NOT enough: the TRIGGER STATE itself must be arrivable from a valid chain state through user-driven txs. On an L1/L2/state-machine the **state-transition validator IS the reachability gate** — F-T233 proved a byte-identical chain-halt panic, sibling-asymmetry, and class-incident precedent, but the trigger state `(zero positions, NC<0)` was rejected by `IsValidStateTransitionForUndercollateralizedSubaccount` on EVERY organic path; it was only producible by genesis-injection. Result: **operator filed MEDIUM → triager bumped it to CRITICAL himself → over 2 reachability rounds the operator withdrew the organic-arrival leg back to the original Medium → Rejected as theoretical, $0 (fee refunded).** **So for any state-corruption/panic candidate, at T5 you must find and READ the state-transition invariant guarding the trigger state and confirm a valid→trigger path exists BEFORE investing in the PoC — not after two triager rounds.** Genesis-seed / `keeper.SetX`-past-genesis prove the MECHANISM, never the REACHABILITY. If the transition guard rejects every arrival path → the finding is Informational/hardening max, frame it as "latent landmine if X ever becomes reachable," never Medium+. NOTE the severity dynamic: the over-severity was the TRIAGER's (Medium→Critical), NOT the operator's — the technical package (mechanism + sibling-asymmetry + class precedent) was compelling enough to get bumped; it still died, purely on state-unreachability. So a triager-raised tier is NOT validation that the finding survives — reachability is the gate regardless of who set the number. Match your own claim to the empirically-arrivable impact, not the worst-case. (Full lesson: `feedback_f_t233_rejected_organic_reachability_2026_05_26`.)

### T6 — Recevability gate (front-loaded — the spine; runs BEFORE deep audit)
Three filters: scope-exclusion, dup, edge-fit.

**T6a — Scope exclusion.**
HARD exclusions — if this is the ONLY impact path → **immediate NO-GO:**
- Centralization / admin-trust: a privileged role that "misbehaves." (killed Centrifuge #283 — pool managers fully trusted)
- Cross-chain arbitrage / MEV as the sole impact.
- Precondition = already-compromised key or already-malicious admin.
- Component/contract outside the program's explicit scope.
- **"Theoretical" / no `loss=$X`:** no concrete exploit path, OR the path can never produce a `loss = $X` line in a PoC (signature-hygiene / state-misrepresentation without direct $ flow). This is the OKX F-007 / Polymarket money-flow filter, applied at Phase T not Week 8. **A surface that cannot produce `loss=$X` dies here.**
- Already known: acknowledged in a prior audit, listed in known-issues, or self-reported.
- User error / phishing / frontend-only.
SOFT exclusions — likely downgrade, not necessarily no-go: governance/timelock can fix before impact · griefing/gas without fund loss (program-dependent) · improbable-but-possible external precondition.

> **The T3 ↔ T6a departure criterion (resolves the trusted-actor tension — DO NOT skip):**
> - If crossing the boundary requires **compromising a role the program's threat model DECLARES trusted** (owner, governance, fully-trusted pool manager) → **DROP** (hard admin-trust exclusion). Reserve F-SOL-001 (owner-gated migration missing a check) and Centrifuge #283 both die here.
> - If the boundary is crossed by **untrusted input that is actually reachable** (a cross-chain peer message an attacker can forge/influence, a keeper param the attacker controls, an external-protocol callback) → **DIG** (real path, the SC-P-03 bridge-peer-trust class).
> The verdict is decided by *who must act to cross the boundary*, read from the program's stated trust model — not by the word "trusted."

**T6b — Dup risk.** HIGH (deprioritize): crowded public contest (many wardens, C4-public) · recently audited by a good firm (textbook gone) · "obvious" finding (classic reentrancy on popular protocol) · public PoC / DefiHackLabs incident. LOW (= your edge): Rust/Solidity cross-language inconsistency (few read Rust) · crypto correctness (FROST/CLSAG/Schnorr/decimals/key-overlap) · cross-chain config / peer-trust / DVN · post-audit periphery / config drift / secrets hygiene.

**T6c — Edge-fit (play your comparative advantage).** HIGH: Rust+Solidity cross-program drift (SC-P-10) · cryptographic protocols · cross-chain/bridge-peer/config · deep multi-step SC chains · post-audit periphery (config, secrets, on-chain state). LOW (commoditized, high competition): generic web2 XSS/CSRF (Symbiotic web killed — thin SPA over read-only API) · "trendy AI surface" with no measurable unique angle.

**T6d — FORTRESS GATE (target-level saturation — the hard NO-GO that fixes the real failure mode). MANDATORY, runs BEFORE T7 scoring.**

> **Why this gate exists (2026-06-01, the 5-fortress lesson).** The skill's rigor is sound — it kills false positives correctly. But across 5 consecutive engagements (Superform, Makina, Reserve, Hermetica, Morpho) it returned 0 findings, and every kill was *OOS* / *already-fixed* / *agent-hallucination* — **never "a real bug killed by excess strictness."** The diagnosis: the failure was NOT analysis depth, it was **TARGET SELECTION.** All 5 were freshly-audited SC cores where perfect depth finds 0 because the deep bugs were already extracted by top firms 3 months earlier. Meanwhile EVERY documented win (Polymarket $10K Web2-on-SC, Request Finance $1K API-auth, XRPL crypto-primitive, Snowbridge cross-chain, Circle Ed25519) came from a surface SC-auditors don't touch. The operator's fear — "the skill is too strict / doesn't go deep where vulns hide" — is half-right: it goes deep, but in the WRONG ZONE (incomplete-fix on audited code = second-arriver strategy). Deep vulns hide in the CLASS the audit never thought to look for, and on the SURFACE the audit never covered. This gate forces the target choice toward the unsaturated.

**The two hard conditions (evaluate at target level, with the Phase 0 audit-count-PER-COMPONENT, not protocol-total):**

1. **Saturation test.** Count audits ON THE IN-SCOPE COMPONENT (not the protocol) dated <6 months. If **≥3 top-firm audits <6 months AND the in-scope code is a strict subset of what those audits covered** (no fresh post-audit delta >~500 LOC of untrusted-reachable code) → the SC-core surface is CLOSED.

2. **Non-saturated-surface test.** Is there an *accessible, in-scope* surface that the SC audits structurally do NOT cover? — Web2/API layer on an SC program (the Polymarket pattern), off-chain orchestration / keeper / relayer that signs on-chain (the upshift seam), a crypto primitive (FROST/Schnorr/ed25519/BLS/ZK-soundness/decimals), a cross-chain peer-trust / config / DVN seam, a fresh un-audited module/chain port.

> **"Audited core CLOSED" never closes these three (the August lesson, 2026-06-01 blind-run — missed 3 Criticals by treating a 4-audited core as closed):** a multi-audited core is closed for *code bugs*, NOT for —
> 1. **Deployed-config-vs-audit-acceptance-conditions.** Audits ACCEPT findings CONDITIONAL on a config ("CS-AUGCORE-001 accepted provided `lagDuration > 24h`"). The deployed config may violate the condition (`lagDuration() = 0` on $14.8M live). That is a Critical found by ONE `cast call`, living inside the "audited core." MANDATORY: this is exactly what **Phase A (Audit-Conditions Extraction)** produces — its `analysis/AUDIT-CONDITIONS.md` table gives you, per accepted/conditional finding, the `onchain_variable` + `threshold` + runnable `probe`. Run those probes (in Phase R) and check each holds at live TVL before any NO-GO. Do NOT decide "core closed" until the AUDIT-CONDITIONS table is built and its on-chain probes are green.
> 2. **On-chain governance / Safe / multisig topology.** Audits review contract code, rarely the *deployed* signer-set overlap (one key pair signing 13/15 Safes = $36.5M two-key reach; a 1-of-1 Safe on an uncatalogued vault). MANDATORY: enumerate every Safe/owner/threshold on-chain.
> 3. **Per-vault config drift across the FULL deployed set.** Audits cover a SAMPLE (~16 of 59 vaults). The other 43 may have weak DVN posture, missing timelocks, mis-set fees. MANDATORY: enumerate all deployed vaults and diff their config against the audited sample.
> These are read-only on-chain checks, NOT code review — run them even when T6d says the code core is CLOSED.

**Verdict:**
- Saturation test = CLOSED **AND** no non-saturated surface accessible → **STILL run the three mandatory on-chain checks above before any NO-GO.** Only if those ALSO come back clean: **target-level NO-GO.** State it plainly: "in-scope SC core is saturated, no Web2/off-chain/crypto-primitive/cross-chain seam, AND deployed-config/Safe-topology/per-vault-drift all verified on-chain clean — perfect depth here finds 0." This is NOT difficulty-filtering (Rule 40): the surface is fully encoded; it is empirically already-mined.
- Saturation CLOSED **but** a non-saturated surface IS accessible → **GO, but the plan MUST target that surface, not the audited core.** The unsaturated surface is found by the DARKSIDE lens (§🌑, mandatory — the standalone **darkside** skill, `~/.claude/skills/darkside/`): Door A defensive-coverage matrix (the untested sibling), Door B dev-paranoia fallback, the verified-unaudited in-scope set, and the post-audit delta. Route the depth to the matching tactical cadence (Web2-on-SC → `WEB2-ON-SC-PROGRAMS-PLAYBOOK.md`; off-chain → Path B upshift; crypto-lib → `CRYPTO-LIB-HUNT-PLAYBOOK.md`; infra-adjacent → `INFRA-ADJACENT-TO-SC-PLAYBOOK.md`; lending off-chain liquidation-SDK/keeper → `LIQUIDATION-READPATH-PLAYBOOK.md`; otherwise the DARKSIDE per-place manual loop). The deep plan hunts the un-reviewed zone; it does NOT spend the slot on incomplete-fix of the audited/reviewed core.
- Saturation OPEN (fresh code, <3 audits, or a real post-audit delta) → proceed to T7 normally — but the DARKSIDE lens still runs to point Pass-1 at the obscure max-trust places, not just the lit mechanisms.

> **The incomplete-fix trap (named, so it's not re-walked).** "Verify the fix of H-01 is root-cause / hunt adjacent functions the 52 findings missed" is a VALID strategy ($135K/9mo precedent) but it is the *second-arriver* play and it is LOW-yield on code a good firm just hardened (Hermetica: 52 CA findings, all High/Med Resolved root-cause, 0 residual). Reserve it for when the post-audit delta is genuinely large OR the audit firm is weak. Do NOT default to it as the headline plan on a freshly-firm-audited core — that is exactly the 5-fortress failure. The headline plan should attack a CLASS or a SURFACE the audit did not.

### T7 — Triage scoring & verdict (ORDINAL — orders your time, NOT the report severity)
Report severity = concrete terminal impact, lives in the report, never a sum of categories, never an invented float. Triage scoring just orders your time. Per surviving path note Low/Med/High for VALUE (T1) · REACHABILITY (T5) · EDGE-FIT (T6c), plus penalties (residual soft-exclusion, DUP). Decision (ordinal):
- **P0 — deep commit:** VALUE High + `reachable` + EDGE-FIT High + DUP Low.
- **P1 — worth a PoC:** VALUE ≥ Med + `reachable` + (EDGE-FIT High OR DUP Low).
- **P2 / watch:** `conditional(state X)` unconfirmed, or mid value with mid dup.
- **DROP:** HARD exclusion on the only path, OR `unreachable`, OR (VALUE Low + DUP High).

**Phase T output — write `TRIAGE-CARD.md`:**
```
TARGET: [name] | PLATFORM: [Cantina/C4/...] | SCOPE: [in-scope contracts/endpoints]
ASSETS (by terminal value):  A1: [asset] — max loss [$/crit] ; A2: ...
ENTRY POINTS / TRUST BOUNDARIES: [list]
ACTORS: [actor]: authorized=[...] | crossing grants=[...]
CANDIDATE PATHS:
  P-01: [entry] →(SC-P-xx)→ [pivot] →→ [asset A1]
        reachability: reachable | conditional(state X) | unreachable
        scope-exclusion: [none | soft: ... | HARD: ...]    loss=$X: [yes $N | NO → drop]
        dup: Low|Med|High ([why])    edge-fit: Low|Med|High
        → TIER: P0|P1|P2|DROP  ([1-line rationale])
  P-02: ...
GLOBAL DECISION: [GO deep on P-0x | NO-GO target (reason) | WATCH until state X confirmed]
TIME ALLOCATED: [honest estimate]
```

**Verdict gate:** if GLOBAL DECISION = NO-GO → STOP. Report the card to the operator, do not enter the Adaptive Plan. A short submission window NEVER short-circuits recevability — an unwinnable target with a deadline is still unwinnable. Only GO / WATCH-then-GO proceeds to the deep plan, and the plan is scoped to the P0/P1 paths only.

> **The T6d Fortress Gate is part of this verdict, not advisory.** Before writing GLOBAL DECISION, state the T6d result explicitly in the card: `FORTRESS GATE: [OPEN | CLOSED-but-surface(X) | CLOSED-NO-GO]`. If CLOSED-NO-GO, the GLOBAL DECISION is NO-GO regardless of how interesting the SC core looks — do not rationalize a thin edge (e.g. "Clarity = thin competition", "Rust = few readers") into a GO when the in-scope core is saturated and no unsaturated surface is in-scope. The honest GO on a CLOSED-but-surface target names the surface and routes the plan there; it does NOT default to incomplete-fix of the audited core. This gate is the encoded fix for the operator's question "is it too strict / not deep enough?" — the answer was neither: it was pointed at saturated cores. T6d redirects the depth to where vulns actually hide.

---

## Adaptive Plan (scales to the Phase 0 profile — and scoped to the Phase T P0/P1 paths)

After Phase 0, ENTER PLAN MODE (EnterPlanMode) and propose the plan that matches the profile. The firm-grade floor applies to EVERY path; only the *shape* differs. **Phases are dependency-ordered, NOT calendar weeks** — "per-chain primitives pass" is a phase; "Week 3-4" is decoration. Depth, not a clock, gates a phase (§7).

### Path A — crypto / cross-chain target → per-chain primitives plan
Default deep path. Use when Phase 0 surfaces real crypto primitives, multiple chains, HD-wallet/multisig/MPC, or non-custodial key handling.
- **P1 Architecture + threat model + scope freeze.**
- **P2 Per-chain crypto primitives** — BIP-32/39/44, EIP-191/712, SLIP-0010, BIP-340 Schnorr, ed25519 malleability, multisig. One pass per chain (each chain = different primitive + different serialization/tx path).
- **P3 Cross-chain logic + serialization + tx construction + RPC layer.**
- **P4 Adversarial review + differential fuzzing + property tests.**
- **P5 Firm-grade report assembly + disclosure coordination.**

### Path B — off-chain orchestration DeFi → upshift cadence (read as reference, do not auto-invoke)
Backend signs on-chain in response to off-chain events; executor/operator wallet; contracts audited by a firm but API/infra treated as a normal web project. Read `~/.claude/skills/upshift/HUNT-METHODOLOGY.md` + `SURFACE-ATTACK-PATTERNS.md` + `IMMORTAL-MODE.md` as methodology. Use the 4-pass discipline (primary → expansion → mirror invariant → chain construction), immortal-mode depth.

### Path C — web / API target → gravedigger cadence
Read `~/.claude/skills/gravedigger/SKILL.md` + `WEB-API-CHECKLIST.md` + relevant playbook (JWT/OAuth/persistence). 9-phase recon→audit spine. Authenticated session testing mandatory (Rule 29). Authorization consistency matrix (Rule 30).

### Path D — smart contract >$50K, hardened → mrrobbot cadence
Read `~/.claude/skills/mrrobbot/SKILL.md`. 4-phase adaptive; phases expand/contract on signal, not a fixed checklist.

**Mixed-profile targets:** run the UNION (Rule 40). A non-custodial cross-chain wallet with a keeper backend = Path A (crypto) + Path B (orchestration seam). Don't pick one and drop the other.

---

## Phase A — AUDIT-CONDITIONS EXTRACTION (MANDATORY when in-scope audits exist; runs BEFORE Phase R and feeds it)

> **The August blind-run failure, root layer (2026-06-01): I COUNTED the audits instead of READING them.** With the ChainSecurity + Hacken PDFs sitting in the workspace, the blind run treated "4 audits" as a *saturation thermometer* (→ Fortress Gate → avoid the core) and never opened them as a *map of conditions*. Three of the original's Criticals (A25/A33/A27) were empirical violations of those audits' OWN acceptance conditions at live config — pre-chewed findings the audits hand you. A25 = ChainSecurity accepted "Blacklisted Address Can Redeem" (High) **conditional on `lagDuration` being large enough**; the deployed flagships run `lagDuration()=0` on $14.8M. The audit *gives you the finding* — it says "this risk exists, neutralized ONLY IF this config holds." Counting "4 audits = closed" throws that map on the floor.

**An audit report is not a saturation signal — it is a list of risks the protocol KNOWS about and accepted under stated conditions. Each accepted/conditional/downgraded finding is a finding-in-waiting that only needs a live read.** For EVERY in-scope audit report (PDF/MD), produce `analysis/AUDIT-CONDITIONS.md` — a table with one row per finding the audit ACCEPTED / RISK-ACCEPTED / ACKNOWLEDGED / DOWNGRADED / mitigated CONDITIONALLY (skip findings simply Resolved by a code change with no config dependency):

| col | content |
|---|---|
| finding_id / title / severity / disposition | the audit's own id + how it dispositioned it |
| **condition_verbatim** | the EXACT quoted sentence stating the condition ("safe PROVIDED X" / "risk accepted because Y" / "must configure Z"). Verbatim, not paraphrase — it is load-bearing. |
| **threshold** | the quantified bound (see Fusion Pass) |
| **onchain_variable** | the contract getter that materializes it (`lagDuration()`, `timeLockDuration()`, `managementFee()`…) or `UNKNOWN` if genuinely off-chain |
| **target** | which contract/vault (name or address) |
| **probe** | a CONCRETE check (see Hardening Rule), runnable in Phase R |

Two rules are MANDATORY — they are the difference between regenerating A25 as an executable `cast call` vs. as a vague "investigate" (proven on the ChainSecurity blind re-test, 2026-06-02: v1 without them emitted `threshold:"sufficiently large", probe_kind:investigation` and would have MISSED the $14.8M Critical; v2 with them emitted `threshold:">24h", probe:"cast call lagDuration()(uint256) && FLAG if < 86400", probe_kind:cast_call`):

1. **FUSION PASS.** The acceptance text is usually QUALITATIVE ("configure X large enough"). The QUANTIFIED bound for the SAME parameter lives ELSEWHERE in the report — a Note, an Assumption section (2.x), the System Overview (8.x). For every condition, search the WHOLE document for any passage quantifying that parameter and FUSE: `threshold` MUST carry the hardest numeric bound found anywhere (ChainSecurity: acceptance §5.1 "large enough" + Note §8.4 "must be bigger than 24h" → threshold = `>24h` = 86400s). A discovered numeric bound that stays only in prose notes is a HARD ERROR — it must surface in the structured `threshold`.
2. **ON-CHAIN ⇒ CAST_CALL, NEVER INVESTIGATION.** If `onchain_variable ≠ UNKNOWN`, `probe` MUST be a runnable `cast call <addr> "<getter>()(<type>)" --rpc-url <rpc>` PLUS the explicit flag rule ("FLAG if result < 86400"). Even a qualitative threshold becomes a cast_call — worst case you read the value and `lagDuration()=0` is itself the finding. `investigation` is legitimate ONLY when the variable is genuinely off-chain/operational ("operator validates inputs"). A known on-chain variable left as `investigation` is a HARD ERROR (recreates the note≠execution failure).

**Orchestration (the fan-out harness, applied to PDFs):** one Explore agent per audit report → extract its table applying both rules → **operator hand-verifies EVERY `condition_verbatim` + `threshold` against the PDF before it enters the table** (the condition is load-bearing exactly like `feedback_cross_language_line_refs_load_bearing`: a misread "24h"→"12h" sends a real `cast call` and a real Co-CEO disclosure against the wrong bound). The verified rows become Phase R's mandatory probe list. This same pass IS the C4-audit-pipeline (incomplete-fix / downgraded-findings / risk-acceptance-violation) wired in as an executed phase, not a note.

> **Phase A feeds T6d and Phase R both.** Run it right after Phase 0, BEFORE the Fortress Gate verdict (its output changes whether "audited core" is really closed — see T6d amendment), and its `probe` column is the seed of Phase R's on-chain checks. Audit-conditions are mined whatever the saturation verdict — a conditionally-accepted finding violated at live config is a finding even on a 9-audit fortress.

**Phase A COMPLETION CRITERION (when the table is "done" — measurable, not "feels covered"):** Phase A is complete when, for EVERY in-scope audit report, EVERY non-Resolved finding (accepted / risk-accepted / acknowledged / downgraded / conditionally-mitigated) has a row, AND every row with `onchain_variable ≠ UNKNOWN` has `probe_kind: cast_call` (zero rows left as `investigation` on a known on-chain var — that's the HARD ERROR above). The mechanical check: `grep -c` the rows vs the audit's own findings-summary count of non-Resolved items; any gap is an unread finding. A "Resolved" finding still gets a row IF its fix has a config dependency (incomplete-fix angle). Until both conditions hold, Phase A is NOT done and you may not move to the Fortress Gate verdict.

**Edge cases (don't let them silently truncate Phase A):**
- **PDF unavailable / paywalled / Google-Drive-gated:** record the audit in `AUDIT-CONDITIONS.md` with `disposition: UNREAD-SOURCE` and a one-line note (which firm, date, why unreachable). It becomes a known coverage gap surfaced in the closeout / `_negative-results.md` ("audit X unread — could hold a class the others missed"), NEVER a silent omission. Try the firm's GitHub-pages mirror / web.archive.org / the protocol repo's `audits/` dir first.
- **Audit that doesn't number its findings** (some Certora/Hacken/formal-verification reports): assign your own stable ids (`<firm>-<n>` in document order) and row every distinct risk statement; the lack of the firm's id is not a reason to skip — extract by risk-statement, not by id.
- **No in-scope audits at all:** Phase A is N/A — say so explicitly in one line and proceed to Phase R; do not fabricate conditions.

---

## Phase R — ACTIVE RECON EXECUTION (MANDATORY, before any "thin" / "NEEDS_SOURCE" / "clean" verdict)

> **The August blind-run failure (2026-06-01): a noted probe is not a run probe.** On a re-run of August Digital I IDENTIFIED the exact Goldsky subgraph URLs and the upUSDC vault address, wrote *"ACTION: verify"* in my notes — and never ran the curl / cast-call. The original engagement found 17 findings (3 Critical) on those exact surfaces; the blind run found 0. Two of the missed findings (a Critical `lagDuration()=0`-violates-audit-condition, a Medium unauth Goldsky PII leak) were each **one command** I had already written down. The dig agents produced CODE ANALYSIS; the ACTIVE RECON I deferred to a keep-list and never executed. **An audit that lists recon actions instead of executing them is not an audit.**

**The rule: every probe you can name, you RUN — in-loop, logged with its output — BEFORE you may write "thin", "NEEDS_SOURCE", "read-only", or "clean" on that surface.** A surface verdict is INVALID if the deciding probe wasn't actually executed. Concretely, for the relevant target profile, EXECUTE and LOG the raw output of:
- **Web/API:** `curl` EVERY documented + guessable endpoint (not just read the OpenAPI). Test auth (nonce reuse, bearer-of-signature, IDOR) with a real session, not by inspecting the schema. Fetch + grep the DEPLOYED front/V2 JS bundles for secrets (webhooks, RPC keys, tokens) — not just the obvious infra repo.
- **On-chain:** `cast call` the config of EVERY in-scope vault/contract (lagDuration, fees, limits, oracle, DVN posture, pause state). Enumerate EVERY Safe/multisig (owners, threshold, signer-overlap). For EVERY accepted/conditional audit finding, read its condition variable on-chain and check it holds at live TVL. Enumerate the FULL deployed vault set and diff config vs the audited sample.
- **Off-chain/infra:** query EVERY "private"/unlisted endpoint found (subgraphs, internal APIs) ANONYMOUSLY to prove auth state. Don't note "verify if queryable" — query it.
- **Cross-chain:** read DVN/peer config on-chain (it's readable — "NEEDS_SOURCE" is WRONG for LZ/CCIP config; the source is the deployed config, not a private repo).

Log each probe's command + raw output to `analysis/RECON-PROBES.md`. The fan-out dig (below) operates on the RESULTS of executed probes, not on un-run hypotheticals. **"NEEDS_SOURCE" is only legitimate when the artifact genuinely cannot be read on-chain or via a public endpoint — never as a substitute for running the read you could have run.**

**Probe ORDER when the surface is large (multi-vault / multi-chain / web+SC+off-chain) — run highest-discrimination-per-second first:**
1. **Phase-A audit-condition `cast call`s FIRST.** Each one is a pre-chewed finding the audit handed you (A25-class) and costs one command — highest yield/sec. Read every accepted/conditional finding's condition variable at live config before anything else.
2. **Safe/multisig topology + authority-root reads** (owners/threshold/signer-overlap) — these decide the trusted-vs-untrusted classification that gates everything downstream, and expose the A20/A34 naming-deception class cheaply.
3. **Config diff across the full deployed set** (vault N vs audited sample) — surfaces the per-config-peer asymmetries (A25 lagDuration: one vault 259200, its sibling 0) that become the mirror-invariant Criticals later (this read is the raw material the 4-PASS Pass 3 turns into findings).
4. **Anonymous queries of "private"/unlisted endpoints** (subgraphs/internal APIs) — one curl proves auth state, often a standalone Medium.
5. **Bundle-JS / image-layer secret grep** — forensic, slower, do after the cheap on-chain reads.
6. **Web endpoint auth matrix** (per-verb, per-network) — the broadest but slowest; last when time-boxed.
If you have only 2h, items 1-3 are non-negotiable (they decide GO/NO-GO and the headline mirror Critical); 4-6 are the expansion. Never skip 1 to start on 6.

**Apply the 🧪 UNBIASED PoC checks (above) to every PoC you build from these probe results** — config-parity, no-mocks-on-tested-leg, baseline+honest-victim, attacker-pays-full-freight, real-mechanism, run-the-disconfirmer. A Phase-R PoC that passes on a mis-configured harness is a false null/positive, not evidence.

## Fan-out harness (HOW you orchestrate by hand — the core execution pattern)

"Orchestrate by hand" does NOT mean "scan files serially." It means YOU author a `Workflow` per phase — fan out over the phase's surfaces, adversarially verify each candidate, then **operator hand-verifies every REAL before it survives.** This is the pattern that did the real work on every firm-grade engagement; reuse it, don't re-improvise it.

**The three-stage pattern (per audit phase):**
```
DIG  (one agent per surface/cluster, parallel)
  → ADVERSARIAL-VERIFY  (one skeptic per candidate, default REFUTED, dedup vs prior audits)
  → OPERATOR HAND-VERIFY  (you, by hand, re-derive every surviving REAL from the code)
```
The third stage is non-negotiable: **agents over-report ~10:1 on hardened code.** On the Reserve engagement, 6 agent "Critical/High" verdicts were overturned by hand (revert-atomicity, registration-vs-runtime, gross-up formula, remainder-mod-c, owner-gated migration). An agent CANNOT self-declare a finding ready — D9 is the floor, your manual read is the layer above it.

**Workflow skeleton** (pipeline = dig and verify pipelined per cluster, no barrier; agentType:'Explore' for read-only digs):
```js
const FIND = { /* schema: {cluster, summary, candidates:[{title,location,mechanism,impact,severity_guess,dismissal_risk,poc_sketch}], kills:[{angle,why_dead}]} */ }
const VERD = { /* schema: {title, verdict:REAL|REFUTED|NEEDS_POC|DOWNGRADE, reasoning, design_intent_coherent, dup_risk} */ }

// ── DEGENERATE-VERDICT GUARD (mandatory) ─────────────────────────────────────
// A schema-valid verdict can still be a STUB: an agent that returns verdict:"REFUTED"
// with reasoning:"Test" (or any non-substantive body) passes the schema but verified
// NOTHING. On the Graph Horizon run, the single most dangerous candidate (escrow-key
// "$3M drain") came back REFUTED with reasoning="Test" — a stub that would have buried a
// (here false, but it could be real) Critical. NEVER trust a refutation you can't read.
const STUB_RE = /^\s*(test|n\/?a|none|ok|done|pass(ed)?|refuted|valid|checked|verified)\.?\s*$/i;
const isDegenerate = (v) =>
  !v || !v.reasoning ||
  v.reasoning.trim().length < 120 ||           // too short to contain a real refutation
  STUB_RE.test(v.reasoning) ||                  // canned filler
  !/[:\.]\d|line|L\d|\.sol|\.rs|\.go|require|modifier|seeds|msg\.sender|function|0x[0-9a-f]/i.test(v.reasoning); // cites no concrete code artifact
// A REFUTED/NEEDS_POC verdict is only trusted if it is NOT degenerate. Degenerate verdicts
// (whatever their label) are RECLASSIFIED to NEEDS_HANDVERIFY — they do NOT silently kill a candidate.

const results = await pipeline(
  CLUSTERS,
  c => agent(c.digPrompt, {label:`dig:${c.key}`, phase:'Hunt', schema:FIND, agentType:'Explore'}),
  (dig, c) => dig?.candidates?.length
    ? parallel(dig.candidates.map(cand => () =>
        agent(adversarialPrompt(cand), {label:`v:${cand.title.slice(0,26)}`, phase:'Verify', schema:VERD, agentType:'Explore'})
          .then(v => ({candidate:cand, verdict:v, degenerate:isDegenerate(v)}))))
        .then(verdicts => ({cluster:c.key, candidates:dig.candidates, kills:dig.kills, verdicts}))
    : {cluster:c.key, candidates:[], kills:dig?.kills||[], verdicts:[]}
)
// HAND-VERIFY SET = every REAL/NEEDS_POC  ∪  every degenerate verdict (regardless of its label).
// A "REFUTED" you cannot read is NOT a kill — it is an un-checked candidate.
const handVerify = results.flatMap(r => r.verdicts)
  .filter(x => x.degenerate || ['REAL','NEEDS_POC'].includes(x.verdict?.verdict));
```
**Dig prompt must carry:** the exact files/lines for the cluster, the **Phase T P0/P1 paths to confirm** (each dig validates the reachability + impact of its assigned path), the relevant **SC-PATH-PATTERNS edges** (SC-P-xx) to test as the class checklist (Solana account/PDA/CPI/signer; EVM reentrancy/rounding/oracle; cross-chain peer-trust SC-P-03/04; library-vs-custom SC-P-10), the economic ORACLE (if you've audited a twin — e.g. EVM↔Solana same logic), and "KILL sound/known/design-intent angles." The fan-out is the EXECUTION of the Phase T paths that survived to P0/P1 — not a fresh undirected scan.
**Adversarial prompt must carry:** "default REFUTED unless airtight; verify the constraint ACTUALLY allows the attack (Anchor macros / Solidity modifiers often already block it); <30s design-intent test (Rule 10); DUP vs the specific prior audits (name them, point the agent at the extracted PDFs); real loss=$X or theoretical."
**After the workflow:** read the full output, build the **hand-verify set = every REAL/NEEDS_POC ∪ every DEGENERATE verdict**, and HAND-VERIFY each against the code before it becomes a finding (or a kill). Log every kill to `analysis/W*-KILLS.md` with the exact code reason (so it's never re-investigated).

> **Degenerate-verdict guard (mandatory — the Graph Horizon lesson).** A schema-valid verdict can be a STUB that verified nothing: `verdict:"REFUTED", reasoning:"Test"`. The adversarial layer FAILS silently this way. **A refutation you cannot read is not a kill — it is an un-checked candidate.** Before trusting ANY `REFUTED`/`NEEDS_POC`, apply `isDegenerate()` (reasoning < ~120 chars, OR canned filler like "Test"/"OK"/"N/A", OR cites no concrete code artifact — file/line/`require`/`msg.sender`/selector). Any degenerate verdict is reclassified to NEEDS_HANDVERIFY and **must** be re-derived by the operator from the code — never counted as a clean kill. On the Graph Horizon run, the escrow-key "$3M drain" candidate came back `REFUTED / reasoning:"Test"`; only operator hand-verification established it was actually false (collector-contract vs dataService key confusion). Had it been real, the stub would have buried a Critical. The guard turns "trust the label" into "trust only a refutation you can read." This is the **second-layer floor**: D9/adversarial is the first layer, the degenerate-guard + operator read is the layer that catches the adversarial layer's own failures.

**Scale to the surface:** a 12K-LOC program → 3-4 clusters; a single library → 1-2; "be comprehensive" → larger finder pool + 3-5-vote adversarial + a completeness critic pass ("what modality/file/claim did we not cover?").

---

## The 4-PASS discipline — run the fan-out FOUR times with different lenses (NOT once)

> **Why 4 passes, not 1 (the August blind-hunt failure, 2026-06-02).** A SINGLE fan-out pass = vector-first hunting = it finds only what the kit was tuned for = on an audited surface it returns refuted textbook noise (proven: the un-directed LendingPool hunt killed ~all 30 candidates). The upshift engagement produced 48 findings vs the ~14 median ceiling precisely because it ran FOUR sequential passes, each a different lens. **The fan-out harness above is the ENGINE for ONE pass; run it four times.** Pass 1 ≈ what 90% of hunters call "a complete engagement"; Passes 2-3-4 are the other ~70% of yield AND the headline chain — AND the only passes that find what an audit missed. Each pass = a fan-out Workflow (dig → adversarial-verify → operator hand-verify), pointed by the Phase S seam statement.

| Pass | Lens | Produces | Trigger |
|---|---|---|---|
| **1 — Primary** | "Is the obvious thing broken on the seam paths?" | base primitives (the Phase T P0/P1 paths, dug) | after Phase S+T |
| **2 — Expansion** | "What did Pass 1 SYSTEMATICALLY miss?" | the patterns no single vector targets | after Pass 1 inventory |
| **3 — Mirror invariant** | "If guard P exists at A, why is it absent at B?" | the asymmetry findings — **where the seam's Criticals form** | after Pass 2 |
| **4 — Chain** | "Which 2+ primitives combine into an attack none alone is?" | the undismissable headline chain | after all primitives mapped |

**Pass 1 — Primary (the directed fan-out you already run).** The fan-out harness, dig clusters = the Phase T P0/P1 paths through the seam. Inventory primitives to `analysis/INVENTORY-PASS-1.md`; stub each hit; DO NOT write full reports yet (writing breaks scan rhythm and starves 2-4). Anti-stop: "found a Critical, let me write it" → NO, finish the inventory.
> **Pass 1 COMPLETION CRITERION (measurable, gates Pass 1→2):** every P0 AND P1 path from `TRIAGE-CARD.md` has a line in `INVENTORY-PASS-1.md` with a verdict (REAL-stub / REFUTED-by-execution / NEEDS-POC) — count the lines against the P0/P1 count, any gap is an un-dug path. Pass 1 is NOT "done" because you found a Critical; it is done when the P0/P1 set is exhausted. (This mirrors the Pass-3 criterion "every primitive has a written V_in vs V_out line" and the §7 measured-stop discipline — every pass transition is a COUNT against a prior artifact, never a feeling.)

**General transition rule for all passes:** trigger Pass N→N+1 only when Pass N's output artifact is COUNT-complete against its input set — P1: INVENTORY-PASS-1 vs TRIAGE-CARD P0/P1 paths; P2: INVENTORY-PASS-2 has a row for each of the 5 sub-passes (2A-2E) per relevant actor/surface; P3: every Pass-1+2 primitive has a MIRROR-AUDIT V_in-vs-V_out line; P4: every primitive pair/triplet in PRIMITIVES-MAP has a chain-or-no-chain verdict. No transition on "feels long / feels enough."

**Pass 2 — Expansion (the pack's blind spots — ~1/3 of yield).** Five mandatory sub-passes, each a fan-out cluster:
- **2A Authority/governance chain** — for EVERY privileged role / admin / upgrade authority / trust anchor from Pass 1, trace the FULL chain to its root (EOA→Safe→Timelock→ProxyAdmin→Impl on EVM; session→role→tenant-admin→platform-admin on web; IAM→assume-role→trust-policy→root on infra; key→KDF→trust-root on crypto). Look for single-point-of-failure at root + **naming deception** (a "multisig"/"timelock"/"MPC" that is actually one key — this is A20/A34, recurrent everywhere).
- **2B Secret/credential hygiene** — forensic sweep for any credential that crossed a build-time→run-time or internal→external boundary (deployed bundles, image layers, CI logs, config dumps). A9/A13 class.
- **2C Privileged-actor under stress** — per privileged actor: what if compromised / rotated / out of resources? Is there pause / recovery / override / timelock? How long static (exposure window)?
- **2D Shadow surface** — staging / dev / QA / replica / debug / legacy / internal-but-reachable. The recurring win: a shadow surface with weaker auth than prod reading/writing prod-adjacent data.
- **2E Error/telemetry leak** — what does it leak on failure (stack traces, internal IDs, topology, the `InvalidSignatureException` class). Delta to `analysis/INVENTORY-PASS-2.md`. Anti-stop: "Pass 1 gave 14, enough" → NO, Pass 2 was 16 of upshift's 48.

**Pass 3 — Mirror invariant (the Critical-forming pass — operationalizes Rule 41).** Lens: "If protection P exists at A, why is it missing at B?" This is the pass that produced the $308M upshift Critical AND A25 (sentUSD lagDuration=259200 vs flagships=0 = asymmetry = oversight, not design). **A side is NOT "clean" without a written `V_in vs V_out` line** (Rule 41 / §7.3). For each primitive from Pass 1+2, identify its mirror pair and ask "is the protection symmetric?":
| Pair | Asymmetry to find |
|---|---|
| Verb/method | same resource, different protection per HTTP verb / RPC method (F1: GET=401, POST=422) |
| Network | prod vs staging vs replica — auth/rate-limit/validation drift |
| Protocol | REST vs GraphQL vs gRPC same resource — permission scope |
| Binding | lang-A vs lang-B same primitive — edge-input handling |
| Direction | encode/decode, serialize/deserialize, ingress/egress, request/response |
| Config-peer | vault A vs sibling vault B same param (lagDuration 0 vs 259200 — A25!) |
| State | activated vs deactivated — does deactivation actually disable the surface? |
| Trust | trusted-input path vs untrusted-input path reaching the same sink |
**The asymmetry IS the finding** (it makes the gap an oversight, not design — the strongest argument). Write each to `findings/<id>/MIRROR-AUDIT.md`. Anti-stop: "found 30 already" → NO, Pass 3 amplification is multiplicative.

**Pass 4 — Chain (the headline).** Lens: "Which 2+ primitives combine into an attack none alone is?" A chain is **undismissable**; a single finding gets argued away ("the key is segmented", "the role is IP-restricted"). Lay out `analysis/PRIMITIVES-MAP.md`; for each pair/triplet ask: does B amplify A? does the combo unlock an action neither alone does? can one actor execute it with no privilege? Universal amplifiers: credential-leak + unauth-trigger (the trigger IS the bypass) · read-escalation + write-sink · replay + state-mutation · shadow-surface + prod-data · info-leak + targeting (removes enumeration cost) · untrusted-input + privileged-sink · upgrade-authority + any-Medium (Medium→Critical). Per chain: `findings/CHAIN-<id>/CHAIN-PROOF.md` with components, step-by-step concrete commands, combined severity (always > max component), sourced numeric impact, why-the-chain-is-undismissable.

**Hard rule:** a firmaudit deep engagement runs all 4 passes. Trigger Pass N→N+1 = "Pass N completion criteria met", never "feels long". STOP only when 4 passes complete + §7 green + gates cleared, never "I have enough." Skipping a pass under-delivers in a NAMED way: skip 2 → miss authority-chain/secret/shadow (A20/A9 class); skip 3 → no mirror Critical, the seam stays abstract (A25 class); skip 4 → no headline chain, the disclosure gets slow-walked.

**CROSS-PASS DEDUP (run before drafting any report — different passes hit the same root from different angles).** The 4 passes deliberately overlap: Pass 1 finds a primitive, Pass 3 finds its mirror, Pass 4 chains it — often the SAME root cause surfaces 2-3 times with different impacts. Submitting them as separate findings that share a root, without linking, gets the weaker ones rejected as self-dups (triager: "B is a dup of A at lower impact") = money left on the table (Polymarket lesson: two findings filed sharing one root cause → the triager killed the lower-impact one as a dup of the higher, paying once instead of twice). Before writing reports, build `analysis/ROOT-CAUSE-MAP.md`: cluster every primitive/finding by ROOT CAUSE (the code/config defect), not by impact. For each cluster:
- **One root, one impact → one finding.** Merge.
- **One root, multiple DISTINCT impacts (e.g. the mirror gap enables both a fund-loss AND a griefing-DoS) → ONE report, the highest-severity impact as headline, the others as "additional impacts of the same root" in-body.** Never two separate submissions sharing a root.
- **Distinct roots that only CHAIN together → the Pass-4 chain report, with each component cross-referenced.** The chain is the submission; components are cited, not separately filed (unless a component is independently submittable at material severity — then file it AND link the chain so the triager sees you're not double-counting).
The map also catches the inverse error: two findings you THOUGHT were one (different roots, coincidentally similar symptom) that should be filed separately. Decide merge-vs-split by ROOT, always.

**ARTIFACT COHERENCE (the submission is N artifacts that must tell ONE story at ONE rigor level — Solv SOLVPR-297, 2026-06-08).** A modern submission is not one document: it's the writeup, the PoC (inline or attached), the platform form-field text, the chain-of-custody comment, and the screenshots. The failure mode is hardening ONE and letting the others silently fall behind, so a triager reading artifact B sees a claim A already retracted or proves less than A asserts. Three mechanical rules, applied after EVERY edit to ANY artifact:
- **Propagate the change.** When the PoC gains an anti-bias control, the writeup's corresponding paragraph gains the same sentence (this session: the `stats` valid-globally control was added to the PoC but the report's privilege-ladder ¶ lagged → the report was *weaker than its own PoC* until aligned). When severity is recalibrated in the writeup (Critical→High after a disconfirmer), the comment must not still say "Critical" — a comment louder than the report it annotates destroys the calibrated credibility (self-tell: the word "Critical" creeping into a comment the report set to High).
- **Purge invalidated references.** When a file is renamed, removed, or a format is rejected (this session: `.sh` PoC rejected → moved inline → every "attached poc.sh" across writeup + form-fields had to be purged or it points at a non-existent file), grep ALL artifacts for the old name/format. Screenshots are artifacts too: when the report's example query went 5-field → 9-field, the 5-field screenshot became a claim/proof gap → re-shoot.
- **Verify WHICH artifact an alarm is about before damage-control.** An adversarial review flagged "you ran prod mutations / claimed 1.18M / said Critical" — all true of the PRIOR engagement's report but ZERO of the shipped read-only one; the wrong file had been handed to the reviewer. Before reacting to an alarm, grep the SHIPPED artifact for the flagged content (same discipline as verifying a KILL/REAL against deployed code, turned on your own artifacts). The instinct to STOP and confirm is correct; often the resolution is "different file."

---

## §7 — Legal stop conditions (immortal mode)

Stop a phase ONLY when, and log the measurement:
1. forge-lint / cargo-clippy green (no compile/lint debt), AND
2. internal-consistency scan = 100% (every guard on path X verified present on its mirror path), AND
3. mirror-coverage exhaustive (every V_in / V_out pair enumerated and compared in writing).

Condition 3 (mirror-coverage exhaustive) is **Pass 3 run to completion** — every primitive has a written `V_in vs V_out` line. You may NOT claim §7 stop until all 4 passes are complete: a stop after Pass 1 is the August-blind-hunt failure (vector-first noise, no seam Critical). "All 4 passes complete" is itself a §7 measurement.

A null result on a right-profile target → `_negative-results.md` with the specific surfaces dug AND the seam statement that was swept, not "solid." A null is only legal if Phase S found no un-swept seam (every boundary's handoff has a named review) — otherwise the null means "I didn't sweep the seam," not "the target is clean." EV gate still governs escalation to submission: >$5K STRONG GO / $1K-5K GO / $200-1K WEAK GO (<4h) / <$200 SKIP. (The time-boxes on gates/EV are scoped tools; "immortal mode" is the engagement-level posture — they don't conflict: you don't time-box the hunt, you time-box the per-finding gate.)

---

## Arguments

```
/firmaudit <target>          # full engagement: Phase 0 → Phase T triage (GO/NO-GO) → plan → execute
/firmaudit --phase0 <target> # Phase 0 intel card only, stop before triage
/firmaudit --triage <target> # Phase 0 + Phase T → GO/NO-GO verdict only (the "is it worth my time" mode), stop before deep plan
/firmaudit --plan <target>   # assume Phase 0 + Phase T GO done, go straight to the adaptive plan scoped to P0/P1
```

`--triage` is the fast go/no-go: when the operator is deciding whether a target/contest is worth the slot, or which of several competing targets to take, run Phase 0 + Phase T and stop at the `TRIAGE-CARD.md` verdict. Cheap, and it kills unwinnable targets before any deep read.

## First action every invocation
1. Confirm immortal mode + no-auto-orchestration to the operator in one line.
2. Run `~/arsenal/audit-lifecycle/bin/init-target.sh` if a workspace isn't initialized (Rule 38).
3. Run `phase0-intel.sh` → Phase 0. Then **Phase S (seam thesis) → Phase T triage → GO/NO-GO BEFORE any deep plan**. Phase S names the boundary nobody owns and BIASES Phase T's path scoring; Phase T is the absorbed top-down gate. Do not skip to a plan. **If Phase T = NO-GO, stop and report the card** — entering deep audit on a NO-GO target is the exact failure this skill exists to prevent.
4. On GO: Phase A (audit-conditions) → Phase R (execute probes) → then the deep plan executes the **4-PASS fan-out** (Pass 1 primary on the seam paths → Pass 2 expansion → Pass 3 mirror-invariant → Pass 4 chain), each pass an operator-hand-verified Workflow. A stop after Pass 1 = the vector-first failure this skill now explicitly forbids.

**The full flow:** Phase 0 (intel) → **Phase S (seam)** → Phase T (GO/NO-GO) → Phase A (audit-conditions) → Phase R (execute recon) → Adaptive Plan executed as **4-PASS fan-out** → §7 stop (all 4 passes + mirror-coverage + seam swept) → gates (kill-gate/severity-commit/D7-D9/preflight).
