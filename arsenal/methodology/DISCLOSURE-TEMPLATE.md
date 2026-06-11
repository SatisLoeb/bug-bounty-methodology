# Security Disclosure Template (Anti-Dismissal Integrated)

**Usage:** Copy this template for each new disclosure. Replace all `[PLACEHOLDERS]`. HTML comments (`<!-- -->`) are guidance — remove before sending. Delete unused argument sections.

---

## EMAIL HEADER

```
To: [security contact — from contact-research-checklist.md]
Subject: [Security Vulnerability] [Contract/Component] [violates/fails to] [Standard/Check] — [Severity] (CVSS [X.X])
```

<!-- Subject examples that worked:
     "[Security Vulnerability] RSASHA256Algorithm violates RFC 3110 (e=1 accepted) — High (CVSS 7.8)"
     "[Security Vulnerability] ExtendedDNSResolver._findValue() OOB array access — High (CVSS 7.5)"
-->

---

## EXECUTIVE SUMMARY

<!-- 3-5 sentences MAX. Decision-makers read only this section.
     First sentence = the kill shot.
     Pattern: "[Contract] (deployed at [addr]) [violates/fails to], [causing] [IMPACT]."
     Include CVSS score. Include immutability/recovery status. -->

`[ContractName]` (deployed at `[0x...]` on [chain]) [violates **[STANDARD]** / fails to validate [CHECK]], [allowing/causing] [DIRECT_IMPACT]. [One-sentence mechanism]. The contract is [immutable / upgradeable via [method]] — [no recovery path / admin can [action]].

**CVSS 3.1:** [vector string] → **[score] ([severity])**

---

## VULNERABILITY DETAILS

### The Missing Check

<!-- Show EXACTLY what's wrong. Quote the standard, then show the code that violates it. -->

Per [STANDARD/SPEC] Section [X], the [operation] **must** [requirement]:

```
[Quote the standard verbatim — 2-3 lines max]
```

The current code in `[Contract.sol]` (line [N]):

```solidity
// [Contract.sol#LN] — [commit hash]
[... 2-5 lines of vulnerable code ...]
```

[1-2 sentences explaining WHY this code violates the standard.]

### Attack Path

<!-- Step-by-step. Each step = one on-chain action or off-chain operation. -->

1. **Precondition:** [What must be true. "None" if permissionless.]
2. **Step 1:** [Actor] calls `[function()]` with `[parameters]` to [objective].
3. **Step 2:** Inside this call, `[what happens at code level]` at line [N].
4. **Step 3 (Trigger):** [The moment the vulnerability fires].
5. **Result:** [Technical outcome: funds locked, name stolen, contract bricked, etc.]

### Full Vulnerability Spectrum

<!-- Optional. Use when the bug has multiple severity levels depending on parameters. -->

- **[Param=A]**: [Severity] — [mechanism] (demonstrated in PoC, exploitable NOW).
- **[Param=B]**: [Severity] — [mechanism] (conditional on [external factor]).
- **[Param=C]**: Not exploitable — [why].

---

### STRATEGIC ARGUMENTS (ANTI-DISMISSAL)

<!-- Pick ONLY the arguments relevant to your finding. Delete unused sections entirely.
     Order them by strength — strongest argument first. -->

#### Argument: Internal Evidence of Oversight

<!-- USE WHEN: The protocol protects against this exact risk in another contract/function. -->

This is not an external risk — it is an **omission by the protocol itself**. The project demonstrates awareness of this risk, as proven by `[OtherContract.sol]`.

In `[OtherContract.sol]` at line [N]:

```solidity
// [OtherContract.sol#LN]
[... their protective code ...]
```

The codebase contains **[X] instances** of this protective pattern. The absence in `[VulnerableContract]` is an inconsistency, not a design decision.

#### Argument: Immutability Amplifier

<!-- USE WHEN: The vulnerable contract is immutable. -->

**Immutability transforms the severity calculus.** For an upgradeable contract, this is "fix it when it matters." For an immutable contract, the finding must be evaluated against the full deployment lifetime:

- `[ContractName]` has no proxy, no `upgradeTo`, no admin function.
- The only remediation is [deploying new contracts / migration].
- If [trigger condition] occurs — today or years from now — the deployed contract cannot defend against it.

#### Argument: Not a Known Issue (Prior Audit Differentiation)

<!-- MANDATORY if ANY audit has touched the same codebase. -->

<!-- MODE A: Prove absence -->
The [Auditor] [Year] audit covered `[ContractName]` ([link]). That audit found [X High and Y Medium] issues, but **none** addressed [vulnerability class].

Searching returned **zero** issues mentioning [keyword1], [keyword2], [keyword3], or [keyword4].

<!-- MODE B: Prove distinction -->
This finding is **distinct** from [Prior Finding ID/Title]:

| | Prior Finding | This Finding |
|---|---|---|
| **Root Cause** | [cause A] | [cause B] |
| **Impact** | [impact A] | [impact B] |
| **Trigger** | [trigger A] | [trigger B] |
| **Contract/Function** | [location A] | [location B] |

#### Argument: Industry Precedents

<!-- USE WHEN: This vulnerability class has been found and validated in other protocols. -->

This vulnerability class has been confirmed as valid across multiple audited protocols:

- **[Protocol 1]** — [Platform] ([Year]), [Severity]. [One-line summary]. [URL]
- **[Protocol 2]** — [Platform] ([Year]), [Severity]. [One-line summary]. [URL]
- **[Protocol 3]** — CVE-[YYYY-NNNN] ([Year]). [One-line summary]. [URL]

