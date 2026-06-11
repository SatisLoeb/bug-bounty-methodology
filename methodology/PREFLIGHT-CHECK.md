# Pre-Flight Check — 24-Point Quality Gate

**Purpose:** Score every finding before submission. Minimum 22/24. No exceptions.

**When:** AFTER report is written, BEFORE sending. Takes ~15 minutes.

---

## Finding Metadata

```
Finding ID:     [PROTOCOL-NNN]
Protocol:       [name]
Platform:       [C4 / Sherlock / Direct]
Severity:       [Critical / High / Medium / Low]
Date:           [YYYY-MM-DD]
Kill Gate:      [PASSED / DOWNGRADED from ___]
```

---

## A. PoC Quality (7 points)

| # | Criterion | Check | Score |
|---|-----------|-------|-------|
| A1 | **Reproducible without modification** | Run PoC from scratch. Does it pass with zero edits? Copy-paste the exact commands. If Solidity: fork-based (`vm.createSelectFork`). If Rust: `cargo test`. If Solana/Anchor: `anchor test`. | [ ] 1 / [ ] 0 |
| A2 | **Concrete numbers, not "significant loss"** | Every impact claim has a specific number attached. "$47,231 loss" not "significant funds at risk". Check all `assert` statements have concrete expected values. | [ ] 1 / [ ] 0 |
| A3 | **Trigger conditions realistic and documented** | The conditions required to trigger the bug are explicitly stated AND each condition is individually achievable. No "attacker waits 6 years" or "requires 51% hashrate". | [ ] 1 / [ ] 0 |
| A4 | **PoC shows DELTA (before/after)** | PoC includes baseline measurement AND post-exploit measurement. The difference is the proof. Not just "it reverts" — show what SHOULD happen vs what DOES happen. | [ ] 1 / [ ] 0 |
| A5 | **Fork-based (Solidity) / test-based (Rust)** | Zero mock contracts. Zero reproduction contracts. Zero helper simulators. Real deployed contracts (Solidity) or real crate code (Rust). | [ ] 1 / [ ] 0 |
| A6 | **No mock hiding a problem** | The PoC doesn't use a mock that coincidentally avoids the bug's prerequisites. Check: would the PoC still work against the REAL dependency? | [ ] 1 / [ ] 0 |
| A7 | **Honest about PoC limitations** | If the PoC simplifies something, it says so. "This PoC uses a static price; in production, the price would be fetched from [oracle]." No hidden assumptions. | [ ] 1 / [ ] 0 |

**A subtotal: ___/7**

---

## B. Argumentation (7 points)

| # | Criterion | Check | Score |
|---|-----------|-------|-------|
| B1 | **Internal consistency argument present** | If the protocol protects against this risk ANYWHERE else in the codebase, that's documented with code refs from both sides. If no internal inconsistency exists, state "N/A — no comparable pattern found." | [ ] 1 / [ ] 0 |
| B2 | **Dismissal vector matrix complete** | Every plausible dismissal vector has been identified AND has a pre-emptive defense with evidence. Minimum 5 vectors checked. | [ ] 1 / [ ] 0 |
| B3 | **Impact quantified in $ or %** | Dollar amount at risk, OR percentage of TVL, OR number of affected users/contracts. "All deposits" is not quantification — "$12M TVL across 3 vaults" is. | [ ] 1 / [ ] 0 |
| B4 | **Severity justified, not oversold** | Severity matches the actual provable impact. If impact is < 0.001% TVL/year → Medium MAX and explicitly stated. Never let the judge discover minimal impact on their own. | [ ] 1 / [ ] 0 |
| B5 | **Recommended fix with code** | Complete code diff that addresses root cause. Not "add a check" — show the exact check with the exact placement. | [ ] 1 / [ ] 0 |
| B6 | **Code references with exact lines** | Every code citation includes file path and line number. Permalink to specific commit when possible. | [ ] 1 / [ ] 0 |
| B7 | **No invalidatable argument** | Every claim in the report has been verified against the actual code. No assumptions that could be disproven by reading the code carefully. **Jupiter Lend Lesson:** #3's bank-run argument was invalidated by `saturating_sub` — this check catches that. | [ ] 1 / [ ] 0 |

**B subtotal: ___/7**

---

## C. Hygiene (4 points)

| # | Criterion | Check | Score |
|---|-----------|-------|-------|
| C1 | **Title < 80 chars, descriptive** | Title communicates the vulnerability type AND the affected component. "[Type] in [component] allows [impact]" pattern. | [ ] 1 / [ ] 0 |
| C2 | **No repetition between sections** | Executive Summary, Vulnerability Details, and Impact don't repeat the same sentences. Each section adds NEW information. | [ ] 1 / [ ] 0 |
| C3 | **Format correct for platform** | C4: follows their markdown template. Sherlock: follows their template. Direct email: follows disclosure template. CVSS vector string included. | [ ] 1 / [ ] 0 |
| C4 | **No credibility-reducing errors** | No typos in function names. No wrong line numbers. No broken markdown. No incorrect Solidity/Rust syntax. Read the report once as if you were the reviewer. | [ ] 1 / [ ] 0 |

