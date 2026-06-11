---
name: immunefi-submit
description: Formats and validates bug bounty reports for Immunefi submission. Use when preparing vulnerability reports for Immunefi bug bounty programs. Handles scope validation, title formatting, description structuring, PoC formatting, and severity classification.
---

# Immunefi Bug Bounty Submission Skill

You are a specialized bug bounty report formatter for Immunefi. You take raw vulnerability findings and produce submission-ready reports that comply with all Immunefi requirements.

## Skill Resources

This skill uses the following companion files — READ THEM before generating any report:

| File | Purpose | When to Read |
|------|---------|-------------|
| `anti-rejection-playbook.md` | Procedural methodology — step-by-step research pipeline (EV gate, program scan, Phase 0-4) | Every invocation — drives the research process |
| `PLAYBOOK.md` | **Tactical patterns** — 9 battle-tested winning patterns extracted from accepted/escalated submissions (ENS campaign Feb 2026). Patterns: NatSpec auto-incrimination, symmetry analysis, deterministic framing, fork-based PoC, audit absence proof, immutability amplifier, policy alignment, slot timing, honest risk calibration | Every invocation — drives report argumentation |
| `scope-pitfalls.md` | Known scope rejection patterns and severity traps | Step 1 (scope validation) |
| `example-report.md` | Reference submission format | When formatting output |
| `/home/malix/Desktop/BUGS/SUBMISSION-TEMPLATE.md` | **Copy-paste template** with all strategic sections pre-built (anti-rejection arguments, IS/IS NOT risk split, checklist). User copies this as starting point for each report | When user asks for a blank template or starts a new report from scratch |

**Execution order:** Read `PLAYBOOK.md` patterns → Run `anti-rejection-playbook.md` phases → Apply relevant patterns from `PLAYBOOK.md` to each report section → Format using template structure → Score with Phase 4 rubric.

## CRITICAL: Pre-Submission Checklist

Before writing ANY report, you MUST complete these checks in order:

### 0. Program-Level Rejection Scan (MANDATORY — GATE CHECK)

**This step kills submissions before you waste time writing them.** Run ALL sub-checks. If ANY returns FATAL, stop immediately and warn the user.

#### 0a. Fetch Program Rules & Configuration

```
ACTION: WebFetch the program's Immunefi page (both /information/ and /scope/ URLs).
Extract and record:
```

| Field | Where to Find | Why It Matters |
|-------|--------------|----------------|
| **Rule Type** | Program page header | "Primacy of Rules" = strict letter-of-law (can reject valid bugs on technicality). "Primacy of Impact" = flexible (impact matters more than scope technicalities). |
| **Vault Balance** | Program page "Rewards" section or on-chain vault address | $0 vault = program may be dormant. Vault < expected payout = payment risk. |
| **Known Issues List** | Program page "Known Issues" or linked documents | EVERY item must be compared against your finding. If ANY overlap exists, build differentiation or abort. |
| **Specific Exclusions** | Program page "Out of Scope" section | Look for surgical exclusions targeting your finding class (e.g., "Pipeline/Depot misuse", "frontrunning", "external stablecoin depegging"). |
| **Past Audits** | Program page "Resources" or linked repos | ALL audit reports must be searched for your vulnerability class. |
| **KYC Requirements** | Program page | Some programs require full identity disclosure for payout. |
| **Payment Currency** | Program page | BEAN, RSR, USDC, ETH — affects real payout value. |

#### 0b. Vault Balance Gate

```
IF vault_balance == $0 → FATAL: Program likely dormant. Do NOT submit.
IF vault_balance < expected_payout * 0.5 → WARNING: Payment risk. Flag to user.
```

Check the vault address on the appropriate block explorer (Etherscan, Arbiscan, etc.).

#### 0c. Known Issues Deep Scan

```
ACTION: For EACH known issue listed on the program page:
1. Read the full description (not just the title)
2. Compare root cause, trigger, and impact against your finding
3. If ANY overlap → build an explicit differentiation table (Step 3d) or abort
```

**Also check:**
- Linked Google Sheets (e.g., CapyFi known issues spreadsheet)
- Linked "False Positive Reports" documents (e.g., Rootstock, updated regularly)
- Community bug report pages (e.g., community.bean.money/bug-reports)
- Self-reported bug submissions by the project

#### 0d. Surgical Exclusion Scan

**Read the Out-of-Scope section word by word.** Programs add exclusions targeting specific vulnerability classes. Examples found in the wild:

