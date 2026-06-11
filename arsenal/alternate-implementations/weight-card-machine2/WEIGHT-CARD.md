# Weight Card — Mandatory Before Non-Informational Submissions

**Purpose:** Catch findings whose impact is narrated instead of computed. Specifically targets the class of findings where the exploit chain is proven (server accepts it, HTTP 200, authenticated:true) but the **weight** — how much does it cost, to whom, irreversibly, at what market-priced comparable — is hand-waved with adjectives like "significant funds" or "large number of users".

**Rule:** For every finding claiming severity ≥ Low with a dollar impact, this card is MANDATORY before submission. At least one of W1 (computed dollar loss) or W5 (paid precedent with dollar figure) must contain a **numerical anchor**. Both slots cannot be qualitative. An unpaid "related H1 #xxx" does not satisfy W5 — only paid references with dollar amounts count.

**Relationship to Chain Proof Gate:** Chain Proof Gate answers *"does the exploit execute?"*. Weight Card answers *"is the exploit profitable, for whom, irreversibly, and market-priced at what?"*. Both gates are complementary. A finding must pass both before submission.

**Reference incident:** Phemex R2 (2026-04-10 submitted, 2026-04-13 marked Informative). The API key privilege escalation was reachable, the endpoint responded, the chain was proven. But the draft said *"I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital"*. Weight was narrated, not computed. Marked Informative, 2 rep, $0. Same architectural lesson as WEEX-002, one-hour apart — except WEEX-002 was saved by Chain Proof Gate ingestion, and Phemex R2 plateaued because its failure mode was weight, not chain.

---

## Finding Metadata

```
Finding ID:       [PROTOCOL-NNN]
Protocol:         [name]
Severity claimed: [Critical / High / Medium / Low]
Finding class:    [ ] fund-theft           [ ] access-control
                  [ ] data-disclosure      [ ] DoS
                  [ ] privilege-escalation [ ] bridge/cross-chain
                  [ ] governance           [ ] other: _______
Draft path:       [path/to/draft.md]
```

---

## Stage 1: Slot Completion

Fill every slot you can. W1 and W5 form the hard gate pair (at least one must contain a numerical anchor). W2, W3, W4 are dashboard slots — they don't block, but their absence is a visible weakness.

### W1 — Loss accounting

**One of three acceptable forms:**

**(a) Computed dollar loss** — formula + cited inputs → dollar figure.
```
Formula:        [$value × victims × frequency × time window]
Inputs:
  - [input 1]:  [value]  (source: on-chain block X / API readback / documented limit)
  - [input 2]:  [value]  (source: ...)
  - [input 3]:  [value]  (source: ...)
Computed loss:  $[amount]
```

**(b) DoS alternative** — measured degradation of a critical endpoint.
```
Target endpoint:     [URL or contract function]
Downtime duration:   [X seconds/minutes/hours]  (measured via reproducible PoC)
Request rate:        [Y req/s]                  (extrapolated from normal traffic or logged)
Affected users:      [Z users]                  (source: disclosed MAU, on-chain active addresses, etc.)
Degradation metric:  [duration × rate × users] = [N failed sessions / blocked TXs / unavailable hours]
```
The duration must be **measured or extrapolated from a reproducible PoC**, never asserted. The DoS alternative counts as a numerical anchor for D8 even without a dollar figure.

**(c) Non-quantifiable — conservative scenario** — prose worst-case.
```
Non-quantifiable because: [specific constraint: e.g. off-chain data, KYC info, access only]
Conservative loss scenario: [worst-case prose with concrete victims and outcomes]
```
**Form (c) is ONLY acceptable if W5 provides the numerical anchor.** Both slots cannot be qualitative.

### W2 — Stakeholder map

Dashboard slot — not gating, but emptiness is a noted weakness.

```
Who bears the loss:
  [ ] LPs              — [specifics, addresses if known]
  [ ] Treasury         — [treasury address if on-chain]
  [ ] Retail users     — [user count estimate]
  [ ] Third-party integrators  — [which integrators]
  [ ] KYC / PII victims        — [data types exposed]
  [ ] Counterparty / whale     — [specific address]
  [ ] Protocol itself          — [contract address]
```

### W3 — Reversibility audit

Dashboard slot. Each recovery mechanism listed with proof of absence or presence.

