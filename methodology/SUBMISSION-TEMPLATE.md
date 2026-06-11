# Bug Bounty Submission Template (Anti-Rejection Integrated)

**Usage:** Copy relevant sections into Immunefi Description and PoC fields. Delete unused arguments. Replace all `[PLACEHOLDERS]`. HTML comments (`<!-- -->`) are guidance — remove before submission.

---

## TITLE (paste into Immunefi Title field)

<!-- MAX 100 chars. Pattern: [Contract] [violates/fails to] [Standard/Check]: [Impact in 5 words] -->
<!-- Examples that worked:
     "RSASHA256Algorithm violates RFC 3110 (e=1 accepted): universal DNSSEC forgery without cryptography"
     "ExtendedDNSResolver._findValue() OOB array access on protocol-documented TXT format"
-->

```
[Contract] [violates/fails to] [Standard/Check]: [consequence in ≤5 words]
```

---

## DESCRIPTION (paste into Immunefi Description field)

## Brief/Intro

<!-- 2-3 sentences MAX. First sentence = the kill shot. Pattern:
     "[Contract] (deployed at [addr]) [violates STANDARD / fails to CHECK], [allowing/causing] [IMPACT]."
     Second sentence = mechanism in one line.
     Third sentence (optional) = severity amplifier (immutability, funds at risk, no recovery).
-->

`[ContractName]` (deployed at `[0x...]`) [violates **[STANDARD]** / fails to validate [CHECK]], [allowing/causing] [DIRECT_IMPACT]. [One-sentence mechanism]. The contract is [immutable / not behind a proxy] — [no admin function / no circuit breaker / no recovery path].

---

## Vulnerability Details

### The Missing Check

<!-- Show EXACTLY what's wrong. Quote the standard, then show the code that violates it.
     If no standard applies, show what the code SHOULD do vs what it DOES. -->

Per [STANDARD/SPEC] Section [X], the [operation] **must** [requirement]:

```
[Quote the standard verbatim — 2-3 lines max]
```

The current code in `[Contract.sol]` (line [N]):

```solidity
// [Contract.sol#LN]
[... 2-5 lines of vulnerable code ...]
```

[1-2 sentences explaining WHY this code violates the standard. Be surgical.]

### Attack Path

<!-- Step-by-step. Each step = one on-chain action or off-chain operation.
     Numbered list. Include function names, parameters, and what happens internally. -->

1. **Precondition:** [What must be true before the attack. "None" if permissionless.]
2. **Step 1:** [Actor] calls `[function()]` with `[parameters]` to [objective].
3. **Step 2:** Inside this call, `[what happens at code level]` at line [N].
4. **Step 3 (Trigger):** [The moment the vulnerability fires — revert, state corruption, bypass].
5. **Result:** [Technical outcome: funds locked, name stolen, contract bricked, etc.]

### Full Vulnerability Spectrum

<!-- Optional. Use when the bug has multiple severity levels depending on parameters.
     Example: ENS e=1 (trivial) vs e=3 (Bleichenbacher) vs e=65537 (safe). -->

- **[Param=A]**: [Severity] — [mechanism] (demonstrated in PoC, exploitable NOW).
- **[Param=B]**: [Severity] — [mechanism] (conditional on [external factor]).
- **[Param=C]**: Not exploitable — [why].

---

### STRATEGIC ARGUMENTS (ANTI-REJECTION)

<!-- Pick ONLY the arguments relevant to your finding. Delete unused sections entirely.
     Order them by strength — strongest argument first. -->

#### Argument: Internal Consistency (Protocol's Own Protection Elsewhere)

<!-- USE WHEN: The protocol protects against this exact risk in another contract/function.
     This is your strongest argument — it proves the team KNOWS about the risk and CHOSE to protect
     against it elsewhere. The missing protection is an oversight, not a design choice. -->

This is not an external risk or an inevitable limitation — it is an **omission by the protocol itself**. The project demonstrates awareness of this risk and knows how to mitigate it, as proven by `[OtherContract.sol]`.