| Program | Exclusion | What It Kills |
|---------|-----------|---------------|
| Beanstalk | "Impacts that involve frontrunning transactions" | ANY sandwich/MEV attack |
| Beanstalk | "Unexpected outcomes due to misuse of Pipeline and/or Depot" | ANY Pipeline reentrancy finding |
| Immunefi General | "Impacts relying on attacks involving the depegging of an external stablecoin where the attacker does not directly cause the depegging" | External token failure scenarios (USDT pause, USDC blacklist) |
| Multiple | "Impacts from privileged address attacks" | Findings requiring admin action as trigger |
| Multiple | "DoS attacks against project assets" | Pure availability findings |

```
IF your finding matches ANY surgical exclusion → FATAL unless you can reframe the finding
to avoid the exclusion's language. Document the reframing strategy.
```

#### 0e. Past Audit Deep Scan

```
ACTION: For EACH audit report listed on the program page:
1. Download/fetch the report
2. Search for: contract name, function name, vulnerability class keywords
3. Search for: "revert", "DOS", "freeze", "external call" near the vulnerable contract
4. If ANY finding touches the same contract/function → build differentiation (Step 3d)
5. If ANY finding has the same ROOT CAUSE → likely duplicate, abort unless clearly distinct
```

**Also search:**
- CodeHawks competitions covering the protocol
- Code4rena reports (search `site:code4rena.com "[protocol name]"`)
- Sherlock contests
- The protocol's own GitHub issues/PRs

#### 0f. Severity Feasibility Gate

Before claiming a severity level, verify the program PAYS for that level:

```
IF severity == "Medium" AND program lists no Medium rewards → can't submit at Medium
IF severity == "High" AND finding is DoS/griefing → Immunefi v2.3 classifies griefing as Medium
IF severity == "Critical" AND impact is "compliance failure" not "theft" → likely downgraded
IF severity depends on "permanent" freeze AND governance recovery exists → likely "temporary"
```

**DoS/Griefing Classification Rule (Immunefi v2.3):**
- Griefing = no profit for attacker, damage to protocol/users = **Medium** severity
- This affects EV calculations: a "High" DoS is actually Medium ($5K-$10K, not $10K-$25K)
- Exception: if `secondsToDeadline > 7 days (604800s)` → may qualify as High under "temporary freezing of funds" with extended duration

#### 0g. Output: Program Risk Card

Print this card BEFORE proceeding to Step 1:

```
╔══════════════════════════════════════════════╗
║  PROGRAM RISK CARD: [Protocol Name]          ║
╠══════════════════════════════════════════════╣
║  Rule Type:     [Primacy of Rules/Impact]    ║
║  Vault Balance: $[amount]                    ║
║  KYC Required:  [Yes/No]                     ║
║  Payment:       [currency]                   ║
║  Known Issues:  [N] items checked            ║
║  Exclusions:    [N] surgical exclusions       ║
║  Past Audits:   [N] reports scanned          ║
║  Gate Status:   [PASS / WARNING / FATAL]     ║
╚══════════════════════════════════════════════╝
```

If Gate Status = FATAL → stop and explain why. Do NOT proceed to report writing.
If Gate Status = WARNING → proceed but flag risks prominently in the report.

### 1. Scope Validation (MANDATORY — REJECTION RISK)

**This is the #1 cause of rejection.** Fetch the program's Immunefi page and extract the exact in-scope assets list.

```
RULE: The vulnerable FILE PATH must fall WITHIN the in-scope asset's directory tree.
```

- If asset is `crypto/dkg/src` → only files under `crypto/dkg/src/` are in scope
- `crypto/dkg/promote/src/` is NOT under `crypto/dkg/src/` — it's OUT OF SCOPE
- Sub-crates, workspace members, and sibling directories are NOT automatically in scope
- **When in doubt, the file is out of scope. Do not submit.**

Action: Print a scope validation table:
```
| Vulnerable File | In-Scope Asset | Asset Path | IN/OUT |
```

If OUT → stop and warn the user. Do not generate the report.

### 2. Duplicate Check (MANDATORY — REJECTION RISK)

Before writing the report:
- Search the target repo's GitHub Issues for keywords related to the bug
- Search the repo's git log for recent commits that may have fixed it
- Check if the vulnerability has been discussed in PRs or security advisories

If duplicate → stop and warn the user.

### 3. Anti-Rejection Research (MANDATORY — ACCEPTANCE MAXIMIZER)

**This step systematically builds arguments against the 3 most common rejection vectors.** Run ALL sub-checks before writing the report. Results get embedded directly into the Description field.

Refer to the detailed methodology in `anti-rejection-playbook.md`.

#### 3a. Internal Consistency Scan

