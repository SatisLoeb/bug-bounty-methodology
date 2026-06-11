# Tactical Playbook — Battle-Tested Winning Patterns

Extracted from accepted/escalated submissions (Feb 2026 campaign). These are PATTERNS, not procedures — apply the relevant ones per finding.

**Track record:** ENS-002 escalated in 17 minutes (8 team members subscribed). ENS-001 submitted as High with full anti-rejection defense.

---

## Pattern 1: NatSpec Auto-Incrimination

**When to use:** The crash/exploit is triggered by an input that matches the protocol's own documented examples or NatSpec.

**Mechanism:** Search `/// @notice`, `/// @dev`, `/// @param`, `/// Examples:`, and inline comments in the vulnerable contract. If ANY documented input triggers the vulnerability, the "invalid input" defense is dead.

**How it won (ENS-002):** The ExtendedDNSResolver NatSpec at line 13 documents `/// Examples: - t[note]='I'm great'`. This exact format triggers Panic(0x32). The contract crashes on its own documented input.

**Formula:** "The contract violates its own specification documented at [file]:[line]. The input `[X]` conforms to the documented format at line [N] yet triggers [revert/panic/corruption]."

**Extended search:** Also check the protocol's unit tests. If their own tests don't cover the crash case, that's a second angle: "The protocol's test suite at [file] does not test the [specific case], confirming this edge case was not considered during development."

---

## Pattern 2: Symmetry Analysis (Safe vs Unsafe Code Paths)

**When to use:** A function has two logical branches, and one is protected while the other isn't.

**Mechanism:** Find the "source pattern" that the vulnerable code was likely copy-pasted from. Show that the protection was lost during duplication. This proves negligence, not design choice.

**How it won (ENS-002):** The 3 `STATE_TRACKED_*` states correctly update `offset` after parsing. The 3 `STATE_IGNORED_*` states are a copy-paste of the same DFA structure but skip the offset update — causing OOB access. The protection was in the template; the copy lost it.

**Formula:** "The codebase contains [N] instances of [protective pattern]. The vulnerable code at [file]:[line] is structurally identical to [safe code at file:line] but lacks the [specific check]. This is an implementation error in a duplicated code path, not a design decision."

**Key insight:** Don't just say "safe vs unsafe." Identify the SPECIFIC pattern that was copied and the SPECIFIC check that was dropped. The more surgical the comparison, the harder to dismiss.

---

## Pattern 3: Deterministic Impact Framing

**When to use:** Always. Immunefi triagers downgrade non-deterministic, high-cost, or recoverable issues.

**Mechanism:** Prove three properties: (1) deterministic — always happens, not probabilistic; (2) permissionless — any caller, no special role; (3) zero-cost — no capital or complex setup required. If all three hold, the triager cannot downgrade.

**How it won (ENS-002):** `Panic(0x32)` = guaranteed revert on every call with the documented format. Any external caller can trigger it. Cost = gas only.

**Formula:** DON'T say "it can crash." DO say: "Every [ENS name / user / deposit] using [this format] becomes permanently [non-resolvable / frozen / inaccessible]. The trigger is [deterministic / permissionless / zero-cost]."

**Vocabulary rules:**
- "deterministic" > "possible"
- "permanently" > "until fixed" (if immutable)
- "every X that uses Y" > "some X might"
- "Panic(0x32)" > "revert" (specific > generic)
- Quantify: "all 9 test cases trigger the crash" > "the contract reverts"

---

## Pattern 4: Fork-Based PoC with Baselines

**When to use:** Every Solidity submission. Non-negotiable after Ethena rejection.

**Mechanism:** The PoC structure that wins: (1) positive baseline — prove normal operation works; (2) negative baseline — prove similar-but-different inputs pass; (3) exploit — prove the specific input breaks it; (4) impact — prove consequences (no key needed, arbitrary data, etc.).

**How it won (ENS-001 & ENS-002):** 7 tests and 9 tests respectively. Baselines first, then escalating exploit severity, then impact tests. All on real deployed mainnet contracts, zero mocks.

**Structure:**
```
testBaseline_NormalBehavior()       — positive: contract works
testBaseline_SimilarInputPasses()   — negative: close inputs don't trigger
testExploit_SpecificTrigger()       — the vulnerability
testExploit_StrongestVariant()      — most devastating variant LEADS
testImpact_Consequence()            — proves real-world impact
```

**Rules:**
- `vm.createSelectFork()` — always fork mainnet
- Real deployed address from Etherscan — never deploy mocks
- Interface-only imports — define `interface ITarget { ... }` not full contracts
- NatSpec on every test — explains WHAT and WHY to the triager
- Expected output section — reviewer can verify without running

---

## Pattern 5: Prior Audit Absence Proof

**When to use:** When any audit has touched the same codebase. Two modes:

**Mode A — Finding is 100% new:** Prove absence by exhaustion. Search the audit platform's findings repo for every relevant keyword. Show zero results.

**How it won (ENS-001):** "Searching the C4 2023-04-ens findings repository returned zero issues mentioning RSA, PKCS, padding, Bleichenbacher, signature forgery, or exponent validation." Seven keywords, zero hits. Irrefutable.

**Mode B — A prior finding LOOKS similar:** Build a differentiation table. 6 axes minimum: root cause, trigger, impact, attack vector, affected operations, recovery.

**Formula (Mode A):** "The [Auditor] [Year] audit specifically covered [ContractName]. That audit found [X] High and [Y] Medium issues, but none addressed [vulnerability class]. Searching returned zero issues mentioning [keyword1], [keyword2], [keyword3], [keyword4], [keyword5], or [keyword6]."

