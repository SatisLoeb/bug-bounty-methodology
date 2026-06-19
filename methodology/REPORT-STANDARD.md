# Report Standard -- Production Template

This is the standard report format for all bug bounty submissions. Derived from the Transak payment cancellation report (the strongest report in the portfolio). Every future report must match this voice, structure, and epistemic discipline.

**Core principles:**
- Epistemic precision: separate confirmed facts from inferred consequences. Never claim what you haven't verified.
- Architectural naming: name the anti-pattern, not just the symptom. "bearer-of-ID auth model" not "missing auth."
- Chain factoring: prove each link independently. The reviewer can verify each claim without trusting the chain.
- Negative space: state what the finding IS NOT. Honest limitations build credibility faster than overclaiming.
- Evidence-first: every claim followed immediately by the proof. No claim without a curl, a code quote, or a screenshot.
- No self-scoring: no CVSS in the report body. Describe impact, let the reviewer score. Put CVSS in platform form fields only.

**Voice:** First person. Technical precision. Direct. No filler. No corporate security jargon. Assume the reviewer is an engineer.

**Killshot + Chain-of-Custody (MANDATORY for Critical/High with PoC):** Every report at Critical or High severity that includes an on-chain or empirically-reproducible exploit must open with a one-sentence killshot (in the Summary section) and be followed within minutes of submission by a chain-of-custody comment posted on the finding thread. Both elements are templated below. Reference incident: Polymarket Cantina #197 moved to `In Review` with triager commentary within 8 minutes of first-touch using this format; sibling findings on the same contest without this format auto-duplicated in the same minute (zero review time). When to apply and when to skip is defined in the "Killshot applicability" section below.

---

## Template

The template below maps to HackerOne form fields. Each field contains guidance on voice and content. Replace `[PLACEHOLDERS]` and remove HTML comments before submission.

---

### Killshot (opening sentence inside Summary, Critical/High with PoC only)

<!--
When applicable, the killshot is the FIRST sentence of the Summary paragraph. Not a separate section, not a header -- just the opening sentence of Summary. The rest of the Summary paragraph continues from there.

A valid killshot contains, in this order:
1. "I have confirmed that" -- asserts empirical knowledge, never theoretical possibility
2. The prerequisite assertion -- "unauthenticated", "with no credentials", "from a fresh wallet", "without a session cookie"
3. The action performed -- "HTTP POST to endpoint X", "signTypedData call with payload Y", "transaction to contract Z"
4. The payload provenance -- "payload built by target's own published SDK", "using the ABI published in their docs"
5. The server/contract response -- "accepted", "returned HTTP 200", "settled on-chain"
6. The on-chain proof (if applicable) -- tx hash, block number, status, gas metrics, addresses
7. The "on behalf of" clause (gas/fund-drain cases) -- "target paid X gas on behalf of attacker EOA Y"

Every claim in the killshot must be verifiable against a source the researcher does not control:
- tx hash → any RPC provider returns the same receipt
- HTTP 200 → triager replays the curl
- SDK provenance → npm registry, target's GitHub org

Never use in the killshot:
- Hedge words: "likely", "appears to", "seems to", "may", "could"
- Conditional language: "if the attacker had", "assuming the server"
- Projected impact numbers ("$2.3M drainable") -- keep those in Impact, killshot is about mechanics
- Internal reasoning ("because the middleware is missing") -- killshot is observed facts, not explanations
- Self-assigned severity ("this is critical") -- let the evidence do the talking

Reference killshot (Polymarket Cantina #197, 2026-04-18):
"I have confirmed that an unauthenticated HTTP POST to v2-local's /submit with a payload built by Polymarket's own published SDK (@polymarket/builder-relayer-client) is accepted, signed by a production hot wallet from the shared pool, and settled on-chain on Polygon. The proof-of-concept transaction 0xa6a0ea2db8f637dd6d95675085e4ebd7a6636d7d7e696cdf6212a88d83f809ca mined in block 85700101 with status 0x1 after Polymarket signer 0x23a4d452... paid 0.05062 MATIC of gas on behalf of attacker EOA 0x46a23E25..."

Non-on-chain substitutions:
- Auth bypass / session theft → "HTTP 200 + server-side artifact retrievable via a different request (new account created, MFA deleted, email changed)"
- Signature forge / key confusion → "a curl command a third party can reproduce to obtain the same bypass, plus the decoded result"
- Smart contract state extraction → "a forge test --fork-url command that asserts a delta on mainnet-forked state"

Common pattern: the proof is a request the triager can re-execute, producing an artifact they can observe on a system the researcher does not control.
-->

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
- Use "critical", "severe", "dangerous" -- let the facts carry severity
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
pure information disclosure, configuration exposure), write "N/A -- not an
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