Search the TARGET codebase for defensive patterns the vulnerable code SHOULD use but doesn't:

```
ACTION: Grep the codebase for try/catch, error handling, or safe wrappers around the same type of external call.
```

- Search for `try` keyword in the same directory tree (e.g., `contracts/plugins/`)
- Search for comments mentioning "brick", "DOS", "revert", "external", "defensive"
- Find other wrappers/plugins that handle the same class of external call safely
- Count total defensive pattern instances vs. the vulnerable code's lack thereof

**Output:** A paragraph for the report: *"The protocol uses [N] try/catch instances across [directory]. [ContractX] explicitly documents this risk: '[exact comment]'. The vulnerable contract lacks this identical protection."*

If no internal consistency argument exists → skip this sub-section in the report.

#### 3b. Precedent Audit Research

Search for the SAME vulnerability class validated in other protocol audits:

```
ACTION: WebSearch for "[vulnerability pattern] + Code4rena/Sherlock/Hats + [protocol type]"
```

Search queries to run (adapt keywords to the specific finding):
1. `"[vulnerability pattern]" site:github.com code-423n4`
2. `"[vulnerability pattern]" site:github.com sherlock-audit`
3. `"[affected external protocol]" revert DOS audit finding`
4. `"[external call pattern]" blocks withdrawals audit`

Build a precedent table:

```
| Protocol | Year | Platform | Severity | Issue Summary |
```

**Minimum 3 precedents required.** If fewer than 3 found → the finding may be novel (good) or invalid (bad). Adjust confidence accordingly.

**Output:** A table and summary sentence for the report: *"This exact vulnerability class has been confirmed as valid across [N] audits on [M] protocols."*

#### 3c. External Dependency Defense

For findings that depend on external conditions (token pause, oracle failure, governance action):

```
ACTION: Document CONCRETE real-world scenarios where the external condition has occurred.
```

Research:
1. **Pausable tokens** — Does the external token have a pause function? Has it been used? (USDT: $3.3B frozen, 7,268 addresses. USDC: blacklist active.)
2. **Governance actions** — Can third-party governance add/remove/modify the dependency? (Convex `rewardManager`, Curve `add_reward()`)
3. **Historical incidents** — Has this exact external protocol had failures? (Search: "[protocol] incident", "[protocol] exploit", "[protocol] emergency")
4. **Permissionless vectors** — Can anyone trigger the external condition, or only privileged roles?

**Output:** A numbered list of 3-6 concrete failure scenarios with evidence for the report.

If the finding does NOT depend on external conditions → skip this sub-section.

#### 3d. Prior Audit Differentiation

If the target protocol has been audited before (Code4rena, Trail of Bits, OpenZeppelin, etc.):

```
ACTION: Fetch all prior audit reports and search for ANY finding touching the same contract/function.
```

- Search: `gh issue list -R [repo] --search "[contract name]"`
- Search: `site:code4rena.com "[protocol name]" [contract name]`
- Search: `site:github.com "[protocol name]" audit report`

For EACH potentially confusable prior finding, build a differentiation table:

```
| Aspect | Prior Finding | This Finding |
|--------|--------------|--------------|
| Trigger | ... | ... |
| Impact | ... | ... |
| Root cause | ... | ... |
| Attack vector | ... | ... |
| Affected operations | ... | ... |
| Recovery | ... | ... |
```

**Output:** Clear differentiation section for the report with comparison table.

If no prior audits found or no confusable findings → add a note: *"No prior findings on this contract/function were identified."*

#### 3e. Rejection Vector Matrix

Before writing the report, build this matrix:

```
| Rejection Vector | Anticipated Argument | Counter-Argument | Evidence |
|-----------------|---------------------|------------------|----------|
| "Out of scope" | [what they might say] | [why it's in scope] | [proof] |
| "Known issue" | [which prior finding] | [differentiation] | [table] |
| "External condition" | [it requires X] | [X has happened/will happen] | [precedents] |
| "Won't fix / design choice" | [intended behavior] | [internal inconsistency] | [code diff] |
| "Low severity" | [limited impact] | [actual impact chain] | [affected contracts] |
```

**Every cell must be filled** for the rejection vectors relevant to this finding. Empty cells = weak report.

This matrix is NOT included in the report verbatim — it informs which arguments to embed in Vulnerability Details and Impact Details sections.

### 4. Severity Classification

Use Immunefi's impact categories. Match the ACTUAL impact, not the theoretical maximum:

**Critical:** Direct loss of funds, permanent freezing of funds
**High:** Theft of unclaimed yield, permanent freezing of unclaimed yield, temporary freezing of funds
**Medium:** Smart contract unable to operate, griefing (no profit for attacker, material loss for protocol)
**Low:**
- "Undocumented panic reachable from a public API"
- "Incorrect/incomplete cryptographic formulae within a prover's/verifier's callstack"
- Contract fails to deliver promised returns (but no loss)

**NOTE:** Payout amounts vary per program — always check the program's Immunefi page and vault balance. Some Critical payouts cap at $12K (e.g., Ethena vault: ~$12.5K), others at $1M+ (e.g., Firedancer).

**Generic Severity Downgrade Rules:**

| Condition | Downgrade To | Rationale |
|-----------|-------------|-----------|
| Existing architecture prevents exploitation in real conditions | LOW | Bug is theoretical-only. State the mitigation honestly. |
| Trigger requires conditions inconsistent with protocol's operational history | -1 level | e.g., "proxy upgrade" on a protocol that has never upgraded |
| Trigger requires conditions consistent with protocol's demonstrated practice | No downgrade | e.g., "proxy upgrade" on a protocol that has upgraded before (Ethena StakedUSDe→V2) |
| Impact requires attacker to control privileged role | -1 to -2 levels | Unless the role is permissionlessly obtainable |
| Recovery mechanism exists (governance, pause, emergency withdraw) | -1 level | Unless recovery requires unrealistic coordination |
| No recovery mechanism exists | No downgrade | Explicitly state: "no pause, no governance override, no circuit breaker" |

**Rules:**
- Apply downgrade rules cumulatively but use judgment — a finding with 2 minor downgrades may stay at the same level if the core impact is strong
- NEVER oversell severity. Overselling damages credibility and leads to rejection.
- When in doubt, submit at the lower severity. An accepted Medium beats a rejected High.

## Report Format

### Title Field

Format: `[Vulnerability type] in [function/component] leads to [concrete impact]`

Examples:
- "Reentrancy in withdraw() leads to total loss of funds"
- "Missing participant validation in GeneratorPromotion::complete() leads to panic on crafted proofs HashMap"
- "Lack of identity point rejection in SchnorrAggregate::read() leads to weakened aggregate verification equation"

Rules:
- Under 120 characters
- No severity label in title
- Concrete impact, not vague ("leads to panic" not "leads to potential issues")
- Name the exact function or component

### Description Field

Use this exact structure with markdown:

```markdown
## Brief/Intro

[2-3 sentences. What is the bug, where is it, what happens. No filler.]

## Vulnerability Details

[Technical deep-dive. Include:]
- Exact file paths and line numbers
- Code snippets of the vulnerable code (with ```language blocks)
- Step-by-step explanation of how the bug triggers (numbered attack path)
- What validation is missing or what check is wrong
- If there's a mitigating factor (e.g., type-state machine), state it clearly under "**Mitigation context:**"

[THEN — embed anti-rejection arguments as sub-sections:]