**Formula (Mode B):** Table with | Aspect | Prior Finding | This Finding | format. Every row MUST differ. If 2+ rows are identical, reconsider whether it's truly new.

---

## Pattern 6: Immutability Amplifier

**When to use:** When the vulnerable contract is immutable (no proxy, no admin upgrade, no circuit breaker). This shifts severity upward by one tier.

**Mechanism:** For upgradeable contracts, the finding is "fix it when it matters." For immutable contracts, the finding must be evaluated against the FULL LIFETIME of the deployment. The bug is permanent, the risk is cumulative, and the only remediation is deploy-new-and-migrate.

**How it won (ENS-001):** Shifted from Medium to High. "RSASHA256Algorithm is not a proxy — no `setImplementation`, no `upgradeTo`, no admin function. If any zone in a trust chain uses e=3 — today or two years from now — the deployed contract cannot defend against the forgery. There is no circuit breaker."

**Formula:** "For a proxied contract, this is 'fix it when it matters.' For an immutable contract, the finding must be evaluated against the full lifetime of the deployment. [ContractName] has no proxy, no admin function, no circuit breaker. The only remediation is deploying new contracts and calling [migration function] — a manual, reactive operation."

**Amplification targets:**
- Conditional exploits become "permanent time bombs"
- External dependency risks become "undefendable if conditions change"
- Low-probability triggers become "guaranteed over deployment lifetime"

---

## Pattern 7: Program Policy Alignment

**When to use:** When the program's own bounty policy supports your severity classification. Programs are bound by their published rules.

**Mechanism:** Read the program's Immunefi page word by word. Find clauses that match your finding's impact category. Quote verbatim. Programs cannot contradict their own published policy without damaging their reputation.

**How it won (ENS-001):** ENS policy states: "High vulnerabilities concerning theft are considered at the full amount of funds at risk — this is to incentivize disclosure of vulnerabilities that may not have significant monetary value today, but could still be damaging if unaddressed." This clause explicitly covers conditional/future-risk findings on immutable contracts.

**Formula:** "Per the program's published bounty policy: '[quote verbatim]'. This finding falls squarely within this clause: [explain match]. [The vulnerability exists on-chain now / The asset class is explicitly covered / The impact category matches exactly]."

**Where to find policy clauses:**
- Immunefi program page → "Rewards by Threat Level" section
- Immunefi program page → "Program Overview" section
- Program's own security policy (often linked from Immunefi page)
- Immunefi's general severity classification docs (for cross-program arguments)

---

## Pattern 8: Submission Sequencing (Slot Timing)

**When to use:** When you have multiple findings for the same protocol and limited submission slots (1/day on most programs).

**Mechanism:** Submit the cleanest, most defensible finding first. This creates a credibility bias with the triager for your subsequent submissions. A first submission that gets escalated in minutes makes the second submission land on a triager who already trusts your work.

**How it won (ENS campaign):** ENS-002 (OOB, simpler, NatSpec auto-incrimination, 9 tests) submitted first → escalated in 17 minutes, 8 team members subscribed. ENS-001 (Bleichenbacher, more complex, severity debate possible) submitted second, landing on a triager primed by the first escalation.

**Ordering rules:**
1. **Cleanest PoC first** — fewer assumptions, fewer reviewer questions
2. **Highest confidence first** — p(acceptance) > 0.7 before p(acceptance) 0.5-0.7
3. **Same severity findings** — simpler one first (reviewer warm-up)
4. **Different severity findings** — depends: if the higher severity is also simpler, lead with it; if the higher severity is debatable, lead with the clean Medium to build trust
5. **Separate protocols** — no sequencing needed; submit in parallel where slots allow

---

## Pattern 9: Honest Risk Calibration (IS / IS NOT)

**When to use:** Always. Splitting risk into "what IS exploitable now" vs "what is NOT exploitable now" is paradoxically the strongest severity defense.

**Mechanism:** Admitting limitations builds trust. The triager sees intellectual honesty and stops looking for hidden weaknesses in your argument. The "IS at risk" section stands unchallenged because you already addressed the "IS NOT" yourself.

**How it won (ENS-001):**
- "What IS at risk (e=1, immediately):" — any zone with e=1 DNSKEY, no external conditions, exploitable now
- "What is NOT at risk (e=3, currently):" — no major TLD uses e=3, trust chain blocks exploitation today

**Formula:** Two subsections in Impact Details:
```
**What IS at risk ([condition], immediately):**
[Unconditional risk. No caveats. This works NOW.]

**What is NOT at risk ([condition], currently):**
[Conditional risk. Honest about current limitations. But note why conditions may change.]
```

**Why it works:** Reviewers are trained to spot inflated severity. When you pre-emptively disclose limitations, you (a) disarm the reviewer's skepticism, (b) make your "IS at risk" section bulletproof, and (c) demonstrate expertise that makes the reviewer defer to your judgment on the severity call.

---

## Anti-Pattern: Things That Get You Rejected

1. **Mock-based PoCs** — instant rejection for Solidity (Ethena lesson, Feb 15)
2. **Hedging language** — "could potentially maybe" = triager reads "probably not"
3. **Inflated severity** — claiming Critical for a griefing bug = credibility destroyed
4. **Missing baselines** — triager can't tell if contract is broken for everything
5. **Vague impact** — "leads to potential issues" = instant downgrade
6. **Ignoring prior audits** — triager WILL check; if you didn't address it, they assume overlap
7. **French in an English submission** — yes, this happened
8. **Trailing spaces in URLs** — causes form validation errors (ironic when submitting OOB bugs)
9. **Submitting to $0 vault programs** — Beanstalk, $0 vault, valid bug, $0 payout
10. **Code in repo != code in production** — Firedancer: function exists but never called in in-scope binary
