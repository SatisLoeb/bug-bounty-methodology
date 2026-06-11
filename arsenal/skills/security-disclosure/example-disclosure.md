# Example: Complete Security Disclosure Email

This is a reference example demonstrating the full disclosure format. Based on a real finding adapted for illustration.

---

## The Email

```
Subject: [Security Vulnerability] OOB array access in ExtendedDNSResolver._findValue() — High (CVSS 7.5)
```

---

## Executive Summary

`ExtendedDNSResolver` (deployed at `0x...`) contains an out-of-bounds array access in the `_findValue()` internal function that causes `Panic(0x32)` on any TXT record using the protocol's own documented format. The crash is deterministic, permissionless, and zero-cost — any DNS name using `t[key]='value'` format becomes permanently non-resolvable through this resolver. The contract is immutable with no proxy, no admin function, and no circuit breaker.

**CVSS 3.1:** AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:H → **7.5 (High)**

---

## Vulnerability Details

### The Bug

The `_findValue()` function at line 47 of `ExtendedDNSResolver.sol` implements a DFA (Deterministic Finite Automaton) to parse TXT record key-value pairs. The DFA has 6 states: 3 "tracked" states (`STATE_TRACKED_KEY`, `STATE_TRACKED_VALUE_START`, `STATE_TRACKED_VALUE`) and 3 "ignored" states (`STATE_IGNORED_KEY`, `STATE_IGNORED_VALUE_START`, `STATE_IGNORED_VALUE`).

The tracked states correctly update the `offset` variable after parsing each character:

```solidity
// ExtendedDNSResolver.sol, line 72 (TRACKED — correct)
case STATE_TRACKED_VALUE:
    if (data[i] == SEPARATOR) {
        offset += len;  // ← offset updated
        state = STATE_START;
    }
```

The ignored states are a copy-paste of the same DFA structure but **skip the offset update**:

```solidity
// ExtendedDNSResolver.sol, line 89 (IGNORED — vulnerable)
case STATE_IGNORED_VALUE:
    if (data[i] == SEPARATOR) {
        // ← offset NOT updated — OOB on next access
        state = STATE_START;
    }
```

### Attack Path

1. **Precondition:** None. Any external caller can trigger this.
2. **Step 1:** A DNS name owner sets a TXT record using the documented format: `t[note]='I'm great'` (from the NatSpec at line 13).
3. **Step 2:** Any caller resolves this name via `resolve()`, which calls `_findValue()`.
4. **Step 3 (Trigger):** The DFA enters `STATE_IGNORED_VALUE` for the untracked key. When the separator is hit, `offset` is not updated. The next iteration accesses `data[offset + ...]` with a stale offset → `Panic(0x32)`.
5. **Result:** Every resolution of this name reverts. The name is permanently non-resolvable through this resolver.

#### Internal evidence of oversight

This is an implementation error in a duplicated code path, not a design decision. The codebase contains **3 tracked states** that correctly update `offset` after parsing. The 3 ignored states are structurally identical but lost the offset update during duplication.

The NatSpec at line 13 explicitly documents the format that triggers the crash:

```solidity
/// Examples: - t[note]='I'm great'
```

The contract crashes on its own documented input format.

#### Why this is not a known issue

The Code4rena 2023-04-ens audit specifically covered `ExtendedDNSResolver`. That audit found 3 High and 5 Medium issues, but **none** addressed the DFA parsing logic or OOB access in `_findValue()`.

Searching the C4 findings repository returned **zero** issues mentioning: `_findValue`, `offset`, `STATE_IGNORED`, `DFA`, `Panic(0x32)`, `OOB`, or `array access`.

#### Real-world precedent

OOB access in parser state machines has been confirmed as a valid vulnerability class across multiple audits:

| Protocol | Year | Platform | Severity | Issue |
|----------|------|----------|----------|-------|
| Example-1 | 2024 | Sherlock | High | DFA parser offset desync in DNS library |
| Example-2 | 2023 | Code4rena | High | State machine skips bounds check on branch |
| Example-3 | 2024 | Direct | Critical | Parser OOB in certificate validation |

---

## Impact Assessment

**Affected deployments:**
- Mainnet: `0x...` (ExtendedDNSResolver)
- All ENS names using TXT records with multi-key format through this resolver

**What happens when triggered:** `Panic(0x32)` — guaranteed revert. Name resolution fails for every call.

**Who can trigger it:** No attacker needed. Any DNS name owner who sets a TXT record using the documented format unknowingly triggers this for all resolvers of their name.

**What IS at risk (immediately):**
All ENS names using `t[key]='value'` TXT format through ExtendedDNSResolver become permanently non-resolvable. This affects any application (wallets, dApps, browsers) that queries these names.

**What is NOT at risk (currently):**
Funds are not directly at risk. Other resolver contracts are not affected. Names using single-key TXT format resolve correctly.

**Recovery mechanism:** None. The contract is immutable — no proxy, no admin function, no circuit breaker. The only remediation is deploying a new resolver contract and migrating affected names.

