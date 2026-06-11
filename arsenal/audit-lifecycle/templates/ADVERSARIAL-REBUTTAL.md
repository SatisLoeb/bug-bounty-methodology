# Adversarial Rebuttal — {FINDING_ID}

> Last updated: <fill-timestamp>
> Workspace: <fill-workspace>
> Draft file under review: <fill-draft-path>

## Purpose

This document forces a deliberate adversarial pass on the finding draft BEFORE submission.
The pass is performed by Claude (or the operator) writing **as the triager** — not as the
researcher. The goal is to produce the rebuttal the triager will most likely write, and to
catch fatal flaws while the draft is still revisable.

**Gate semantics:**
- This file MUST be populated before preflight-mechanical.sh returns PASS.
- Minimum 6 distinct angles required. Fewer = gate fail.
- Each angle MUST have a non-empty `Counter` section. "No defense" is itself a flag — if a
  finding has no counter to a plausible triager rebuttal, the finding is too weak to submit.
- The final Verdict section MUST resolve to one of: `READY_TO_SUBMIT` / `DOWNGRADE_REQUIRED`
  / `KILL` / `NEEDS_MORE_EVIDENCE`. Any other verdict fails the gate.

**Why this exists:**
- F-001 Superform v2 (2026-05-16) was self-validated as "ready to submit" with 22/24+
  preflight, then collapsed under operator-driven adversarial review on 6 structural
  issues that should have been caught here: "drainage ≠ non-accrual" framing, no
  identifiable attacker, mock PoC vs fork test requirement, unsourced impact numbers,
  design-intent rebuttal, external-integration scope exclusion.
- The pattern: per-finding gates (kill-gate, weight-card, chain-proof) operate at the
  syntactic level (does the slot have a value?) but not the semantic level (does the
  value survive an adversary?). Adversarial Rebuttal closes that loop.

---

## Angle 1: Scope class mismatch

**Triager rebuttal:** Does the finding's claimed severity class actually exist in the
program's scope definitions? Quote the exact severity definition string from the program
page and compare to the finding's framing.

**Specific check:**
- Quote the program's exact severity class definition (Critical / High / Medium).
- Does the finding's first-paragraph framing use language that matches the scope class
  verbatim, or does it bend the words?
- Is "drainage" vs "non-accrual" being conflated? Is "theft" being claimed without an
  identifiable extracting party? Is "loss of user funds" being implied without depositors
  actually losing principal?

**Finding's claim:**
<fill — quote the finding's severity framing>

**Scope's actual class:**
<fill — quote the scope definition verbatim>

**Match verdict:** EXACT_MATCH / BENDS_LANGUAGE / NO_MATCH

**Counter (if BENDS_LANGUAGE or NO_MATCH):**
<fill — explain why the bending is defensible, OR concede severity downgrade is required>

---

## Angle 2: Identifiable adversary

**Triager rebuttal:** Who is the attacker? What do they extract? Can they choose the
timing? If the answer to any of these is "no specific party" / "no transfer" / "no
control over trigger", the finding is a systemic condition, not a vulnerability.

**Specific check:**
- Does the finding name a specific extracting actor (user, validator, attacker, curator)?
- Does the finding describe a state transition where attacker-controlled funds increase
  while victim-controlled funds decrease?
- Does the attacker choose the timing of the exploit, or does the condition fire
  passively?

**Finding's attacker model:**
<fill — name the attacker, the extraction, and the trigger control>

