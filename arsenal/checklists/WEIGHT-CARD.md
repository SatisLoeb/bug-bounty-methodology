# Weight Card — Mandatory Before Non-Informational Submissions

**Purpose:** Catch findings where the chain executes correctly (D7 passes) but the impact is narrated rather than computed. A server returning HTTP 200 on a forged request is a fact. "Potentially affects many users" is not. This gate forces numerical anchoring before submission.

**Rule:** For every finding claiming severity ≥ Low with a dollar impact, this gate is MANDATORY before submission. The hard gate is a single numerical anchor: at least one of W1 (computed dollar loss) or W5 (paid precedent with dollar figure) must contain a numerical value. Both slots cannot be qualitative.

**Reference incident:** Phemex R2 (submitted 2026-04-10, marked Informative 2026-04-13). Chain was proven (POST /assets/transfer returned code=0, status=10 via trading key). Draft contained `I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital`. The finding passed what would have been a D7 chain proof check — the endpoint accepted the primitive. It failed because the weight was narrated, not computed. Rule #15 (honest impact quantification) existed but fired reactively after the submission. This gate forces computation proactively, before the draft leaves the workspace.

**Complementary to Chain Proof Gate:** D7 answers "does the exploit execute?". D8 (this gate) answers "given it executes, is it profitable for whom, irreversibly, and market-priced at what?". Both gates are needed. A finding can pass D7 (chain proven) and fail D8 (weight absent) — that was Phemex R2. A finding can fail D7 (chain not proven) and the weight question never matters — the submission is already blocked.

---

## Finding Metadata

```
Finding ID:          [PROTOCOL-NNN]
Protocol:            [name]
Severity claimed:    [ ] Critical  [ ] High  [ ] Medium  [ ] Low  [ ] Informational
Class:               [ ] fund theft       [ ] auth bypass      [ ] credential leak
                     [ ] signature forge  [ ] IDOR             [ ] info disclosure
                     [ ] DoS              [ ] business logic   [ ] other: _______
D7 status:           [ ] PASS  [ ] N/A (not auth-class)
Draft path:          [path/to/draft.md]
```

If severity = Informational → Weight Card not required, gate auto-passes. Skip to Stage 4 and mark "N/A — Informational".

---

## Stage 1: Slot Completion

Populate the 5 slots. Stage 2 will check the hard gate (W1 OR W5 numerical). Stages 3-4 review dashboard slots and authorize submission.

### W1 — Loss accounting

**Role:** Computed dollar loss OR measured degradation for the specific exploit.

**Format required:** one of three:

**(a) Numerical formula with inputs cited.**
```
Formula:   [mathematical expression — e.g., stolen_amount × victims × frequency × duration]
Inputs:    [each variable sourced — on-chain reads, API counts, documented protocol limits]
           - [var 1]: [value] (source: [cast call tx / API response / docs URL / block number])
           - [var 2]: [value] (source: ...)
           - [var 3]: [value] (source: ...)
Computed:  $[dollar amount]
```

**(b) DoS alternative — measured degradation with downtime anchor.**
```
Endpoint affected:   [critical path name and URL]
Downtime duration:   [measured seconds/minutes/hours, from reproducible PoC]
Request volume:      [req/s on the endpoint, from production metrics or estimation with source]
Affected users:      [count from documented user base]
Failed operations:   downtime × req/s × affected users = [N failed sessions]
```
DoS alternative counts as numerical anchor for D8 without a dollar figure or paid precedent. Required: duration must be measured or extrapolated from the PoC, not asserted. "An attacker could DoS the endpoint" without a duration is not a numerical anchor.

**(c) Non-quantifiable — conservative scenario (escape hatch).**
```
Quantification not feasible because: [specific reason, e.g., "requires opening leveraged
  positions with real capital to measure profit", "requires a deployed production
  instance we do not have access to", "impact is in non-monetary user data"]
Conservative worst-case: [prose worst-case, assuming attacker maximizes the primitive
  within ethical constraints]
```
**This form is ONLY acceptable if W5 is populated with ≥1 paid precedent and a dollar figure.** Both W1 and W5 cannot be qualitative. If W1 is escape-hatch and W5 is also empty or qualitative, Stage 2 D8 fails.

### W2 — Stakeholder map (dashboard)