**CVSS 3.1:** AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:N/A:H → **7.5 (High)**

---

## Proof of Concept

### Overview

9 tests prove the OOB access on the real deployed contract at `0x...`:

1. **3 baseline tests**: Normal single-key TXT resolution works correctly
2. **4 exploit tests**: Multi-key format triggers Panic(0x32) deterministically
3. **2 impact tests**: Affected names are permanently non-resolvable

### Setup

```bash
mkdir ens-oob-poc && cd ens-oob-poc
forge init --no-git . --force
```

### Test Code

Save as `test/ENS_OOB.t.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

interface IExtendedDNSResolver {
    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory);
}

/// @title ExtendedDNSResolver OOB — PoC
/// @notice Demonstrates Panic(0x32) on the deployed mainnet contract.
///         Zero mock contracts. Fork-based verification only.
contract ENS_OOB_Test is Test {
    address constant RESOLVER = 0x...; // Real deployed address
    IExtendedDNSResolver resolver;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        resolver = IExtendedDNSResolver(RESOLVER);
    }

    /// @notice BASELINE: Single-key TXT resolves correctly.
    function testBaseline_SingleKeyResolves() public view {
        // [Normal operation succeeds]
    }

    /// @notice EXPLOIT: Multi-key format causes Panic(0x32).
    ///         Root cause: STATE_IGNORED_VALUE skips offset update.
    function testExploit_MultiKeyPanic() public {
        // [Triggers the vulnerability]
        // vm.expectRevert(...)
    }

    // ... additional tests
}
```

### Running

```bash
ETH_RPC_URL=https://ethereum-rpc.publicnode.com forge test --match-contract ENS_OOB_Test -vvv
```

### Expected Output

```
Ran 9 tests for test/ENS_OOB.t.sol:ENS_OOB_Test
[PASS] testBaseline_SingleKeyResolves() (gas varies)
[PASS] testBaseline_DifferentKeyTypes() (gas varies)
[PASS] testBaseline_EmptyTXT() (gas varies)
[PASS] testExploit_MultiKeyPanic() (gas varies)
[PASS] testExploit_DocumentedFormatPanic() (gas varies)
[PASS] testExploit_AllSeparatorTypes() (gas varies)
[PASS] testExploit_MinimalTrigger() (gas varies)
[PASS] testImpact_PermanentNonResolution() (gas varies)
[PASS] testImpact_AffectsAllCallers() (gas varies)
Suite result: ok. 9 passed; 0 failed; 0 skipped
```

---

## Recommended Fix

Update the ignored states to track offset correctly:

```diff
// ExtendedDNSResolver.sol, line 89
case STATE_IGNORED_VALUE:
    if (data[i] == SEPARATOR) {
+       offset += len;
        state = STATE_START;
    }
```

This mirrors the existing pattern in `STATE_TRACKED_VALUE` (line 72) and maintains DFA consistency across all states.

---

## Disclosure Timeline

- **2026-02-15**: Vulnerability discovered during code review
- **2026-02-16**: PoC developed and verified on mainnet fork
- **2026-02-17**: Initial disclosure sent to security@ens.domains (PGP encrypted)
- **2026-02-17**: This report
- **2026-05-18**: Planned public disclosure (90 days)

Timeline will be extended upon request if a fix is actively in progress.

---

## Researcher Contact

- **Researcher**: [handle]
- **PGP Key**: [fingerprint] (available on keys.openpgp.org)
- **Email**: [email]
- **Disclosure Policy**: 90-day coordinated disclosure. Extended upon mutual agreement if fix is in active development.

---

## References

- **Vulnerable code:** [GitHub permalink to _findValue(), exact lines]
- **NatSpec documentation:** [GitHub permalink to line 13 with documented format]
- **Safe code (comparison):** [GitHub permalink to STATE_TRACKED_VALUE offset update]
- **Deployment:** [Etherscan verified contract link]
- **Prior audit (no coverage):** [C4 2023-04-ens report URL]

---

## Pre-Disclosure Checklist (Internal — Remove Before Sending)

- [x] **Step 0 — Target Assessment**: TVL verified, contact found (security@, PGP available)
- [x] **Step 1 — Production Reachability**: Contract deployed, verified source matches
- [x] **Step 2 — Duplicate Check**: No prior findings on _findValue() or DFA parser
- [x] **Step 3 — Anti-Dismissal Research**: Internal consistency (3 tracked states protect, 3 ignored don't), prior audit absence proved, precedents found
- [x] **Step 4 — Quality Gate (24pt)**: 23/24
- [x] **PGP encryption**: security@ens.domains, key verified on keyserver
- [x] **Fork test passes**: 9/9 green on fresh setup
- [x] **CVSS calculated**: 7.5 (High) with vector string
- [x] **90-day timeline stated**: 2026-05-18 planned public disclosure
- [x] **IS/IS NOT risk split**: Honest — availability impact only, no funds at risk
