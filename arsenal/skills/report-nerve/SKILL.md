---
name: report-nerve
description: >-
  Production-grade structural framework for bug bounty reports, security advisories, vulnerability disclosures, and post-dismissal appeals. Provides the rigor scaffolding: killshot opening for Critical/High with PoC, chain-of-custody comment template, chain acceptance verification block, weight accounting pre-submission gate, enforcement matrix tables, anti-pattern naming discipline, negative space articulation, and baseline+contrast evidence structure. Use whenever drafting a serious external security report destined for HackerOne, Cantina, HackenProof, Code4rena, Sherlock, Immunefi (when applicable), or upstream GHSA. Invoke chill skill as a styling pass when the target program uses human triagers prone to anti-AI screening (HackerOne, public Cantina contests, HackenProof). Skip chill when the target is a formal Cantina private audit, IACR academic submission, or pure upstream OSS GHSA.
---

# report-nerve

The structural skeleton for production-grade security reports. Derived from the Polymarket Cantina #197 submission (the strongest report in the portfolio, moved to In Review with triager commentary within 8 minutes of first-touch) and the Transak payment cancellation report. Every Critical/High submission with a reproducible exploit must match this voice, structure, and epistemic discipline.

## Core principles

- **Epistemic precision**: separate confirmed facts from inferred consequences. Never claim what you haven't verified.
- **Architectural naming**: name the anti-pattern, not just the symptom. "bearer-of-ID auth model" not "missing auth."
- **Chain factoring**: prove each link independently. The triager can verify each claim without trusting the chain.
- **Negative space**: state what the finding IS NOT. Honest limitations build credibility faster than overclaiming.
- **Evidence-first**: every claim followed immediately by the proof. No claim without a curl, a code quote, or a screenshot.
- **No self-scoring in body**: CVSS goes in form fields only, not in the report body. Describe impact, let the triager score.

**Voice baseline**: First person. Technical precision. Direct. No filler. No corporate security jargon. Assume the triager is an engineer.

## Composition with chill skill

This skill provides the **structural** layer (what sections exist, what evidence is mandatory, what gates must pass). The companion skill `chill` provides the **voice** layer (contractions, hedges on inferences, effort traces, no em dashes, no triple parallelism).

### When this skill invokes chill automatically

Apply both `report-nerve` and `chill` when the target is:

- HackerOne (any program — triagers explicitly screen for AI-generated reports)
- Public Cantina contests (not private audits)
- HackenProof (auth-class findings especially, where triager scrutiny is heaviest)
- Code4rena public contests
- Any program where the user has prior signal damage from "AI-generated" close (Deribit case)
- Any resubmission after a previous Informative close that cited AI/writing concerns

### When this skill skips chill

Run `report-nerve` without the `chill` styling pass when the target is:

- Cantina private audits (formal clean style expected, triagers are engineers not anti-AI screeners)
- IACR ePrint papers / academic cryptographic submissions
- Upstream GHSA reports to OSS maintainers (Daniel Wirtz / protobufjs case — maintainers want technical density)
- Internal company security tickets / private disclosure to a vendor security@ address
- When the user explicitly asks for "formal style", "white paper format", or "no chill"

### Tension resolution (when both skills run)

When `chill` is applied as a styling pass over `report-nerve`'s structural output:

- **Killshot stays firm** (zero hedge words). Hedges apply only to inferences elsewhere in the report (CWE classification, scoring debate, root-cause guess).
- **Tables OK for empirical data** (enforcement matrices, capability audits, W4 cast call readbacks). Prose for argumentative content (Impact, Recommended Fix).
- **Anti-pattern naming stays mandatory but as integrated prose**, not under labelled sections.
- **Standards (CWE / OWASP / NIST) go in form fields**, not in dedicated body sections. Inline mention in prose maximum once.
- **Chain-of-custody comment structure preserved** (5 elements: opening assertion, reproduction pointer, independent paths, binding clause, explorer link). Phrasing can be slightly less formal.
- **Weight accounting (W1-W5) stays internal** — never appears in report body under those labels. Numerical anchors that emerge from W1/W4/W5 can be cited in Impact prose with their source, without the framework label.

Full resolution details are in the `chill` skill body.

---

## Mandatory components (decision tree)

Before drafting, identify which components are mandatory for this finding.

### Killshot (opening sentence of Summary)

**Mandatory when ALL of these are true:**

- Severity claimed is Critical or High
- Exploit is empirically reproducible (PoC produces server-side artifact, on-chain tx, or forge-test state delta)
- Bounty floor for the program is ≥ $5K
- PoC involves state-changing actions (not pure info disclosure)

**Skip when:**

- Pure information disclosure with no state impact
- Design-level concerns without a PoC
- Conceptual findings where exploit would require privileged access the researcher doesn't have
- Low/Informational findings where the format weight is disproportionate

**Rule of thumb**: if you can't write the killshot in a single sentence without hedge words, the PoC is not strong enough for this format. Fix the PoC before writing the report.

### Chain-of-custody comment

**Mandatory** alongside the killshot. Post within 1-2 minutes of submission going live as a separate comment on the finding thread.

**Skip** if killshot is skipped.

### Chain Acceptance Verification block (in report body)

**Mandatory** for every auth-class finding:

- Auth bypass / signature forge / JWT manipulation / session hijack
- Hardcoded credential exploitation
- IDOR write / password reset / account binding
- Token replay / refresh abuse