**Role:** Who loses, with on-chain addresses or documented account identifiers where possible.

```
Primary victims:     [LPs / treasury / retail holders / KYC submitters / integrators]
On-chain addresses:  [if applicable, list addresses]
Off-chain identifiers: [user base count, account types, jurisdictional categories]
Blast radius:        [protocol-specific / cross-protocol / ecosystem-wide]
```

Empty W2 = dashboard weakness noted but does not block. A finding with a computed W1 but no stakeholder map is still submittable; the hunter accepts reduced argumentation density.

### W3 — Reversibility audit (dashboard)

**Role:** Recovery mechanisms present or absent. Each mechanism listed with on-chain or documentation proof.

```
| Mechanism          | Present?  | Proof                                          | Effective against this bug? |
|--------------------|-----------|------------------------------------------------|----------------------------|
| Pause              | [Y/N]     | cast call [address] "paused()" → [value]      | [Y/N — reasoning]          |
| Governance override| [Y/N]     | governance doc URL / timelock address         | [Y/N]                      |
| Timelock           | [Y/N]     | cast call [timelock] "getMinDelay()" → [sec]  | [Y/N]                      |
| Circuit breaker    | [Y/N]     | bytecode grep / contract function enumeration | [Y/N]                      |
| Admin upgrade      | [Y/N]     | EIP-1967 admin slot readback                   | [Y/N]                      |
```

For web/API findings: replace with platform-specific recovery primitives (session invalidation, token rotation, password reset, etc.).