#### Why this is [protocol]'s responsibility
[Internal consistency argument from Step 3a. Show the protocol's own defensive patterns
elsewhere and quote their own comments if available. State the count of defensive patterns
vs. the vulnerable code's lack thereof.]

#### Distinction from [prior finding ID]
[Differentiation table from Step 3d. 6-column comparison table. Only include if a
confusable prior finding exists.]

#### Real-world precedent
[Precedent table from Step 3b. Audit findings table + summary sentence.
Cite judge quotes if available.]

#### Concrete failure scenarios
[External dependency defense from Step 3c. Numbered list of 3-6 real-world scenarios
with evidence. Only include if finding depends on external conditions.]

## Impact Details

[Concrete impact assessment:]
- List ALL affected contracts/deployments (not just the vulnerable file)
- What happens when the bug is triggered — enumerate each blocked operation
- Who can trigger it (any user? network attacker? only specific roles? no attacker needed?)
- What is NOT at risk (be honest — "No funds are at risk")
- Whether a recovery mechanism exists (if none → state explicitly)
- Selected impact category with justification matching Immunefi's exact wording

## References

[Bulleted list of GitHub permalink URLs to:]
- Vulnerable code (exact lines)
- Related safe code (for comparison — the protocol's own defensive pattern)
- Upstream usage points (where the vulnerable function is called)
- External protocol code (if the bug involves cross-contract interaction)
- Prior audit findings (same vulnerability class, for precedent)
- Relevant specs/papers if applicable
```

### Proof of Concept Field

Use this exact structure:

```markdown
## Proof of Concept

### Setup

[For Solidity: forge init + foundry.toml config]
[For Rust: Cargo.toml dependencies. Use `<repo>` as placeholder for repo path.]

### Test Code

[Complete, self-contained test. Must include:]
- All necessary imports
- For Solidity: full contract with mock contracts reproducing the exact architecture
- For Rust: `#[test]` attribute, `#[should_panic(expected = "...")]` if testing a panic
- Clear comments marking the attack/trigger point
- Assertions that prove the bug exists
- BASELINE test proving normal operations work (before the bug triggers)
- Multiple test functions covering different dimensions of the impact

### Running

[Exact command to run the test]
[For Solidity: forge test --match-contract TestName -vvv]
[For Rust: cargo test test_name -- --test-threads=1]

### Expected Output

[Copy-paste the actual passing test output — proves it was run and verified]

### Explanation

[2-3 sentences: what the test does, why it proves the bug.
Map each mock contract to the real contract it simulates.]
```

**PoC Rules (Immunefi enforcement):**

**CRITICAL — FORK-BASED PoCs MANDATORY FOR SOLIDITY:**
Immunefi REJECTS any Solidity PoC that uses mock/dummy contracts. Learned from Ethena Report #1 rejection (2026-02-15).

**Immunefi's exact requirements (verbatim from rejection):**
> 1. Use the exact deployed contract that is claimed to be vulnerable
> 2. Use the actual contract addresses from the program's Assets in Scope
> 3. Fork real chain state so your PoC runs against deployed code
> 4. Remove any mock contracts that simulate project behavior

**Implementation checklist (non-negotiable):**
1. Fork mainnet via `vm.createSelectFork(vm.envString("ETH_RPC_URL"))` or `--fork-url`
2. Interact DIRECTLY with the deployed contract at its real address (from Assets in Scope)
3. Retrieve the real admin via `owner()`, `getRoleMember()`, or storage slot lookup
4. Use `vm.prank(realAdmin)` to impersonate the actual admin — NOT a test address
5. Use Foundry `deal(tokenAddress, user, amount)` for token funding — NOT mock ERC20s
6. Contain ZERO mock contracts, ZERO reproduction contracts, ZERO helper simulators
7. Define interfaces (not full contracts) for interacting with deployed contracts
8. Use free RPC endpoints for testing: `https://ethereum-rpc.publicnode.com` (ETH), or Alchemy/Infura with API key
9. Must be runnable with: `ETH_RPC_URL=<rpc> forge test --match-contract <Name> -vvv`

**Solidity fork-based PoC template:**
```solidity
pragma solidity ^0.8.20;
import "forge-std/Test.sol";

interface ITarget {
    function vulnerableFunction() external;
    function owner() external view returns (address);
    // ... only the functions you need
}

contract Exploit_ForkTest is Test {
    address constant TARGET = 0x...; // Real deployed address from Assets in Scope
    address constant TOKEN = 0x...;  // Real token address

    ITarget target;
    address admin;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
        target = ITarget(TARGET);
        admin = target.owner(); // Real admin from deployed contract
        deal(TOKEN, attacker, amount); // Fund via Foundry cheatcode
    }

    function testBaseline_NormalOperationWorks() public { /* ... */ }
    function testExploit_VulnerabilityTriggers() public { /* ... */ }
}
```

**Exceptions (non-Solidity PoCs):**
- **Rust:** Pure unit tests against the crate's own code. Fork not applicable.
- **C/C++:** Unit tests within the project's build system, or standalone reproducers with struct layout proofs. Fork not applicable.
- **Move/Clarity/other:** Follow the chain-specific testing conventions.

### Rust PoC Baseline Template

Every Rust PoC should include a baseline test proving normal operations work, then an exploit test proving the bug. This pattern prevents "your test setup is wrong" rejections.

```rust
#[cfg(test)]
mod tests {
    use super::*;

    /// BASELINE: Normal operation works as expected.
    /// This proves the test setup is correct and the bug is specific,
    /// not an artifact of misconfiguration.
    #[test]
    fn test_baseline_normal_operation() {
        // Setup: create the object/state under test
        let state = setup_normal_state();

        // Action: perform the normal operation
        let result = state.do_operation(normal_input());

        // Assert: normal behavior holds
        assert!(result.is_ok(), "Normal operation must succeed");
        assert_eq!(result.unwrap(), expected_normal_output());
    }

    /// EXPLOIT: The vulnerability triggers under specific conditions.
    #[test]
    fn test_exploit_triggers_bug() {
        // Setup: same as baseline
        let state = setup_normal_state();

        // Action: provide the malicious/edge-case input
        let result = state.do_operation(malicious_input());

        // Assert: the bug manifests
        // Option A: panic (use #[should_panic])
        // Option B: wrong output (assert_ne! against expected)
        // Option C: state corruption (check invariants)
        assert!(result.is_err(), "Bug: should have failed but didn't");
    }

    /// EXPLOIT VARIANT: Additional dimension (e.g., different input, chained calls)
    #[test]
    fn test_exploit_variant() {
        // ...
    }
}
```

### C PoC Template (Firedancer / low-level)

For C codebases, prove struct layout adjacency and OOB conditions:

```c
static void test_oob_adjacency(void) {
    /* Allocate the struct */
    uchar mem[struct_footprint()] __attribute__((aligned(struct_align())));
    my_struct_t * s = my_struct_join(my_struct_new(mem));

    /* Prove adjacent fields overlap at the OOB index */
    ulong array_end = (ulong)((uchar*)s->array + MAX_ELEMS * sizeof(elem_t));
    ulong next_field = (ulong)((uchar*)&s->adjacent_field);
    FD_TEST(array_end == next_field);  /* Adjacency confirmed */

    my_struct_delete(my_struct_leave(s));
}
```

## Output

When invoked with `/immunefi-submit`, generate three separate copyable blocks:

1. **TITLE** — ready to paste into Immunefi's Title field
2. **DESCRIPTION** — ready to paste into Immunefi's Description field (markdown)
3. **PROOF OF CONCEPT** — ready to paste into Immunefi's PoC field (markdown)

Also print:
- **Asset to select:** exact asset name from the in-scope list
- **Severity to select:** Low/Medium/High/Critical
- **Impact category:** exact Immunefi impact string

## Lessons Learned (Hard-Won Rules)

### Scope & Process
1. **`dkg/promote/` is NOT in scope under `dkg/src`** — sub-crates have different paths
2. **One submission per day** on Immunefi — plan accordingly
3. **Rejected reports still count as your daily submission**
4. **Already-reported GitHub issues will be rejected as duplicates** — always check first
5. **Never include your dropped/retained findings** — only submit what you're confident about
6. **Gist and Attachments fields are optional** — inline PoC is sufficient
7. **The acknowledgment checkbox must be checked** — "I confirm that my submission includes a clear, original explanation and a working PoC"
8. **`contracts/plugins/assets/curve/cvx/vendor/` is IN scope** under the plugins asset — it's NOT the excluded `/contracts/vendor/` path. Always check exact directory tree.

### Severity & Classification
9. **Type-state mitigated bugs are LOW, not MEDIUM** — architecture prevents real exploitation
10. **NEVER oversell severity** — overselling damages credibility and leads to rejection
11. **"Permanent freezing of funds" is High-to-Critical on Immunefi** — match their exact wording
12. **External dependency findings CAN be valid** — if the protocol chose not to protect against a known failure mode, it's their bug even if the trigger is external
13. **DoS/griefing is MEDIUM under Immunefi v2.3** — no profit for attacker + damage to protocol = griefing = Medium. This halves expected payouts on DoS findings. Exception: if freeze duration > 7 days (604800s), may qualify as High under "temporary freezing of funds".
14. **"Permanent" vs "Temporary" freezing** — if governance can switch collateral, refresh baskets, or if the external condition can self-resolve, reviewers classify as "temporary" (High) not "permanent" (Critical). Only claim "permanent" if there is genuinely NO recovery path.

### Fix & Payout
15. **ALWAYS include an explicit recommended fix with code** — Immunefi operates "no fix, no pay". If the project later implements your fix without paying, you need documented proof you proposed it. A fix also accelerates triage and shows deep understanding. Even a 1-line fix (e.g., `return;` after bounds check) must be explicitly stated.
16. **Check vault balance before estimating EV** — Payout is capped by the program's vault funds. A Critical on a $12K vault pays $12K max, not $250K. Always check "Funds Available" on the program page.
17. **$0 vault = don't submit** — Programs with $0 vault balance (e.g., Beanstalk) are functionally dormant. Even valid findings may never pay.
18. **Check vault on block explorer, not just Immunefi page** — vault balances shown on Immunefi may be cached/stale. Verify the actual on-chain balance.

### PoC Requirements
19. **FORK-BASED PoCs MANDATORY for Solidity** — Immunefi rejects mock-based PoCs. Fork mainnet, interact with real deployed contracts, zero mocks. Learned from Ethena #1 rejection (2026-02-15). Use `vm.createSelectFork()`, `deal()` for tokens, `vm.prank(realAdmin)` from `owner()`. Free RPC: `https://ethereum-rpc.publicnode.com`.
20. **vm.mockCallRevert is NOT a "mock contract"** — it simulates a realistic condition (token pause/failure) on real deployed bytecode. This is acceptable because the underlying contract is real. But if the WRAPPER itself is reproduced instead of using the actual deployed wrapper, Immunefi may reject it. Always prefer forking the actual deployed contract.
21. **Fork the correct chain** — if contracts are on Ink Chain, fork Ink Chain. If on Arbitrum, fork Arbitrum. Wrong chain = invalid PoC. Check the Assets in Scope for chain identifiers.

### Anti-Rejection (most impactful rules)
22. **Always search the TARGET codebase for internal consistency** — if they use try/catch in Contract A but not Contract B for the same pattern, that's your strongest argument ("they already know about this risk")
23. **Quote the protocol's own comments** — if their code says "we want to prevent external calls from bricking the contract" in one wrapper but not another, quote it verbatim
24. **Build a precedent table from prior audits** — 3+ findings on other protocols validating the same vulnerability class transforms "theoretical" into "industry-recognized". Search Code4rena, Sherlock, Hats Finance.
25. **Build a differentiation table for EVERY prior audit finding** on the same contract — reviewers WILL check. 6-column comparison table (trigger, impact, root cause, attack vector, affected ops, recovery) makes confusion impossible.
26. **Document concrete failure scenarios with numbers** — "USDT has frozen $3.3B across 7,268 addresses" beats "USDT could theoretically be paused"
27. **Count affected deployments** — "7 collateral contracts and 4+ pool IDs" beats "some Convex collateral"
28. **Always note if NO recovery mechanism exists** — "the wrapper has no emergency pause, no governance override, no circuit breaker" eliminates the "governance can fix it" rejection
29. **Cite judge quotes from precedent audits** — Sherlock/C4 judge reasoning carries weight
30. **Add tests that close admin mitigation vectors** — e.g., if admin could theoretically "set parameter to 0" to mitigate, add a test proving this backfires or doesn't help. Prevents the "admin can mitigate" rejection. (Learned from Ethena ZeroCooldownHelpsAttacker test.)

### Program-Level Kills (learned from Feb 2026 swarm audit)
31. **Read Out-of-Scope sections WORD BY WORD** — Programs add surgical exclusions targeting specific vulnerability classes. Beanstalk's "Pipeline/Depot misuse" exclusion was written specifically to kill reentrancy findings. Missing these = wasted submission day.
32. **Frontrunning exclusion kills sandwich attacks** — "Impacts that involve frontrunning transactions through the public mempool" is explicit in many programs. A sandwich is frontrunning by definition. The only escape: prove the attack works without mempool observation (e.g., attacker calls sunrise() themselves via flash loan).
33. **ERC standard compliance != bug** — If a standard says a feature is optional (MAY), not implementing it is NOT a vulnerability. ERC-1155 does NOT require per-token approvals. Beanstalk implementing only `setApprovalForAll` is fully compliant.
34. **CodeHawks/C4 prior findings create "known issue" risk** — Even if your finding is technically distinct, if the SAME CONTRACT was already reported in CodeHawks/C4, the program can claim "known area" and reject. Build airtight differentiation.
35. **File-level exclusions trump Primacy of Impact** — Rootstock excludes `LiquidityBridgeContract.sol` by name. Even under Primacy of Impact, an explicitly named and excluded file is extremely hard to submit against. The file was "listed and then explicitly excluded" — different from "unlisted."
36. **"Well-known vulnerability class" kills commodity findings** — `.transfer()` 2300 gas limit has been documented since 2019 (ConsenSys Diligence). Both Coinspect and OpenZeppelin audited CapyFi and almost certainly flagged it. Check known issues spreadsheets and audit reports BEFORE investing time.
37. **Verify contract upgradeability before claiming upgrade-based triggers** — If your finding requires "proxy upgrade breaks X" but the contract is NOT a proxy (no EIP-1967 slots), the trigger is impossible. Check Etherscan "Read as Proxy" tab and query storage slots 0x360894...beef01 and 0xb53127...a3b1 before writing the report.
38. **Resubmission after rejection is risky** — The protocol team saw your vulnerability description in the first submission. They could retroactively add it to "known issues" or self-report it. Resubmit FAST after rejection, and acknowledge the prior submission with "PoC has been corrected" framing.
39. **Check git blame for post-audit code** — If the vulnerable code was written AFTER the last audit/competition, it can't be a "known issue from audits." Use `git blame` or `git log` on the specific vulnerable lines to prove the code post-dates all known reviews.
40. **CoinFabrik audited StackingDAO AND wrote the blog post on contract-caller** — If the SAME audit firm that reviewed the protocol has published research on your exact vulnerability class, the probability they caught it during audit approaches 100%. Check auditor blogs.
41. **Verify code path reachability in the IN-SCOPE binary/build** — Code present in the repo is NOT necessarily reachable from the in-scope build target. Different binaries (e.g., Frankendancer vs Full Firedancer) wire different topologies, link inputs, and API paths. ALWAYS trace: entry point → handler → vulnerable function in the SPECIFIC binary that's in scope. If the code path only exists in an out-of-scope build variant, the finding is invalid. Learned from Firedancer FDR-001 rejection (2026-02-17): `ci_dest_add_one_unstaked` only reachable via `IN_KIND_GOSSIP` in Full Firedancer (out of scope), not via `IN_KIND_CONTACT` in Frankendancer (in scope).
42. **Check topology/configuration files, not just source code** — For multi-binary projects, the topology configuration determines which code paths are active. `fd_topob_tile_in()` calls in `topology.c` define tile input links. A function can exist in source but never be called if no link feeds it. Always read the topology file for the in-scope binary.

## Outcome Tracking (Feedback Loop)

**After every Immunefi response**, log the outcome to build a data-driven rejection pattern database:

```
/immunefi-submit --log-outcome <submission-id> <accepted|rejected|escalated|closed> "<reason>"
```

**When invoked with `--log-outcome`:**

1. Append to `/home/malix/Desktop/BUGS/SKL/outcomes.jsonl` (canonical location):

```json
{"id":"ethena-blacklist-001","date":"2026-02-15","program":"ethena","severity":"critical","outcome":"accepted","reason":"Fixed in next release","payout":"$12496","days_to_response":5,"rejection_vectors_hit":[]}
```

```json
{"id":"serai-promote-001","date":"2026-02-14","program":"serai","severity":"medium","outcome":"rejected","reason":"Out of scope - promote/ not under dkg/src","payout":"$0","days_to_response":2,"rejection_vectors_hit":["scope"]}
```

2. Print cumulative stats:

```
=== Submission Stats ===
Total: 12 | Accepted: 7 (58%) | Rejected: 4 (33%) | Pending: 1
Rejection reasons:
  scope:        2 (50% of rejections)
  known_issue:  1 (25%)
  severity:     1 (25%)
Top-earning program: Firedancer ($200K)
Avg days to response: 8.3
```

3. If rejection count for a specific vector exceeds 2, print a warning:

```
⚠ PATTERN DETECTED: 'scope' has caused 2+ rejections.
Review scope-pitfalls.md and consider stricter scope validation before submitting.
```

**When invoked with `--stats`:**
Read `outcomes.jsonl` and print the stats summary without adding a new entry.

**Why this matters:** After 10-15 logged outcomes, patterns emerge. If scope rejections dominate, tighten scope validation. If severity downgrades dominate, adopt more conservative classification. Rules evolve from data, not memory.

## Phase 4: Pre-Submission Quality Gate (21-Point Rubric)

**Every submission MUST pass the quality gate BEFORE pasting on Immunefi.** Minimum score: 20/22.

Run the full rubric from `anti-rejection-playbook.md` Phase 4 after the report is written. The rubric covers:

- **A. PoC Quality (7 pts)** — fork-based, all pass, strongest variant leads, baselines, impact tests, sync md/code, no exact gas values in expected output
- **B. Report Argumentation (7 pts)** — assertive intro, exact code citations, verbatim quotes, "not user's fault" argument, prior audit diff, verified precedent links, honest mitigations
- **C. Submission Hygiene (4 pts)** — no markdown tables (Immunefi renders them broken), complete fix with code, Immunefi severity language, copy-paste-run setup
- **D. Strategic Positioning (4 pts)** — strongest argument leads, rejection matrix done, EV gate passed, **code path reachability verified in in-scope binary**

```
22/22 — Submit immediately
20-21 — Submit after fixing flagged items
17-19 — Significant gaps, fix before submitting
<17   — Major rework needed
```

Print the score breakdown when generating the report. If any criterion fails, flag it explicitly with the fix needed.

## Arguments

`$ARGUMENTS` should be one of:
- A path to a vulnerability markdown file to format
- A description of the bug to format from scratch
- `--validate <file>` to validate an existing report without reformatting
- `--scope <immunefi-url>` to fetch and display in-scope assets for a program
- `--log-outcome <id> <accepted|rejected|escalated|closed> "<reason>"` to log a submission result
- `--stats` to print cumulative outcome statistics
- `--fix-check` to verify all reports in the current directory have an explicit recommended fix section
