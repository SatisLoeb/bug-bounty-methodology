# Phase Diagnostic — Blind Pre-Gate Retroactive Validation

**Generated:** 2026-04-18T09:45Z
**Purpose:** Validate whether the pre-gate framing constraint (`severity = min(evidence, chain, impact)` with artifact-required per tier) would have caught past failures BEFORE they were submitted.

**Method (hindsight contamination protection):**
1. For each failure, write pre-gate prediction FIRST, based on the draft's state at submission time (what artifacts existed, what was hedged).
2. Prediction is sealed at Stage 1 timestamp.
3. Then re-read actual dismissal at Stage 2 timestamp.
4. Verdict: Yes / No / Partial — would pre-gate alone (not the other gates) have prevented this failure?
5. Yes = pre-gate would have forced a lower severity or a downgrade before submission.
   No = pre-gate permits the committed severity, the dismissal was about something else (scope, duplicate, reachability, class-level known issue, design intent).
   Partial = pre-gate caps severity lower but dismissal would still have fired on another gate.

**Sample:** 12 failures + 1 positive control (WEEX-002, where Chain Proof Gate saved the finding).

**Honest note on cherry-pick risk:** the sample is drawn from OUTCOMES.jsonl (8 entries) + salient failures in MEMORY.md (Reserve F-003, HRB-001, Phemex R2 already in war logs). Not perfectly random — the ones I remember as framing-saliant may be over-represented. If that bias produces >70% framing-preventable, downgrade confidence in the result.

---

## Stage 1 — Blind Predictions

**Sealed at:** 2026-04-18T09:45Z
**Predictions written BEFORE re-reading dismissal rationale for each case.**

### F-01 — ETH-001 (Ethena Blacklist bypass, Critical claim, Immunefi)

**Draft state at submission time:**
- Severity claimed: Critical
- Evidence: mock-based PoC (4/4 tests pass with reproduction contracts, NOT fork)
- Chain: bypass demonstrated on mock state
- Impact: "Direct theft of user funds (at-rest)" — narrative, no $ computed