In `[OtherContract.sol]` at line [N], an explicit protection is used to prevent exactly this scenario:

```solidity
// [OtherContract.sol#LN]
[... their protective code ...]
```

The codebase contains **[X] instances** of this protective pattern. The absence of this protection in `[VulnerableContract]` is an inconsistency, not a design decision.

#### Argument: Immutability Amplifier

<!-- USE WHEN: The vulnerable contract is immutable (no proxy, no admin upgrade, no circuit breaker).
     This shifts severity upward — "fix it when it matters" is impossible. The bug must be evaluated
     against the FULL LIFETIME of the deployment, not just current conditions. -->

**This is where immutability transforms the severity calculus.** For a proxied or upgradeable contract, this finding would be "fix it when it matters." For an immutable contract, the finding must be evaluated against the full lifetime of the deployment:

- `[ContractName]` is not a proxy — there is no `setImplementation`, no `upgradeTo`, no admin function.
- The only remediation path is [deploying new contracts and calling X / a governance vote / migration] — a manual, reactive operation.
- [The external condition that would trigger exploitation] is not static: [evidence of historical change or plausible future change].
- If [trigger condition] occurs — today or years from now — the deployed contract cannot defend against it. There is no circuit breaker.

The contract's security depends entirely on an external invariant ([describe invariant]) that the contract itself does not enforce and cannot enforce. This is the structural defect.

#### Argument: Not a Known Issue (Prior Audit Differentiation)

<!-- MANDATORY if ANY audit has touched the same contract or codebase.
     Two modes:
     Mode A — Finding is 100% new (no prior audit found anything similar): prove absence.
     Mode B — A prior finding LOOKS similar but is fundamentally different: prove distinction. -->

<!-- MODE A: Prove absence -->

The [Auditor] [Year] audit specifically covered `[ContractName]` ([link]). That audit found [X High and Y Medium] issues, but **none** addressed [your vulnerability class].

Searching the [audit platform] findings repository returned **zero** issues mentioning [keyword1], [keyword2], [keyword3], or [keyword4].

<!-- MODE B: Prove distinction -->

This finding is **entirely new** and must not be confused with [Prior Finding ID/Title]. The differences are fundamental:

| | Prior Finding | This Finding |
|---|---|---|
| **Root Cause** | [cause A] | [cause B] |
| **Impact** | [impact A] | [impact B] |
| **Trigger** | [trigger A] | [trigger B] |
| **Contract/Function** | [location A] | [location B] |

#### Argument: Industry Precedents (Audit Validation)

<!-- USE WHEN: This vulnerability class has been found and paid in other protocols.
     Shows the class is recognized as legitimate. 2-4 precedents is ideal. -->

This vulnerability class has been confirmed as high-impact across multiple audited protocols:

- **[Protocol 1]** — [Platform] ([Year]), Severity: [High/Critical]. [One-line summary]. [URL]
- **[Protocol 2]** — [Platform] ([Year]), Severity: [High/Critical]. [One-line summary]. [URL]
- **[Protocol 3]** — CVE-[YYYY-NNNN] ([Year]). [One-line summary]. [URL]

#### Argument: Concrete Failure Scenarios (External Dependencies)

<!-- USE WHEN: Your bug depends on an external condition that reviewers might dismiss as "unlikely."
     Prove it's realistic with historical evidence, on-chain data, or protocol mechanics. -->

The attack requires [external condition], which is a realistic and documented scenario:

1. **Historical precedent:** [Token/Protocol X] experienced [exact same condition] on [date]. [Evidence: TX hash, blog post, incident report].
2. **Mechanical feasibility:** The [external protocol] exposes function `[f()]` callable by [governance/anyone] that can trigger this condition. [Link to contract].
3. **On-chain evidence:** As of [date], [X contracts / Y dollars / Z users] are exposed to this condition. [Etherscan/Dune query link].