**Test performed:** [Yes / N/A -- not an auth-class finding]

**Ethical variant:** [fictitious external_id / our own account / two accounts we control / file we created / metadata-only probe / N/A]

**Target endpoint:** [URL or function that validates the primitive -- this is where the backend decides accept/reject]

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
Complementary to Chain Acceptance Verification -- answers "given the exploit
executes, is the impact priced?" rather than "does the exploit execute?".

Skipping this section on a non-Informational finding = automatic D8 fail
in preflight = submission blocked at claimed severity. See WEIGHT-CARD.md.

If the finding is pure information disclosure claimed at Informational/Low,
write "N/A -- claimed at Informational" and move on.

If the finding is a smart contract fund theft with forge-test PoC asserting
a state delta on mainnet fork, the state delta IS the implicit W1 -- write
"W1 implicit: state delta asserted in PoC tests" and populate W5 only.

For every other finding, populate at least W1 OR W5 with a numerical anchor.
Both slots cannot be qualitative. Run `~/arsenal/tools/precedent-scan.sh
<class>` to populate W5 fast -- it emits a copy-paste-ready block matching
the W5 table format below exactly.
-->

**Severity claimed:** [Critical / High / Medium / Low / Informational]

**Numerical anchor source:** [W1 computed / W1 DoS alternative / W5 paid precedent / both / N/A -- Informational]