**If passive / no attacker:** Is the program's scope inclusive of systemic / accounting
findings (some are, some aren't)? Quote the program's stance.

**Counter (if no attacker identifiable):**
<fill — argue that the systemic class is still in-scope, OR concede severity downgrade>

---

## Angle 3: PoC type vs program rules

**Triager rebuttal:** Does the PoC match the program's required PoC format? Cantina,
Immunefi, and Sherlock often specify fork-based tests against deployed mainnet contracts
explicitly. Mock-based PoCs are routinely rejected.

**Specific check:**
- Quote the program's PoC format requirement.
- Does the finding's PoC use `vm.createSelectFork` against the actual deployed contract
  address, or does it use mock contracts that simulate behavior?
- If mocks: is there an explicit waiver in the program rules? Or is the mock equivalence
  argument made rigorously in the draft?

**Program's PoC requirement:**
<fill — quote verbatim>

**Finding's PoC type:** FORK / MOCK / HYBRID

**Counter (if MOCK on a fork-required program):**
<fill — explain rigorously why mock equivalence holds, OR concede PoC conversion is required>

---

## Angle 4: Impact numbers sourcing

**Triager rebuttal:** Where does each numerical claim in the impact section come from?
"$30K-$45K annualized loss" without sourcing is dismissable. Each input variable must
trace to an on-chain read, a documented limit, an industry-standard reference, or a
defensible model.

**Specific check:**
- List each numerical claim in the Impact section: gas units, gas price, asset prices,
  update frequency, affected strategy count, outage frequency, TVL, etc.
- For each: does it trace to a citable source (on-chain read with block number, audit
  report, public incident log, contract constant)?
- Are any numbers fabricated as "reasonable estimates" without a source?

**Numerical claims and sources:**

| Claim | Value | Source | Defensible? |
|-------|-------|--------|-------------|
| <gas/update> | <value> | <on-chain measurement / arbitrary> | YES/NO |
| <gas price> | <value> | <chain median / arbitrary> | YES/NO |
| <update interval> | <value> | <on-chain read / arbitrary> | YES/NO |
| <strategy count> | <value> | <on-chain enumeration / arbitrary> | YES/NO |
| <outage frequency> | <value> | <chain status page / arbitrary> | YES/NO |
| <TVL> | <value> | <DeFiLlama / contract balance read> | YES/NO |
| <annualized total> | <value> | <derived> | YES/NO |

**If any NO:** What is the realistic range with sourced inputs only? Often this collapses
the impact to 10-25% of the claimed figure.

**Counter (if numbers are unsourced):**
<fill — provide sourced numbers, OR concede impact downgrade to "qualitative / low quantifiable">

---

## Angle 5: Design intent rebuttal

**Triager rebuttal:** Does the protocol team have a documented intent that contradicts
the finding's framing? Inline comments, audit responses, public documentation, commit
messages, and team Twitter posts all count. If team says "intended", the finding shifts
from "vulnerability" to "design disagreement".

**Specific check:**
- Search the affected source files for inline comments near the affected code that
  explain the design.
- Search the protocol's audit reports for the team's response to similar prior findings.
- Search the protocol's public docs for the architectural rationale.
- Search recent commits for messages that explain the change.

**Documented team intent (if any):**
<fill — quote inline comments, audit responses, doc passages verbatim with file:line refs>

**Does intent contradict the finding's framing?** YES / NO / PARTIAL

**Counter (if YES):**
<fill — argue why the team's stated intent does not actually cover the specific failure
mode the finding identifies, OR concede that the finding may be classified as design
opinion rather than vulnerability>

---

## Angle 6: Empirical baseline state

**Triager rebuttal:** Is the vulnerability already producing real-world impact today, or
is the claim conditional on future state that does not exist yet? "If X is configured
this way" / "If Y reaches scale" / "If users start using Z" framing is consistently
downgraded to Informational unless the conditional has clearly defined trigger and
realistic likelihood.

**Specific check:**
- Read the affected contract's current on-chain state (relevant balances, counters,
  configurations, parameter values) at a specific block.
- Has the vulnerability's effect manifested in event logs / state deltas historically?
- If not: how long has the contract been deployed? Is the lack of manifestation evidence
  that the bypass is not reachable, or that the trigger has not occurred yet?
- If trigger is "L2 sequencer outage" or similar external event: has it occurred in the
  contract's lifetime, and what was the observed impact?

**On-chain state snapshot:**

| Variable | Address | Block | Value | Interpretation |
|----------|---------|-------|-------|----------------|
| <var> | <addr> | <block> | <value> | <e.g., "claimableUpkeep=0 means feature has never accrued"> |

**Historical event evidence:**
<fill — event count for relevant signature over last N blocks, with block range>

**Manifestation verdict:**
- CURRENTLY_ACTIVE (impact happening today)
- PREVIOUSLY_TRIGGERED (impact happened in the past, may recur)
- CONDITIONAL_FUTURE (impact requires future state)
- NEVER_MANIFESTED (impact not observed in contract's lifetime)

**Counter (if CONDITIONAL_FUTURE or NEVER_MANIFESTED):**
<fill — argue why the trigger is realistic and the future state is likely, OR concede
that severity downgrade to Informational is required>

---

## Optional additional angles (use when applicable)

### Angle 7: External integration scope exclusion

**Triager rebuttal:** Does the finding's trigger depend on a third-party system (bridge,
oracle, external token, L2 sequencer, governance vote)? Many programs exclude "loss
attributable to external integrations" or "third-party failures".