Absent recovery mechanisms STRENGTHEN severity. A finding where every mechanism is "not present" is permanent and irreversible — explicitly note this in the report body (already part of Rule #13, re-surfaced here).

### W4 — Live conditions proof (conditional gating — mandatory for TVL-scaled claims)

**Role:** Prove the profitability conditions are active NOW, on mainnet, at a specific block or timestamp. Distinct from D7 (server accepts the forged primitive) — W4 proves the economic surroundings are favorable AND the severity claim matches the specific deployment state at the cited block.

**When W4 is MANDATORY (gating under D8):**
- Finding claims "$X TVL at risk" / "$Y affected" — needs readback of balance on the named contracts
- Finding claims "N wrappers / vaults / contracts affected NOW" — needs enumeration of the N contracts with their live state
- Finding severity is defended by precedents that scale with TVL (freeze findings, DoS of a vault, oracle manipulation affecting pool liquidity, governance takeover of a vault)
- Finding cites historical frozen-funds / exploited-value numbers as the weight anchor — the historical number must be matched to the SPECIFIC current deployment's state

**When W4 is DASHBOARD ONLY (non-gating):**
- Access control bypass where the weight is the access itself, not TVL (logic error, state corruption)
- Pure information disclosure (severity floor already reflects the absent dollar weight)
- Smart contract state delta forge-test with asserted $ loss on mainnet fork — the forge test IS the W4 (block pinned, fork-based, reads real state, asserts real delta)
- Signature forge / auth bypass findings where the impact is data access, not fund theft
- Pure logic bugs where correctness (not quantity) is the finding

**Format (when mandatory):**

```
Block/timestamp:     [block number, UTC timestamp]
Target contracts:    [EVERY contract address named in the severity claim, with its readback]
  [addr 1]:          totalSupply = [value], reserve/balance = [value], paused = [Y/N]
  [addr 2]:          totalSupply = [value], ...
Live failure mode:   [the specific tokens/conditions that trigger the exploit — matched against the
                      specific deployment, not a generic class-level scenario. If the draft cites
                      USDT-pause as the failure mode, the target contract MUST actually use USDT in
                      the relevant position.]
Exploit profitable:  [Y/N — arithmetic check at the cited block. If N → severity claim
                      unsupported, downgrade or drop.]
```

For web/API findings: "live conditions" translates to "the vulnerable endpoint is serving production traffic, the leaked secret has not been rotated, the bypass endpoint is not behind a WAF rule that blocks the attack vector, and user sessions are active". Provide timestamps. W4 is non-gating for web/API unless the finding claims "$X revenue at risk" / "N users affected NOW".

**Test for whether W4 is mandatory:** does the finding's severity claim scale with the TVL/count of specific contracts? If yes → W4 mandatory. If the severity is independent of TVL (logic bug, access control, signature forge) → W4 dashboard only.

**Reference incident** (Reserve F-003 Convex freeze 2026-04-13): draft claimed HIGH severity "Permanent freezing of funds" and named 6 vulnerable ConvexStakingWrappers with precedent table and "$3.3B+ USDT frozen history". D7 clean (PoC passing), D8 grep clean (no narrative phrases), W1/W5 populated. On-chain W4 verification at current block showed 5/6 named wrappers have `totalSupply() = 0` and the 1 with TVL has CVX (Convex's own token) as its sole extra reward — an unfailable token. Draft's HIGH severity was unsupported by specific deployment state. The quantitative claim ("2 wrappers immediately vulnerable") was true in the source code but false on-chain. Without mandatory W4 gating, this draft would have been submitted and dismissed in ~10 min by a triager running the same `cast call` queries.

### W5 — Precedent anchor

**Role:** Market-priced via published payouts. ≥1 paid precedent with a dollar figure is the minimum for W5 to count as a numerical anchor under D8.

```
| Report                      | Class                | Payout   | Source                  |
|-----------------------------|----------------------|----------|-------------------------|
| [report ID or URL]          | [vuln class]         | $[amount]| [H1/C4/Cantina/Sherlock]|
| [report ID or URL]          | [vuln class]         | $[amount]| [H1/C4/Cantina/Sherlock]|
| [report ID or URL]          | [vuln class]         | $[amount]| [H1/C4/Cantina/Sherlock]|
```

**Hard rules for W5:**
- Each row MUST have a dollar amount. "Related H1 #xxx" without a paid figure does not count.
- Unpaid disclosed reports (status: Disclosed but bounty: None) do not count.
- Program average payout data (e.g., "median SSRF = $X") counts only if the source cites specific reports.
- C4/Cantina/Sherlock contest awards count only if the specific finding was awarded.
- OUTCOMES.jsonl local records count if they contain a payout > 0.
- 1 row satisfies D8 (hard gate). 2-3 rows make the argument defensible. More than 3 is overkill.

Use `~/arsenal/tools/precedent-scan.sh <class>` to populate W5 fast. It emits a copy-paste-ready block matching this table format exactly.

---

## Stage 2: Hard Gate Check (D8)

D8 has two independent requirements. Both must pass (where applicable) for D8 to pass.

### Stage 2a — Numerical anchor (always required)

Answer: **Does W1 OR W5 contain a numerical anchor?**

| W1 state | W5 state | Stage 2a verdict |
|----------|----------|------------------|
| Computed dollar formula with inputs | Any | **PASS** |
| DoS alternative with downtime × req/s × users | Any | **PASS** |
| Non-quantifiable (escape hatch) | ≥1 paid precedent with $ figure | **PASS** |
| Non-quantifiable (escape hatch) | Empty / qualitative / unpaid refs only | **FAIL** |
| Empty | ≥1 paid precedent with $ figure | **PASS** (W1 should still be populated with at least escape-hatch prose) |
| Empty | Empty | **FAIL** |

### Stage 2b — Live conditions match (mandatory IFF finding claims TVL-at-risk or N-contracts-affected)

First, determine if Stage 2b applies:

```
Does the finding's severity claim scale with the TVL of a specific named contract,
a specific number of named contracts, or a specific user base size?

[ ] YES — Stage 2b is MANDATORY. Proceed to the checklist below.
[ ] NO — severity is independent of live TVL/count (access control bypass, signature
    forge, pure logic bug, state-delta forge-test with asserted $ loss, pure info
    disclosure). Stage 2b = N/A. Skip.
```

If Stage 2b applies, answer each question:

```
For EACH contract address named in the severity claim:

[ ] Block/timestamp cited in W4
[ ] Readback of totalSupply / balance / reserves via cast call (or equivalent)
[ ] The readback value > 0 OR explicitly acknowledged as 0 with latent-risk framing
[ ] For claims naming N contracts: all N contracts enumerated with readback
[ ] Failure mode (the specific tokens/conditions triggering the exploit) matches the
    specific deployment (not a generic class-level scenario). If the draft cites
    USDT-pause, the target contract must actually use USDT in the relevant position.
[ ] Arithmetic: current TVL × failure probability × extraction fraction = claimed
    severity anchor. Numbers must be consistent across the draft.
```

| All checked | Stage 2b verdict |
|---|---|
| Yes | **PASS** |
| Any unchecked | **FAIL** |

### Stage 2 overall verdict

| Stage 2a | Stage 2b | D8 overall |
|---|---|---|
| PASS | PASS or N/A | **PASS** |
| PASS | FAIL | **FAIL** (quantitative claim unsupported by deployment state) |
| FAIL | any | **FAIL** (no numerical anchor) |

**If D8 = FAIL:** four options.
1. Populate W1 with a computed formula. Use on-chain reads, documented protocol limits, or measured DoS degradation.
2. Populate W5 with a paid precedent. Run `precedent-scan.sh <class>` and copy the emitted W5 block into the report.
3. Populate W4 with actual on-chain readback at a specific block for every contract named in the severity claim. Downgrade severity if readback doesn't match the claim.
4. Downgrade severity to Informational and remove any prose claiming dollar impact.

Do not submit at the claimed severity until D8 passes.

**Meta-rule for Stage 2b:** the readback output must appear in the record, not a description of the readback. If Stage 2b is filled with "I ran cast call and saw the right values" instead of the literal `cast call 0x... "totalSupply()" → 12,480,000,000` output, the gate is not valid. Same hallucination defense as Chain Proof Gate Stage 4.

---

## Stage 3: Dashboard Review

Empty dashboard slots are not gating, but they are noted as argumentation weaknesses. Fill out this checklist before proceeding to Stage 4.

```
[ ] W2 — Stakeholder map populated (victims identified)
[ ] W3 — Reversibility audit completed (recovery mechanisms audited)
[ ] W4 — Live conditions proof (status: gating if TVL-claim, dashboard otherwise)
```

Note: W4 is conditionally gating (Stage 2b). If the finding claims TVL-at-risk or N-contracts-affected impact, W4 is not a dashboard slot — it is a hard gate and must be checked in Stage 2b before reaching Stage 3. If the finding is severity-independent from live TVL (access control, logic bug, signature forge), W4 remains dashboard and an empty W4 is merely a noted weakness.

Slots left empty → explicitly note in the report body: "Argumentation weakness: [list]". This is honest framing and prevents over-strong claims. A hunter who leaves W4 empty (where non-gating) should not claim "the attack is profitable right now" — the claim becomes "the attack would be profitable under conditions X, Y, Z which I have not verified at a specific block".

---

## Stage 4: Submission Authorization

**Before filling this section, paste the literal content of each populated slot below. Do not describe the slots from memory — the slot content must appear in the record. This prevents hallucinated "I computed W1" without actually having a number.**

```
W1 — Loss accounting:
[PASTE THE LITERAL CONTENT of the W1 slot from the draft here, including formula, inputs,
and computed value. If escape-hatch, paste the full "Quantification not feasible because..."
block.]

W5 — Precedent anchor (if applicable):
[PASTE THE LITERAL CONTENT of the W5 table from the draft here, including at least one row
with a dollar amount if used as the numerical anchor.]

W4 — Live conditions proof (MANDATORY if finding claims TVL-at-risk or N-contracts-affected):
[PASTE THE LITERAL cast call output for EVERY contract named in the severity claim, with
block number. Example: "cast call 0x511daB8... "totalSupply()(uint256)" --rpc-url ... → 0".
If N/A, state why: "W4 N/A — access control bypass, severity independent from live TVL"
or similar.]

W2/W3 slot status:
[ ] W2 filled  [ ] W2 empty
[ ] W3 filled  [ ] W3 empty
W4 status:
[ ] W4 gating + filled with on-chain readback
[ ] W4 gating + filled + readback contradicts severity claim → downgrade required
[ ] W4 N/A (severity-independent finding class)
[ ] W4 dashboard-only + filled
[ ] W4 dashboard-only + empty (argumentation weakness noted)
```

```
D8 hard gate verdict:    [ ] PASS  [ ] FAIL
Stage 2a (W1/W5):        [ ] PASS  [ ] FAIL
Stage 2b (W4 match):     [ ] PASS  [ ] FAIL  [ ] N/A
Numerical anchor source: [ ] W1 computed  [ ] W1 DoS alternative  [ ] W5 paid precedent  [ ] both
Dashboard weaknesses:    [list empty slots or "none"]
Claimed severity:        [Critical / High / Medium / Low]
Adjusted severity:       [unchanged / downgraded to ___]

Final verdict: [ ] AUTHORIZED  [ ] BLOCKED  [ ] DOWNGRADED to [new severity]
```

If BLOCKED: do not submit until Stage 2 resolves.
If DOWNGRADED: update severity in draft AND in submission form AND remove all prose claiming the higher-severity impact.
If AUTHORIZED: proceed to PREFLIGHT-CHECK.md (criterion D8 checks this gate was run).

**Meta-rule:** if the slot content fields are filled with text like "W1 has a formula" instead of the actual formula and dollar amount, the gate is not valid. This rule exists because I am capable of hallucinating that a slot was computed when it was not. The only defense is requiring the actual slot content to appear in the record.

---

## Gate Exceptions

This gate does NOT apply (D8 full N/A) to:

- **Pure information disclosure findings already claimed at Informational/Low.** The severity floor already reflects the absent weight. If the hunter claims Medium+ on an info disclosure, the gate DOES apply — the claim triggers the requirement.
- **Smart contract findings with forge-test PoCs that assert state deltas on mainnet fork.** The state delta IS the computed W1 AND the live conditions proof (W4) — the fork test is pinned to a block and reads real state. Example: `assertEq(victim.balance, 0)` after the exploit test on `vm.createSelectFork(mainnet, block_X)` = W1 and W4 implicit. The hunter should still populate W5 where precedent exists. **Important caveat**: this exception applies only if the forge test's `assertEq` is expressed in dollar-equivalent terms or against a contract with direct dollar meaning (e.g., USDC balance). If the forge test asserts "user_checkpoint reverts" (access pattern) without asserting a $ delta, the exception does NOT apply and full D8 + Stage 2b review is required.
- **DoS findings where downtime × req/s × users is the primary metric.** W1 (b) form applies. The downtime count is the numerical anchor. This is the "DoS alternative" codified. Stage 2b is N/A because the DoS metric is the weight (not TVL).
- **Findings where the HTTP response IS the impact measurement** (e.g., `/api/users` returning 247 users with emails is both the chain proof and the weight — the count is the anchor). In these cases, W1 contains the enumerated count and the affected population size. Stage 2b is N/A because the count is the weight.

Stage 2b (W4 mandatory) specifically applies to:

- **Smart contract findings claiming "$X TVL at risk" / "Y wrappers/vaults/contracts affected NOW"** — W4 must enumerate every named contract with on-chain readback.
- **Findings citing "historical frozen-funds amounts" as weight anchor** ("$3.3B+ USDT frozen", "$X stuck in Curve pools", etc.) — the historical number is narrative weight in disguise unless the CURRENT deployment is explicitly matched to that failure mode.
- **Freeze/DoS findings where the impact is "locked funds"** — need to prove funds are currently locked (or deposited such that they CAN be locked).
- **Oracle manipulation findings where the impact scales with pool liquidity** — W4 must show current pool reserves at the cited block.
- **Governance takeover findings** — W4 must show current quorum requirements, timelock delays, admin keys.

For every other finding claiming severity ≥ Low with a dollar impact, Stage 2a (W1/W5) is the hard gate and Stage 2b is N/A.

For every other finding claiming severity ≥ Low with a dollar impact, this gate is mandatory.

---

## War Log

| Date | Finding | Before gate | After gate | Δ severity | Δ reward |
|------|---------|-------------|------------|-----------|----------|
| 2026-04-13 | Phemex R2 /assets/transfer via trading key (retroactive test) | Submitted with "I have not confirmed whether this enables profitable extraction via margin manipulation, because doing so would require opening leveraged positions with real capital" — W1 qualitative, W5 empty. Chain D7 would pass (server returns code=0, status=10). **D8 FAILS.** | Gate forces downgrade to Informational OR populating W5 via precedent-scan.sh for "API key privilege escalation" class. Retroactive test result: downgrade was the correct call. | Should have been Informational from the start | Prevented $0 informative submission + preserved credibility |
| 2026-04-13 | WEEX-002 Zendesk JWT forge (retroactive test) | Chain proven by Chain Proof Gate (HTTP 200 + authenticated:true + permanent appUser). Weight Card would have used W5 (hardcoded JWT signing key precedents on H1) + W2 (6.2M user support conversation history). | (retroactive simulation) Gate authorizes: W5 populated from hardcoded-credential / JWT-secret class in H1 corpus → paid precedents confirmed, $2,500–$10,000 range defended. | Unchanged (Critical) — Chain Proof Gate carried the severity, Weight Card anchors the market price claim |
| 2026-04-13 | Reserve F-003 Convex extra reward freeze | Draft claims HIGH "Permanent freezing of funds", names 6 ConvexStakingWrappers, cites "$3.3B+ USDT frozen history" and 7 Medium/High precedents. D7 grep: 0 hits. D8 grep: 0 hits. Forge tests: 11/11 pass on mainnet fork. Stage 2a passes. | Stage 2b W4 on-chain readback: 5/6 wrappers have totalSupply = 0, 1/6 (wcvxETHPlusETH) has ~153 LP but its sole extra reward is CVX (unfailable). The 2 "immediately vulnerable" wrappers are empty. Realistic $ at risk at current block ≈ 0. **Stage 2b FAIL.** | HIGH → DOWNGRADE (Low/Informational) or DROP. Latent risk framing: becomes HIGH only if empty wrappers gain TVL AND non-CVX extras are added. | Prevented dismissed HIGH submission; D7 grep + Stage 2a would not have caught this — Stage 2b W4 readback is what fired. |

---

## Anti-Pattern Phrases — Narrative Weight Indicators

If the draft contains any of these phrases WITHOUT a Stage 1 numerical anchor backing them up, the draft is not submission-ready at the claimed severity:

- "could drain"
- "could extract"
- "could potentially"
- "significant funds"
- "substantial losses"
- "large number of users"
- "many users"
- "many accounts"
- "estimated to"
- "potentially affects"
- "at risk"
- "exposes users to"
- "attacker could extract"
- "could lead to"
- "may result in"
- "would enable loss of"
- "all users"
- "all deposits"
- "all funds"
- "widespread impact"
- "catastrophic"
- "devastating"
- "severe financial damage"
- "impact is significant"

The phrase `grep -nE` one-liner for mechanical detection:

```bash
grep -nE "could drain|could extract|could potentially|significant funds|substantial losses|large number of users|many users|many accounts|estimated to|potentially affects|at risk|exposes users to|attacker could extract|could lead to|may result in|would enable loss of|all users|all deposits|all funds|widespread impact|catastrophic|devastating|severe financial damage|impact is significant" "$DRAFT_PATH"
```

These phrases are not banned outright — they can appear in the report body to frame context. But each occurrence should be paired with a specific number elsewhere in the same section. A report full of "could X" with zero dollar amounts or enumerated counts is narrative impact, not computed weight. D8 catches that.

**Counter-example:** "The exploit could drain the vault's full reserves — computed at 12,480 USDC across 23 active depositors at block 19,847,332 (cast call totalAssets → 12,480,000,000 with 6 decimals)." — the "could drain" phrase is followed immediately by a specific number and on-chain source. D8 passes because W1 is populated.

**The test:** if a triager replaced "significant funds" with "$3.47" in your draft, would the argument still hold? If the sentence becomes absurd ("The attacker could extract $3.47 from all users"), the number is doing the work of the argument and must be real. Run `precedent-scan.sh` for W5 or compute W1 from on-chain inputs, then replace the adjective with a number.

---

## Relationship to Chain Proof Gate (D7)

| Question | Gate | When |
|----------|------|------|
| Does the server accept the forged/bypassed primitive? | **D7** (CHAIN-PROOF-GATE.md) | Before report writing, on auth-class findings |
| Given the primitive is accepted, is the impact priced? | **D8** (this gate) | Before submission, on findings claiming ≥ Low severity with dollar impact |

Both gates are needed. A finding must pass both (where applicable). A finding that passes D7 and fails D8 is exactly Phemex R2. A finding that passes D8 but fails D7 is what the Chain Proof Gate rejects — "I have a precedent for this class, so the exploit must work too" is not a chain proof.

Scope overlap: auth-class findings (JWT forge, hardcoded credentials, etc.) that claim High/Critical severity go through both gates. Smart contract fund theft findings with forge tests go through D8 only (chain proof is implicit in the state delta). Pure info disclosure findings claimed at Informational go through neither.