**Skip** for:

- Pure smart contract state delta findings (the PoC itself proves the impact, write "N/A — not an auth-class finding, the PoC itself proves the impact")
- Pure information disclosure
- Configuration exposure without exploitation

Skipping this section on an auth-class finding = automatic preflight fail = submission blocked.

### Weight accounting (internal gate, NOT in report body)

**Mandatory pre-submission discipline** for every finding claiming severity ≥ Low with a dollar impact. Lives in internal notes / preflight checks / KILLED-FINDINGS-LESSONS.yaml. The framework label NEVER appears in the report body.

Numerical anchors that emerge from W1 (dollar amount), W4 (live conditions readback), or W5 (precedent payouts) can be cited in the report's Impact or Steps to Reproduce sections as prose with their source — but never under "W1 / W2 / W3 / W4 / W5" labels.

For Informational claims: write "N/A — claimed at Informational" in internal notes and move on.

### Enforcement matrix table

**Mandatory** for auth-consistency findings (where the issue is that the control exists in some contexts but not others). The matrix proves the inconsistency empirically.

**Skip** when:

- The finding is "control never enforced" (no inconsistency to demonstrate, just describe the surface)
- The finding is a single endpoint or single contract function

---

## Killshot construction

A valid killshot contains, in this order:

1. **"I have confirmed that"** — asserts empirical knowledge, never theoretical possibility
2. **The prerequisite assertion** — "unauthenticated", "with no credentials", "from a fresh wallet", "without a session cookie"
3. **The action performed** — "HTTP POST to endpoint X", "signTypedData call with payload Y", "transaction to contract Z"
4. **The payload provenance** — "payload built by target's own published SDK", "using the ABI published in their docs"
5. **The server / contract response** — "accepted", "returned HTTP 200", "settled on-chain"
6. **The on-chain proof if applicable** — tx hash, block number, status, gas metrics, addresses
7. **The "on behalf of" clause** for gas/fund-drain cases — "target paid X gas on behalf of attacker EOA Y"

Every claim in the killshot must be verifiable against a source the researcher does not control:

- tx hash → any RPC provider returns the same receipt
- HTTP 200 → triager replays the curl
- SDK provenance → npm registry, target's GitHub org

**Never use in the killshot:**

- Hedge words: "likely", "appears to", "seems to", "may", "could"
- Conditional language: "if the attacker had", "assuming the server"
- Projected impact numbers ("$2.3M drainable") — keep those in Impact, killshot is about mechanics
- Internal reasoning ("because the middleware is missing") — killshot is observed facts, not explanations
- Self-assigned severity ("this is critical") — let the evidence do the talking