**Program exclusion text:**
<fill — quote verbatim if applicable>

**Defense:** Is the bug in the protocol's HANDLING of the external event (in scope) or
in the external event itself (out of scope)?

<fill>

### Angle 8: Known issue / prior audit dupe

**Triager rebuttal:** Has any prior audit, public disclosure, or contest finding
addressed this exact bug or class? Does the program list it under Known Issues?

**Prior audit search:**
<fill — search all program-listed audits for keyword matches, list hits with file:line>

**Known Issues match:**
<fill — quote program's Known Issues list and assess fit>

**Differentiation (if dupe risk):**
<fill — explain how this finding differs from prior work>

### Angle 9: Privilege requirement

**Triager rebuttal:** Does the exploit require a privileged role (admin, governor,
curator, validator, operator)? Many programs exclude "attacks requiring compromise of
trusted roles".

**Program's trust model:**
<fill — quote verbatim>

**Finding's privilege requirement:** PERMISSIONLESS / REQUIRES_ROLE / REQUIRES_COLLUSION

**If REQUIRES_ROLE:** Is the role's compromise itself part of the threat model the
program rewards, or is the role explicitly trusted by design?

<fill>

### Angle 10: Recovery / mitigation already in place

**Triager rebuttal:** Does the protocol have another control downstream that catches
this attack? Timelock, pause mechanism, governance veto, automated circuit breaker?

**Other controls in play:**
<fill — read the codebase for controls that fire on the same conditions>

**Does any other control catch the attack?** YES / NO / PARTIAL

**If YES:** Finding should be reclassified as "defense-in-depth bypass of a secondary
layer" — typically Medium, not High/Critical.

---

## Verdict

**Required:** At minimum 6 angles must be filled (1-6 above). Optional angles 7-10
filled where applicable.

**Aggregate signal count:**
- BENDS_LANGUAGE / NO_MATCH on Angle 1: <yes/no>
- No attacker on Angle 2: <yes/no>
- MOCK on fork-required program on Angle 3: <yes/no>
- ≥1 NO in numerical sourcing on Angle 4: <yes/no>
- YES on intent contradiction on Angle 5: <yes/no>
- CONDITIONAL_FUTURE / NEVER_MANIFESTED on Angle 6: <yes/no>

**Decision matrix:**

| Signal count | Decision |
|--------------|----------|
| 0-1 weak signals | READY_TO_SUBMIT |
| 2-3 weak signals | DOWNGRADE_REQUIRED (re-frame at lower severity, re-run rebuttal) |
| 4+ weak signals | KILL (finding will not survive triage; do not submit) |
| Any single fatal flaw (e.g., NO_MATCH on scope or MOCK on fork-required program) | NEEDS_MORE_EVIDENCE or KILL |

**Verdict:** <READY_TO_SUBMIT | DOWNGRADE_REQUIRED | KILL | NEEDS_MORE_EVIDENCE>

**Rationale (one paragraph):**
<fill — write the one-paragraph justification, citing which angles drove the verdict>

**If DOWNGRADE_REQUIRED:** new target severity = <Low / Medium>. Re-run rebuttal at new
severity to confirm survivability.

**If NEEDS_MORE_EVIDENCE:** specific evidence needed = <list>. Acquire before re-running.

**If KILL:** log to OUTCOMES.jsonl with `held_reason=adversarial_rebuttal_fatal`. Move
findings file to `findings/killed/`. Document the kill reason in PROGRESS.md so the
lesson is preserved for future findings.

**Signed by operator:** `[ ] ADVERSARIAL_REBUTTAL_SIGNED_<verdict>`

(Replace `<verdict>` with one of the four verdicts above to sign. The preflight gate
parses this exact string format.)

---

## Notes

- The Adversarial Rebuttal is performed AFTER the Kill Gate and Weight Card but BEFORE
  the Preflight Check. Kill Gate eliminates false positives by mechanical questions;
  Weight Card forces numerical anchors; Adversarial Rebuttal forces a semantic survival
  check against the actual triager's playbook.
- If you find yourself unable to fill 6 angles because "they don't apply to this
  finding", that itself is a signal — every finding has at minimum the 6 mandatory
  angles addressable, because every finding has a severity claim, an attacker model, a
  PoC, an impact, an intent context, and an empirical baseline.
- The intent is NOT to discourage legitimate findings. The intent is to catch the
  specific failure mode where self-validation passes syntactic gates but collapses on
  semantic review.