#### Argument: Concrete Failure Scenarios

<!-- USE WHEN: Your bug depends on an external condition. Prove it's realistic. -->

The vulnerability requires [external condition], which is documented and realistic:

1. **Historical precedent:** [Token/Protocol X] experienced [condition] on [date]. [Evidence].
2. **Mechanical feasibility:** [External protocol] exposes `[f()]` callable by [role]. [Link].
3. **On-chain evidence:** As of [date], [X contracts / $Y] are exposed. [Explorer link].

#### Argument: Standards Alignment

<!-- USE WHEN: The protocol's own security commitments support your severity. -->

Per the protocol's published security documentation:

> "[Quote verbatim]"

This finding falls within this commitment: [explain match].

---

## IMPACT ASSESSMENT

**Affected deployments:**
- [Chain 1]: `[0x...]` ([explorer link])
- [Chain 2]: `[0x...]` ([explorer link])
- Downstream: `[Contracts that call/depend on the vulnerable contract]`

**What happens when triggered:** [Concrete on-chain effect].

**Who can trigger it:** [Any caller / Governance / Specific role]. The `[function()]` is `[external/public]` and [requires no permissions / requires X role].

**What IS at risk ([condition], immediately):**
<!-- Unconditional, immediate risk. Quantify. -->
[Describe what's exploitable RIGHT NOW.]

**What is NOT at risk ([condition], currently):**
<!-- Intellectual honesty. Paradoxically strengthens your report. -->
[Describe honest limitations.]

**Recovery mechanism:** [None — immutable / Requires governance vote / Admin can [action]].

**CVSS 3.1:** [Full vector string] → [Score] ([Severity])

---

## PROOF OF CONCEPT

### Overview

[N] tests prove [vulnerability] on the real deployed contract at `[0x...]`:

1. **[X] baseline tests**: [Normal operation works]
2. **[Y] exploit tests**: [Vulnerability fires]
3. **[Z] impact tests**: [Real-world consequences]

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

interface ITarget {
    function vulnerableFunction() external;
}

/// @title [Vulnerability Name] — PoC
/// @notice Demonstrates [what] on deployed contract at [0x...].
///         Zero mock contracts. Fork-based verification only.
contract [TestName] is Test {
    address constant TARGET = [0x...];

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    /// @notice BASELINE: [Normal operation works].
    function testBaseline_[NormalBehavior]() public view {
        // [Prove normal conditions]
    }

    /// @notice EXPLOIT: [Vulnerability description].
    function testExploit_[VulnerabilityName]() public {
        // [Trigger the vulnerability]
    }

    /// @notice IMPACT: [Real-world consequence].
    function testImpact_[ConsequenceName]() public {
        // [Prove the consequence]
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
[PASS] testBaseline_[NormalBehavior]() (gas varies)
[PASS] testExploit_[VulnerabilityName]() (gas varies)
[PASS] testImpact_[ConsequenceName]() (gas varies)
Suite result: ok. [N] passed; 0 failed; 0 skipped
```

### Explanation

The PoC forks [chain] and calls the real deployed `[ContractName]` at `[0x...]`. Zero mock contracts. Fork-based verification only.

- **Baseline tests** prove [normal operation].
- **Exploit tests** prove [vulnerability fires on deployed contract].
- **Impact tests** prove [real-world consequence].

---

## RECOMMENDED FIX

[One sentence describing the fix approach.]

```diff
// [Contract.sol]
- [vulnerable line]
+ [fixed line]
```

**Alternative fix:** [Simpler band-aid if applicable.]

---

## DISCLOSURE TIMELINE

- **[Date]**: Vulnerability discovered
- **[Date]**: PoC developed and verified
- **[Date]**: Initial disclosure sent to [contact method]
- **[Date + 90 days]**: Planned public disclosure

Timeline will be extended upon request if a fix is actively in progress.

---

## RESEARCHER CONTACT

- **Researcher**: [Name/Handle]
- **PGP Key**: [Fingerprint] ([keyserver link])
- **Email**: [email]
- **Disclosure Policy**: 90-day coordinated disclosure. Extended upon mutual agreement.

---

## REFERENCES

- **Vulnerable code:** [GitHub permalink to exact lines]
- **Standard violated:** [RFC/EIP/spec URL with section]
- **Deployment:** [Block explorer verified contract link]
- **Prior audit (no coverage):** [Audit report URL]
- **CVE precedent:** [If applicable]

---

## PRE-DISCLOSURE CHECKLIST (Internal — Remove Before Sending)

- [ ] **Step 0 — Target Assessment**: TVL verified? Contact found? PGP available?
- [ ] **Step 1 — Production Reachability**: Code deployed and reachable? Version matches repo?
- [ ] **Step 2 — Duplicate Check**: Searched GitHub, CVEs, C4, Sherlock, CodeHawks?
- [ ] **Step 3 — Anti-Dismissal Research**: Internal consistency? Prior audit differentiation? Precedents?
- [ ] **Step 4 — Quality Gate (24pt)**: Minimum 22/24?
- [ ] **PGP encryption**: Used if key available?
- [ ] **Fork test passes**: All green on fresh clone?
- [ ] **CVSS calculated**: Vector string included?
- [ ] **90-day timeline**: Stated clearly?
- [ ] **IS/IS NOT risk split**: Honest and present?
- [ ] **Recommended fix**: Complete with code?
- [ ] **All links**: Permalinks (not HEAD)?