**Reference killshot (Polymarket Cantina #197, 2026-04-18):**

> I have confirmed that an unauthenticated HTTP POST to v2-local's /submit with a payload built by Polymarket's own published SDK (@polymarket/builder-relayer-client) is accepted, signed by a production hot wallet from the shared pool, and settled on-chain on Polygon. The proof-of-concept transaction 0xa6a0ea2db8f637dd6d95675085e4ebd7a6636d7d7e696cdf6212a88d83f809ca mined in block 85700101 with status 0x1 after Polymarket signer 0x23a4d452... paid 0.05062 MATIC of gas on behalf of attacker EOA 0x46a23E25...

**Non-on-chain substitutions:**

- Auth bypass / session theft → "HTTP 200 + server-side artifact retrievable via a different request (new account created, MFA deleted, email changed)"
- Signature forge / key confusion → "a curl command a third party can reproduce to obtain the same bypass, plus the decoded result"
- Smart contract state extraction → "a forge test --fork-url command that asserts a delta on mainnet-forked state"

The common pattern: the proof is a request the triager can re-execute, producing an artifact they can observe on a system the researcher does not control.

---

## Chain-of-custody comment construction

Post within 1-2 minutes of submission going live as a separate comment on the finding thread, NOT inside the report body.

Three reasons the block lives in a comment, not the body:

1. The report body is read linearly. A chain-of-custody section inside the report gets buried under Impact / Recommendation. A public comment posted minutes after submission surfaces at the top of the activity feed.
2. Comments are timestamped by the platform. The researcher demonstrates they were ready to answer "how can I verify this?" before the triager asked — confidence and professionalism signal.
3. The "independence" argument reads as padding inside a report but as "here is everything you need to falsify me in under 5 minutes; I am not hiding" inside a comment.

**Required structural elements (all 5 must be present):**

1. **Opening assertion** — "every numerical claim in this report resolves against live state" or equivalent. One sentence.
2. **Reproduction pointer** — name the PoC file / script, name the RPCs or endpoints that work, state the exact observable (HTTP 200 vs 401, tx mined vs reverted, test PASS vs FAIL).
3. **Independent verification paths** — enumerated, each labeled. For on-chain: receipt layer, block layer, cross-RPC, calldata binding, explorer link. For web/API: cURL that anyone can run, decoded result, explorer/dashboard URL, server-side artifact that persists across sessions.
4. **Calldata / payload binding clause** — the "this specific X could not exist unless the claimed process occurred" argument. Identify the specific bytes/fields that bind the observed artifact to the claimed attack. This distinguishes a genuine PoC from a replayed-old-tx fabrication.
5. **Explorer / UI link** — the triager's one-click check.

**Reference comment (Polymarket Cantina #197, 2026-04-18):**

> every numerical claim in this report resolves against live Polygon state. triage can replay the PoC directly from final-proof-mined.js on any Polygon RPC (Alchemy, drpc.org, publicnode, etc.) and obtain the same HTTP 200 from v2-local and HTTP 401 from v2. independent chain-of-custody:
>
> receipt: eth_getTransactionReceipt on tx 0xa6a0ea2d... returns status 0x1, block 85700101, gas 223,207, relayer 0x23a4d452..., to RelayHub 0xd216153c...
>
> block: block 85700101 hash 0xe42288d5... matches the receipt's blockHash; PoC tx is at transactionIndex 186 of 246 in that block.
>
> cross-RPC confirmation: drpc.org returns the same receipt (independent of Alchemy), 1,748+ confirmations accumulated at the time of writing, no reorg risk.
>
> calldata proof: the RelayHub.relayCall calldata (selector 0x405cec67) embeds attacker EOA 0x46a23e25... at input[10:74]. this binds the mined tx to the unauthenticated /submit request — the relayer would not have produced this specific calldata unless it processed the attacker's POST with a matching payload from a wallet it never authorized.
>
> public explorer: https://polygonscan.com/tx/0xa6a0ea2d...

**Note on chill styling**: when chill is applied, the comment phrasing can use lowercase opener, contractions, and dropped formal punctuation, but all 5 structural elements remain. The binding clause stays unhedged (it's an empirical assertion).

---

## Report body template

The template below maps to HackerOne / Cantina form fields. Each field contains guidance on voice and content. When `chill` is applied as styling pass, voice changes per chill's rules; structure remains.

### Pre-Summary intro paragraph (chill mode only)

When `chill` is invoked, prepend a short P1 paragraph BEFORE the Summary section. This establishes human authorship without delaying the killshot.

```
Hi team,

[Context line: how you found it, when, what you were debugging]. [Optional
second line if resubmission: address prior issues upfront]. Walking through
the actual finding below.
```

Skip this paragraph when running without chill (formal mode).

### Summary

ONE PARAGRAPH. 3-7 sentences. The entire finding compressed.

**Structure when killshot mandatory:**

1. **Killshot** (first sentence — empirical assertion per construction rules above)
2. **Chain summary** in one sentence (mechanism, not implications)
3. **Confirmed facts** enumerated: "I have confirmed [N] independent facts: (1)..., (2)..., (3)..."
4. **What you did NOT confirm and why** — "I have not confirmed [X] because doing so would require [Y]"
5. **Anti-pattern naming** in prose: "I'd put this in the [name] class: [one-line definition]"

**Structure when killshot skipped:**

1. **What is exposed/broken** (name the component, name the anti-pattern in prose)
2. **What an attacker can do** (concrete action, not abstract risk)
3. **How** (the mechanism in one sentence)
4. **What you confirmed vs what you inferred**

DO NOT in Summary:

- Start with "I found" or "There is a vulnerability"
- Use "critical", "severe", "dangerous" — let the facts carry severity
- Give CVSS scores in body text (form fields only)
- List CWEs in body text (form fields only)
- Use bullet points

### Steps to Reproduce

Each step = one independently verifiable action. The triager must be able to copy-paste each curl and get the same result.

**Required structure:**

1. **Confirm the precondition** (prove the vulnerability surface exists)
2. **Confirm the control IS enforced where expected** (baseline — proves this is an inconsistency, not blanket design)
3. **Confirm the control IS NOT enforced where it should be** (the finding)
4. **Demonstrate the chain** (or describe it if execution would cause harm)

Each step:

- Title: "Confirm [what this proves]"
- Evidence: curl command or code quote with exact output
- Verdict: one-line assessment

Voice between steps: factual, no commentary. Let the evidence accumulate.

When `chill` is applied: section titles like "### Step 1, getting a main bearer" instead of "### Step 1: Authenticate". Verdicts can be casual ("That's correct" / "Got back the expected challenge"). Evidence blocks remain technical.

### Proof of Concept

Provides the EVIDENCE TABLE and ARCHITECTURAL ANALYSIS that supports the steps above.

**Structure:**

1. **Endpoint / function audit table** (what requires auth, what doesn't) — empirical data, table OK regardless of chill state
2. **Enforcement matrix** if auth-consistency finding — empirical data, table OK regardless of chill state
3. **Code evidence from production** (bundle analysis, contract code, API responses)
4. **Anti-pattern named** in prose (regardless of chill state)

Voice: analytical, not argumentative. Documenting facts, not making a case.

**Example enforcement matrix (auth-consistency finding):**

```markdown
**Control enforcement matrix (verified 2026-05-16):**

| Operation | Action | Main bearer | Subaccount bearer |
|-----------|--------|-------------|---------------------|
| transfer_to_user | External transfer | Challenge ✓ | Blocked (scope) |
| transfer_to_subaccount | Internal transfer | No challenge ✗ | No challenge ✗ |
| create_subaccount | Creates fund target | No challenge ✗ | N/A |
| create_api_key | Persistent credential | Challenge ✓ | No challenge ✗ |
```

The matrix is the evidence. It survives chill styling unchanged.

**Anti-pattern naming (in prose, no labelled section):**

```
This is the bearer-perimeter inconsistency pattern: the auth challenge is
correctly gated on the main account's identity boundary, but the same
operation invoked through a child-context bearer obtained via exchange_token
sidesteps the gate even though the credential being minted has the same
scope reach.
```

The naming is preserved; the formal section heading is not.

### Chain Acceptance Verification

MANDATORY for every auth-class finding. Documents that the vulnerable primitive is accepted by the intended backend (not just that the primitive is structurally valid).

**Template:**

```
**Test performed:** Yes / N/A — not an auth-class finding

**Ethical variant:** [fictitious external_id / our own account / two accounts we
control / file we created / metadata-only probe / N/A]

**Target endpoint:** [URL or function that validates the primitive — this is
where the backend decides accept/reject]

**Request (replayable):**
[curl command, copy-pasteable, production-safe]

**Response:**
HTTP_STATUS=[200/201/etc]
[body excerpt showing server-side acceptance artifact]

**What this proves:**
[One sentence. Example: "Zendesk's Smooch backend validated the HS256 signature
with the leaked secret, created a permanent appUser record bound to the forged
external_id, and returned authenticated:true. The leaked secret is
cryptographically valid and the backend trusts JWTs signed with it."]

**What this does NOT prove:**
[One sentence. Example: "I did not present the forged JWT with a real WEEX
user's external_id because that would access their conversation history. The
architecture grants that capability (realtime baseUrl returned with the forged
userId) but I did not execute that variant."]
```

When `chill` is applied: the "What this proves / What this does NOT prove" symmetric pairing is preserved here as an exception to F3 — this is a structured evidence record, not rhetorical pairing.

### Recommended Fix

3-5 concrete fixes when running in formal mode (no chill). 1-2 concrete fixes when running with chill (prose, not numbered cascade).

**Voice in formal mode**: imperative. No "you should consider" — state what needs to happen. Include code-level guidance where possible.

**Voice with chill applied**: prose paragraphs. One clean primary fix explained, one alternative mentioned naturally. No numbered list.

```
The clean fix is to have [endpoint] [specific action]. The [mechanism] already
exists at [location], it just doesn't get invoked when [condition].

If on the other hand the design intent really is [alternative interpretation],
the [documentation / surface] should reflect that, because right now it says
[quote] which contradicts the observed behavior.
```

### Supporting Material / References

Bullet list of evidence with source. Each item = one verifiable fact.

Production sources preferred over staging. Include file sizes for bundle verification.

```
- [Source]: [URL] ([size]) — [what it proves]
- [Prior finding if applicable]: [URL] — [how it relates]
- No prior public disclosure found in [searched locations] as of [date]
```

(Standards references — CWE, OWASP, NIST — go in form fields, NOT in this section, per chill Rule 4. Exception: if the standard is genuinely the strongest argument for the finding's classification, one inline mention in prose elsewhere is acceptable.)

### Impact

TWO sub-sections: Customer Impact and Business Impact. Written as flowing paragraphs, not bullet lists.

**Customer Impact structure:**

1. "The practical consequence is..." (concrete, not abstract)
2. Describe the full chain from attacker action to victim impact
3. "This is amplified by..." (scale, integrations, deployment breadth) — this is where W1 numerical anchors can appear in prose
4. "This is not..." (explicit negative space — what's NOT at risk)
5. "I have not confirmed..." (what you deliberately didn't test)

**Business Impact structure:**

1. Scale numbers ($TVL, users, volume, partners) — W1/W4 anchors in prose
2. Regulatory context (FCA, SOC2, etc.)
3. Architectural framing (gap between security posture and actual controls)
4. The structural finding articulated

Voice: precise, honest, no overselling. An acknowledged Medium beats a dismissed High.

When chill is applied: prose stays prose, no symmetric "What IS / What is NOT" pairs, hedges on inferences, contractions natural. The anti-pattern name from Summary is referenced again in the structural finding articulation.

### Closing (chill mode only)

When chill is invoked, end with one short polite line (per chill P8): "Thanks for the time on this." / "Happy to clarify anything." / "Available for a call if it helps."

Skip in formal mode.

---

## Weight Accounting (internal pre-submission gate, NOT in report body)

MANDATORY pre-submission discipline for every finding claiming severity ≥ Low with a dollar impact. Lives in internal notes / preflight checks / KILLED-FINDINGS-LESSONS.yaml. **The framework label NEVER appears in the report body.**

Numerical anchors that emerge from W1 / W4 / W5 can be cited in Impact or Steps to Reproduce prose with their source — without the framework label.

Skipping this gate on a non-Informational finding = automatic preflight fail = submission blocked at claimed severity.

### W1 — Loss accounting

Compute the dollar exposure with a formula. Each input has a source (cast call output, API readback, docs URL, block number).

```
Formula:   [mathematical expression — e.g., stolen_amount × victims × frequency × duration]
Inputs:    - [variable 1]: [value] (source: [cast call / API readback / docs URL / block number])
           - [variable 2]: [value] (source: ...)
Computed:  $[dollar amount]
```

**DoS alternative when no fund theft:**

```
Endpoint affected:   [critical path URL]
Downtime duration:   [measured seconds/minutes/hours from PoC]
Request volume:      [req/s with source]
Affected users:      [count from documented user base]
Failed operations:   downtime × req/s × users = [N]
```

**Non-quantifiable escape hatch (only valid if W5 has ≥1 paid precedent):**

```
Quantification not feasible because: [specific ethical or access constraint]
Conservative worst-case: [prose worst-case]
```

### W2 — Stakeholder map (dashboard, optional)

LPs / treasury / retail / third-party integrators / KYC victims — with on-chain addresses or documented identifiers where applicable.

### W3 — Reversibility audit (dashboard, optional)

```
| Mechanism | Present? | Proof | Effective? |
|-----------|----------|-------|------------|
| Pause | [Y/N] | [cast call result] | [Y/N] |
| Governance override | [Y/N] | [doc URL] | [Y/N] |
| Timelock | [Y/N] | [getMinDelay readback] | [Y/N] |
| Circuit breaker | [Y/N] | [function enumeration] | [Y/N] |
```

### W3b — Freeze/halt severity-lock (MANDATORY when impact is funds-INACCESSIBLE, not funds-stolen)

Freeze/halt findings get downgraded High→Low/N/A via two triager escape hatches. Close both in the INITIAL report — severity rarely reopens (C4 PJQA = 48h post-prelim-judging only). Do NOT argue the label "freeze"; argue substance (user holds no accessible value, material duration, no user-side recourse — binary and PoC-resolvable).

- **Vector A — value-in-transit** recharacterized as "normal queueing, funds will arrive." Counter: source balance = 0 (burned), destination = 0 (mint reverted) → value destroyed on A, not existing on B. Historical event evidence proving the precondition (another user at high % of cap) is production behavior (block + recipient). "No attacker required" cuts FOR you.
- **Vector B — infrastructure halt** (checkpoint/DoS bricks the whole mechanism) recharacterized as "repairable via chain upgrade/admin, so not real loss." Counter: recovery-exists ≠ recovery-is-fast/user-accessible — spell out "[no pause, no governance override, no circuit breaker; recovery requires coordinated chain binary upgrade, multi-day, all validators, frozen throughout]." The High class presupposes recovery exists; treating its existence as a downgrade collapses two schedule boundaries.

Three mandatory Impact lines (both vectors): **User-side recourse: none** (PoC enumerates every user-callable fn, proves none reverses the freeze) · **User-side inaccessibility** (no accessible representation of value during window) · **frozen-$ × realistic-MINIMUM duration as the headline** (not the full-supply ceiling — ceiling reads theoretical). Sibling-protection cite (a spoofing/guard test on an adjacent fn, `file:line`) = internal-consistency argument against Low.

Reference: feedback_bridge_freeze_label_vs_substance.md (Injective Peggy S-23 Low+$0 despite exact-rec silent-patch; Ripio #3753469 N/A).

### W4 — Live conditions proof (MANDATORY if finding claims TVL-at-risk; dashboard otherwise)

```
Block/timestamp:      [block number, UTC timestamp]
Target contracts:     [EVERY contract address named in the severity claim]
  [addr 1]: [cast call totalSupply()/balanceOf/... output, copy-paste literal]
  [addr 2]: [cast call output]
Live failure mode:    [the SPECIFIC tokens/conditions triggering the exploit on
                       THIS deployment]
Exploit profitable:   [Y/N — arithmetic at the cited block. If N → severity unsupported.]
```

### W5 — Precedent anchor

```
| Report | Class | Payout | Source |
| --- | --- | --- | --- |
| [report ID or URL] | [vuln class] | $[amount] | H1/C4/Cantina/Sherlock |
| [report ID or URL] | [vuln class] | $[amount] | H1/C4/Cantina/Sherlock |
```

Each row MUST have a dollar figure. "Related H1 #xxx" without a paid amount does not count.

### Decision rule

For every finding ≥ Low with dollar impact, populate at least W1 OR W5 with a numerical anchor. Both slots cannot be qualitative.

If W4 is mandatory (TVL-at-risk claim), populate with literal on-chain readback at a specific block.

If W1 yields $0 and W5 yields no paid precedent for the class → severity claim is unsupported → either drop severity or do not submit.

---

## Pre-submission checklist (rigor layer)

When `chill` is also applied, this checklist runs IN ADDITION to chill's checklist. The two are concatenated, not alternatives.

### Universal items (every report)

- [ ] Every claim has evidence (curl, code quote, or screenshot) immediately following it
- [ ] Baseline test included (proves inconsistency, not blanket design) — when finding is auth-consistency class
- [ ] Anti-pattern named in prose (not just "missing X")
- [ ] "Confirmed / not confirmed" distinction made explicitly
- [ ] Negative space articulated (what IS NOT at risk) — in Impact prose, not symmetric section
- [ ] No CVSS in body text (form fields only)
- [ ] No CWE / OWASP / NIST enumeration block in body (form fields only, inline prose mention max once)
- [ ] Scale / business context included in Impact
- [ ] Fixes are imperative or prose recommendation, not "consider" suggestions
- [ ] Every curl command is copy-pasteable and production-safe
- [ ] No real user data accessed or disrupted
- [ ] Every direct quote in the body verified byte-for-byte against raw source. WebFetch / AI summaries do NOT count as verification.

### Killshot + chain-of-custody items (Critical/High with PoC only)

Skip this block if finding is info-disclosure, design-level-no-PoC, or below the $5K bounty floor.

- [ ] Killshot sentence drafted as FIRST sentence of Summary (not a separate header)
- [ ] Killshot contains all 7 structural elements applicable to the finding type
- [ ] Killshot contains zero hedge words: grep the sentence for `likely|appears|seems|may|could|if the attacker had|assuming` — any match is a fail
- [ ] Every claim in the killshot is verifiable against a source the researcher does not control (external RPC, npm registry, public explorer, target's own GitHub org)
- [ ] Chain-of-custody comment drafted in workspace (separate file, not submission body) BEFORE submission goes live
- [ ] Chain-of-custody comment contains all 5 structural elements
- [ ] Chain-of-custody comment identifies the specific bytes/fields binding the observed artifact to the claimed attack
- [ ] Plan to post the chain-of-custody comment within 2 minutes of submission going live (same session, same workspace, clipboard ready)

### Chain Acceptance Verification items (auth-class findings only)

- [ ] Ethical variant identified and documented (fictitious external_id / our own account / etc.)
- [ ] Test executed against the production target endpoint that validates the primitive
- [ ] HTTP_STATUS captured with `-w` flag
- [ ] Server-side acceptance artifact documented (account row created, MFA deleted, JWT returned with claims, tx mined)
- [ ] "What this proves" and "What this does NOT prove" both populated explicitly

### Weight accounting items (internal only, NOT in body)

- [ ] W1 formula computed OR W1 DoS alternative populated OR W1 non-quantifiable escape hatch documented
- [ ] If non-quantifiable escape hatch used: W5 has ≥1 paid precedent for the class
- [ ] W4 populated with live on-chain readback IF finding claims TVL-at-risk
- [ ] All numerical anchors cited in Impact prose are sourced (block number, cast call output, API readback)
- [ ] Weight accounting framework labels (W1, W2, W3, W4, W5) appear NOWHERE in report body

### Chill composition items (only when chill is invoked)

- [ ] Run chill skill's pre-submission checklist in full
- [ ] Verify killshot survived chill pass with zero hedges
- [ ] Verify anti-pattern naming survived chill pass (still named in prose)
- [ ] Verify chain-of-custody comment structure (5 elements) survived chill pass
- [ ] Verify weight accounting framework labels did not leak into body

---

## Voice Rules (reference, formal mode)

These rules apply to body text when `report-nerve` runs WITHOUT chill (formal mode for Cantina private audit, IACR, GHSA upstream, etc.). When chill IS invoked, defer to chill's voice rules — they supersede this table.

| Rule | Do | Don't |
|------|-----|-------|
| Claims | "I have confirmed" / "I have not confirmed" | "This vulnerability allows" (passive, vague) |
| Anti-patterns | "bearer-of-ID auth model" / "wildcard trust delegation" | "missing authentication" (generic) |
| Severity | Describe impact in concrete terms | Use "CRITICAL" or self-assign CVSS |
| Limitations | "I deliberately did not test this because..." | Hide limitations or skip them |
| Evidence | curl output, code quotes, exact responses | "Testing revealed" without showing the test |
| Scope | Negative space articulated | Omit limitations to inflate severity |
| Fixes | "The [endpoint] must require [X]" | "Consider implementing" / "It is recommended" |
| Standards | OWASP ASVS V3.7.1, NIST SP 800-63B-4 with section reference (inline once max) | OWASP Top 10 (too generic), dedicated standards section |
| Tone | First person, precise, direct, technical | Third person, passive voice, corporate |
| Formatting | Flowing paragraphs, tables for empirical data only, code blocks for evidence | Bullet-point lists for arguments |

---

## Escalation comment template (post-submission follow-up)

After initial submission, deepen the finding with additional evidence in follow-up comments when new findings emerge:

```
[Evidence type]: [What you found] confirmed in [source].

[Technical detail: static analysis, additional code path, on-chain state, etc.]

This means [implication — how it changes the capability table].

[Updated capability table if applicable]

Note: [field/behavior] is [condition-dependent]. [Specific conditions].
```

---

## Triager response discipline

Single point of read before posting any reply to a triager or client after submission. Covers three failure modes observed under fatigue. Apply this list to every external comment, not just initial reports.

> **CLOSING GATE — mandatory.** This section is not an optional checklist. The three greps below are the **closing condition** for any external English draft produced in this session: a draft is not considered complete until all three return clean. Treat the grep as the final action before the draft is rendered or sent, not as a review item to skip when tired.
>
> **In-session auto-execution.** When producing or revising any external English draft in a Claude Code session (initial report, triager response, appeal comment, follow-up), run this closing gate automatically as the final step before presenting the draft to the user. The procedure: (1) write the draft to a temporary workspace file, (2) run the three greps on that file, (3) present the draft together with the grep output, (4) if any grep hits, do not present the draft as final — flag the hit, propose the correction, re-grep after correction. Do not present a draft as final without showing the grep result.
>
> **Scope of the auto-gate.** This in-session enforcement covers drafts produced by the assistant in a Claude Code session. It does **not** cover the case where the researcher types a response directly into a platform field (Cantina comment box, HackerOne reply, email client) without routing through the session. For direct platform typing the grep stays a manual discipline; the researcher runs it on the clipboard or paste buffer before submitting.

### Rule 1: No self-flagellation

Zero apology phrases in the comment body. A technical correction is a clarification, not a fault. The triager retains every sentence you write; self-deprecation becomes ammunition for downgrade.

Banned phrases (grep before posting):

- `sorry`, `apologies`, `my apologies`
- `my fault`, `my bad`
- `careless`, `that was sloppy`, `I was lazy`
- `I was wrong about X` (use `let me clarify X` instead)
- `overstated` when self-inflicted (use `re-scoping to X` instead)
- `the gate is doing its job` and similar self-congratulating concessions

Correction phrasing template: `Let me clarify [thing]. [Technical correction without affective framing.]`

Reference incidents: Deribit rewrite (multiple "sorry" insertions in draft), dYdX F-T233 first-draft response (self-deprecating "saved me from sending more artifacts" line).

### Rule 2: No unsolicited severity concession

Severity calibration is the triager's job downward, not the researcher's pre-emptive concession. If the triager has not contested severity, do not concede it. The honest-submission rule (never oversell at submission time) stands; this rule covers the post-submission window only.

If a concession becomes technically necessary because a load-bearing claim died (reachability not demonstrable, sibling path killed by code read), phrase it as a precise factual withdrawal of the affected leg, not as a severity self-reduction:

- Acceptable: `Withdrawing the [X] reachability leg. Code read at [file:line] confirms [specific blocker]. The [Y] claim stands on its own evidence.`
- Banned: `I think this is lower severity than I claimed`, `Probably Medium not High`, `Happy to recalibrate down to [X]`, `My calibration is yours`, `Calibration is yours` trailing.

If the triager downgrades, accept the downgrade in one line without volunteering further reduction. Let them calibrate down if they want; do not pre-empt them.

Reference incidents: dYdX F-T233 followup #2 (2026-05-20) — withdrew reachability leg explicitly with file:line evidence, no severity self-reduction sentence; this is the correct shape. Earlier draft of same response contained "I don't think Critical is right" pre-emptive concession, cut before sending.

### Rule 3: No unverified path mentioned to a triager

A path mentioned to a triager becomes an implicit claim. If it is later killed by code read, it converts retroactively to a false claim and erodes the report's credibility.

A path enters a triager comment only if one of these is true:

- PoC PASS on the path (test artifact attached or referenced)
- Documented kill at `file:line` recorded in private notes

Banned formulations in any external comment:

- `candidate path I'd build next`
- `this might also be reachable via`
- `I suspect X could trigger it`
- `worth checking if Y is also exploitable`
- `there may be a sibling path through Z`

Unverified paths stay in `hunt-notes.md` (or the workspace equivalent), never in a comment field on a submission platform.

Reference incident: dYdX F-T233 (2026-05-19) — funding multi-perpetual was mentioned as a candidate path in a first-draft response before any test. Subsequent code read killed it at `subaccount.go:703-707`. The mention was cut before sending and the kill was recorded in private notes; that is the correct location.

### Rule 4: Every capability/sensitivity claim cites a SHOWN response body, never a route name or structure

This is the rule that would have caught the Helix #134 overclaims before submission. A claim of the form "X exposes Y" / "the session reads sensitive data" / "this endpoint serves KYC" / "the attacker can write" is **load-bearing**, and it must point to a **pasted response body that shows it**, not to a route name, a bundle route-map entry, or the structure of the thing. Inferring a capability from structure ("the endpoint is named `/onramp` so it exposes KYC") is the exact same epistemic error as inferring exploitability from a code pattern ("it's a read-path so it's exploitable") — structure is a hypothesis, the observed artifact is the conclusion. If you can't paste the body that proves the capability, the claim is an overclaim: cut it, or mark it explicitly as un-demonstrated.

Helix #134 shipped with **four** capability claims inferred-from-structure, never observed, all collapsed when the body was actually pulled under triager pressure: (1) "KYC-onramp linkage" — came from the `/onramp/*` route name; real bodies serve no PII. (2) "reads and writes both" — inferred from PATCH routes existing; the PATCH returned 400-device-gated, never shown mutating. (3) "sensitive trading-position config" — the fallback; real body was system defaults on a fresh account. (4) the route-map listing treated as a capability map.

**When the sensitive body is empty (test account) or un-gettable (would need a real user):**
- SHOW the empty body verbatim (don't hide it, don't summarize it to `{...}` — the `{...}` is the exact tell the triager already rejected). Frame impact on the proven MECHANISM, name the weak spot explicitly ("I can't demonstrate the sensitive contents without touching a real user"), hand the triager the mechanism + the empty reads to weight.
- Prove the ATO/impact by **EQUIVALENCE, not by faking content**: mint two sessions for the SAME victim — one the LEGIT way (a credential the victim granted, signing the victim's own challenge = the victim's real session) and one the ATTACKER way (a fresh attacker credential). Hit the same routes with each. Byte-identical responses prove the attacker holds a functionally identical copy of the victim's session, independent of account contents (empty → both empty; full → both full). This beats filling the test account: you don't fabricate impact, you prove impact TRACKS the real account whatever it holds. Helix #134: 6/6 routes byte-identical, `/user/me` identical to the millisecond.
- The equivalence claim is ITSELF load-bearing — don't write "6/6 identical" with `200 {...}` both sides. Deploy at least one FULL body-pair on a non-trivial data route (both bodies entire, side by side) so "identical" is SHOWN, not asserted.

**Retracting your own overclaim on shown evidence BUYS triager trust** — it converts a contested report into a credible one. A researcher who pulls the real body, sees it doesn't support the claim, and retracts it spontaneously is trusted on what remains. Do NOT re-assert the capability a 2nd/3rd time, do NOT hide the empty body, do NOT claim a level the shown bodies don't support. Reference: Helix #134 (2026-06-11), four overclaims retracted on re-capture, replaced with the session-equivalence proof.

### Closing gate — mandatory before draft is considered complete

Run these three greps on the draft. All three must return clean before the draft is rendered or sent. This is the closing condition referenced in the section header — not an optional review.

> **RN-1 hardening (darkside-on-report-nerve, 2026-06-23): grep-clean is NECESSARY, not SUFFICIENT.** A syntactic grep catches only the LISTED phrasings; the same self-flagellation / severity-concession / unverified-path / overclaim survives in UNLISTED wording ("I should have caught this" misses the Rule-1 grep; a hedged concession misses Rule-2). The real gates are the SEMANTIC Rule 1-4 read above + the D9 adversarial-rebuttal pass (CLAUDE.md Rule 42 — the layer that caught the 6 semantic flaws the syntactic D0-D8 missed on Superform). The grep is the mechanical BACKSTOP, never the proof the draft is clean. Treat a clean grep as 'no known tell remains', then still do the semantic read.

```bash
# Rule 1 — self-flagellation
grep -iE 'sorry|apolog|my fault|my bad|careless|I was wrong|overstated' <draft>

# Rule 2 — unsolicited severity concession
grep -iE 'I think this is (lower|medium|low)|probably (medium|low)|recalibrate down|calibration is yours|happy to (recalibrate|downgrade)' <draft>

# Rule 3 — unverified path mention
grep -iE 'candidate path|might also be reachable|I suspect|may be a sibling|worth checking if' <draft>

# Rule 4 — capability claim without a shown body: any 200/exposes/reads/writes/sensitive/identical
#   near a {...} placeholder = a load-bearing claim that's summarized instead of shown. Manual check:
#   for each "X exposes Y / session reads Z / N/N identical", confirm the FULL body is pasted, not {...}.
grep -nE '\{\.\.\.\}|200 \{[^}]*\.\.\.|exposes|reads (and|both)|sensitive|[0-9]+/[0-9]+ identical' <draft>
```

Any hit on Rule 1 or Rule 2: remove the phrase. Any hit on Rule 3: either prove the path first and re-add as a verified claim, or cut it. Any hit on Rule 4: confirm the capability/sensitivity/equivalence claim points to a pasted full body (not `{...}`, not a route name); if the body isn't shown, paste it or cut the claim.

---

## Appeal template (after Informative close)

When a finding has been closed Informative and the close is defensible to challenge:

1. **Acknowledge the specific concerns** of the close in the first paragraph (concession upfront, per chill P1 when applied)
2. **Re-test against current production state**, document with fresh artifacts (new timestamps, new tx hashes if applicable)
3. **Narrow the scope** to the most defensible claim — drop disputed sub-findings, focus on the cleanest empirical assertion
4. **Re-construct the killshot** for the narrowed claim
5. **Anticipate scoring debate** explicitly — pre-empt the metrics most likely to be contested with one paragraph of hedged-but-honest reasoning
6. **W5 precedent table becomes tactically legitimate** in appeal context (cite 1-3 paid precedents inline) — unlike initial submission where W5 stays internal

Reference: Deribit #3604442 closed Informative on 2026-05-13 → resubmitted as #3739432 on 2026-05-16 with chill styling, narrowed scope, concession-first opening, pre-empted CVSS scoring debate.

---

## Skill metadata

- **Version**: 1.0
- **Last updated**: 2026-05-16
- **Maintainer**: user (malix / SatisLoeb / Xvush / malikb31s contexts)
- **Companion skill**: `chill` (voice and style layer for anti-AI-classifier programs)
- **Derived from**: REPORT-STANDARD.md, validated against Polymarket Cantina #197 (8-minute first-touch) and Transak payment cancellation report (strongest portfolio piece, $6K payout)
- **Reference incidents**:
  - Polymarket Cantina #197: killshot + chain-of-custody = `In Review` within 8 minutes
  - Solv Protocol SOLVPR-245: chill + report-nerve composition, first production test
  - Deribit #3604442 → #3739432: appeal template after AI-generated close
  - GHSA-q6x5-8v7m-xcrf: pure rigor, no chill (upstream OSS maintainer audience)

## Companion skills (cross-references)

This skill handles structure and rigor. It does NOT handle:

- **Voice and anti-AI styling**: see `chill` (auto-invoked when target program uses human triagers prone to AI screening)
- **Adversarial triage check** (pre-submission "triageur rabat-joie" review): separate skill
- **Severity calibration / CVSS scoring discipline**: separate skill
- **Scope verification against program policy**: separate skill
- **Pattern matching against KILLED-FINDINGS-LESSONS.yaml**: separate skill

Typical composition flow for a serious Critical/High submission:

1. `report-nerve` produces the structural skeleton (killshot, sections, evidence requirements, weight accounting gate)
2. Weight accounting gate runs (internal check, never in body)
3. `chill` applied as styling pass IF target program is anti-AI-screening (HackerOne, public Cantina, HackenProof)
4. Adversarial triage runs before submission (separate skill)
5. Submit, post chain-of-custody comment within 2 minutes
6. Note outcome in SURFACES-OUTCOMES.jsonl