**C subtotal: ___/4**

---

## D. Strategic (6 points)

| # | Criterion | Check | Score |
|---|-----------|-------|-------|
| D1 | **Verified not a known issue / duplicate** | Searched: GitHub Issues/PRs, git log, C4/Sherlock/CodeHawks archives, known issues list, contest README. Document what was searched and results. | [ ] 1 / [ ] 0 |
| D2 | **Code path traced from entry point to bug** | Complete trace: `public_function() → internal_call() → vulnerable_code()`. Not "this function is vulnerable" — show HOW a user reaches it. | [ ] 1 / [ ] 0 |
| D3 | **Existing guards documented (or absence)** | If guards exist on this path: document them and explain why they're insufficient. If no guards: explicitly state "no validation exists on this path." | [ ] 1 / [ ] 0 |
| D4 | **Worst-case AND realistic-case separated** | Report distinguishes between maximum theoretical impact and realistic expected impact. Both are stated. This prevents "you're exaggerating" dismissal. | [ ] 1 / [ ] 0 |
| D5 | **No unverifiable claims** | Every claim can be verified by the reviewer with the information provided. No "we observed that..." without showing the observation. No "typically..." without citation. | [ ] 1 / [ ] 0 |
| D6 | **IS/IS NOT risk split** | Report explicitly states what the bug DOES affect AND what it does NOT affect. Honest limitation disclosure paradoxically strengthens credibility. Example: "This does NOT allow direct fund theft. It DOES cause permanent loss of yield for all depositors." | [ ] 1 / [ ] 0 |
| D7 | **Chain proof end-to-end (auth/credential/signature findings only)** | For every finding in the class auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding: the report contains a concrete HTTP response (or equivalent) proving the vulnerable primitive is ACCEPTED by the intended backend. No hedge phrases ("I did not test", "inferred from", "strongly indicates", "would authenticate", "deliberately not executed"). The CHAIN-PROOF-GATE.md Stage 1 grep returned 0 matches OR the matches are explicitly tied to an ethical-constraint sentence with no workaround. **This criterion is GATING** — D7 fail = do not submit regardless of total score. | [ ] 1 / [ ] 0 / [ ] N/A (not an auth-class finding) |
| D8 | **Weight anchored (all findings claiming severity ≥ Low with dollar impact)** | Two-part gate: **(8a) Numerical anchor** — the report contains at least one numerical anchor, either W1 (computed dollar loss with formula and inputs from on-chain reads, API counts, or documented limits) OR W5 (≥1 paid precedent with a dollar figure from H1 disclosed / C4 awards / Cantina reports / Sherlock contests / OUTCOMES.jsonl). DoS alternative counts as W1 numerical anchor if downtime × req/s × affected users is measured from a reproducible PoC. Anti-pattern phrases ("could drain", "potentially affects", "significant funds", "widespread impact", "catastrophic") without accompanying numerical anchor = 8a failing signal. **(8b) Live conditions match** — mandatory IFF the finding claims TVL-at-risk or N-contracts-affected impact: W4 must contain on-chain readback (totalSupply / balanceOf / reserves / paused / extraRewards) at a specific block, for EVERY contract named in the severity claim. The readback must match the quantitative claim. If 5/6 named contracts have totalSupply = 0, the "6 wrappers vulnerable" claim is unsupported → 8b FAIL. 8b N/A for access control bypass, signature forge, pure logic bugs, state-delta forge-tests with asserted $ loss, pure info disclosure. W2/W3 remain dashboard slots. **This criterion is GATING (both sub-parts)** — D8 fail = do not submit at claimed severity; populate W1/W5 (for 8a) and/or W4 on-chain readback (for 8b), or downgrade severity. Run `~/arsenal/tools/precedent-scan.sh <class>` for W5; use `cast call` against named addresses for W4. | [ ] 1 / [ ] 0 / [ ] N/A (Informational only) |

**D subtotal: ___/8** (6 scored + 2 gating)

---

## Scoring

```
A (PoC Quality):      ___/7
B (Argumentation):    ___/7
C (Hygiene):          ___/4
D (Strategic):        ___/6    (D1-D6 scored)
D7 (Chain proof):     [ ] PASS / [ ] FAIL / [ ] N/A  (gating, not scored)
D8 (Weight anchor):   [ ] PASS / [ ] FAIL / [ ] N/A  (gating, not scored)
                      -------
TOTAL:                ___/24
```

### Decision

