# Report Standard — Production Template

This is the standard report format for all bug bounty submissions. Derived from the Transak payment cancellation report (the strongest report in the portfolio). Every future report must match this voice, structure, and epistemic discipline.

**Core principles:**
- Epistemic precision: separate confirmed facts from inferred consequences. Never claim what you haven't verified.
- Architectural naming: name the anti-pattern, not just the symptom. "bearer-of-ID auth model" not "missing auth."
- Chain factoring: prove each link independently. The reviewer can verify each claim without trusting the chain.
- Negative space: state what the finding IS NOT. Honest limitations build credibility faster than overclaiming.
- Evidence-first: every claim followed immediately by the proof. No claim without a curl, a code quote, or a screenshot.
- No self-scoring: no CVSS in the report body. Describe impact, let the reviewer score. Put CVSS in platform form fields only.

**Voice:** First person. Technical precision. Direct. No filler. No corporate security jargon. Assume the reviewer is an engineer.

---

## Template

The template below maps to HackerOne form fields. Each field contains guidance on voice and content. Replace `[PLACEHOLDERS]` and remove HTML comments before submission.

---

### Summary

<!-- 
ONE PARAGRAPH. 3-7 sentences. This is the entire finding compressed.

Structure:
1. What is exposed/broken (name the component, name the anti-pattern)
2. What an attacker can do (concrete action, not abstract risk)
3. How (the mechanism in one sentence)
4. What you confirmed vs what you inferred

Voice: "The [component] exposes [N] endpoints that [do X] without [Y]. The sole access control is [describe the actual auth model]. [How attacker gets the required data]. [What you confirmed]. [What you deliberately did not test and why]."

DO NOT:
- Start with "I found" or "There is a vulnerability"
- Use "critical", "severe", "dangerous" — let the facts carry severity
- Give CVSS scores
- List CWEs (put in form fields)
- Use bullet points
-->