**W1 -- Loss accounting:**
```
Formula:   [mathematical expression -- e.g., stolen_amount × victims × frequency × duration]
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
OR (non-quantifiable escape hatch -- ONLY valid if W5 has ≥1 paid precedent):
```
Quantification not feasible because: [specific ethical or access constraint]
Conservative worst-case: [prose worst-case]
```

**W5 -- Precedent anchor:**

| Report | Class | Payout | Source |
| --- | --- | --- | --- |
| [report ID or URL] | [vuln class] | $[amount] | H1/C4/Cantina/Sherlock |
| [report ID or URL] | [vuln class] | $[amount] | H1/C4/Cantina/Sherlock |

Each row MUST have a dollar figure. "Related H1 #xxx" without a paid amount does not count. Use `~/arsenal/tools/precedent-scan.sh <class>` to generate this block.

**W2 -- Stakeholder map (dashboard, optional):** [LPs / treasury / retail / third-party integrators / KYC victims -- with on-chain addresses or documented identifiers where applicable]

**W3 -- Reversibility audit (dashboard, optional):**

| Mechanism | Present? | Proof | Effective? |
|-----------|----------|-------|------------|
| Pause | [Y/N] | [cast call result] | [Y/N] |
| Governance override | [Y/N] | [doc URL] | [Y/N] |
| Timelock | [Y/N] | [getMinDelay readback] | [Y/N] |
| Circuit breaker | [Y/N] | [function enumeration] | [Y/N] |

**W4 -- Live conditions proof (MANDATORY IFF finding claims TVL-at-risk or N-contracts-affected; dashboard otherwise):**

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
Exploit profitable:   [Y/N -- arithmetic at the cited block. If N → severity unsupported.]
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

### Severity Lock — Bridge Halt / Fund-Freeze (MANDATORY when the impact is funds-inaccessible, not funds-stolen)

<!--
Two distinct downgrade vectors hit freeze/halt findings. Both are triager escape hatches that turn a High into a Low/N/A. Close them in the INITIAL report, never in appeal (severity rarely reopens — e.g. C4 PJQA is 48h post-prelim-judging only). Encodes feedback_bridge_freeze_label_vs_substance.md (Injective Peggy S-23 Low+$0 despite exact-rec silent-patch; Ripio #3753469 N/A "queueing not freezing").

VECTOR A — VALUE-IN-TRANSIT freeze recharacterized as "normal cross-chain queueing, funds will arrive."
VECTOR B — INFRASTRUCTURE halt (checkpoint/DoS bricks the whole mechanism) recharacterized as "repairable via chain upgrade / admin action, so not real loss."

Do NOT argue the label "freeze." Argue SUBSTANCE: user holds no accessible representation of value, for material duration, with no user-side recourse. That is binary and PoC-resolvable; the label is a definitional dispute the triager wins by fiat.
-->

**Severity rationale (state explicitly, lock the boundary before the triager reads it):**

This is a [High/Critical] under [program schedule clause]. Funds are inaccessible to the user for [duration] with [no recovery path / recovery only via X]. The schedule places [recovery-exists + material-duration → High] / [no-recovery → Critical]; this finding sits at [boundary] because [reason]. The existence of an [admin/governance/chain-upgrade] recovery path does not move this below High — the High class explicitly presupposes recovery exists; treating its existence as a downgrade collapses two boundaries the schedule keeps separate.

**Mandatory lines in Impact (both vectors):**
- **User-side recourse: none.** [PoC enumerates every user-callable function on the affected component and proves none reverses the freeze for the depositor/user.]
- **User-side inaccessibility.** During the window the user holds no accessible representation of value: [source balance = 0 / destination = 0 / mechanism bricked]. Not "in transit somewhere" — [destroyed / unreachable] on chain.
- **Frozen value × duration as the headline.** [$X TVL] inaccessible for [realistic minimum duration]. Lead with the realistic minimum (ordinary user, normal conditions, e.g. hours-to-UTC-rollover or the upgrade-coordination window), NOT the full-supply ceiling — the ceiling reads theoretical and gets dismissed.

**Vector-A extra (value-in-transit):** historical event evidence proving the precondition (another user already at high % of cap) is production behavior — block number + recipient. "No attacker required" cuts FOR you: a condition firing under honest routine use is more likely to harm users, not less.

**Vector-B extra (infra-halt):** spell out that recovery is NOT cheap/fast/user-accessible — "[no pause, no governance override, no circuit breaker; recovery requires a coordinated chain binary upgrade, multi-day, all validators, bridge frozen the entire window]." Recovery-exists ≠ recovery-is-fast. If the same protection exists for a SIBLING code path (e.g. a spoofing test on an adjacent claim/function), cite it (`file:line`): the team already classified this class as a real attack vector one function over (internal-consistency, Rule 8) — that argues against a Low.

---

## Chain-of-Custody Comment (posted immediately after submission, Critical/High with PoC only)

<!--
Do NOT include the chain-of-custody block inside the submitted report body. It is a follow-up comment posted on the finding thread within 1-2 minutes of the initial submission. Platforms surface recent comments at the top of the activity feed -- this block is the second thing the triager sees after the report itself.

Three reasons the block lives in a comment, not the body:
1. The report body is read linearly. A chain-of-custody section inside the report gets buried under Impact / Recommendation. A public comment posted minutes after submission surfaces at the top of the activity feed.
2. Comments are timestamped by the platform. The researcher demonstrates they were ready to answer "how can I verify this?" before the triager asked -- confidence and professionalism signal.
3. The "independence" argument reads as padding inside a report but as "here is everything you need to falsify me in under 5 minutes; I am not hiding" inside a comment.

Required structural elements of the comment:

1. Opening assertion -- "every numerical claim in this report resolves against live state" or equivalent. One sentence.
2. Reproduction pointer -- name the PoC file / script, name the RPCs or endpoints that work, state the exact observable (HTTP 200 vs 401, tx mined vs reverted, test PASS vs FAIL).
3. Independent verification paths -- enumerated, each labeled. For on-chain: receipt layer, block layer, cross-RPC, calldata binding, explorer link. For web/API: cURL that anyone can run, decoded result, explorer/dashboard URL, server-side artifact that persists across sessions.
4. Calldata / payload binding clause -- the "this specific X could not exist unless the claimed process occurred" argument. Identify the specific bytes/fields that bind the observed artifact to the claimed attack. This distinguishes a genuine PoC from a replayed-old-tx fabrication.
5. Explorer / UI link -- the triager's one-click check.

Reference comment (Polymarket Cantina #197, 2026-04-18):

"every numerical claim in this report resolves against live Polygon state. triage can replay the PoC directly from final-proof-mined.js on any Polygon RPC (Alchemy, drpc.org, publicnode, etc.) and obtain the same HTTP 200 from v2-local and HTTP 401 from v2. independent chain-of-custody:

receipt: eth_getTransactionReceipt on tx 0xa6a0ea2d... returns status 0x1, block 85700101, gas 223,207, relayer 0x23a4d452..., to RelayHub 0xd216153c...

block: block 85700101 hash 0xe42288d5... matches the receipt's blockHash; PoC tx is at transactionIndex 186 of 246 in that block.

cross-RPC confirmation: drpc.org returns the same receipt (independent of Alchemy), 1,748+ confirmations accumulated at the time of writing, no reorg risk.

calldata proof: the RelayHub.relayCall calldata (selector 0x405cec67) embeds attacker EOA 0x46a23e25... at input[10:74]. this binds the mined tx to the unauthenticated /submit request -- the relayer would not have produced this specific calldata unless it processed the attacker's POST with a matching payload from a wallet it never authorized.

public explorer: https://polygonscan.com/tx/0xa6a0ea2d..."

Post-ready template (copy-paste into the comment field, fill the bracketed slots, remove this HTML comment):

```
every [numerical claim|empirical claim|code claim] in this report resolves against [live state|scope commit|runtime under X binary]. triage can [replay the PoC directly from FILE | run CURL | forge test] on [any RPC provider|a clean clone|the endpoint at URL] and [obtain the same HTTP 200|produce the same PASS output|observe the same state delta]. independent [chain-of-custody|verification paths]:

[label 1]: [one-line evidence, often a single curl/cast/forge output snippet]

[label 2]: [second independent source confirming the same fact]

[label 3 -- cross-source]: [second provider / second endpoint / second tool returning matching data]

[label 4 -- binding clause]: the [calldata|payload|response body] at [specific field / byte range] embeds [specific attacker-controlled value]. this binds the [observed artifact] to the claimed attack -- [the external system] would not have produced this specific [artifact] unless it processed the [attacker input].

public explorer / UI: [URL]
```

Post within 2 minutes of the submission going live. Comments later than the initial triager look lose the top-of-feed surfacing advantage.
-->

---

## Killshot applicability (decision tree)

Apply the killshot + chain-of-custody format to any finding with:
- Critical or High severity claim
- On-chain OR empirically-reproducible exploit (forge test / curl + server-side artifact / SDK replay)
- Bounty payout floor ≥ $5K
- PoC involves state-changing actions (not pure info disclosure)

Do NOT apply the killshot + chain-of-custody format to:
- Pure information disclosure with no state impact (the "observed endpoint leaks X" format is fine)
- Design-level concerns without a PoC
- Conceptual findings where the exploit would require privileged access the researcher does not have
- Low-severity findings where the format's weight is disproportionate

When in doubt: if you can't write the killshot in a single sentence without hedge words, the PoC is not strong enough for this format. Fix the PoC before writing the report.

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
- [ ] Every direct quote in the body (anything in `"..."` or `>` blockquote) verified byte-for-byte against raw source via `gh api` / `grep` / `curl`. WebFetch / AI summaries of source content do NOT count as verification. If the source is an image, do not cite textual content from it without OCR + independent confirmation.

## Pre-Submission Checklist (Killshot + Chain-of-Custody, Critical/High with PoC only)

Apply these additional items when the finding meets the "Killshot applicability" criteria above. Skip the entire block if the finding is info-disclosure, design-level-no-PoC, or below the $5K bounty floor.

- [ ] Killshot sentence drafted as the FIRST sentence of Summary (not a separate header)
- [ ] Killshot contains all seven structural elements (verified empirically, prerequisite, action, provenance, response, on-chain proof if applicable, "on behalf of" clause if gas/fund drain)
- [ ] Killshot contains zero hedge words: grep the sentence for `likely|appears|seems|may|could|if the attacker had|assuming` -- any match is a fail
- [ ] Every claim in the killshot is verifiable against a source the researcher does not control (external RPC, npm registry, public explorer, target's own GitHub org)
- [ ] Chain-of-custody comment drafted in the workspace (separate file, not the submission body) before submission goes live
- [ ] Chain-of-custody comment contains all five structural elements (opening assertion, reproduction pointer, independent paths, binding clause, explorer link)
- [ ] Chain-of-custody comment identifies the specific bytes/fields that bind the observed artifact to the claimed attack
- [ ] Plan to post the chain-of-custody comment within 2 minutes of the submission going live (same session, same workspace, clipboard ready)