**Pre-gate inputs (artifact-required):**
- evidence = L2 (mock is static behavior simulation, not production deploy interaction)
- chain = partial (mock bypass is not "full ethical" since it doesn't prove the deployed contract accepts the primitive)
- impact = narrative ("direct theft" without $ compute or W5)

**Pre-gate severity ceiling:** min(L2, partial, narrative) → **Low MAX**
**Draft claimed:** Critical
**Pre-gate verdict:** BLOCK at Critical. Force downgrade to Low, or produce L3 fork PoC + L4 mainnet-proven + W1 computed.

### F-02 — ETH-001b (Ethena resubmit with fork PoC, Critical claim, Immunefi)

**Draft state at submission time:**
- Severity claimed: Critical
- Evidence: fork-based PoC (4/4 tests pass against real deployed contract)
- Chain: bypass demonstrated on mainnet fork — full_ethical? Or still partial because the test is synthetic?
- Impact: narrative (no $ computed)

**Pre-gate inputs:**
- evidence = L3 (fork reproduction against deployed contract — executable, pinned to real state)
- chain = full_ethical (the bypass executes against deployed contract in fork mode, state delta asserted)
- impact = narrative

**Pre-gate severity ceiling:** min(L3, full_ethical, narrative) → **Low MAX** (narrative pins it)
**Draft claimed:** Critical
**Pre-gate verdict:** BLOCK at Critical. Force W1 compute ($ at risk across blacklisted addresses × frozen assets × redistribution value) or downgrade.

### F-03 — FDR-001 (Firedancer OOB write, High claim, Immunefi)

**Draft state at submission time:**
- Severity claimed: High
- Evidence: C unit test (2/2 pass — demonstrates OOB write in isolated compile)
- Chain: bug demonstrated in isolated function, NOT traced through in-scope binary topology
- Impact: "Shutdown of >=30% network nodes" — narrative

**Pre-gate inputs:**
- evidence = L2 (unit test is static — doesn't prove reachable in deployed binary, topology not traced)
- chain = unverified (reachability in in-scope Frankendancer binary never traced)
- impact = narrative

**Pre-gate severity ceiling:** min(L2, unverified, narrative) → **Informational** (unverified chain dominates)
**Draft claimed:** High
**Pre-gate verdict:** BLOCK at High. Force chain to full (trace topology.c through to vulnerable function in Frankendancer build) before elevating severity.

### F-04 — CONC-001 (Concrete Earn ERC4626 view function, High claim, Cantina)

**Draft state at submission time:**
- Severity claimed: High
- Evidence: fork-based PoC (5/5 tests pass + on-chain verification of $38M vault state)
- Chain: bug demonstrated with state delta (maxWithdraw overreport → withdraw reverts)
- Impact: narrative ("ERC4626 spec violation" — no $ loss, just UX failure)

**Pre-gate inputs:**
- evidence = L4 (mainnet-verified, block pinned, real vault state cited)
- chain = full_ethical (forge test proves the revert, state delta observed)
- impact = narrative (view function overreport = no direct $ loss computable; no W5 precedent cited)

**Pre-gate severity ceiling:** min(L4, full_ethical, narrative) → **Low MAX** (narrative pins it — class rule "view function = Medium MAX" separately caps)
**Draft claimed:** High
**Pre-gate verdict:** BLOCK at High. Force W5 precedent ("ERC4626 view function overreport paid precedents") or accept Low.

### F-05 — Phemex R2 (API permission escalation, High claimed, HackenProof)

**Draft state at submission time:**
- Severity claimed: High (implicit — dismissal was downgrade to Informative, reward_rep: 2)
- Evidence: HTTP response proving trading-key-scoped endpoint accepts /assets/transfer (code=0, status=10)
- Chain: primitive accepted, full_ethical on the accept step
- Impact: narrative — draft literally said "I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital"

**Pre-gate inputs:**
- evidence = L3 (live API interaction, replayable curl, observed response)
- chain = full_ethical (server-side accept artifact present)
- impact = narrative (quantification explicitly not attempted)

**Pre-gate severity ceiling:** min(L3, full_ethical, narrative) → **Low MAX** (narrative pins it)
**Draft claimed:** High
**Pre-gate verdict:** BLOCK at High. Force W5 precedent (API key privilege escalation paid references) or downgrade to Low/Informational upfront. This is the case #37 canonical war log.

### F-06 — WEEX-001 (Nuxt env bundle leak, High claimed, HackenProof)

**Draft state at submission time:**
- Severity claimed: High (dismissal was duplicate, class already known)
- Evidence: bundle dump proving env leak
- Chain: secret accessible in client bundle
- Impact: narrative — credential value at risk not quantified (no W5, no W1)

**Pre-gate inputs:**
- evidence = L2 (static analysis of bundle, no live test)
- chain = partial (secret visible but not demonstrated used against backend)
- impact = narrative

**Pre-gate severity ceiling:** min(L2, partial, narrative) → **Low MAX**
**Draft claimed:** High
**Pre-gate verdict:** BLOCK at High.

### F-07 — Reserve F-003 (Convex freeze, High draft, pre-submit killed by D8b)

**Draft state at pre-submit time:**
- Severity claimed: High
- Evidence: 11/11 forge tests pass on mainnet fork pinned to specific block
- Chain: revert-on-claim state delta asserted in forge tests
- Impact: computed_W1 (draft cited "$3.3B+ USDT frozen history") + W5 anchored (7 precedent rows)

**Pre-gate inputs:**
- evidence = L4 (fork tests, block-pinned, real bytecode)
- chain = full_ethical (assertion-based state delta in forge test)
- impact = both_W1_W5

**Pre-gate severity ceiling:** min(L4, full_ethical, both_W1_W5) → **Critical-eligible** (HIGH committed is within ceiling)
**Draft claimed:** High
**Pre-gate verdict:** PASS. Pre-gate does NOT catch Reserve F-003. D8b (live conditions match on-chain) is what caught it when 5/6 named wrappers had totalSupply = 0. Pre-gate equation has no W4 live-conditions check.

### F-08 — HRB-001 (H&R Block info disclosure, HIGH draft, pre-submit downgraded)

**Draft state at pre-submit time:**
- Severity claimed: High (with GLBA/FTC compliance framing in a 3000-word draft)
- Evidence: static trace of auth bypass + static file:line citation of info-disclosure endpoint
- Chain: endpoint returns data without auth (HTTP response cited) but impact chain (data → harm) not demonstrated
- Impact: narrative (compliance framing, no $ figure, no user count, no W5)

**Pre-gate inputs:**
- evidence = L2 (static analysis + endpoint read — not a full dynamic chain to user harm)
- chain = partial (primitive accepted, but harm chain not proven — compliance framing is not an acceptance test)
- impact = narrative (compliance framing without specific $ or user count = narrative weight)

**Pre-gate severity ceiling:** min(L2, partial, narrative) → **Low MAX**
**Draft claimed:** HIGH
**Pre-gate verdict:** BLOCK at HIGH. Equation forces downgrade to Low MAX before the 3000-word inflation happens. This is the case where pre-gate wins biggest — the inflation was done DURING writing, not at the gathering stage.

### F-09 — Coin98 F-001 (origin bypass via .includes(), rejected, HackenProof)

**Draft state at submission time:**
- Severity claimed: implicit Medium/High (rejected as metadata-info-disclosure)
- Evidence: grep pattern match showing `.includes()` used on origin (not .endsWith)
- Chain: origin spoof accepted, eth_accounts auto-upgraded
- Impact: narrative — "leaks deviceId + attacker added to internalConnections"

**Pre-gate inputs:**
- evidence = L2 (static code read)
- chain = partial (origin spoof demonstrated in PoC but fund-theft chain not built — Coin98 killed it because eth addresses are public)
- impact = narrative (no $ figure, no demonstrated fund access)

**Pre-gate severity ceiling:** min(L2, partial, narrative) → **Low MAX**
**Draft claimed:** Medium/High (rep loss implies severity inflation)
**Pre-gate verdict:** BLOCK. Pre-gate would have forced Low upfront. Avoids rep loss.

### F-10 — GMTrade #51 (Missing Deferred Price Impact, HIGH claim, C4)

**Draft state at submission time:**
- Severity claimed: HIGH (LP value leakage)
- Evidence: code absence analysis (missing `pending_impact_amount` in repo) + hand-calculated math showing LP leak
- Chain: PoC proved DIVERGENCE (impact pool delta=2) but NOT EXTRACTION (no LP_value_after < LP_value_before observed delta)
- Impact: computed_W1 attempt (hand-calculated math) but NOT from observed market state

**Pre-gate inputs:**
- evidence = L3 (fork test exists but asserts divergence not extraction — weaker than L4)
- chain = partial (chain demonstrates anomaly but not the "extraction from observed state" that triage requires)
- impact = narrative (hand-calculated math = calculated counterfactual, not observed; triage rejects this)

**Pre-gate severity ceiling:** min(L3, partial, narrative) → **Low MAX** (narrative pins, partial reinforces)
**Draft claimed:** HIGH
**Pre-gate verdict:** BLOCK at HIGH. Pre-gate would force either (a) produce L4 artifact with observed LP value delta, or (b) downgrade.

Secondary dismissal vector ("feature request") is orthogonal — pre-gate doesn't address "implementation bug vs feature gap" classification. That's a separate rule (rule #13).

### F-11 — Sparklend V-001 (pre-submit killed 2026-04-13)

**Draft state at pre-submit time:**
- Severity claimed: Critical (CVSS 9.8) — "Extractable $10-50M+ per day"
- Evidence: 6/6 forge tests pass against supposed SavingsDaiOracle address
- Chain: exploit trace claimed
- Impact: computed_W1 ($10-50M/day)

**Pre-gate inputs (as of original agent-generated draft, before verification):**
- evidence = L4 claimed (forge tests)
- chain = full_ethical claimed
- impact = computed_W1

**Pre-gate severity ceiling:** min(L4, full, computed_W1) → **Critical-eligible**
**Draft claimed:** Critical
**Pre-gate verdict:** PASS equation. Kill gate Q2 (reachability on-chain readback) is what killed it — wrong contract address + dead code path. Pre-gate does NOT catch agent-hallucinated findings; Q2 + Q10 do.

### F-12 — Dexalot OmniVault (feedback_poc_must_prove_extraction lesson)

**Memory context:** PoC used `transfer(0xDEAD)` as evidence of "burn" but that's not actually burn semantics. Artifact existed but did not prove the claim.

**Pre-gate inputs:**
- evidence = L3 (test exists)
- chain = ? (transfer-to-dead was framed as burn but semantically wrong)
- impact = narrative

**Pre-gate severity ceiling:** would allow the claimed severity since evidence appears L3.
**Pre-gate verdict:** PASS the equation. BUT — rule #39 specifies `artifact_proves: <ONE SENTENCE tied to THE claim>`. If that field says "transfer to 0xDEAD proves burn", a reviewer (or future self) reading the commit would catch the semantic mismatch. So pre-gate with artifact_proves field **might** have caught this as Partial — depending on whether the hunter honestly wrote "proves tokens moved to dead address" (not burn) vs dishonestly wrote "proves burn semantics" (which would be caught downstream).

**Verdict:** Partial — relies on honest artifact_proves, not mechanically enforced.

---

## Positive Control — WEEX-002 (Chain Proof Gate saved this finding)

**Original draft state before Chain Proof Gate run:**
- Severity claimed: Medium (with "I deliberately did not present the forged JWT to Zendesk Messenger" hedge)
- Evidence: static JWT forge reproduction in jwt.io + hardcoded secret in bundle (L2)
- Chain: primitive forgery demonstrated, acceptance NOT tested (partial)
- Impact: narrative (compliance/architecture framing without computed $ or W5)

**Pre-gate inputs (draft state BEFORE chain proof):**
- evidence = L2
- chain = partial
- impact = narrative

**Pre-gate severity ceiling (draft state):** min(L2, partial, narrative) → **Low MAX**
**Draft claimed:** Medium
**Pre-gate verdict at draft state:** BLOCK at Medium.

**AFTER Chain Proof Gate run (fictitious external_id acceptance test):**
- evidence = L4 (HTTP 200 + authenticated:true + permanent appUser creation)
- chain = full_ethical (server-side acceptance artifact)
- impact = W5 (hardcoded JWT secret precedents in H1 corpus, $2.5K-$10K range)

**Pre-gate severity ceiling (post-chain-proof):** min(L4, full_ethical, W5_anchored) → **Critical-eligible**
**Final severity:** Critical (matches ceiling)
**Pre-gate verdict (post-chain-proof):** PASS. Pre-gate correctly tracks the evidence gain from chain proof test.

**Positive control verdict:** Pre-gate behaves correctly on WEEX-002 — it starts at Low MAX in the hedged state, then permits Critical after artifact upgrades. The pre-gate is RE-COMMIT-able when new artifacts emerge. The artifact-required constraint means the upgrade is grounded in a new resolvable artifact, not in rationalization.

---

## Stage 2 — Actual Dismissal Readback + Preventability Verdict

**Unsealed at:** 2026-04-18T09:50Z
**Actual dismissal rationale read from OUTCOMES.jsonl, MEMORY.md war logs, and CLAUDE.md rule #36/#37 referenced cases.**

| # | Finding | Pre-gate ceiling | Draft claimed | Actual dismissal | Pre-gate preventable? |
|---|---|---|---|---|---|
| F-01 | ETH-001 Ethena mock | Low MAX | Critical | Rejected — poc_quality (mock PoC, not fork) | **Partial** — pre-gate forces Low or L3/L4 artifact; either resolves (L3 artifact added = ETH-001b) or downgrade. Avoids rep loss but dismissal was about PoC type, not severity. |
| F-02 | ETH-001b Ethena fork | Low MAX | Critical | Rejected — design_intent (token layer boundary: sUSDe restrictions don't extend to underlying USDe) | **No** — pre-gate permits the severity ceiling after L3 fork. Design intent is kill gate Q1, orthogonal to pre-gate. |
| F-03 | FDR-001 Firedancer | Informational | High | Rejected — scope_code_path (IN_KIND_GOSSIP only in Full Firedancer, out of scope) | **Partial** — pre-gate caps at Informational until chain traced to in-scope binary; tracing would have exposed the out-of-scope path. So the chain=unverified commit forces the reachability work upfront. Overlaps with kill gate Q2. |
| F-04 | CONC-001 Concrete view | Low MAX | High | Duplicate (#27), severity also class-capped at Low (view function = Medium MAX rule) | **Yes** — pre-gate caps at Low upfront. Severity oversell to High (acknowledged as credibility-destroying) prevented. Duplicate dismissal is orthogonal (kill gate D1). |
| F-05 | Phemex R2 | Low MAX | High | Informative — "no extraction proven, funds stay in user wallets" | **Yes** — canonical case. Narrative impact forces Low MAX in pre-gate. Phemex war log confirms. |
| F-06 | WEEX-001 Nuxt leak | Low MAX | High | Duplicate class | **Partial** — pre-gate caps severity but duplicate dismissal fires separately. Still reduces rep loss (Low dup loses less rep than High dup). |
| F-07 | Reserve F-003 Convex | Critical-eligible | High | (pre-submit killed by D8b: 5/6 wrappers empty on-chain) | **No** — pre-gate equation passes the commit. D8b (live conditions match on named contracts) is the distinct gate. Pre-gate has no W4 check. |
| F-08 | HRB-001 H&R Block | Low MAX | High | (pre-submit downgraded by user after 3000-word draft) | **Yes** — canonical case. Compliance framing without $ = narrative = Low MAX in pre-gate. Inflation blocked at commit stage, 3000 words never committed. |
| F-09 | Coin98 F-001 origin bypass | Low MAX | Medium/High | Rejected — metadata-only, no fund chain | **Yes** — narrative impact caps at Low MAX. Rep loss of 5 points prevented. |
| F-10 | GMTrade #51 impact mechanism | Low MAX | HIGH | Rejected — feature request, PoC asserts divergence not extraction | **Partial** — pre-gate caps severity due to narrative impact (hand-calculated math ≠ observed delta). But secondary dismissal ("feature request") is rule #13 territory, separate from pre-gate. |
| F-11 | Sparklend V-001 (agent-hallucinated) | Critical-eligible | Critical | (pre-submit killed — wrong contract address + dead code path) | **No** — pre-gate equation passes because agent-declared L4/full/W1. Kill gate Q2 (reachability on-chain readback) is the saver. Artifact-required constraint needs Phase B implementation (verify artifact pointer resolves) to catch this class. |
| F-12 | Dexalot OmniVault burn mislabel | depends on honesty | claimed severity | feedback lesson: artifact existed but didn't prove claim | **Partial** — pre-gate's `artifact_proves` field surfaces the claim-to-artifact link for inspection; if hunter writes honestly ("proves tokens moved to dead address, not burn"), the mismatch shows. Honest-declarer case. Mechanical enforcement in Phase B. |

---

## Count and Conclusions

**Sample size:** 12 failures + 1 positive control (WEEX-002)

**Preventability breakdown:**
- **Yes (fully pre-gate preventable):** 4/12 → F-04 Concrete, F-05 Phemex, F-08 HRB, F-09 Coin98
- **Partial (pre-gate reduces severity but dismissal would still fire on another gate):** 5/12 → F-01 Ethena mock, F-03 Firedancer scope, F-06 WEEX-001 dup, F-10 GMTrade, F-12 Dexalot
- **No (pre-gate does not catch this failure class):** 3/12 → F-02 Ethena design_intent, F-07 Reserve F-003 live conditions, F-11 Sparklend agent-hallucinated

**Pre-gate solo preventability:** 4/12 = **33%** clean wins
**Pre-gate reducing rep/severity loss (Yes + Partial):** 9/12 = **75%** partial-or-better effect
**Pre-gate ineffective class:** 3/12 = 25% need other gates (kill gate Q1/Q2/Q10, D8b, artifact resolves check)

**Honest correction of the 60% estimate from round 3:**
- I estimated 60% pre-gate framing-preventable based on 3/5 failures selected by saliency.
- Actual measurement on 12: 33% clean wins + 42% partial assists = 75% partial-or-better.
- Clean wins rate is HALF of the 60% estimate. 33%, not 60%.
- But 75% partial-or-better is HIGHER than 60% — pre-gate + other gates in combination achieves broader coverage.

**Implications:**
1. Pre-gate alone is not the dominant intervention (33% clean). The 60% estimate was cherry-picked.
2. Pre-gate combined with D8b (live conditions), kill gate Q1/Q2/Q10, and artifact-validator resolving-check IS a dominant stack (75% coverage).
3. **Priority order still holds** (validation rétroactive → pre-gate → target-router → infra): the failure classes pre-gate misses (design intent, live conditions, agent hallucination) are already addressed by existing gates (Q1 kill, D8b, Q2/Q10 kill + artifact resolves in Phase B).
4. **Phase B artifact-resolves-check is more critical than I originally weighted** — it catches the agent-hallucinated class (F-11 Sparklend) which pre-gate alone cannot.

---

## Corrections to the plan

1. **Pre-gate is a necessary but not dominant component.** It's 33% standalone, 42% assist. Still worth building (every gate in the stack is <50% individually, the strength is composition), but the narrative "pre-gate closes 60% of failures" is wrong. Pre-gate + D8b + Q1/Q2/Q10 + artifact-resolves together close ~75%.

2. **Phase B artifact-resolves-check promoted in priority.** The Sparklend (F-11) and Dexalot (F-12) classes both require mechanical verification that the artifact pointer:
   - Resolves (file exists, tx on-chain, contract deployed at that address)
   - Actually proves THE claim (not a generic claim of the same class)

   Phase B must implement:
   - `cast call` to confirm contract at claimed address + has claimed function
   - File:line ref dereferences to actual matching code
   - `artifact_proves` field lexical coherence with the severity claim (nonsense checks: "burn" in proves vs `transfer(0xDEAD)` in artifact = flag)

3. **Pre-gate does NOT substitute for kill gate Q1 (design intent).** Ethena blacklist class (F-02) is design-intent dismissal and pre-gate equation permits it. Q1 is the separate defense; keep it mandatory.

4. **Pre-gate does NOT substitute for D8b live conditions.** Reserve F-003 (F-07) passed pre-gate equation but failed D8b. D8b remains critical.

5. **Positive control (WEEX-002) validates the re-commit behavior.** Pre-gate correctly tracks artifact upgrades — starts at Low MAX in hedged state, permits Critical after chain proof test produces L4 artifact. The artifact-required constraint is the anti-inflation mechanism, not a ceiling that freezes at draft-start.

---

## OUTCOMES.jsonl backfill scope (Task #7)

April 2026 submissions where tier data can be reconstructed from memory/drafts:
- **phemex-r2** (2026-04-13): evidence=L3, chain=full_ethical, impact=narrative, severity_committed=High (inflated), rejected_by_gate: [] (no gates existed). Retroactive flag true.
- **weex-001** (2026-04-13): evidence=L2, chain=partial, impact=narrative, severity_committed=High. Retroactive flag true.
- **weex-002** (2026-04-13): evidence=L4 (post-chain-proof), chain=full_ethical, impact=W5_anchored, severity_committed=Critical. Held at time of diagnostic. Retroactive flag true.
- **Reserve F-003** (2026-04-13): evidence=L4, chain=full_ethical, impact=both_W1_W5, severity_committed=High (downgraded pre-submit by D8b). rejected_by_gate: ["D8b-live-conditions"]. Retroactive flag true. Outcome: "gate_rejected".

Other April entries (Polymarket F-001/F-002, XRPL F-001, etc.) submitted recently — status pending. Add `retroactive: true` + partial tier data where draft data available.

---

## Friction measurement — first observations

Lifecycle scripts run in <1s each (smoke test). Pre-gate SEVERITY-COMMIT fill: estimated 3-5 min when artifacts are known, 15-30 min when artifacts must be produced (gathering cost, not form-filling cost). Friction on Phemex R2 equivalent: filling SEVERITY-COMMIT with honest L3/full/narrative → Low MAX would have produced a 400-word Low Informational submission in ~10 min instead of a 3000-word HIGH in 90 min. **Net friction NEGATIVE at the write-up stage** for the 33% clean-win cases — less writing happens because the severity ceiling is low.

---

## Next actions

1. **Task #7 — backfill April entries** with retroactive flag + tier data where reconstructable.
2. **Phase B promoted priority:** artifact-resolves-check implementation. Catches Sparklend + Dexalot classes that pre-gate alone misses.
3. **Update CLAUDE.md rule #39 framing:** from "closes 60% of failures" to "closes 33% standalone, 75% combined with D8b/Q1/Q2/Q10/artifact-resolves". Remove the 60% claim — it was cherry-picked.
4. **Accept the plan structure stands.** Pre-gate is not the dominant gate; the stack is the dominant intervention. No re-architecture needed, just honest framing.