```
24/24 + D7 PASS/NA + D8 PASS/NA  — Send immediately. No changes needed.
22-23 + D7 PASS/NA + D8 PASS/NA  — Send after fixing flagged items (< 30 min fixes).
19-21 + D7 PASS/NA + D8 PASS/NA  — Significant gaps. Fix ALL failing criteria before sending.
<19                              — Major rework needed. Do NOT send.
ANY score + D7 FAIL              — BLOCKED. Run CHAIN-PROOF-GATE.md Stage 2 to complete
                                   the chain OR downgrade severity and remove hedge
                                   phrases. D7 is gating because an auth finding without
                                   acceptance proof plateaus at Informational regardless
                                   of report polish (WEEX-002 / Phemex R2 lesson,
                                   2026-04-13).
ANY score + D8a FAIL             — BLOCKED at claimed severity. Either compute W1 with
                                   on-chain reads, documented limits, or measured DoS
                                   downtime; or run arsenal/tools/precedent-scan.sh
                                   <class> to populate W5 with paid references; or
                                   downgrade severity to Informational. D8a is gating
                                   because a finding without a numerical anchor plateaus
                                   at Informational regardless of chain quality
                                   (Phemex R2 lesson, 2026-04-10/13 — chain was proven,
                                   weight was narrated, result was Informative).
ANY score + D8b FAIL             — BLOCKED at claimed severity. The severity claim scales
                                   with TVL/count of specific contracts but the on-chain
                                   state at current block does not match the claim. Run
                                   cast call on every named contract, update W4 with the
                                   literal output, downgrade severity to match observed
                                   state, OR add latent-risk framing and drop the claim
                                   of immediate high impact. D8b is gating because a
                                   quantitative claim that is empirically wrong on-chain
                                   plateaus at dismissed regardless of precedent depth
                                   (Reserve F-003 Convex freeze lesson, 2026-04-13 —
                                   5/6 wrappers had 0 TVL, 1/6 had only CVX as extra
                                   reward, draft claimed HIGH "permanent freezing" on
                                   a deployment where realistic $ at risk ≈ 0).
```

**Note:** D7 and D8 are independent gates catching distinct failure modes. D7 = "does the exploit execute?". D8 = "given it executes, is the impact priced (8a) AND does the priced impact match the current deployment state (8b)?". A finding must pass all applicable sub-gates. Phemex R2 would have passed D7 (chain executed) and failed D8a (weight narrated). Reserve F-003 Convex freeze would have passed D7 + D8a (PoC works, precedents cited) and failed D8b (named vulnerable contracts are empty on-chain). WEEX-002 passes both (chain proven + precedent anchor in W5 if populated).

### Failed Criteria Action Items

| Failed # | Issue | Fix Required | Time Est |
|----------|-------|-------------|----------|
| | | | |
| | | | |
| | | | |

---

## 9 Tactical Patterns Reference (apply before final submission)

| # | Pattern | When to Apply | Check Applied? |
|---|---------|--------------|----------------|
| P1 | **NatSpec Auto-Incrimination** | Contract's own docs describe the exact input that triggers the crash | [ ] |
| P2 | **Symmetry Analysis** | Safe code path exists elsewhere, unsafe path here = copy-paste negligence | [ ] |
| P3 | **Deterministic Impact Framing** | Impact is certain + permissionless + zero-cost. Use "permanent" > "until fixed" | [ ] |
| P4 | **Fork-Based PoC with Baselines** | Always (Solidity). 5-test structure: 2 baselines + exploit + strongest + impact | [ ] |
| P5 | **Prior Audit Absence Proof** | Finding not in prior audits. Mode A: exhaustion (7 keywords). Mode B: 6-axis diff | [ ] |
| P6 | **Immutability Amplifier** | Contract is non-upgradeable. No proxy + no admin + no circuit breaker = permanent | [ ] |
| P7 | **Policy Alignment** | Quote the program's own policy verbatim. Protocols can't contradict their rules | [ ] |
| P8 | **Submission Sequencing** | Multi-findings: submit most defensible first → credibility bias for subsequent ones | [ ] |
| P9 | **IS/IS NOT Risk Calibration** | Always. Admitting limitations REINFORCES credibility paradoxically | [ ] |

---

## Impact Quantification Requirements (by severity)

| Severity | Minimum Evidence Required |
|----------|--------------------------|
| Critical | $ amount at risk + realistic scenario + 1-tx PoC |
| High | $ amount OR invariant broken + realistic scenario |
| Medium | Quantified damage (even if small) + honest limits. If < 0.001% TVL/year → say so |
| Low/QA | Clear description, no overselling. State it's low. |

**Anti-Jupiter #3 Rule:** If the impact amounts to < 0.001% TVL annually, it is Medium MAX. State this proactively in the report. Never let the reviewer calculate it and realize you oversold.

**Anti-Jupiter #4 Rule:** No fantaisiste extrapolations. "Over 1 year, this compounds to..." is only valid if the 1-year scenario is realistic. If it requires continuous attack for 365 days, say so.

---

## Calibration Log

Track scores vs outcomes to calibrate which criteria predict acceptance:

| Date | Finding ID | Pre-Score | Final Severity | Outcome | Failed Criteria | Notes |
|------|-----------|-----------|---------------|---------|----------------|-------|
| | | | | | | |

After 10+ entries: drop criteria that don't correlate with outcomes. Add new ones from observed dismissal patterns.