```
Pause function:     [ ] absent [ ] present (effective? [Y/N]) — proof: cast call <addr> "paused()"
Governance override: [ ] absent [ ] present (latency: [X days]) — proof: governance contract check
Timelock:           [ ] absent [ ] present (duration: [Y hours]) — proof: TimelockController getMinDelay()
Circuit breaker:    [ ] absent [ ] present (trigger: [condition]) — proof: ...
Migration path:     [ ] absent [ ] present — proof: ...

Effective recovery: [ ] yes [ ] no [ ] partial
```

### W4 — Live conditions proof

Dashboard slot. Distinct from Chain Proof Gate D7 (D7 = server accepts forged primitive; W4 = profitability conditions active NOW).

```
Block / timestamp:    [block number or ISO8601 timestamp]
Pool liquidity:       [$ amount] (read via cast call, block X)
Paused state:         [false / true] (read via cast call, block X)
Active user interaction: [recent tx count / volume / TVL trend] (source)
TVL at block X:       [$ amount]
```

For web/API findings, W4 covers: endpoint live, API key not rotated, user base still active. Proof via innocuous readback (e.g. `/api/health` returning 200, user count endpoint, public status page).

### W5 — Precedent anchor

**One of the two hard gate slots.** Market-price the finding against published paid precedents.

```
| Report | Class | Payout | Source |
| --- | --- | --- | --- |
| [report ID or URL] | [vulnerability class] | $[paid amount] | [H1 / C4 / Cantina / Sherlock] |
| [report ID or URL] | [vulnerability class] | $[paid amount] | [H1 / C4 / Cantina / Sherlock] |
| [report ID or URL] | [vulnerability class] | $[paid amount] | [H1 / C4 / Cantina / Sherlock] |
```

**Minimum 1 row for D8 pass** if W1 is qualitative (form c). **Minimum 2-3 rows for a defensible argument.** Unpaid references do not count.

Fast population: `arsenal/tools/precedent-scan.sh "<class>"` emits a copy-paste-ready W5 block directly formatted for this template.

---

## Stage 2: Hard Gate Check

Answer the binary question:

```
W1 contains a numerical anchor (form a or b):  [ ] YES  [ ] NO
W5 contains ≥1 paid precedent with $ figure:    [ ] YES  [ ] NO

At least one is YES:                            [ ] YES  [ ] NO
```

**Verdict:**

| At-least-one = YES | Verdict |
|---|---|
| YES | PROCEED to Stage 3 (dashboard review) |
| NO  | STOP — either compute W1 from on-chain/documented inputs, or run `precedent-scan.sh` to populate W5, or downgrade severity to Informational and remove all dollar claims from the draft. |

**D8 in PREFLIGHT-CHECK.md mirrors this verdict as gating.** D8 fail = do not submit at claimed severity regardless of total score.

---

## Stage 3: Dashboard Review

For each dashboard slot, check whether it is populated. Emptiness does not block submission, but surfaces argumentation weakness pre-submission.

```
W2 Stakeholder map:    [ ] populated  [ ] empty (weakness)
W3 Reversibility audit: [ ] populated  [ ] empty (weakness)
W4 Live conditions:    [ ] populated  [ ] empty (weakness)

Argumentation weakness noted: [list empty slots]
```

Decide: strengthen weak slots now, or submit knowing the triager may challenge on these exact points. **This is a visibility exercise, not a block.** The EV gate in Kill Gate decides go/no-go; Weight Card makes the weakness visible so the decision is informed.

---

## Stage 4: Submission Authorization

**Before filling this section, run `precedent-scan.sh "<class>"` against the finding class for real and paste the literal output below if you used W5 as the numerical anchor. Do not describe the result from memory.**

```
$ arsenal/tools/precedent-scan.sh "<class>"

[PASTE THE LITERAL OUTPUT OF THE W5 COPY-PASTE BLOCK HERE. If form (a) or (b) was used for W1, write "W5 not used — W1 provides the anchor".]
```