[Component] exposes [endpoints/functions] that [action] without [expected control]. The [actual auth model name] -- where [describe what constitutes authorization] -- is [why it's insufficient], because [how the required data leaks to attackers]. [Chain summary in one sentence]. I have confirmed [N] independent facts: (1) [fact], (2) [fact], (3) [fact]. [What you have NOT confirmed and why -- "because doing so would require [disrupting X / accessing Y]"]. [CVSS vector components explained in plain English, not as a score].

---

### Steps To Reproduce

<!--
Each step = one independently verifiable action. The reviewer must be able to copy-paste each curl and get the same result.

Structure:
1. Confirm the precondition (prove the vulnerability surface exists)
2. Confirm the control IS enforced where expected (baseline -- proves this is an inconsistency, not blanket design)
3. Confirm the control IS NOT enforced where it should be (the finding)
4. Demonstrate the chain (or describe it if execution would cause harm)

Each step:
- Title: "Confirm [what this proves]"
- Evidence: curl command or code quote with exact output
- Verdict: one-line assessment ("No [X]. [Component] [did/did not] [Y]. [✓ correct / ✗ missing]")

Voice: factual, no commentary between steps. Let the evidence accumulate.
-->

**Prerequisites:**
[Account setup, environment, tools needed. Keep to 2-3 lines.]

**Step 1: Confirm [surface/precondition exists].**

[Explanation of what this step verifies and why it matters.]

```bash
[curl command or code -- copy-pasteable, production-safe]
```

[Exact response, trimmed to relevant fields:]
```json
[response]
```

[One-line verdict.]

**Step 2: Confirm [control IS enforced where expected] (baseline).**

<!-- This step is CRITICAL. It proves the finding is an inconsistency, not design. If the control isn't enforced ANYWHERE, the finding is weaker. Show where it works before showing where it doesn't. -->

```bash
[curl command]
```

[Response showing enforcement. Example: `{"security_key_authorization_required":true}`]

[Control] enforced. This is correct.

**Step 3: Confirm [control IS NOT enforced where it should be].**

```bash
[curl command]
```

[Response showing no enforcement. Example: `{"result":{"state":"confirmed"}}`]

No [control]. [Action] completed immediately. [Why this contradicts the baseline.]

**Step 4: [Continue chain or describe attack flow].**

<!-- If executing the full chain would harm real users, describe the PoC structure without executing it. State explicitly: "The attack as executed by an attacker (PoC structure -- not executed against real users):" -->

[Continue until the chain is complete.]

---

### Proof of Concept

<!--
This section provides the EVIDENCE TABLE and ARCHITECTURAL ANALYSIS that supports the steps above.

Structure:
1. Endpoint/function audit table (what requires auth, what doesn't)
2. Code evidence from production (bundle analysis, contract code, API responses)
3. The anti-pattern articulated as an architectural finding

Voice: analytical, not argumentative. You're documenting facts, not making a case.
-->

**[Component] authentication audit ([environment], [date]):**

| Endpoint | Auth required | Response without auth | Destructive? |
|----------|--------------|----------------------|-------------|
| [endpoint 1] | [type] | [response] | [Yes/No] |
| [endpoint 2] | None | HTTP 200 | Yes |

<!-- If auth consistency finding, use an enforcement matrix: -->

**[Control] enforcement matrix:**

| Operation | Moves funds/Creates keys | [Context A] | [Context B] |
|-----------|-------------------------|-------------|-------------|
| [op 1] | [what it does] | [Control] ✓ | [Control] ✓ |
| [op 2] | [what it does] | [Control] ✓ | No [control] ✗ |

**Code evidence ([source], confirmed [date]):**

```javascript
// [source file or bundle, size for verification]
[exact code quote -- minimal, just enough to prove the claim]
```

[1-2 sentences explaining what this code proves.]

<!-- Name the anti-pattern: -->

This is the [anti-pattern name]: [one sentence defining it]. The [component] [does X] because [architectural reason], and [other component] [broadcasts/exposes] those same [tokens/IDs/secrets] to [untrusted context].

---

### Chain Acceptance Verification

<!--
MANDATORY for every auth-bypass / hardcoded-credential / signature-forge /
JWT-token / session-hijack / IDOR-write / password-reset / account-binding
finding. Skipping this section on an auth-class finding = automatic D7 fail
in preflight = submission blocked. See CHAIN-PROOF-GATE.md.

If the finding is NOT in the auth class (e.g. smart contract state delta,
pure information disclosure, configuration exposure), write "N/A — not an
auth-class finding, the PoC itself proves the impact" and move on.

The goal of this section is to PROVE the vulnerable primitive is accepted
by the intended backend, not just that the primitive is structurally
valid. A forged JWT that is "cryptographically well-formed" is different
from a forged JWT that "Zendesk's backend returns 200 authenticated:true
for". Prove the second, not the first.

The test MUST use an ethical variant that does not touch real user data:
- JWT forge → use fictitious external_id
- IDOR write → use two accounts we control
- Password reset → reset our own account
- File read → target a file we created
- Credential test → hit enumeration/metadata endpoint only
See CHAIN-PROOF-GATE.md Stage 2 for the full catalog.
-->

**Test performed:** [Yes / N/A — not an auth-class finding]

**Ethical variant:** [fictitious external_id / our own account / two accounts we control / file we created / metadata-only probe / N/A]

**Target endpoint:** [URL or function that validates the primitive — this is where the backend decides accept/reject]

**Request (replayable):**
```bash
curl -sS -o /tmp/resp -w "HTTP_STATUS=%{http_code}\n" \
  '[URL]' \
  -H '[auth header]' \
  --data-raw '[body]'
```

**Response:**
```
HTTP_STATUS=[200/201/etc]
```
```json
[body excerpt showing server-side acceptance artifact]
```

**What this proves:**
[One sentence. Example: "Zendesk's Smooch backend validated the HS256 signature with the leaked secret, created a permanent appUser record bound to the forged external_id, and returned authenticated:true. The leaked secret is cryptographically valid and the backend trusts JWTs signed with it."]

**What this does NOT prove:**
[One sentence. Example: "I did not present the forged JWT with a real WEEX user's external_id because that would access their conversation history. The architecture grants that capability (realtime baseUrl returned with the forged userId) but I did not execute that variant."]

---

### Weight Accounting

<!--
MANDATORY for every finding claiming severity ≥ Low with a dollar impact.
Complementary to Chain Acceptance Verification — answers "given the exploit
executes, is the impact priced?" rather than "does the exploit execute?".

Skipping this section on a non-Informational finding = automatic D8 fail
in preflight = submission blocked at claimed severity. See WEIGHT-CARD.md.

If the finding is pure information disclosure claimed at Informational/Low,
write "N/A — claimed at Informational" and move on.

If the finding is a smart contract fund theft with forge-test PoC asserting
a state delta on mainnet fork, the state delta IS the implicit W1 — write
"W1 implicit: state delta asserted in PoC tests" and populate W5 only.

For every other finding, populate at least W1 OR W5 with a numerical anchor.
Both slots cannot be qualitative. Run `~/arsenal/tools/precedent-scan.sh
<class>` to populate W5 fast — it emits a copy-paste-ready block matching
the W5 table format below exactly.
-->

**Severity claimed:** [Critical / High / Medium / Low / Informational]

**Numerical anchor source:** [W1 computed / W1 DoS alternative / W5 paid precedent / both / N/A — Informational]

**W1 — Loss accounting:**
```
Formula:   [mathematical expression — e.g., stolen_amount × victims × frequency × duration]
Inputs:    - [variable 1]: [value] (source: [cast call / API readback / docs URL / block number])
           - [variable 2]: [value] (source: ...)
           - [variable 3]: [value] (source: ...)
Computed:  $[dollar amount]
```
OR (DoS alternative):
```
Endpoint affected:   [critical path URL]
Downtime duration:   [measured seconds/minutes/hours from PoC]
Request volume:      [req/s with source]
Affected users:      [count from documented user base]
Failed operations:   downtime × req/s × users = [N]
```
OR (non-quantifiable escape hatch — ONLY valid if W5 has ≥1 paid precedent):
```
Quantification not feasible because: [specific ethical or access constraint]
Conservative worst-case: [prose worst-case]
```

**W5 — Precedent anchor:**

| Report | Class | Payout | Source |
| --- | --- | --- | --- |
| [report ID or URL] | [vuln class] | $[amount] | H1/C4/Cantina/Sherlock |
| [report ID or URL] | [vuln class] | $[amount] | H1/C4/Cantina/Sherlock |

Each row MUST have a dollar figure. "Related H1 #xxx" without a paid amount does not count. Use `~/arsenal/tools/precedent-scan.sh <class>` to generate this block.

**W2 — Stakeholder map (dashboard, optional):** [LPs / treasury / retail / third-party integrators / KYC victims — with on-chain addresses or documented identifiers where applicable]

**W3 — Reversibility audit (dashboard, optional):**

| Mechanism | Present? | Proof | Effective? |
|-----------|----------|-------|------------|
| Pause | [Y/N] | [cast call result] | [Y/N] |
| Governance override | [Y/N] | [doc URL] | [Y/N] |
| Timelock | [Y/N] | [getMinDelay readback] | [Y/N] |
| Circuit breaker | [Y/N] | [function enumeration] | [Y/N] |

**W4 — Live conditions proof (MANDATORY IFF finding claims TVL-at-risk or N-contracts-affected; dashboard otherwise):**

```
Block/timestamp:      [block number, UTC timestamp]
Target contracts:     [EVERY contract address named in the severity claim]
  [addr 1]: [cast call totalSupply()/balanceOf/... output, copy-paste literal]
  [addr 2]: [cast call output]
  ...
Live failure mode:    [the SPECIFIC tokens/conditions triggering the exploit on THIS
                       deployment. If the draft cites "USDT pause" as the failure mode,
                       the target contract must actually use USDT in the relevant position.
                       Generic class-level scenarios don't count.]
Exploit profitable:   [Y/N — arithmetic at the cited block. If N → severity unsupported.]
```

**When W4 is mandatory:** finding claims "$X TVL at risk" / "N wrappers / vaults / contracts affected NOW" / cites historical frozen-funds numbers as weight anchor. In these cases, W4 is a hard gate (Stage 2b in WEIGHT-CARD.md).

**When W4 is dashboard-only:** access control bypass (severity independent from TVL), signature forge, pure logic bugs, state-delta forge-tests with asserted $ loss, pure info disclosure. An empty W4 in these cases is merely a noted argumentation weakness, not a hard block.

**The test:** does the finding's severity claim scale with the TVL of a specific named contract? If yes → W4 mandatory, populate with literal on-chain readback. If no → W4 dashboard-only.

**Argumentation weakness noted:** [list empty dashboard slots, or "none"]

---

### Recommended Fix

<!--
3-5 concrete fixes. Each one sentence. Ordered by priority.

Voice: imperative. No "you should consider" -- state what needs to happen.
Include code-level guidance where possible.
-->

[Fix 1 -- address the root cause]. The [endpoints] must require [specific auth mechanism] bound to [session/user/transaction]. The current [anti-pattern name] is insufficient because [one-line reason].

[Fix 2 -- address the data leak]. Replace [current behavior] with [specific fix]. The [data source] is available from [where]; it should be [how to use it correctly].

[Fix 3 -- defense in depth]. Add [mechanism] for [operations]. Generate [secret] server-side at [lifecycle point], deliver it solely to [authorized context], and require it as [signature/token] on all [operations].

[Fix 4 -- credential rotation if applicable]. Rotate [credential]. It is [where it's exposed] and allows [what it enables].

---

### Supporting Material/References

<!--
Bullet list of evidence. Each item = one verifiable fact with source.
Production sources preferred over staging. Include file sizes for bundle verification.
-->

- [Source]: [URL] ([size]) -- [what it proves]
- [Prior finding if applicable]: [URL] -- [how it relates]
- [Standard violated]: CWE-[N], OWASP [ref]
- No prior public disclosure found in [searched locations] as of [date]

---

### Impact

<!--
TWO SECTIONS: Customer Impact and Business Impact. Written as flowing paragraphs, not bullet lists.

Customer Impact structure:
1. "The practical consequence is..." (concrete, not abstract)
2. Describe the full chain from attacker action to victim impact
3. "This is amplified by..." (scale, integrations, deployment breadth)
4. "This is not..." (explicit negative space -- what's NOT at risk)
5. "I have not confirmed..." (what you deliberately didn't test)

Business Impact structure:
1. Scale numbers ($TVL, users, volume, partners)
2. Regulatory context (FCA, SOC2, etc.)
3. Architectural framing (gap between security posture and actual controls)
4. The structural finding articulated

Voice: precise, honest, no overselling. An acknowledged Medium beats a dismissed High.
-->

**Customer impact:**

The practical consequence is that [concrete attacker capability]. The [component] [broadcasts/exposes] [data] -- including [specific fields] -- to [untrusted context] via [mechanism], and the [service's] [endpoints] accept requests solely on the basis of [what constitutes auth]. [Describe the chain]. The attacker needs solely [minimal requirements].

This is [amplified/bounded] by [scale factor]. [Integration breadth, deployment count, user base].

This is not [what it's NOT]. I have not confirmed [what you didn't test] -- [why: "because doing so would require disrupting a real user's [X]"]. The [architectural analysis] suggests [plausible outcome], yet I want to be precise: the confirmed impact is [X], not [Y].

This is not [second limitation]. [Why it's not at risk -- specific technical reason].

**Business impact:**

[Company] [processes/manages] [$X] in [metric] across [N] users, [holds/has] [regulatory status], and [relevant history -- prior incidents, settlements, compliance]. The [component's] [anti-pattern name] -- where [what constitutes auth] -- is architecturally inconsistent with the [other component's] behavior, which [broadcasts/exposes] those same [identifiers] to [untrusted context]. The gap between the security model implied by [company's] [regulatory/marketing posture] and the actual authentication on the [service's] [endpoints] is the structural finding.

---

## Voice Rules (Reference)

These rules apply to all text inside the form fields above.

| Rule | Do | Don't |
|------|-----|-------|
| Claims | "I have confirmed" / "I have not confirmed" | "This vulnerability allows" (passive, vague) |
| Anti-patterns | "bearer-of-ID auth model" / "wildcard trust delegation" | "missing authentication" (generic) |
| Severity | Describe impact in concrete terms | Use "CRITICAL" or self-assign CVSS |
| Limitations | "I deliberately did not test this because..." | Hide limitations or skip them |
| Evidence | curl output, code quotes, exact responses | "Testing revealed" without showing the test |
| Scope | "What IS at risk" / "What is NOT at risk" | Omit limitations to inflate severity |
| Fixes | "The [endpoint] must require [X]" | "Consider implementing" / "It is recommended" |
| Precedents | Table with report ID, program, bounty, parallel | Name-dropping without specifics |
| Standards | OWASP ASVS V3.7.1, NIST SP 800-63B-4 with section | "OWASP Top 10" (too generic) |
| Tone | First person, precise, direct, technical | Third person, passive voice, corporate |
| Formatting | Flowing paragraphs, tables for structured data, code blocks for evidence | Bullet-point lists for arguments |

## Escalation Comment Template

After initial submission, deepen the finding with additional evidence in follow-up comments:

```
[Evidence type]: [What you found] confirmed in [source].

[Technical detail: static analysis, additional code path, on-chain state, etc.]

This means [implication -- how it changes the capability table].

[Updated capability table if applicable]

Note: [field/behavior] is [condition-dependent]. [Specific conditions].
```

## Pre-Submission Checklist (Internal)

- [ ] Every claim has evidence (curl, code quote, or screenshot) immediately following it
- [ ] Baseline test included (proves inconsistency, not blanket design)
- [ ] Anti-pattern named (not just "missing X")
- [ ] "Confirmed / not confirmed" distinction made explicitly
- [ ] Negative space articulated (what IS NOT at risk)
- [ ] No CVSS in body text (form fields only)
- [ ] No CWE in body text (form fields only, or Supporting Material section)
- [ ] Scale/business context included in Impact
- [ ] Fixes are imperative, not suggestions
- [ ] Every curl command is copy-pasteable and production-safe
- [ ] No real user data was accessed or disrupted
- [ ] Precedent table included if similar findings exist
- [ ] Standards violated section included if applicable