#### Argument: Program Policy Alignment

<!-- USE WHEN: The program's own bounty policy supports your severity classification.
     Quote their policy VERBATIM. Programs are bound by their own published rules. -->

Per the program's published bounty policy:

> "[Quote the relevant policy clause verbatim]"

This finding falls squarely within this clause: [explain how your finding matches the policy language]. [The vulnerability exists on-chain now / The asset class is explicitly covered / The impact category matches exactly].

---

## Impact Details

<!-- Be precise. Use Immunefi's exact severity taxonomy vocabulary. -->

**Affected deployments:**
- Mainnet: `[0x...]` ([Etherscan link])
- [Other chains]: `[0x...]`
- Downstream: `[Contracts that call/depend on the vulnerable contract]`

**What happens when triggered:** [Concrete description of the on-chain effect].

**Who can trigger it:** [Any external caller / Governance / Specific role]. The `[function()]` is `[external/public]` and [requires no special permissions / requires X role].

**What IS at risk ([condition], immediately):**
<!-- Be specific about what's exploitable RIGHT NOW with no external conditions. -->
[Describe the immediate, unconditional risk. Quantify if possible.]

**What is NOT at risk ([condition], currently):**
<!-- Intellectual honesty. Shows you're not inflating. Paradoxically STRENGTHENS your report. -->
[Describe what's NOT exploitable today and why. Be honest about conditions required.]

**Recovery mechanism:** [None — contract is immutable / Requires governance vote within X blocks / Admin can call emergencyPause()].

**Impact category:** [Exact Immunefi category: "Theft of funds", "Permanent freezing of funds", "Smart contract unable to operate", "Griefing (e.g. no profit motive for an attacker)"]

---

## Recommended Fix

<!-- Propose a real fix. Shows competence and good faith. Diff format preferred. -->

[One sentence describing the fix approach.]

```diff
// [Contract.sol]
- [vulnerable line]
+ [fixed line]
```

<!-- If a simple diff isn't enough, provide a full code block with the corrected function. -->

**Alternative fix:** [Simpler band-aid if applicable, with caveat that proper fix is better.]

---

## References

<!-- Links that support your report. Permalink to exact lines, not HEAD. -->

- **Vulnerable code:** [GitHub permalink to exact lines]
- **Standard violated:** [RFC/EIP/spec URL with section number]
- **Deployment:** [Etherscan verified contract link]
- **Prior audit (no coverage):** [Audit report URL]
- **CVE precedent:** [CVE or prior disclosure URL]
- **Program policy:** [Immunefi program page URL]

---
---

## PROOF OF CONCEPT (paste into Immunefi PoC field)

<!-- MANDATORY RULES (learned from rejections):
     1. FORK-BASED ONLY — vm.createSelectFork(), real mainnet contracts, zero mocks
     2. Real deployed addresses — verify on Etherscan before hardcoding
     3. Baselines FIRST — prove normal operation works before showing the exploit
     4. NatSpec on every test — explain what each test proves
     5. Expected output section — reviewer can compare without running
     6. Single command to run — no multi-step setup
-->

## Proof of Concept

### Overview

<!-- Pattern: [N] tests prove [what] on the real deployed contract:
     - [X] baselines: [what they prove]
     - [Y] exploit tests: [what they prove]
     - [Z] impact tests: [what they prove]
-->

[N] tests prove [vulnerability] on the real deployed contract at `[0x...]`:

1. **[X] baseline tests**: [Normal operation works — SHA matches, valid inputs accepted, invalid rejected]
2. **[Y] exploit tests**: [The vulnerability fires — forged input accepted, revert triggered, state corrupted]
3. **[Z] impact tests**: [Consequences — no private key needed, arbitrary data affected, funds extractable]

### Setup

```bash
mkdir [poc-name] && cd [poc-name]
forge init --no-git . --force
```

### Test Code

Save as `test/[TestName].t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

// [Interface or import for the target contract]

/// @title [Vulnerability Name] — PoC
/// @notice Demonstrates [what] on the deployed mainnet contract at [0x...].
///         Zero mock contracts. Fork-based verification only.
contract [TestName] is Test {
    // Target contract on mainnet
    address constant TARGET = [0x...];

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        // [Initialize interface to target]
    }

    // ================================================================
    // BASELINES
    // ================================================================

    /// @notice Sanity check: [normal operation works as expected].
    function testBaseline_[NormalBehavior]() public view {
        // [Prove the contract works correctly under normal conditions]
    }

    // ================================================================
    // EXPLOIT
    // ================================================================

    /// @notice EXPLOIT: [One-line description of what this proves].
    ///
    ///         Root cause ([Contract.sol] line [N]):
    ///         ```
    ///         [Quote the vulnerable line]
    ///         ```
    ///         [2-3 lines explaining the mechanism]
    function testExploit_[VulnerabilityName]() public {
        // [Trigger the vulnerability]
        // [Assert the unexpected/malicious outcome]
    }

    // ================================================================
    // IMPACT
    // ================================================================

    /// @notice [What this impact test demonstrates].
    function testImpact_[ConsequenceName]() public {
        // [Prove the real-world consequence]
    }
}
```

### Running

```bash
ETH_RPC_URL=https://ethereum-rpc.publicnode.com forge test --match-contract [TestName] -vvv
```

### Expected Output

```
Ran [N] tests for test/[TestName].t.sol:[TestName]
[PASS] testBaseline_[NormalBehavior]()
[PASS] testExploit_[VulnerabilityName]()
[PASS] testImpact_[ConsequenceName]()
Suite result: ok. [N] passed; 0 failed; 0 skipped
```

### Explanation

<!-- Connect the dots. What did the PoC prove? Why does it matter?
     Mention: real deployed contract, zero mocks, fork-based, mainnet address.
     Separate e2e exploitability from the contract-level bug if needed. -->

The PoC forks Ethereum mainnet and calls the real deployed `[ContractName]` at `[0x...]`. Zero mock contracts are used.

- **Baseline tests** prove [normal operation].
- **Exploit tests** prove [the vulnerability fires on the deployed contract].
- **Impact tests** prove [the real-world consequence — no key needed, arbitrary data, etc.].

[If applicable: explain what IS exploitable end-to-end vs what requires external conditions.]

---

## PRE-SUBMISSION CHECKLIST

<!-- Run through this BEFORE pasting into Immunefi. Delete this section from the submission. -->

- [ ] **Step 0 — Program Risk Card**: Vault balance > $0? Finding not in exclusions? No surgical exclusion match?
- [ ] **Step 1 — Scope Validation**: Asset address is EXACTLY in scope? Contract path matches?
- [ ] **Step 2 — Duplicate Check**: Searched GitHub Issues/PRs, C4, Sherlock, CodeHawks for same contract+function?
- [ ] **Step 3 — Anti-Rejection Research**: Internal consistency scanned? Prior audits differentiated? External dependency defended?
- [ ] **Step 4 — Quality Gate (22pt)**: PoC quality (7), argumentation (7), hygiene (4), strategic positioning (4) — minimum 20/22?
- [ ] **Gist created**: Secret Gist with .t.sol file? URL has no trailing space?
- [ ] **Fork test passes**: `forge test --match-contract [X] -vvv` — all green on fresh clone?
- [ ] **Title < 100 chars**?
- [ ] **No French** in submission?
- [ ] **Impact category** matches Immunefi taxonomy exactly?
- [ ] **"What IS at risk" / "What is NOT at risk"** split is honest and present?
- [ ] **Severity** matches impact category? (Theft = High/Critical, Griefing = Medium, DoS = Medium)
- [ ] **All links** are permalinks (not HEAD)?
- [ ] **Crafted inputs explained**: If PoC uses crafted keys/values, explain they demonstrate structural flaw, not a dependency?
