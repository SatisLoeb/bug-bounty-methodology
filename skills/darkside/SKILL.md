---
name: darkside
description: >
  Re-founded standalone dark-corner hunting skill for audited high-value targets. The germe (the
  user's own framing): "Va voir ce que les devs ont TESTÉ pour valider leur sécurité → liste ce
  qu'ils ont OUBLIÉ de tester ou PAS VU → le tout avec la mentalité du voleur qui EMMAGASINE des
  primitives pour VOLER le protocole — pas pour trouver un bug isolé." THREE entry doors: Doors A>B
  mine what the devs EXPRESSED, Door C mines what they NEVER WROTE. Door A = DEFENSIVE-COVERAGE MATRIX
  (mine the devs' adversarial test suite, build money-path × covered-Y/N, the N column is the worklist,
  the sibling-they-didn't-test is the candidate — PRIMARY whenever an adversarial test suite exists);
  Door B = DEV-PARANOIA-MAP (grep their fear-comments + invariant-runners + changelog adjacents —
  FALLBACK only when A is empty/absent or as post-A complement); Door C = UNWRITTEN-INVARIANT MAP
  (thief-mode not catalogue-mode: diff the target against the canonical form of its type, list every
  design DEVIATION, make explicit the invariant the devs never wrote because they believe it holds by
  construction, attack that belief by an untrusted actor — runs in PARALLEL to A/B, finds the
  no-CWE composition bug that survives multi-audit fortresses, does NOT fan-out). Every candidate
  enters a THIEF INVENTORY whose admission gate is chainability-to-a-theft, fused with chain-triage.
  The 5 axes are demoted from generator to per-candidate analyzer. Use standalone on any audited
  target, and firmaudit references it at Pass-1. Trigger on "/darkside", "darkside", "mine the devs'
  tests", "ce que les devs ont testé", "place où l'attention a fui", "max-trust min-verification",
  "untested sibling", "unwritten invariant", "what's bizarre and specific", "thief not catalogue",
  "qu'est-ce qui est unique à cette target", and automatically when firmaudit reaches Pass-1 on an
  audited (top-firm, test-suite-bearing) target.
---

# /darkside — mine what the devs TESTED, what they FEARED, and what they NEVER WROTE

**Va voir ce que les devs ont testé. Liste ce qu'ils ont oublié de tester ou pas vu. Puis regarde ce
qui est BIZARRE et SPÉCIFIQUE à cette target que les auditeurs ont accepté comme normal — les
invariants qu'ils n'ont jamais écrits parce qu'ils croient qu'ils tiennent par construction.
Mentalité du voleur qui emmagasine des primitives pour voler — pas un bug isolé.**

This skill exists because the germe was generative and self-arresting — it had a *finite entry
point* (the devs' own adversarial test suite) and a *hard admission criterion* (chainability to a
theft). The current firmaudit §🌑 volet generalized it into a contemplative abstraction ("places
attention fled, max-trust × min-verification, 5 axes") that lost both the bounded door and the
validator. Track record settles it: on **injective-core v1.20.0**, the germe (mine attack tests →
the voucher accounting was the *untested sibling* of the 4 EVM-halt tests they DID write) found the
only Critical; the 5-axes abstraction on the same target found 5 nulls. We re-suspend the
abstraction back onto the germe: **the germe is PRIMARY, paranoia is FALLBACK, the 5 axes are an
analyzer not a generator, and the thief inventory is the gate nothing skips.**

**Door C closes the one gap A+B structurally cannot.** Doors A (mine their tests) and B (mine their
fear-comments) are both bounded by what the devs *conceived* — a test or a comment presupposes a
threat they imagined. On a fortress that survived multiple audits in catalogue-mode, every NAMED
class is already swept; the remaining bug is the **composition of this protocol's specific design
deviations that nobody modeled because it has no name**. Door C is the thief-mode entry that finds
it (the F-STALE-NAV win: a stale-NAV redemption-arbitrage that four audits + a full catalogue-mode
agent pipeline all missed, found by asking "what is unique to THIS protocol that everyone accepted as
normal" — see §1 Door C). It runs in parallel to A/B, it is the slowest door, and it is the only one
that does NOT fan-out to agents — seeing a singularity is *surprise*, which pattern-matching
suppresses. **Catalogue-mode = completeness (read the catalogue better than the auditors). Thief-mode
= discovery (abuse the precise thing that has no entry in the catalogue).**

## Operating mode — when to invoke

- **Standalone:** invoke `/darkside` on any audited target the moment you have a clone and a sense
  of the money-path keepers. It does not need firmaudit. It is the right first move on
  top-firm-audited code where the low fruit is already picked (the audits picked it) and the money
  is at the *bottom* of the surfaces that got waved through.
- **firmaudit-referenced:** firmaudit reaches Pass-1 on an audited target → it hands off to this
  skill for the dark-corner phase AFTER the broad sweep maps terrain. Broad agent fan-out MAPS;
  darkside DIGS. They are not interchangeable.
- **Tie-break (if firmaudit §🌑 and this skill ever diverge, THIS skill wins).** firmaudit §🌑 is a
  9-line pointer here; it is not a second copy of the method. If a future edit ever leaves it
  describing the 5 axes as a *generator* (the old structure), that is stale — **the germe wins over
  the 5-axes-as-generator, on the injective track-record** (germe found the only Critical, the
  abstraction found 5 nulls). Door A/B is the entry; the axes are the analyzer. Never start a hunt
  by "running the 5 axes."
- **Immortal / earned-depth:** no time box, no token box. But depth is **EARNED, not spent** — the
  Gate (§0) decides whether descent is even warranted, and the Exit (§5) stops a dead surface before
  fatigue masquerades as thoroughness. Token cost is a non-constraint; a missed vuln is the only
  cost that counts.

## 0. THE GATE (before any descent)

Before opening a single keeper, compute whether this target earns depth.

- **Fortress score** (run at intake): `audit_count ≥ 2` is a heavy **signal** (especially if one is
  an in-repo internal audit); `audit_count ≥ 3` + top-tier auditor (Trail of Bits, OtterSec,
  Quantstamp, Cantina, Cyfrin, Halborn) + adversarial dev-tests present + fresh audit (thin residual)
  + clean payout history → **HIGH fortress** (the threshold the tactical doc §0 scores at). HIGH does
  not mean "skip" — it means *Door A is
  richer* (more adversarial tests to mine) but the residual is thin, so NO-GO unless there is a
  fresh delta or a genuinely un-swept seam (off-chain, new module, cross-chain handoff). Mezo was a
  textbook fortress (5× audited, Thesis team, DEV-NOTES anticipating their own DoS) → ~15 surfaces
  deep-beast, 2 PoC'd, both honest-dropped, $0. Don't spend immortal depth on an unwinnable target.
- **N-KILLs = STOP:** N KILL-GATE failures with 0 surviving candidates on a surface → STOP that
  surface, redirect (§ FAIL-FAST). On injective v1.20.0, 5 P0/P1 surfaces went honest-null; that's
  the signal the fortress is confirmed — log it and re-engage only on a new version delta.
- **Decision:** emit one of **NO-GO** (fortress + no delta + no seam) / **DELTA-ONLY** (audit the
  post-clone git delta + the new modules) / **FULL-DESCENT** (thinner-audited, pre-first-audit,
  off-chain seam, or a fresh adversarial-test surface worth mining). Full fortress-score criteria and
  the timebox classifier live in the tactical doc.

## 0.5 — THE HUNTER'S OWN DARK SIDE (apply the germe to YOURSELF before the devs)

**The operator's framing (2026-06-11, tokenize.it): "tu agis exactement comme les devs qu'on chasse — on devrait appliquer un darkside sur toi."** It's literally true and it's the most important guard in this skill. A hunter who audits like a defensive dev — respecting boundaries, closing cleanly, assuming walls — is exactly as blind as the dev who codes like that. Before you mine the devs' unwritten invariants, mine your OWN. These four are the recurring ones; each cost a real finding in one engagement until the operator pushed.

**0.5.1 — OBSTACLES AREN'T WALLS; and a real wall has a window. (the umbrella)** Every "OOS / can't reach / not available / blocked / fortress / dead end / requires X I lack" is a HYPOTHESIS dressed as a CONCLUSION. Two-step on every stopping-point: **(step 1) is it even a wall?** — execute the probe. "owner-gated" → can a non-owner BECOME owner (init-exploit, clone-hijack-if-salt-doesn't-bind-owner, `_msgSender` spoof if forwarder skips the from-sig, role-admin gap, storage collision)? "not in the repo" → `git log --all`, a mirror, archive.org? "the PoC kills it" → is the kill-PoC biased / on the genuine path? Most walls dissolve here. **(step 2) if it IS real, find the window before accepting** — a different actor, path, framing, sibling fn, composition, or off-program disclosure channel. A wall is accepted ONLY with the window-search logged ("I looked here: [executed checks], none found"), never by default. The tell you're at a FAKE wall: the feeling "well, that's blocked, moving on" arriving BEFORE you executed a probe. (Inverse guard / anti-inflation: the window-search CAN come back empty → then the wall is real, like a Critical-only grid whose literal text excludes `onlyOwner`. SEARCH with an executed check; don't assume a window exists either.)

**0.5.2 — DON'T RESPECT THE `onlyOwner` WALL — try to BECOME the actor.** Treating every privileged path (`onlyOwner`/`onlyRole`/`onlyManager`/admin) as auto-OOS is the defensive-auditor reflex. The thief reflex: the privilege gate is the TARGET. A program's "rogue privileged users NOT valid" excludes an admin MISBEHAVING — NOT a non-privileged attacker ACQUIRING the privilege (categorically different, usually in-scope and Critical). The unlock: an owner-only finding (e.g. a param the owner abuses to harm a counterparty) is a coin-flip alone, but becomes a CLEAN undismissable Critical IF chained to a takeover (the takeover is the missing first hop). So on EVERY privileged path, before writing OOS, run the BECOME-THE-ACTOR pass: (1) become owner (uninit clone/logic, re-init via `__Init`-chain gap, 2-step ownership race, clone front-run if the salt doesn't bind the owner arg, CREATE2 collision); (2) spoof the caller (ERC-2771 `_msgSender` forgeable if the trustedForwarder relays without verifying the `from` EIP-712 sig, or a wrong `_contextSuffixLength`/`_msgData` override mis-parses the appended sender); (3) escalate a role (role-admin gap, a role that's its own admin, DEFAULT_ADMIN reachable); (4) collide storage (UUPS impl `__gap` mis-size shifting owner/role slots). Only after all four come back executed-null is "rogue-admin OOS" legitimate — and even then note the owner-gated finding as "Critical-if-chained-to-takeover."

**0.5.3 — A NULL/KILL IS INVALID UNLESS YOU RAN THE DECIDING ARTIFACT, AND THE KILL-PoC IS AS UNBIASED AS A CONFIRM-PoC.** Closing-bias = playing against the operator: a "null/fortress/kill/no-submission" optimized to close cleanly rather than to find the bug. Two mechanical sins to never repeat: (a) **concluding on a PoC you didn't run** — agents (and you under pressure) write "PASS" on a test that never compiled; re-run every agent PoC yourself and see the output before trusting any verdict it rests on. (b) **a kill-PoC biased toward the kill** — building it on a convenient path/actor/inputs that make the kill trivial (e.g. testing the carry-starvation on `buy()` where the owner already controls the price, instead of the genuine `claimExit` path where proceeds are EXOGENOUS — the biased version manufactured "owner-design/redundant" and buried a real finding; the unbiased version on the real path reopened it). The bias-checks (config parity, real path, no harness-induced result, baseline + DISCONFIRMER in the same PoC) apply SYMMETRICALLY: a biased PASS submits garbage, a biased KILL buries a real bug. Add the disconfirmer to confirm a kill is real (add the guard whose absence is the claimed bug → the exploit must now revert, the honest baseline must still pass).

**(c) — generalize (a) to EVERY workflow/agent debrief, not just kill-PoCs (operator caught this 2026-06-11, Injective-web S5): a load-bearing EMPIRICAL claim from a Workflow/agent is a HYPOTHESIS until I re-run the deciding artifact MYSELF and paste MY output — before I report it to the operator as true.** The Workflow tool's fan-out EXPLORES (its value); but its synthesis text ("unauth → 200", "updated:0", "`.notified` = 1 occurrence", "pool = $260", "the mobile chunk is a 692B stub") is the agent's word, and agents fabricate exactly like a kill-PoC that "PASS"-ed without compiling. So before any debrief that the operator's decision rests on: re-curl the killshot / status / body, re-grep the count or the "no consumer reads field Y", re-run the PoC the verdict rests on, re-read the number on-chain or from the file — and report MY reproduced output, not the agent's. Agent REASONING and architecture-mapping carry forward as hypotheses; any EMPIRICAL assertion that enters my report gets reproduced by my own hand first. (On S3 the re-verify CONFIRMED all 5 claims exactly — the habit is not distrust-for-its-own-sake; it is that the operator acts on my report and my report must rest on artifacts I ran.) The tell I'm about to violate it: typing "the workflow found / the agent confirmed / the synthesis says X" into a debrief without having re-executed X this turn → STOP, re-run X, report my output. This applies to ALL Workflow output (the two-layer hunt workflows especially — their Layer outputs are agent-synthesized), not only to null/kill verdicts.

**(d) — VERIFY WHAT THE AGENT DIDN'T SAY: check COVERAGE, not just correctness (operator, 2026-06-11: "vérifie aussi ce qu'ils ne sortent pas, vérifie s'ils ne ratent pas des surfaces").** An agent has TWO failure modes and (c) only catches one. (i) What it SAYS is wrong → re-run the claim. (ii) What it DIDN'T say → it swept a NARROWER space than it implies, missed endpoints/backends/files/fields, and its SILENCE reads as "nothing there" when the truth is "not looked at." Mode (ii) is MORE dangerous because a false claim is visible (re-testable) but a MISSED SURFACE is invisible — there is nothing to re-test, just a hole nobody points at. This is exactly how my "BFF has no PII" thesis failed: agents scanned the DECLARED OpenAPI and concluded "none," and the hole (undeclared routes, OTHER backends, non-keyword field names) appeared NOWHERE in their output — a confident null over a sub-space presented as the whole space. So before trusting any agent NULL/"nothing found"/"all X are Y": independently establish the FULL space and confront the agent's coverage against it. Concretely — (1) did the agent enumerate the complete surface, or a convenient subset? (re-derive the full set MYSELF: `find`/`grep` every file, list every host in the bundles, every route incl. undeclared, every backend, every field in the body — not just the ones the agent named). (2) Run the SURFACE-INVENTORY discipline (`~/.claude/skills/SURFACE-INVENTORY-PLAYBOOK.md`) / COVERAGE-LEDGER as the anti-(ii) tool: the inventory is the full space; the agent's findings are a coverage claim against it; any surface the agent never names = UNCOVERED, not null. (3) The tell of a coverage hole: an agent NULL whose scope is implicit ("no PII anywhere" — anywhere = where?). Pin the scope: "no PII in WHICH routes/hosts/fields?" — then check whether that scope is the whole space or a slice. A null is only as wide as the space the agent actually enumerated, and I must establish that width myself, not inherit it from the agent's confident tone.

**0.5.4 — VERIFY ALL SURFACES BEFORE "FORTRESS"; "encoded" ≠ "applied"; the operator pushing once = you closed too early.** "Fortress of the whole target" is illegal while any in-scope surface lacks an executed artifact (read 120/545 lines of a file, never opened the audit PDF that was in git history → not covered). And a lesson sitting in memory does NOT make you obey it — `prove-the-null` was in memory the whole session and you still concluded on a biased PoC. Memory is necessary, not sufficient; these guards live in the SKILL (loaded whole, every invocation) precisely because memory truncates and gets ignored. Re-open velocity is the real metric: if the operator pushing once surfaces something real, you closed too early. On tokenize.it the operator pushed FOUR times and was right four times — that's four fake walls you'd have accepted. Run 0.5.1–0.5.3 on yourself BEFORE reporting any null, so the operator doesn't have to be your disconfirmer.

**0.5.5 — THE DEPLOYED LAYER IS AN IN-SCOPE SURFACE THE CODE-REVIEW NEVER AUDITS; a "fortress" verdict is illegal without a read-only deployed pass (the August vein, Mezo 2026-06-11).** Proving the CODE sound (even 5×-audited) does NOT clear the deployed state — they are two separate surfaces, and code-review never reads what's actually on-chain. The deployed layer is where August's 39 findings (several Critical) lived: single-key Safe authority (A20/A34), a violated audit-condition (A25), deployed-impl drift. So before any fortress/null verdict on an audited on-chain target, run the read-only deployed pass (read-only state reads are NOT live testing — allowed even under "no mainnet interaction"; `eth_getStorageAt`/`eth_call`/verified-source-fetch only). Three reads per fund-moving deployed contract: **(1) upgrade authority** — EIP-1967 admin slot → ProxyAdmin → `owner()` → EOA single-key = A20 Critical, or Safe → read threshold/owners (1-of-1 / low-threshold / one key-pair on N Safes = A20/A34). **(2) deployed-impl ≠ repo** — EIP-1967 impl slot → fetch the VERIFIED SOURCE (`/api/v2/smart-contracts/<impl>`) and diff against repo HEAD; a deployed older impl missing a known fix on fund-moving code = theft. **NEVER bytecode-grep for revert strings** (the compiler compresses them → "lacks guard X" is a false positive; Mezo: bytecode-grep said BorrowerOps "lacks all guards", verified source was 1404 lines = repo line-for-line). **(3) deployed oracle/params vs audit conditions** — read the live oracle, DECODE `latestRoundData()` (sane value? right decimals?), compare staleness/MCR/CCR to what the audit ACCEPTED a risk under (A25). The two near-false-positives this pass makes (bytecode-grep "lacks guard", "special-looking oracle") are both killed by reading the ARTIFACT not the structure — same `prove-the-null/shown-body` rule. On Mezo all three were sound (Safe 5-of-9, 6/6 impl=repo, oracle sane=audited) → null, but the null was PROVEN by the reads, not assumed by "the code is a fortress." Full tactical protocol: `firmaudit § DEPLOYED-LAYER READ PASS`.

**0.5.6 — RUN THE COVERAGE LEDGER BEFORE ANY FORTRESS/NULL/NO-GO — enumerate every in-scope file, not just the surfaces with a seam (mandatory, the Mezo 2026-06-11 hole).** Door A/B/C and the seam-thesis aim depth at the high-signal surfaces — a strength — but they share one blind spot: you deep-beast the chosen surfaces, prove them sound, and write "fortress" while N other in-scope files were never enumerated. On Mezo, 8 surfaces were named and proven sound → "fortress", but `find *.sol` showed 20 contracts, 8 NEVER even listed (~1631 LOC), skipped by "no seam" + "canonical-Liquity-dup" — a dup-PRIOR silently became a don't-look. The operator's statistical tell exposes it: if a 279-submission cohort finds things and you find nothing, the likeliest cause isn't "I searched my surfaces badly," it's "I didn't search everywhere and nothing made me confront the gap." So **before writing any fortress/null/NO-GO verdict, run `~/.claude/skills/COVERAGE-LEDGER-PLAYBOOK.md`:** mechanically `find` every in-scope file (Solidity + Go + the deployed addresses), classify each `COVERED+artifact` / `COVERED+seam-null` / `SKIPPED+allowed-reason`, and confirm ZERO `UNCOVERED`. "Canonical-dup / helper / trivial / no-seam / small" are NOT standalone skip reasons (they are depth-priors); each such file still earns a delta-pass — open it, grep the project's custom additions (interest layer, native-BTC, recovery-mode, EIP-712 graft), read the untrusted-reachable state-changers, write one artifact or one allowed-skip. This is the completeness twin of 0.5.4 ("verify all surfaces before fortress"): 0.5.4 says no surface lacks an artifact; THIS says you must first ENUMERATE all surfaces so you can't silently omit one. The fortress verdict must be able to say "I enumerated N files; M covered by executed artifact, K skipped for [allowed reasons], 0 uncovered." (On Mezo, the ledger-driven sweep of the 8 uncovered contracts returned 0 valid — all canonical-dup or trusted-internal — but the null is now PROVEN complete, not assumed from the 8 chosen surfaces.)

**0.5.7 — A PoC THAT "RUNS GREEN" IS WORTHLESS UNTIL YOU VERIFY THE DECIDING STATE ACTUALLY MOVED — the silent no-op is a biased null in disguise (Perena Bankineco, 2026-06-16, operator: "le poc ne doit jamais être biaisé").** The most insidious bias is not a wrong assertion — it is a step that SILENTLY DOES NOTHING while reporting success, so the whole chain passes and the verdict reads "REFUTED" because the attack's PREREQUISITE never fired, not because the protocol defended. Concrete: a fork chain mint→stake→keeper-yield-push→unstake netted the attacker −9.46 USDC → "D3 REFUTED." But an anti-bias re-read showed the keeper's `update_yielding_info` returned OK while the tranche `share_price` delta = **0** — the push was a no-op (it needed a multi-reporter consensus the harness didn't supply), so the attacker netted negative because NO yield was ever distributed, not because the 1% fee beat the straddle. The null was biased; retracted. **Mechanical guard, mandatory on every multi-step PoC before trusting a PASS *or* a null: after the pivotal action (price-push, oracle-update, deposit, slash, state-transition), RE-READ the exact state variable it was supposed to change and ASSERT it moved in the expected direction by the expected magnitude. If `state_after == state_before`, the step no-op'd → the result is NOT evidence, whatever the tx receipt says.** A green tx receipt proves the instruction did not REVERT; it does NOT prove it had the EFFECT your chain depends on — Anchor/Solana instructions routinely succeed-as-no-op when a gate, consensus threshold, staleness window, or `if needed` guard is unmet (Bankineco's `update_yielding_info` silently skips unless reporter-consensus is met; `update_yielding_amount` "Pushed yield X" then no-ops on an unfunded vault ATA). The tell you're about to ship a no-op null: your PoC's pivotal step is a keeper/admin/oracle action you SIMULATED, you saw "OK", and you moved straight to the attacker's leg WITHOUT reading back that the simulated action changed the value the attacker exploits. Bake a `require(state_after != state_before)` (or an explicit logged delta) into the PoC at the pivot — a chain whose pivot is unproven is half-done, exactly like a confirmer with no disconfirmer. **Corollary — when a faithful pivot is genuinely un-drivable on the harness (e.g. the real yield realization CPIs into a live external protocol — MarginFi/Kamino — that static-cloned state can't satisfy), do NOT fake the pivot's return to force the chain through (that is a biased harness); instead report the executed GATES you DID hit (consensus required, `losses_accepted` privileged, yield_manager-gated, external-CPI-bound) and state plainly that the clean end-to-end was NOT achieved.** Gates-proven + biased-null-retracted + "clean refutation not achieved" is an honest verdict; a forced green chain over a faked pivot is not. Sibling of 0.5.3 (run the deciding artifact) applied to the EFFECT, not the existence, of the step.

**0.5.8 — DON'T RESPECT THE GATE — pierce it; "gated/401/auth-required" is the defensive-auditor reflex applied to access control (2026-06-17, Coinstore, operator directive).** Treating a gated surface ("it's behind auth / returns 401 / requires login → blocked → next") as auto-done is the SAME blindness as respecting the `onlyOwner` wall (0.5.2) — you are auditing like the defensive dev who assumes the gate holds. A gate names a control's EXISTENCE, never its STRENGTH. The thief's reflex: the gate is the TARGET, and a 401 is a sign something valuable is HERE, the place to dig HARDEST. On EVERY gated surface, before writing "blocked/hardened", run the 4 bypass angles: **(A) AUTHN≠AUTHZ (highest value)** — the gate proves a valid token is needed; does the controller verify THIS token OWNS THIS resource? a resource-id (orderId/withdrawId/subAccount/addrId/positionId) with no ownership bind = IDOR/BFLA. A 401 proves authn and NOTHING about authz — and a GLOBAL pre-routing authn filter (Coinstore: even `/api/v1/doesnotexist` returns 401-user-not-login) is solid against unauth probing but moves 100% of the value to the post-filter authz it does NOT test. **(B) UNGUARDED SIBLING** — v1-vs-v2 drift, REST-vs-WS-vs-GraphQL, on-chain-vs-keeper/off-chain, contract-call-vs-permit/signature, web-vs-mobile, staging mirror. **(C) GATE SATISFIABLE** — token issued before 2FA completes (M-H1-007), destructive op takes a standard credential while a read needs sudo/re-auth (M-H1-002 inversion), replayable/forgeable sig, a sig that covers payload-but-not-actor. **(D) DIFFERENTIAL LEAK** — 401-vs-403-vs-404-vs-timing leaks other actors' resource state. Piercing has TWO honest outcomes (cuts both ways, the anti-inflation half): find the window (bypass candidate) OR PROVE the gate holds against THIS angle → the value moves to the NEXT angle, never to "done" — and a recon-only probe that can't reach the authz layer does NOT prove a bypass, it scopes the SUSPENDED harness that would. The tell you're a defensive auditor: writing "gated/401/requires-auth → blocked → next" WITHOUT running the 4 angles. Sibling of 0.5.2 (become the actor) applied to access-control gates. Full rule: `feedback_gated_is_not_a_verdict_pierce_the_gate.md` + `firmaudit § banned dismissal move (5)`.

**0.5.9 — "PROBABLY UNREACHABLE" IS NOT A VERDICT — the INVERSE of 0.5.8, when YOU found the missing gate (2026-06-17, Mito Finance, operator: "on ne l'abandonne pas sur du probablement, on creuse chaque recoin, même si ça prend deux mois").** 0.5.8 is "the gate exists → pierce it." This is its mirror: you PROVED a real high-impact defect (a MISSING owner-gate, a trusted-value path, a fund-mover with no validation) and the only thing between it and a payable Critical is REACHABILITY — and you catch yourself writing "probably unreachable / latent / non-attacker-reachable / skip." That is the defensive-auditor reflex again, just on the impact side: you stopped at the FIRST closed leg. A high-impact defect is NEVER abandoned on "probably." Reachability is not one check — it is a SURFACE to exhaust recoin-by-recoin, each leg an EXECUTED artifact (live `simulate`/`cast`/read with pasted output, or a byte-trace). Recoins for a "caller-must-be-X" gated sink: **(a) become-X cheaply** (register/buy/take-over an existing privileged instance, a weak/abandoned/contract owner key); **(b) does ANY blessed instance reach the sink via ANY handler** — grep every call-site/reply/submsg, not the happy path; **(c) owner-controlled CONFIG** making the blessed code emit the sink; **(d) the UPGRADE path** (migrate-admin → attacker code); **(e) the REACHABLE SIBLING with the same weak root** — if the unreachable sink has a sibling everyone already calls (Mito: every market_make routes through the SAME trust-boundary the unreachable execute_messages_for_vault hits), PIVOT the finding to the sibling; **(f) cross-instance binding** ("is registered X" vs "owns ITS OWN resource" → cross-tenant); **(g) compose with a cheaper bug**. Only when ALL recoins are executed-null does "non-reachable" stand — and even then it's a real LATENT defect to CATALOGUE (activates if config flips, e.g. open-registrations turned on), not nothing. Tell: "probably unreachable / latent / skip" arriving right after the obvious registration/permission leg closed, with un-run recoins remaining. See `feedback_probably_unreachable_is_not_a_verdict_make_it_reachable.md` + `feedback_gated_is_a_hypothesis_attack_the_gate_with_full_effort.md`.

**0.5.10 — UNDERSTAND THE SYSTEM BEFORE REVERSE-ENGINEERING THE BYTECODE — stop the blind RE, find the source/audit FIRST (2026-06-17, Mito Finance, operator: "concentre-toi, est-ce que tu comprends exactement comment ça marche?").** When the source isn't in front of you and you're tracing a decompiled binary (WASM/SBF/EVM) with anonymous offsets — GUESSING what `f_pk`/`m+648`/a storage slot means — you are building on sand: a single wrong guess hangs the whole analysis (Mito: I traced `m+648`=config.owner from the WASM; it was the `vaults[caller]` Map key, and the entire reachability verdict rested on that error until the source was found). Before (and instead of) blind RE, exhaust the cheap ground-truth channels IN ORDER: **(1) the public AUDIT REPORT** — SCV-Security/Oak/Zellic/Halborn/Code4rena/Sherlock publish reports that describe the handlers WITH file:line + the trust-boundary bug class + each finding's STATUS (acknowledged = still-live worklist; the Mito SCV #2 "malicious vault drains master via forward-reply" was EXACTLY the bug I was reverse-engineering, named with file:line). Search `github.com/SCV-Security/PublicReports`, `oak-security/audit-reports`, `Zellic/publications`, firm-name+protocol. **(2) the SOURCE crate** — Rust/CosmWasm types crate often ships on crates.io: download via the STATIC CDN `https://static.crates.io/crates/<n>/<n>-<ver>.crate` (the API blocks bots with a data-access error; the static CDN does not); `.cargo_vcs_info.json` inside = git commit sha + `path_in_vcs` workspace layout. **(3) embedded file paths** — `strings <wasm> | grep -oE 'contracts/[a-z/_-]+\.rs'` reveals the real module structure (forward.rs/handle.rs/registration.rs) so you read the RIGHT handler, not guess. **(4) global commit-sha search** — a commit sha is globally unique → GitHub commit-search finds the repo/fork/mirror if anything is public. **(5) the deployed contract's own enum** — trigger a parse error (`{"__x__":{}}`) to enumerate the EXACT deployed message variants, which OFTEN DIFFER from the published types crate (Mito's deployed launchpad had `SetVaultAddress`/`UpdateProjectDescription` the crate lacked, and `SetQuotePrice` capitalized). Only when the source is genuinely private AND no audit describes the handler do you fall back to byte-tracing — and then you CALIBRATE the decompile against the audit's file:line anchors. The tell: you're reading `dcmp` line offsets and inventing struct field meanings while a public SCV report or a crates.io crate sits un-fetched. (Mito: the SCV report turned 6h of WASM-guessing into an understood system in 20min — and revealed my target bug was a known acknowledged SEVERE finding.)

## 1. THE THREE DOORS — A>B mine the EXPRESSED, C mines the UNWRITTEN

**PRIORITY RULE (state it, obey it):** Doors A and B mine what the devs **expressed** (tests they
wrote, fears they commented); Door C mines what they **never wrote because they believed it held by
construction**. A and B are **co-equal in EXISTENCE** (between them they cover every target-kind —
test-suite-bearing AND comment-only) but **ORDERED in PRIORITY**: if an **adversarial test suite
exists**, **Door A is PRIMARY and MANDATORY** — build the coverage matrix first and exhaust the
N-column before anything else; **Door B activates only when Door A is empty/absent** (no adversarial
tests at all) **or as a post-A complement** once the matrix N-column is exhausted. Never run B
*instead of* A when A is available. The germe's failure mode in the old volet was exactly this
inversion — the test-mining germe was buried as a parenthesis at the tail of the paranoia block.
Door A is the germe. It comes first.

**Door C is NOT in the A>B ordering — it runs in PARALLEL and answers a different question.** A and B
ask *"what did the devs fear, and what's the sibling they forgot?"* — both are bounded by the devs'
own imagination (a test or comment presupposes a threat they CONCEIVED). Door C asks *"what is BIZARRE
and SPECIFIC to THIS protocol that the auditors accepted as normal — what unwritten invariant does
that singularity rest on, that nobody modeled because it has no name?"* The bug Door C finds is
**invisible to A by construction**: there is no "tested sibling" to put it next to, because nobody
ever conceived the threat. **On a fortress that has survived multiple audits in catalogue-mode, Door C
is where the remaining bug lives** — the audits already swept every named class; what's left is the
composition of this protocol's specific design choices that has no CWE. Run Door C on any target whose
design deviates from the canonical form of its type (a hand-posted NAV instead of a derived one, a
park-not-burn queue instead of burn-at-request, a bespoke fee instead of the standard) — i.e. almost
every high-value target worth auditing. **It is the slowest door and the only one that does not
fan-out** (seeing a singularity is *surprise*, which pattern-matching suppresses — see §1 Door C).

### Door A — DEFENSIVE-COVERAGE MATRIX (PRIMARY)

The bounded, enumerable, self-arresting entry. The devs wrote tests to *prove their security to
themselves*; that suite is a finite map of what they feared — and its complement is what they
forgot.

1. **Locate the adversarial test suite.** Cast a wide net:
   ```bash
   # Go / Cosmos-SDK
   find . -path '*interchaintest/security/*' -o -name '*_test.go' | xargs grep -l -iE 't\.Run\("(attack|exploit|malicious|adversar|overflow|reentr|griefing|halt|dos|drain|steal|panic)'
   grep -rln 'func Test.*(Attack|Exploit|Malicious|Security|Invariant|Fuzz)' --include='*_test.go'
   # Solidity / Foundry
   grep -rln -iE 'function test(Fork)?_?(Attack|Exploit|Revert|Cannot|Fail|Steal|Drain|Reentr|Overflow)' --include='*.t.sol'
   find . -name 'invariant*' -o -name '*Invariant*.t.sol'
   # invariant runners (both ecosystems)
   find . -name '*_invariants_check.go' -o -name '*invariant*.go'
   ```
2. **Build the matrix.** Two columns only: `{ money-path fn / runtime invariant }` × `{ covered by
   an adversarial test? Y/N }`. Enumerate the money-movers first (mint/burn/redeem/transfer/
   withdraw/liquidate/settle/auction/socialize/reroute), then the runtime invariants. For each, ask:
   is there a test that *attacks* this exact function/invariant, or merely a happy-path unit test?
   Happy-path = **N**. Only an adversarial test counts as **Y**.
3. **The N column IS the bounded worklist.** This is the whole point — it is finite, it is
   enumerable, it self-arrests. You are not spraying candidates; you are reading a list the devs
   wrote for you in the negative.
4. **The key pattern — sibling they didn't test.** The richest cell: they tested **sibling A** at a
   pattern and **NOT sibling B** at the same pattern. Find one adversarial test, then grep for the
   structural sibling that the test does not cover. That sibling is the candidate.

   **Worked example — injective-core voucher (the Door A win):** four `interchaintest/security/`
   tests covered EVM-halt / reentrancy / precompile abuse — all *held*. The matrix N-cell: the
   **voucher accounting** path (`GetAllVouchers` → auction EndBlock) had **no adversarial test**.
   Mining the gap: KV key was `field‖delim‖addr` parsed with a fixed `addrLen = 20`; a 32-byte
   CW/module address misparses → `sdk.NewCoin(misparsedDenom)` **panics**, not silently undercounts.
   Traced to auction-EndBlock with no recover → **deterministic chain-halt**. Reading-alone rated it
   Medium; *running* the PoC (TEST-don't-READ) revealed the panic → **Critical**. That was the only
   Critical on the target. The 4 tested siblings held; the 1 untested sibling was the bug.

   Grep tells for this class of misparse: `addrLen = 20`, `k[len(k)-20:]`, `sdk.NewCoin(parsedDenom`
   inside iterators.

### Door B — DEV-PARANOIA-MAP (FALLBACK)

Activate only when Door A is **empty/absent** (the repo has no adversarial test suite — common on
thinner-audited or pre-first-audit targets) **or as a complement AFTER the Door A N-column is
exhausted**. When there are no attack tests to mine, the devs annotate their own fear in comments
and runtime invariants. Each annotation = a max-trust × min-verification point + a declared-impossible
state to attack.

```bash
# fear-comments in money-path keepers
grep -rniE 'CRITICAL|should never|must never|must always|impossible|defensive|INCONSISTENT STATE|sanity|invariant|assume[ds]? that|by construction' \
  --include='*.go' --include='*.rs' --include='*.sol' <money-path-dirs>
# runtime invariant runners
find . -name '*_invariants_check.go' -o -name 'Invariant*.sol'
# changelog / fix-commits → adjacent unfixed sibling
git log --oneline -i --grep='fix\|security\|invariant\|overflow\|panic\|halt' | head -40
```

Discipline (these are the lessons that keep B honest):

- **A defensive comment is a LEAD, not a finding.** On a fortress the dev is usually *right*. The
  finding is the **real gap between the dev's stated rationale and the actual code**, not the comment
  itself.
- **Disconfirmer for an invariant = ENUMERATE EVERY WRITER of the guarded state.** Never "by
  inspection." Prove it holds across all writers, or find the one writer that breaks it. Classify the
  finding by **WHO reaches the breaking writer** (untrusted actor = live; admin-only = OOS unless the
  role boundary is exceeded).
- **Severity gate — check the CONSEQUENCE first.** Most violated invariants just **PAUSE / skip /
  log** = fail-safe = DoS-not-theft = often **Info**. Don't PoC a fail-safe as if it were a drain.

  **Worked example — injective-core S4 triple-fault (the Door B null):** a fear-comment said
  "sufficient balance," but the list-builder used `TotalBalance` while the check failed on
  `AvailableBalance` — a *real* documented Total-vs-Available gap, exactly the lead Door B exists to
  surface. Disconfirmer = enumerate every writer of the balance state: all writers were uniform →
  `Available == Total` at every reachable state → the breaking path was **unreachable** → **honest
  null by all-writers enumeration**, not by inspection. That is Door B done right: a real-looking
  lead, killed by the mandatory writer-enumeration, costing one disconfirmer and zero PoC.

### The web/API case — Door A is rarely truly empty, and the thief gate carries more weight

On web/API targets there is usually **no adversarial *unit* test suite to mine** — so it *looks* like
Door A is empty and you fall straight to Door B + the axes. Two corrections keep the germe alive here:

1. **Door A on web = the pentest report's tested-endpoint list, if one exists.** A prior pentest /
   audit report IS the coverage matrix already written: `{endpoint × tested? Y/N}`. The endpoints
   it never lists are the N-column; the auth/tenant-isolation/rate-limit *fixtures* (`*.e2e.spec`,
   `cypress/`, `playwright/`) are the adversarial tests. Build the matrix from those FIRST. Door A is
   empty only when there is no report AND no auth test fixtures at all.
2. **When Door A really is empty (no report, no fixtures), Door B + the axes carry the hunt — and
   that is exactly the case where the axes drift back toward GENERATOR.** There is no test-set
   complement to bound them, so the bound has to come from elsewhere: the **thief-inventory admission
   gate (§2) becomes the primary bound, not a secondary check.** Every axis-surfaced candidate must
   pass the gate's **family-B test for web/human programs** — "chainable to a payable capability: ATO,
   BAC/BOLA/IDOR, auth-bypass, priv-esc, PII/KYC exposure, infra-halt — OR to fund-movement?" — before
   it earns a probe, otherwise the web hunt re-collapses into the contemplative spray. **Do NOT read
   the gate as fund-movement-only here** (that is the corrected §2 blind spot — on a web/human program
   the payable capability IS the impact, no `loss = $X` needed; killing an ATO/BAC/PII primitive
   "because no funds move" is the exact miss this correction closes). (Injective web, 2026-06-10: no
   attack suite → Door A empty → axis-1 *stated-assumption* surfaced P-W9 — the BFF issues a JWT for
   `granterAddress` but may only verify the signature proves possession of `sender` → authz
   impersonation / ATO. It survived as a lead because it chained to a concrete **family-B** ATO — NOT
   to fund-movement; under a fund-movement-only gate it dies. It became the operator's triaged High
   #134. The dozen other axis-1 observations that chained to neither family were noted, not probed.)

### Door C — UNWRITTEN-INVARIANT MAP (thief-mode, not catalogue-mode)

**The germe of Door C (the operator's own framing):** *"There are patterns any serious team knows.
A real thief doesn't read the catalogue; he looks at what THIS protocol does that is unique, and
abuses the precise thing nobody modeled because it has no name. Stop asking 'which pattern applies'
and ask 'what is BIZARRE and SPECIFIC to this target that the auditors accepted as normal' — the
invariants they never wrote because they believe they hold by construction."*

**Why A and B can't reach it.** Door A mines the tests they wrote; Door B mines the fears they
commented. Both are bounded by what the devs *conceived* — a named threat. The catalogue bug (a
known class: NAV-update sandwich, first-depositor inflation, rate-read-before-slash) is findable by
reading the catalogue better than the auditors did; it is real work but it is *completeness of the
catalogue*, not discovery. Door C's bug has **no CWE, no name, no test, no fear-comment** — it is the
*composition* of this protocol's specific design choices that nobody modeled. It is invisible to Door
A *by definition*: there is no tested sibling beside it.

**The 4-step mechanic (run it in this order — it does NOT fan-out to agents; a model that
pattern-matches suppresses the surprise that seeing a singularity requires):**

1. **Establish the canonical form.** What does a *normal* instance of this protocol-type look like?
   (A normal lending-vault DERIVES its NAV from an oracle/on-chain read; a normal redeem queue burns
   at request; a normal vault charges the standard withdrawal fee.) Write the canonical shape down.
2. **Diff the target against canonical — list every DEVIATION.** Each place this protocol does
   something non-standard is a candidate: the NAV is *posted by hand* not derived; the queue *parks*
   shares not burns; there is a *bespoke* instant-redemption fee; a *dead post-check* (an `allowance
   == 0` guard masked by an earlier `safeApprove(0)` reset) — a dead check is a fossil of an abandoned
   fear, dig it. Singularity ≠ complexity: the complex named mechanisms are the MOST-lit; the dark
   place is the *bizarre-but-trivial-looking* choice every reviewer waved past.
3. **For each deviation, make the UNWRITTEN INVARIANT explicit.** State the belief that makes the
   deviation *safe in the dev's mind* — the thing they never wrote as an invariant because they
   believe it holds by construction. (Hand-posted NAV → unwritten belief: *"the posted value always
   faithfully reflects what LPs can recover."* Park-not-burn queue → *"the queue's price-lock is
   symmetric."* The tell you've found a real one: the dev's own comment defends ONE side of the
   belief and is silent on the other — see the worked example.)
4. **Attack the belief, by an UNTRUSTED actor.** Find the reachable state where the unwritten
   invariant is FALSE. The bug is not in any single deviation; it is in the *composition* of two or
   three of them that no review whole-viewed. Then it rides the normal conveyor: thief-inventory (§2)
   → manual loop (§4) → unbiased PoC with `loss = $X` → kill-gate → signed verdict.

**Worked example — F-STALE-NAV-REDEMPTION-ARB (the Door C win that A/B and a full catalogue-mode
pipeline all missed).** Target: August Oraclized vaults (coreUSDC/upGAMMA, TokenizedAccount impl).
- **Canonical (step 1):** a normal vault derives NAV continuously from an on-chain read.
- **Deviations (step 2):** (a) `externalAssets` is *posted by hand* by a single operator via
  `updateTotalAssets`, discrete and laggy (mean 2.7d, up to 12.1d between posts; upGAMMA was 9.5d
  stale live); (b) `requestRedeem` with `lagDuration>0` *parks* shares and *freezes* the claim
  amount at request-time pps (`_receiverAmounts[cluster][rcv] = assetsAfterFee`), paid verbatim at
  claim (`_claim` L2324 `safeTransfer(rcv, claimableAssets)` — **no re-pricing**); (c) the real
  strategy value (the Gamma LP) moves *continuously and is readable on-chain*.
- **Unwritten invariant (step 3):** *"the queue's price-lock is symmetric."* The proof the devs
  believed it by construction is in their OWN comment at `_registerRedeemRequest`: *"We transfer the
  shares to the liquidity pool in order to avoid fluctuations on the token price"* — they reasoned
  ONLY about protecting the request-instant pps from the burn, and were SILENT on whether the frozen
  amount stays faithful to real value during the lag. One side defended, the other side never
  written.
- **Attack the belief (step 4):** the lock is symmetric *in theory*, one-directional *in the hands of
  anyone who reads the chain*. A holder who reads on-chain that real value dropped below the posted
  NAV does `requestRedeem` to freeze the exit at the stale-high price BEFORE the operator posts the
  drop; the loss lands entirely on the holders who didn't exit. Fork PoC (real upGAMMA, real
  operator): thief queues at stale pps → realizes 999,999 (+99,999 over fair) while a passive victim
  is marked to 861,395 (−38,604 under fair); the disconfirmer that bounds it — flat-capital
  deposit-then-queue nets ZERO (enter and exit at the same stale pps) → it requires a PRE-EXISTING
  position → honest verdict **Medium, informed-redemption arbitrage** (passive→informed
  socialization), not "anyone drains the vault." Four audits + a catalogue-mode pipeline missed it;
  the closest prior finding (F-14334, stale subaccount valuation, *Accepted*) saw the staleness but
  read it as "owner re-values as needed," never as "the lag IS an exit-arbitrage window via the
  queue" — **the composition is the bug, and the composition has no name.**

**Door C discipline (keeps it honest, same spirit as A/B):**
- **A deviation is a LEAD, not a finding** — most non-standard choices are deliberate and safe. The
  finding is the reachable state where the *unwritten* invariant breaks, proven by PoC, not the
  weirdness itself. Run the disconfirmer that bounds it (F-STALE: flat-capital = net-zero killed the
  "anyone drains" framing → honest Medium).
- **Classify by WHO reaches it.** F-STALE survives because the down-move is an EXOGENOUS strategy loss
  readable by any holder and `requestRedeem` is permissionless — the attacker front-runs the
  *recognition*, does not *cause* the loss. If the only actor who can reach the broken state is the
  operator/admin, it's OOS unless a role boundary is exceeded (same gate as B).
- **The unwritten invariant is usually a COMPOSITION of 2-3 deviations**, each audited *alone* and
  *accepted*. The shared-root frame (§2) is natural here: one root (e.g. "discrete hand-posted
  single-operator NAV with no real-price bound") spawns several findings (sandwich-the-post,
  brick-the-post, arbitrage-the-stale-gap) — report the root + each independent consequence.

## 2. THE THIEF INVENTORY — the admission gate (fused with chain-triage)

This is the validator the old volet lacked. The old §🌑 *localized* dark places but never *validated*
chainability — so it produced contemplative candidates that went nowhere. The thief inventory is the
gate every A/B/C candidate must pass before it earns a single line of PoC.

1. **Every A/B/C candidate → a primitive `Pn`** in a running inventory. Not "a bug" — a *primitive*: a
   thing you can STORE toward a theft (a panic you can trigger, a state you can desync, a value you
   can read that you shouldn't, a check you can skip, a window you can open, **a stale value you can
   exit against before it updates**). Door C's candidates are *broken unwritten invariants*; they
   enter the inventory exactly like A/B's, and the same admission gate applies.
2. **ADMISSION GATE (the one question — corrected 2026-06-11, the operator's "even during the hunt
   it must be missing findings"):** *"Does this untested / dark place hand me a primitive I can STORE
   toward a concrete PAYABLE-IMPACT path — **fund-movement OR a payable capability** — even via
   chaining?"* If it chains to neither (and chain-triage finds no pairing that gets it there) →
   **note it, spend NO PoC.** This turns the bounded N-column into a *bounded fundable* list.

   **The admitted-impact set is NOT "fund-theft only" — that narrow reading is a HUNT-TIME blind spot,
   not just a scoring error.** Because this gate runs *during* the hunt ("spend NO PoC" = stop
   digging), a "fund-movement-only" reading makes an agent ABANDON a real finding at the primitive
   stage — it is never PoC'd, never found, not merely under-scored. Two impact families are admitted,
   and which one governs is decided by the **program class** (see `[[capability-vs-view-the-paying-vein]]`,
   the authority on this — read it before applying this gate):
   - **A — fund-movement** (the SC/DeFi-contest default): theft, drain, mint, freeze/halt-of-funds,
     stale-value arbitrage, suppressed-credit, double-front, bad-debt socialization, **quantified
     griefing / DoS with a `$` figure**. Any value that moves, is extracted, is frozen, or is denied.
     On Code4rena / Cantina-SC / Immunefi-DeFi this family is the whole gate — a finding with no
     `loss = $X` dies at triage, so admit only family A and the money-flow prefilter stands.
   - **B — payable capability** (the web/API / human-triager families: HackerOne, public Cantina,
     HackenProof, bug-bounty web programs): **ATO / session-takeover, broken access control / BOLA /
     IDOR, auth bypass, privilege escalation, PII / KYC / sensitive-data exposure, infrastructure
     halt / bridge-freeze** — a CAPABILITY the attacker acquires (acts as another, removes a
     protection, reads what they must not), with **no `loss = $X` required**. These PAY on their
     programs and the family-A reading would KILL them at the primitive stage. Helix #134 (the
     operator's triaged High) is exactly family B — an ATO with no fund-movement; the un-amended gate
     would have killed it. S-23 (bridge-halt, valid+patched) is the freeze edge of A/B.

   **Apply at hunt time, not just scoring:** before writing "spend NO PoC" on a primitive, check it
   against BOTH families for the *current program's class*. Only "chains to neither A nor B for this
   program" earns the no-PoC note. Tell you mis-applied the narrow gate: you caught yourself dropping
   an ATO / BAC / PII / auth-bypass / halt primitive "because it doesn't move funds" on a web/human
   program — that is the blind spot this correction exists to close.
3. **Hunt PAIRS.** Inventory every weak/OOS/Acknowledged/Low/dark primitive — even ones dead alone.
   Then hunt: does `Pa` supply the *trigger / reachability / window / amplification* that `Pb` lacked
   alone? Critical-pair heuristics: auth-gap + value-move · oracle-blindness + liquidation path ·
   dedup/replay + signed financial action · share-math edge (div-0, totalSupply==0) + vault withdraw
   · bad-debt-socialization + supplier-exit/dust · a fix that closed ONE path while a SIBLING path
   reaches the same impact un-mitigated.
4. **The prize is a shared ROOT, not a magic Critical.** Multiple weak primitives feeding ONE root
   cause = a single coherent higher-severity thesis, far more defensible than any one alone. Report
   format when chained: `STANDALONE: Medium (x) / CHAINED: High (y)` + explicit chain path
   `[A] → [pivot] → [B] → concrete impact` + the `loss = $X` of the chained impact.
5. **ANTI-INFLATION (mandatory, symmetric to the executed disconfirmer).** A chain is real ONLY if
   **every hop is executed/proven** AND **the attacker nets positive.** Dismantle your own chain
   before believing it. **Zest worked example:** a "bank-run free-money" CHAIN-A looked Critical, but
   dust didn't bypass `is-healthy`, couldn't open underwater, and creating bad debt still cost the
   attacker collateral → the dust primitive was a *timing aid*, not free money → honest verdict
   **Medium/High, not Critical.** A chain you can't net-positive-prove is the same LLM-garbage as an
   un-executed dismissal, just in the other direction. Scope still governs every hop (an OOS hop —
   oracle, DAO — can only participate if a later in-scope untrusted-reachable hop carries the impact).

## 3. THE 5 AXES — per-candidate ANALYZER (NOT generator)

**Demotion stated explicitly:** in the old volet the 5 axes were the *generator* — noisy, unbounded,
they sprayed candidates everywhere and produced the 5 injective nulls. Here they are **demoted to an
analyzer that reads ONE bounded candidate** already admitted by Door A/B/C + the thief inventory. Their
job is to explain **WHY this candidate is dark** and **HOW to attack it** — never to invent new
candidates.

**Axis-1 vs Door C — do not confuse them (different altitudes).** Door C is a *generator* that walks
the protocol's design DEVIATIONS to surface a broken unwritten invariant as a new candidate; the
*Stated-assumption axis* below is an *analyzer* that, given an ALREADY-ADMITTED candidate, asks what
the spec/comment asserts about THAT candidate. Door C produces the candidate ("the queue-lock is
believed symmetric — attack that"); the axis then sharpens it ("the comment defends the request-pps
side only"). Run Door C to FIND it; run axis-1 to UNDERSTAND it. Never use axis-1 as a generator —
that is the old contemplative failure mode; Door C is the disciplined, design-anchored generator.

| Axis | Per-candidate question (applied to ONE admitted candidate) |
|------|------------------------------------------------------------|
| **Stated assumption** | What does the spec/README/comment *assert as true* about this candidate, that the code doesn't actually enforce? (injective: "sufficient balance" asserted, Total-vs-Available not enforced. F-STALE: the `_registerRedeemRequest` comment asserts the park "avoids price fluctuation" — true for the request instant, silent on the lag window.) |
| **Inter-review boundary** | Does this candidate straddle two reviews/auditors/layers where each assumed the other covered the handoff? (the seam — audited-code↔deployed-config, lang-A↔lang-B binding, on-chain↔off-chain keeper) |
| **Unquestioned surface** | Was this candidate reviewed under ONLY ONE lens (correctness / rounding) but never under the *extraction* lens (MEV, cross-fn, untrusted-actor)? Re-derive a NEW impact. |
| **Absence** | The mirror invariant: grep the guard's *presence* on the N-1 sibling paths, then find the bare Nth path where it's absent. (Rule 41 — a file is not "clean" without a written `V_in vs V_out` line.) |
| **Temporal** | Does an edge/transition state (cache-cold, same-block, first/last actor, mid-migration, EndBlock window) make the candidate reachable when steady-state hides it? |

SC / web / off-chain concrete forms of each axis live in the tactical doc. Apply only the axes that
fit the candidate; do not force all five.

## 4. THE MANUAL LOOP (per admitted candidate)

Reused as-is from DARKSIDE-HUNT.md — the per-candidate descent. Summary (full steps in the tactical
doc):

1. **GATE#0 — trusted-reachable?** Hoist this FIRST. Can an *untrusted* actor reach the breaking
   writer/path? Admin-only = OOS unless a role boundary is exceeded. Kills ~half the inventory near-free.
2. **SCOPE-SPLIT** — confirm the involved sets actually overlap / the path is in deployed scope.
3. **TRACE attack → BREAK** — trace entry point to the exact line that breaks, in the DEPLOYED build.
4. **HYPOTHESIS + DISCONFIRMER on the LOAD-BEARING leg** — aim the disconfirmer at the leg the claim
   rests on, not an adjacent dead one. (dre-labs sibling: the transient ReentrancyGuard slot is
   per-address — re-entering the *sibling* vault, not the manager, is the load-bearing leg.)
5. **Unbiased PoC, `loss = $X`** — fork/simnet with config parity to deployed (real rates, egroups,
   staleness, caps, decimals, bitmap), no mocks on the tested leg, baseline + honest victim in the
   same PoC, attacker pays full freight, price/time via the REAL mechanism, selectors/addresses/slots
   verified at submit block. **Solv SOLVPR-297 control:** the unbiased control for a web-auth BFLA was
   proving the *same token* returns 200 on a benign resolver (`stats`) → the token is VALID, the 401
   is a *targeted* auth refusal not a dead token. Without that control a skeptic dismisses the gap.
   **GENUINE-PAIR-FIRST (OKX adapters, 2026-06-11) — the plant-shortcut, in the dark-corner form.** Before
   any draft, execute the WHOLE chain ONCE on the REAL deployed contract + its REAL counterparty + REAL
   production params/routing, and read the observed state. A two-halves PoC bridged by `deal()` + a stand-in
   reads 5/5 PASS while the end-to-end never happens in prod. The OKX adapter "unguarded callback → scoop
   stranded surplus" reached a finished Medium report, then died on the genuine pair: the *stranding* half was
   proven on a REFUND adapter with the suffix omitted, the *drain* half on a different adapter from a `deal()`-ed
   balance; run on the actual routed pair with real params, production routes `sqrtX96=0` (full-consume) →
   residue = 0 → the precondition the finding needs NEVER occurs → theoretical → KILL. Tells you took a stand-in:
   "I used adapter X because its selector matches the pool I fork" (a genuine adapter is called ONLY by its own
   dex's pool — borrowing a selector = NOT the real path); stranding and drain on different contracts; the
   precondition `deal()`-ed not produced by a real routed call; deployed code ≠ repo-main (the deployed OKX
   adapter reverted `SafeTransferFailed` where repo-main's transfer drained). **Liveness + genuine-precondition
   are reachability gates — run them FIRST, never deferred to "the team can do a balanceOf sweep" (that deferral
   is the impact-confirmation-outsourcing a triager downgrades for).**
   **HARNESS + SUSPEND when the deciding step needs an action you cannot run (Helix #134, 2026-06-11).** When the
   load-bearing leg needs a signature (EIP-191/712/SIWE), a broadcast tx, an authz grant, a wallet/browser drive,
   or any self-owned probe needing the operator's keys, do NOT convert "I can't execute this leg" into "this leg is
   dead / unreachable / latent" — they are categorically different. Do EVERYTHING keyless first (model the RAW
   attacker request not the UI happy-path, build the signer, all read-only/`cast`/`curl`/LCD verification, the
   keyless disconfirmer); then deliver THREE things for the last key-needing step: (1) the EXACT runnable harness
   (copy-paste, real addresses/endpoints/nonce-flow, not pseudo-code), (2) the precise instruction (what to
   broadcast/sign/click + which output to observe), (3) `VERDICT: SUSPENDED — pending [exact action]`. The branch
   shelved as "unreachable" on #134 (P-W9 "needs an external wallet" = FALSE; `sender`=any throwaway key + a
   good-type grant = direct-API-reachable) was the operator's submitted High once executed. (Destructive /
   third-party-data / rules-forbidden probes stay un-auto-run — distinct guard.)
   **PROVE AN ATO/session-takeover BY EQUIVALENCE, not by faking content (Helix #134).** A PoC on an EMPTY test
   account proves only the MECHANISM (you can enter the room), not the IMPACT (what's in it). Don't fill the
   account to fabricate impact, and don't guess a write-schema blind after 2 ZodError fails (that's acharnement).
   Instead: mint two sessions for the SAME victim — one the LEGIT way (a credential the victim granted, signing the
   victim's own challenge = the victim's real session), one the ATTACKER way (a fresh attacker credential) — and
   hit the same routes with each. Byte-identical responses prove the attacker holds a functionally identical copy
   of the victim's session, independent of account contents (empty → both empty; full → both full). This is
   content-independent and beats filling the account. #134: 6/6 routes byte-identical, `/user/me` identical to the
   millisecond. (The equivalence is itself load-bearing → show one FULL body-pair, never `200 {...}` both sides;
   see `report-nerve § Triager response Rule 4`.)
6. **KILL-GATE Q1–Q10** — design intent, reachability, disjoint sets, existing guards, trigger
   feasibility, industry-known, upgradeability, auditor cross-ref, post-audit dating, on-chain state.
7. **FULL-CORNER closure** — do not stop at the happy path; push extremes (0, 1, max-u128, dust,
   decimals mismatch, empty-set, single-element, same-block, cross-asset, first/last actor). The bug
   lives at the boundary. **Morpho liquidation:** the value was the *consistency* across collateral
   handlers, not any single bug — mirror-asymmetry across siblings, one report shared-root.
8. **SIGNED VERDICT** — D9 adversarial rebuttal, READY_TO_SUBMIT or DOWNGRADE/KILL.

## 5. EXIT — drop-on-EV ≠ drop-on-fatigue

Reused as-is. A surface dies on **EV** (every admitted primitive in the inventory chains to no theft,
or every chain fails anti-inflation/scope) — not on **fatigue** ("this is taking long, probably
fine"). The trigger phrase to DIG, not conclude, is catching yourself about to write
"OOS / REFUTED / probably / likely fine / solid / skip" on a surface you have not run code against.

**dre-labs #1259 worked example (the exit gate done right):** the corner was driven to the bottom —
the load-bearing leg (re-entering the *sibling* vault via `onERC721Received`, not intra-manager) was
*executed* under `-vvvv` to confirm the in-callback action really fired (real Transfer events, real
entry, no underfunding), snapshot/revert equalized only PRE-attack state, and a 1-wei drift was traced
to a sequencing artifact and *fixed*, not ignored. The exit was an EV/proof decision on an executed
corner, not a fatigue drop. Full step text and the negative-results template are in the tactical doc.

> **MANDATORY before ANY null/drop verdict: re-run §0.5 (THE HUNTER'S OWN DARK SIDE) on yourself.** This is the exact moment your own dark side fires — the "fortress / OOS / kill / no-submission" you're about to write is the fake wall §0.5.1 warns about. Before the verdict ships: (a) every dismissed surface has an EXECUTED artifact, not a reasoned wall (§0.5.1); (b) every `onlyOwner`/privileged dismissal survived the BECOME-THE-ACTOR pass (§0.5.2); (c) every kill rests on a PoC you RAN that is unbiased + has a disconfirmer (§0.5.3); (d) no "whole-target fortress" claim while an in-scope surface is unexecuted (§0.5.4); (e) every multi-step PoC's PIVOT was read-back-verified to have actually moved the deciding state — no silent no-op masquerading as a refutation (§0.5.7). If the operator would push and find a window, you haven't earned the null. Be your own disconfirmer so they don't have to be.

## Skill Resources / dependencies

| Resource | Location | Purpose |
|----------|----------|---------|
| **DARKSIDE-HUNT.md** | `~/.claude/skills/darkside/DARKSIDE-HUNT.md` | The tactical doc — full Gate §0 fortress criteria, the 8-step manual loop in full, the 5-axes SC/web/off-chain forms, the negative-results / NO-GO template |
| **firmaudit** | skill | References this skill at Pass-1 on audited targets; chain-triage primitive-inventory machinery lives in firmaudit §🔗 (the thief inventory in §2 fuses with it) |
| **gravedigger** | skill | The broad manual dark-corner sweep that MAPS terrain before darkside DIGS |
| **exploit-primitive-mindset** | skill | Class-before-code framing — read at intake so the thief inventory knows what theft-primitive THIS protocol-type even permits |
| **report-nerve / chill** | skills | Structure + human-triager voice once a candidate survives to a report (chill for HackerOne / public Cantina / HackenProof; skip for Cantina-private / GHSA / IACR) |

## FAIL-FAST DIRECTS effort, never RETAINS it

Closing guard — the non-defeatist core. Fail-fast is **PRO-digging**, not pessimism. A gated branch
(Door A N-cell turns out covered after all; an invariant proven to hold by all-writers enumeration; a
price-staleness branch killed by a live read showing feeds are never stale) **REDIRECTS the effort to
the sibling branch of the SAME surface** — it never condemns the surface. Dup-risk is a SOFT prior
directing WHERE the deep hours go, never a "don't dig here" (and on private programs dup is only known
*after* submission). The corrosive tell to catch in yourself: "skip / fortress / not-worth-the-day /
move-on" about a SURFACE before executing its branches. The pro version: "branch X gated by [executed
read], redirecting to branch Y of the same surface." **Judge the fortress AFTER searching it, by
executed artifact — never before, by reasoning.**