```
Numerical anchor used:    [ ] W1 (a) computed   [ ] W1 (b) DoS   [ ] W5 (paid precedents)
W1 form:                  [computed / DoS / non-quantifiable / skipped]
W1 value:                 [$ amount OR DoS metric OR "non-quantifiable (see W5)"]
W5 precedents cited:      [count]
W2 stakeholder map:       [ ] populated  [ ] empty
W3 reversibility audit:   [ ] populated  [ ] empty
W4 live conditions:       [ ] populated  [ ] empty
Weakness accepted:        [list or "none"]

Final verdict: [ ] AUTHORIZED  [ ] BLOCKED  [ ] DOWNGRADED to [new severity]
```

If BLOCKED: do not submit at claimed severity. Either complete W1 from on-chain inputs, expand W5, or downgrade.
If DOWNGRADED: update severity in draft AND in submission form AND remove all phrases claiming higher impact.
If AUTHORIZED: proceed to PREFLIGHT-CHECK.md (criterion D8 checks this gate was run).

**Meta-rule:** if the precedent-scan output field is filled with text like "I ran precedent-scan and got a range" instead of an actual `$ precedent-scan.sh ...` invocation + its literal stdout, the gate is not valid. Same hallucination defense as Chain Proof Gate Stage 4.

---

## Gate Exceptions

This gate does NOT apply to:

- **Purely informational findings** already claimed at Informational/Low severity. The severity floor already reflects the absent dollar weight; there is nothing to anchor. Low-severity information disclosure, debug output leakage, banner exposure, etc. — if the severity is already at the floor, the gate is N/A.

- **DoS findings** — these use the W1 alternate anchor (form b) rather than dollar computation or precedent. `downtime duration × estimated req/sec × affected users` counts as a numerical anchor for D8. Example: *"critical trading endpoint unavailable for 4h × 120 req/s × 6.2M users = 1.7M failed sessions"*. Required: the duration must be measured or extrapolated from a reproducible PoC, not asserted.

- **Smart contract findings with forge-test PoCs that assert state delta on mainnet fork.** The state delta *is* the W1 numerical anchor — computed loss is mechanically derived from `assertEq(vault.balance() after exploit, vault.balance() - X)`. No separate W1 needed. W5 still recommended for market pricing.

- **Findings where the HTTP response IS the weight** — e.g. `/api/users?limit=all` returning 247 KYC records: the response body is the impact and "weight" is implicit in the count returned. No separate W1 needed if the response is already cited in the PoC.

For every other finding making a dollar claim at severity ≥ Low, this gate is mandatory.

---

## War Log

| Date | Finding | Before gate | After gate | Δ severity | Δ reward |
|------|---------|-------------|------------|-----------|----------|
| 2026-04-10/13 | Phemex R2 /assets/transfer via trading key | Submitted with "I have not confirmed whether this enables profitable extraction via margin manipulation" — weight narrated, not computed | N/A — gate did not exist yet | Marked Informative post-submission | +2 rep, $0 |
| 2026-04-13 | WEEX-002 Zendesk JWT forge | Chain proven by Chain Proof Gate → Weight Card would have used W5 (hardcoded signing key precedents on H1) + W2 (6.2M users support convo history) | (retroactive simulation) | Medium/Informative → Critical via Chain Proof Gate; Weight Card would have anchored the $ claim | $2,500-$10,000 range defended |

---

## Anti-Pattern Phrases — Never Ship These Without a Numerical Anchor

If the draft contains any of these exact phrases but W1 is non-numerical AND W5 is empty, the draft is not submission-ready:

- "could drain [funds / users / the treasury]"
- "could extract [significant / substantial] funds"
- "significant funds at risk"
- "large number of users affected"
- "substantial losses possible"
- "many users exposed"
- "potentially affects [all / many / a large number of]"
- "estimated to cost [without formula]"
- "exposes users to [financial loss / account takeover / identity theft]"
- "attacker could [drain / extract / steal]" (without quantification at each step)
- "impact is significant"
- "widespread impact"
- "catastrophic impact"
- "severe financial damage"
- "devastating to [protocol / users / ecosystem]"

These phrases are red flags that the weight is narrated. The fix is never cosmetic rewording. The fix is to run `precedent-scan.sh` for W5 or compute W1 from real inputs, then replace the adjective with a number or a paid precedent row.

**The test:** if a triager replaced "significant funds" with "$3.47" in your draft, would the argument still hold? If the sentence becomes absurd, the number is doing the work of the argument. Put a real number there.
