---
name: mrrobbot
description: Adaptive security audit framework for smart contracts and web targets. Combines gravedigger recon with the 4-phase adaptive deep audit methodology. Use for bounties >$50K. Phases expand/contract based on signal — not a fixed checklist.
---

# MrRobbot — Adaptive Security Audit Framework

You are executing the MrRobbot methodology — an adaptive security audit framework that adjusts its depth based on what you find. This replaces surface scanning with parallel agents. The framework was battle-tested on Reserve Protocol ($10M bounty, 14+ audits, produced 1 confirmed Medium via check matrix technique).

**Core principle:** Go deep on one target for weeks. The bugs that survive 14 audits live in UNAUDITED code, cross-module state transitions, and function-level check inconsistencies — not in surface patterns.

## Arguments

```
/mrrobbot <target>              # Start new investigation
/mrrobbot <target> --resume     # Resume existing investigation
/mrrobbot <target> --status     # Show investigation status
```

## Skill Resources

| File | Purpose | When |
|------|---------|------|
| `/home/malix/Desktop/BUGS/KILL-GATE-TEMPLATE.md` | 10-question false positive elimination | Before deep-diving any finding |
| `/home/malix/Desktop/BUGS/CHAIN-PROOF-GATE.md` | **Chain Proof Gate (D7)** — Stage 1 hedge grep + Stage 2 ethical variant generator. **MANDATORY** for auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding findings | Phase 4 — BEFORE report writing, on every auth-class finding |
| `/home/malix/Desktop/BUGS/WEIGHT-CARD.md` | **Weight Card (D8)** — 5-slot dashboard with hard gate on W1 (computed loss) or W5 (paid precedent) numerical anchor. **MANDATORY** for every finding claiming severity ≥ Low with dollar impact. Complementary to Chain Proof Gate — D7 = "does exploit execute?", D8 = "is impact priced?" | Phase 4 — BEFORE report writing, on every non-Informational finding |
| `/home/malix/Desktop/BUGS/REPORT-STANDARD.md` | **Production report template** — Transak voice, epistemic precision, chain factoring. Contains mandatory `Chain Acceptance Verification` section + `Weight Accounting` section | Phase 4 — ALL report writing |
| `/home/malix/Desktop/BUGS/PREFLIGHT-CHECK.md` | 24-point quality gate with gating criteria D7 (chain proof) + D8 (weight anchor) | Before submitting any finding |
| `~/arsenal/tools/precedent-scan.sh` | Emits copy-paste-ready W5 precedent table for the Weight Card. Wraps H1-HUNTING-PATTERNS + H1-STATISTICS + OUTCOMES.jsonl. Usage: `./precedent-scan.sh "IDOR"` | Phase 4 — populate W5 fast |
| `/home/malix/Desktop/BUGS/CRITICAL-HUNT-CHECKLIST.md` | Smart contract hunting patterns | Phase 1 surface scan |
| `~/arsenal/tools/reverse-lookup.py` | SBOM cross-reference | Phase 0 triage |
| `~/arsenal/tracking/research_db.jsonl` | Cumulative research database | Phase 0 triage |
| Gravedigger `RECON-PLAYBOOK.md` | Protocol intelligence | Phase 0 triage (web targets) |
| Gravedigger `WEB-API-CHECKLIST.md` | Web/API procedures | Web target phases |

## Automated Tools (MANDATORY — run these, don't do manually what tools can do)

| Tool | Command | When |
|------|---------|------|
| `~/arsenal/tools/pattern-scan.sh` | `./pattern-scan.sh <dir> --type vault\|dex\|bridge\|lending\|staking --lang sol\|rs\|go` | Phase 0 — first thing after cloning. Run BEFORE manual review. |
| `~/arsenal/tools/check-matrix.py` | `python3 check-matrix.py <dir> --output matrix.md` | Phase 1 — run on every SC target. Finds modifier inconsistencies in 30s. |
| `~/arsenal/tools/invariant-gen.py` | `python3 invariant-gen.py <dir> --output invariants.t.sol` | Phase 2 — generates fuzz tests. Run, then customize and execute with forge. |
| `~/arsenal/tools/fork-diff.sh` | `./fork-diff.sh <local_fork> <parent_repo_url>` | Phase 0 — when target is a fork. Focus on [SECURITY] tagged changes. |
| `~/arsenal/tools/vuln-propagate.py` | `python3 vuln-propagate.py --parent "protocol" --file "File.sol" --pattern "regex"` | Phase 4 — after confirming a finding. Check all forks for same bug. |
| `~/arsenal/tools/enrich-finding.py` | `python3 enrich-finding.py --address 0x... --chain ethereum --type vault` | Phase 4 — before writing report. Quantify TVL and on-chain state. |
| `~/arsenal/tools/report-gen.py` | `python3 report-gen.py --finding finding.json --platform h1\|hackenproof\|cantina` | Phase 4 — generate formatted report from structured finding data. |
| `~/arsenal/tools/github-monitor.py` | `python3 github-monitor.py` | Background — watch repos for security-relevant commits. |
| `~/arsenal/tools/dep-audit.sh` | `./dep-audit.sh <dir> --lang sol\|rs\|go` | Phase 0.7 — maps all deps, versions, CVEs, fork diffs. Outputs DEPENDENCY-AUDIT.md. |

## Pattern Databases (REFERENCE — use pattern-scan.sh to apply automatically)

| File | Content | Count |
|------|---------|-------|
| `~/arsenal/methodology/C4-HUNTING-PATTERNS.md` | Solidity vulnerability patterns from C4 reports | 128 patterns |
| `~/arsenal/methodology/MULTI-LANG-PATTERNS.md` | Rust (R-001 to R-010), Go (G-001 to G-008), Cairo (C-001 to C-005), Move (M-001 to M-003) | 28 patterns |
| `~/arsenal/methodology/H1-HUNTING-PATTERNS.md` | HackerOne hacktivity patterns: IDOR, SSRF, RCE, race conditions, auth bypass, business logic, API, cache, AI/LLM | 60+ patterns |
| `~/arsenal/methodology/H1-STATISTICS.md` | Bounty ROI analysis, payout distribution, target selection heuristics, industry patterns | Data-driven |

## PoC Templates (COPY-PASTE — don't write PoCs from scratch)

| Template | File |
|----------|------|
| ERC4626 first depositor inflation | `~/arsenal/templates/foundry/erc4626-inflation.t.sol` |
| Access control bypass | `~/arsenal/templates/foundry/access-control-bypass.t.sol` |
| Cross-contract reentrancy | `~/arsenal/templates/foundry/reentrancy-cross-contract.t.sol` |
| Oracle manipulation | `~/arsenal/templates/foundry/oracle-manipulation.t.sol` |
| Signature replay | `~/arsenal/templates/foundry/signature-replay.t.sol` |
| Bridge message replay | `~/arsenal/templates/foundry/bridge-message-replay.t.sol` |
| Dependency math lib fuzz | `~/arsenal/templates/foundry/dep-math-fuzz.t.sol` |
| Dependency fork diff fuzz | `~/arsenal/templates/foundry/dep-fork-diff-fuzz.t.sol` |
| Dependency oracle fuzz | `~/arsenal/templates/foundry/dep-oracle-fuzz.t.sol` |
| Dependency bridge codec fuzz | `~/arsenal/templates/foundry/dep-bridge-codec-fuzz.t.sol` |
| Gravedigger `JWT-ARSENAL-PLAYBOOK.md` | JWT vuln discovery | Auto-activated on JWT detection |
| Gravedigger `ATTACK-CHAIN-PLAYBOOK.md` | Chain construction | Phase 3+ |

**Integration:** `/disclose` for report formatting, `/immunefi-submit` for Immunefi.

## DEP FUZZING HARNESS GUIDE (Phase 2.6)

**Goal:** Find 0-days in dependencies by fuzzing them with inputs the TARGET would generate.
Nobody audits the layers below the audited code. Curve/Vyper 2023 = $70M+ drained via compiler bug.

### Setup: Foundry project for dep fuzzing

```bash
# 1. Create isolated Foundry project for dep fuzzing
mkdir dep-fuzz && cd dep-fuzz && forge init --no-commit
# 2. Install the dep at the EXACT version the target pins
forge install <dep-repo>@<commit-hash> --no-commit
# 3. If dep uses npm: copy from target's node_modules or pin in package.json
# 4. Add remappings matching the target's remappings.txt
```

### Harness Template: Custom Math Library

```solidity
// test/DepMathFuzz.t.sol
// Target: protocol that uses CustomMathLib for fixed-point arithmetic
import "forge-std/Test.sol";
import {CustomMathLib} from "dep/CustomMathLib.sol";

contract DepMathFuzz is Test {
    using CustomMathLib for uint256;

    // INVARIANT 1: mul then div should return ≤ original (no free money)
    function testFuzz_mulDivNoProfit(uint256 a, uint256 b, uint256 c) public pure {
        vm.assume(c > 0);
        vm.assume(b > 0);
        vm.assume(a < type(uint128).max); // bound to realistic range
        uint256 result = a.mulDiv(b, c);
        uint256 reversed = result.mulDiv(c, b);
        assert(reversed <= a + 1); // allow 1 wei rounding
    }

    // INVARIANT 2: rounding direction consistency
    function testFuzz_ceilGteFloor(uint256 a, uint256 b, uint256 c) public pure {
        vm.assume(c > 0);
        vm.assume(a < type(uint128).max);
        uint256 floor = a.mulDivDown(b, c);
        uint256 ceil = a.mulDivUp(b, c);
        assert(ceil >= floor);
        assert(ceil - floor <= 1); // diff is at most 1
    }

    // INVARIANT 3: no overflow where target expects none
    // Bound inputs to the range the TARGET actually uses
    function testFuzz_targetRangeNoRevert(uint256 amount) public pure {
        amount = bound(amount, 1, 1e30); // realistic token range
        uint256 rate = 1e18; // typical exchange rate
        // This should NOT revert in the target's usage context
        uint256 result = amount.mulDivDown(rate, 1e18);
        assert(result <= amount);
    }
}
```

### Harness Template: Oracle/Price Feed Dependency

```solidity
// test/DepOracleFuzz.t.sol
// Target: protocol wrapping a custom oracle (not Chainlink)
import "forge-std/Test.sol";
import {CustomOracle} from "dep/CustomOracle.sol";

contract DepOracleFuzz is Test {
    CustomOracle oracle;

    function setUp() public {
        oracle = new CustomOracle();
    }

    // INVARIANT: price cannot be manipulated by single-block operations
    function testFuzz_priceStability(uint256 amount, uint256 seed) public {
        uint256 priceBefore = oracle.getPrice();
        // Simulate what an attacker could do in one tx
        // (swap, deposit, withdraw, donate)
        vm.assume(amount < type(uint128).max);
        // ... execute attack action on oracle's source pool ...
        uint256 priceAfter = oracle.getPrice();
        // Price should not move more than X% in one block
        uint256 maxDeviation = priceBefore / 100; // 1%
        assert(priceAfter >= priceBefore - maxDeviation);
        assert(priceAfter <= priceBefore + maxDeviation);
    }

    // INVARIANT: stale price detection works
    function testFuzz_stalePriceReverts(uint256 timeSkip) public {
        timeSkip = bound(timeSkip, 1 hours, 30 days);
        vm.warp(block.timestamp + timeSkip);
        // Oracle should revert or return (0,0) for stale data
        try oracle.getPrice() returns (uint256 price) {
            // If it doesn't revert, price should be flagged as stale
            assert(oracle.isStale() || timeSkip < oracle.heartbeat());
        } catch {
            // Expected: revert on stale data
        }
    }
}
```

### Harness Template: Bridge/Cross-Chain Message Encoding

```solidity
// test/DepBridgeFuzz.t.sol
// Target: protocol using custom bridge message encoding
import "forge-std/Test.sol";
import {MessageCodec} from "dep/MessageCodec.sol";

contract DepBridgeFuzz is Test {
    // INVARIANT: encode then decode = original (roundtrip)
    function testFuzz_encodeDecodeRoundtrip(
        address sender, address receiver, uint256 amount, uint64 nonce
    ) public pure {
        bytes memory encoded = MessageCodec.encode(sender, receiver, amount, nonce);
        (address decSender, address decReceiver, uint256 decAmount, uint64 decNonce)
            = MessageCodec.decode(encoded);
        assert(decSender == sender);
        assert(decReceiver == receiver);
        assert(decAmount == amount);
        assert(decNonce == nonce);
    }

    // INVARIANT: malformed messages revert (no silent corruption)
    function testFuzz_malformedMessageReverts(bytes memory garbage) public {
        vm.assume(garbage.length != MessageCodec.MESSAGE_LENGTH);
        try MessageCodec.decode(garbage) {
            // If it doesn't revert, the output must be deterministic
            // (i.e., not silently corrupted)
            revert("should have reverted on malformed message");
        } catch {
            // Expected
        }
    }

    // INVARIANT: no duplicate message hash (replay protection)
    function testFuzz_uniqueHashes(
        address sender, uint256 amount1, uint256 amount2, uint64 nonce
    ) public pure {
        vm.assume(amount1 != amount2);
        bytes32 hash1 = MessageCodec.hash(sender, sender, amount1, nonce);
        bytes32 hash2 = MessageCodec.hash(sender, sender, amount2, nonce);
        assert(hash1 != hash2);
    }
}
```

### Harness Template: Forked/Modified Dependency (DIFF FUZZING)

```solidity
// test/ForkDiffFuzz.t.sol
// Compare ORIGINAL dep behavior vs FORKED dep behavior
// If they diverge on same input = the fork introduced a bug
import "forge-std/Test.sol";
import {OriginalLib} from "original-dep/Lib.sol";
import {ForkedLib} from "forked-dep/Lib.sol";

contract ForkDiffFuzz is Test {
    // INVARIANT: fork and original produce same results
    function testFuzz_forkMatchesOriginal(uint256 a, uint256 b) public pure {
        vm.assume(b > 0);
        uint256 originalResult = OriginalLib.compute(a, b);
        uint256 forkedResult = ForkedLib.compute(a, b);
        assert(originalResult == forkedResult);
    }

    // Find the DIVERGENCE: fuzz only the modified functions
    function testFuzz_modifiedFunctionOnly(uint256 input) public pure {
        // Only fuzz the function that the fork CHANGED
        // (identified via fork-diff.sh)
        input = bound(input, 0, type(uint64).max); // fork changed uint16→uint64
        uint256 result = ForkedLib.modifiedFunction(input);
        // Assert the invariant the original maintained
        assert(result <= type(uint64).max);
    }
}
```

### Echidna Config for Dep Fuzzing

```yaml
# echidna.yaml — config for dependency fuzzing
testMode: assertion      # or "property" for bool-returning tests
testLimit: 100000        # 100K iterations minimum
seqLen: 10               # sequence length for stateful fuzzing
shrinkLimit: 5000        # shrink failing cases
corpusDir: corpus        # save corpus for reproducibility
cryticArgs:
  - --solc-remaps
  - "@dep/=lib/dep/contracts/"
```

### Dep Fuzzing Decision Matrix

| Dep Type | Harness Strategy | Key Invariants | Iterations |
|----------|-----------------|----------------|------------|
| Custom math lib | mulDiv roundtrip, rounding consistency, overflow bounds | 3-5 | 100K each |
| Oracle/price feed | Price stability, staleness, manipulation resistance | 2-3 | 50K each |
| Bridge message codec | Encode/decode roundtrip, malformed rejection, hash uniqueness | 3 | 100K each |
| Forked dependency | Diff fuzz: fork vs original on same inputs | 1 per modified fn | 100K each |
| Staking/reward lib | Reward monotonicity, no profit from stake+unstake, total conservation | 3-4 | 100K each |
| AMM/DEX lib | xy=k invariant, slippage bounds, no arb from swap+reverse | 2-3 | 100K each |

### When to escalate dep fuzzing results

```
Fuzzer finds failing invariant in dep:
  1. Verify: is the failing input reachable from the TARGET's code?
     → Trace: target function → dep function → failing input
     → If target bounds inputs (e.g., amount < 1e30), check if failing input is in bounds
  2. If reachable: build PoC that triggers the dep bug THROUGH the target
  3. Report to BOTH: target's bounty program AND dep maintainers
     → Target bounty for the impact on their protocol
     → Dep disclosure for the root cause fix
  4. If dep is used by other protocols: vuln-propagate.py to check all forks
     → One dep bug = multiple bounties across protocols
```

---

## TARGET TYPE DETECTION

On `/mrrobbot <target>`, detect target type and route:

```
IF target has smart contracts in scope:
    → SMART CONTRACT PATH (Phase 0-4 below)

IF target has web app + API:
    → WEB PATH (use gravedigger Phases 1-6, but apply "close the chain" rule)
    → MANDATORY: Find the initial access (XSS/redirect) BEFORE reporting broken controls
    → If no initial access after 8h → SKIP web, focus on smart contracts

IF target has BOTH:
    → Smart contracts FIRST (higher ROI, no "requires XSS" dismissal)
    → Web second (only if SC phase produces <2 findings)

IF target is mobile app:
    → APK analysis: deep links, WebView, JSBridge
    → Need ARM device for dynamic testing
```

---

## SMART CONTRACT PATH

### Phase -1: Lifecycle Init (MANDATORY — precedes Phase 0)

**Enforces CLAUDE.md rule #38. FIRST COMMAND of any new target engagement, regardless of skill or entry path.**

```bash
TARGET_HINTS="smart.contract solidity" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <target>
```

Adjust `TARGET_HINTS` per classification: `solana anchor` / `blockchain.node p2p` / `web api rest` / `mobile android` / `defi fintech payment`. Multiple keywords combine.

**Bootstraps workspace + ROUTING + PROGRESS + SEVERITY-COMMIT template + OUTCOMES.jsonl.** Idempotent. Re-run safe after context compression.

**If skipped:** preflight-mechanical.sh refuses PASS at Phase 4 (D0-init marker missing). OUTCOMES records `preflight_run: false`.

---

### Phase 0: Triage (2h, FIXED)

**Goal:** Decide if target is worth multi-week investment.

```
0.1  Clone repos, count LOC, map architecture
0.2  Count prior audits PER COMPONENT (not just protocol total — 60+ audits across 7 components = skip)
0.3  Identify NEWEST/UNAUDITED code — ALWAYS the entry point
0.4  Check bounty structure and payout history
0.5  Reverse dependency lookup (~/arsenal/tools/reverse-lookup.py)
0.6  MANDATORY: Search C4/Sherlock/Cantina reports for the protocol AND its dependencies.
     Extract all HIGH/MEDIUM findings. Build a protocol-specific pattern database.
     For forks: search the PARENT protocol's audits (Aave fork → search Aave findings).
     For integrations: search the INTEGRATION's audits (LayerZero endpoint → search all LZ audits).
     This takes 1h but gives hunting patterns that surface scanners miss.
     Store results in {target}-recon/findings/PRIOR-AUDIT-FINDINGS.md
0.6b C4 AUDIT REPORT × LIVE BOUNTY CROSS-REFERENCE (if target has prior C4/Sherlock audit AND live bounty):
     a) Download the full public audit report from code4rena.com/reports
     b) For each H/M finding: verify the fix on the deployed contract
        → Real fix (root cause addressed) → mark PATCHED
        → Bandaid fix (single require/modifier, root cause intact) → DEEP DIVE as new finding
        → Not fixed at all → IMMEDIATE finding candidate
     c) Check all downgraded/QA findings — judge said Low ≠ no bug. Re-evaluate at current TVL/conditions.
     d) Check adjacent functions to every H-01 — same pattern, different params, unreviewed?
     e) Store in {target}-recon/findings/C4-CROSS-REFERENCE.md with fix status per finding
     IMPORTANT: PoC must prove extraction from OBSERVED state deltas (LP_value_after < LP_value_before),
     not calculated counterfactuals (solidity_cost - rust_cost). Counterfactuals get dismissed as "feature request."
0.7  DEPENDENCY ZERO-DAY AUDIT (Reserve Protocol lesson — bugs survive 14 audits in layers BELOW the audited code)
     a) List ALL deps with exact versions (package.json, foundry.toml, remappings.txt, lib/)
     b) CVE scan: check each dep against known CVEs (npm audit, snyk, osv.dev)
     c) Fork diff: if any dep is forked/vendored, diff against parent upstream
        → grep vendor/ dirs for "modified", "changed", "custom", "Reserve", "added by"
     d) Version lag: compare pinned version vs latest release of each dep
     e) Composition map: how does target COMBINE deps? Novel integration = bug surface
     f) Identify HIGH-VALUE dep targets:
        - Custom math/crypto libraries (not OZ/Aave/Chainlink)
        - Obscure deps with <3 audits
        - Forked deps with modifications
        - Bridge/cross-chain messaging SDKs
        - Compiler/toolchain on exotic chains
     g) Decision gate:
        → Obscure/forked/outdated dep found → DEEP DIVE: read dep code + fuzz in Phase 2
        → All deps battle-tested (OZ, Chainlink, Aave) → SKIP dep audit, focus on target code
     h) Store dep inventory in {target}-recon/DEPENDENCY-AUDIT.md
```

**Decision gate:**

| Signal | Action |
|--------|--------|
| Unaudited code found (new integration, new version) | **PROCEED** — highest ROI |
| <3 prior audits + >$50K bounty | **PROCEED** |
| 10+ audits, ALL code audited, saturated submissions | **SKIP** unless unaudited component |
| Bounty paid $0 with 200+ submissions | **SKIP** |

**Output:** `{target}-recon/` workspace + GO/SKIP decision

---

### Phase 1: Unaudited Code + Check Matrix (3-7 days, ADAPTIVE)

**Goal:** Line-by-line audit of newest/unaudited code. Build THE CHECK MATRIX.

**Lifecycle invocation (MANDATORY per finding candidate, enforces CLAUDE.md rule #39):**

```bash
~/arsenal/audit-lifecycle/bin/on-finding.sh <FINDING_ID>
```

Instantiates `{FINDING_ID}-kill-gate.md`, `{FINDING_ID}-severity-commit.md`, `{FINDING_ID}-chain-proof.md`, `{FINDING_ID}-weight-card.md` in `findings/`.

After Kill Gate PROCEED: populate `SEVERITY-COMMIT-{id}.md` with artifact-required inputs, run `~/arsenal/audit-lifecycle/lib/artifact-validator.sh` — MUST PASS before writing draft. See rule #39.

```
1.1  Read EVERY line of unaudited contracts
1.2  Build CHECK MATRIX (the technique that finds bugs):
     - List ALL external/public functions
     - For each: list ALL modifiers + require statements
     - Compare functions that SHOULD have same checks
     - Inconsistency = finding candidate
1.3  For each inconsistency: write Foundry test to confirm
1.4  For post-audit code: git blame to find changes after last audit
```

**THE CHECK MATRIX (critical technique):**
```python
# Extract from every .sol file in scope:
for each function:
    record: name, visibility, modifiers[], require_checks[]

# Build comparison table:
Function          | nonReentrant | auth_check | state_check | custom_check
function_A        | ✓            | ✓          | ✓           | ✓
function_B        | ✓            | ✓          | ✓           | ✗  ← BUG
```

Two functions that do the same thing but differ in checks = access control bypass.

**Example (Reserve F-001):** `bid()` checks `bidsEnabled`, `createTrustedFill()` doesn't. Same trade initiation, different checks.

**MANDATORY MIRROR INVARIANT AUDIT (CLAUDE.md rule #41, runs in Phase 1 before declaring any in/out file clean):**

For bridges, vaults, escrow, lock/unlock, mint/burn — any protocol with paired state-changing operations — the Check Matrix must include a vertical mirror comparison across the in/out boundary, not only the horizontal comparison between siblings of the same direction.

```python
# For each bidirectional pair in the protocol:
pairs = [
    ("transferToAgent", "transferToken"),        # bridge ingress/egress
    ("transferToAgent", "transferEther"),         # native variant
    ("deposit", "withdraw"),                      # vault
    ("mint", "redeem"),                           # ERC4626 share
    ("convertToShares", "convertToAssets"),       # inverse rounding direction
    ("lock", "unlock"),                           # cross-chain asset
    ("mint", "burn"),                             # wrapped token
    ("sendMessage", "dispatchMessage"),           # message bridge
    ("encode", "decode"),                         # symmetric codec
    ("registerToken", "unregisterToken"),         # registry symmetry
    ("fund", "release"),                          # escrow
    ("dispute", "resolve"),                       # challenger/defender
]

# For each pair, extract validation sets V_in and V_out side-by-side:
for (f_in, f_out) in pairs:
    V_in  = { each require/revert/modifier/balance-delta check in f_in }
    V_out = { each require/revert/modifier/balance-delta check in f_out }
    diff_in_only  = V_in - V_out  # protection on ingress, absent on egress
    diff_out_only = V_out - V_in  # protection on egress, absent on ingress
    for check in (diff_in_only | diff_out_only):
        # Each asymmetry is a finding-candidate UNLESS one of these is true:
        # (a) one-sentence articulable design reason (e.g., "transferFrom pulls from
        #     attacker-controlled source while transfer pushes to user-controlled dest")
        # (b) different-layer guarantee (e.g., "registry enforces token validity at
        #     registration so egress trusts already-registered tokens") — verify by
        #     reading the guarantor code, not by assuming
        # (c) documented in a code comment or spec
        # If none of a/b/c hold, it is an oversight → apply Kill Gate
```

**Grep starter patterns** (tune to the codebase):

```bash
# bridges
grep -nE "function (transferToAgent|transferFromAgent|transferToken|transferEther|lock|unlock|registerToken|unregisterToken|processInbound|processOutbound|handleMessage|dispatchMessage|encodeMessage|decodeMessage)" src/

# vaults / ERC4626
grep -nE "function (deposit|withdraw|mint|redeem|convertToShares|convertToAssets)" src/

# escrow / dispute
grep -nE "function (fund|release|dispute|resolve|claim|refund|challenge|settle)" src/
```

**Mechanical gate for Phase 1 completeness:** if your audit notes contain "file X audited clean" without a companion line explicitly stating the mirror comparison result (e.g., `"transferToAgent V_in={balanceDelta, isContract, nonZero} vs transferToken V_out={∅} — ASYMMETRY, finding-candidate"`), the file is not clean and Phase 1 is not complete on that file. Force both halves to be written before moving on.

**Why:** 2026-04-19 Snowbridge audit session, notes recorded `Functions.sol (transferToAgent has FoT protection)` AND `AgentExecutor.sol audited clean` in the same pass. The bug was the absence of the ingress FoT guard on the egress side of the same codebase. V12 found it next day. Checkbox audit ("has FoT check ✓") without the mirror comparison is incomplete — absence-of-protection bugs are invisible to presence-scanning. Mirror audit is how humans achieve the same uniformity that LLM auditors have by default.

**Example (Snowbridge SNOW-002):**
```
Pair: transferToAgent (ingress) / transferToken (egress)
V_in:  { isContract, nonZeroAmount, balanceDeltaCheck, revertOnShortDelivery }
V_out: { safeTransferReturnCheck }
Diff V_in \ V_out: { balanceDeltaCheck, revertOnShortDelivery }
Articulable design reason? NO — same protocol, same 1:1 invariant, PR #1636 added V_in's balanceDeltaCheck explicitly, did not touch V_out.
→ ASYMMETRY → finding-candidate → Kill Gate → Proceed → SNOW-002 High
```

**MANDATORY FUND THEFT SCAN (run on EVERY SC target, 30 min):**

These patterns produced the only accepted findings on heavily-audited targets. Run before the check matrix.

| # | Pattern | Detection | Reference |
|---|---------|-----------|-----------|
| 1 | **Silent type truncation** | `grep -rn "as u8\|as u16\|as u32\|as u64" --include="*.rs"` -- for each cast, can source exceed target max? Especially in price * amount * 10^precision calculations. | GMTrade #31 ($200K, `as u32` on price) |
| 2 | **Cross-market payout mismatch** | Trace swap routing: which market gets credited? Trace payout: which market gets debited? If different entities, accounting is split. | GMTrade #45 ($200K, phantom LP credit) |
| 3 | **Partial state commitment** | Find hash commitment (stateHash). List all settlement math variables. Which are committed vs live-read? If denominator (totalSupply) is live but numerator (balances) is committed, TOCTOU. | Dexalot DXLTOVDD-336 (OFT bridge manipulation) |
| 4 | **Branch asymmetry in math** | Find if/else branches computing the same formula. Compare side by side. Missing multiplier in one branch = bug. | Zest ZESTPSC-11 (reserve factor missing in above-optimal branch, CRITICAL confirmed) |
| 5 | **assert!/panic! on peer data** | `grep -rn "assert!\|panic!" --include="*.rs"` -- if error message names external actor ("server sent", "peer returned"), it's a crash via peer input. | Monad #167, TRON-C01 |

**Decision rule for fork/port targets:** Can you write a PoC that steals funds using ONLY the code that EXISTS? If the PoC depends on what DOESN'T exist (missing feature), it's a feature request and will be rejected. Implementation bugs win. Design divergences lose.

**Adaptive gate:**

| Signal | Action |
|--------|--------|
| Check matrix finds 0 inconsistencies | Compress to 2 days, move to Phase 2 |
| Check matrix finds 1 inconsistency | Standard 3 days: confirm + PoC |
| Check matrix finds 2+ inconsistencies | **EXPAND to 7 days** — bugs cluster |
| Unaudited code is 100% clean | Pivot to post-audit git diff |

**Output:** Check matrix table, finding candidates with PoC tests

---

### Phase 2: Invariant Fuzzing + Static Analysis (2-5 days, ADAPTIVE)

**Goal:** Let machines find what eyes miss.

```
2.1  Identify core invariants from:
     - Protocol documentation / README
     - Code comments (search "invariant", "must", "always", "never")
     - Implied by function names (e.g., "monotonicallyIncreasing")
2.2  Write Foundry fuzz tests for each invariant
2.3  Run 10K-50K per invariant
2.4  Run Slither on all in-scope repos
2.5  Fixed-point / custom math library audit (if exists)
2.6  DEPENDENCY FUZZING (if Phase 0.7 identified high-value dep targets):
     a) Clone the dep repo at the EXACT version/commit the target uses
     b) Identify dep's core invariants (from dep's own tests, docs, or code comments)
     c) Write targeted Foundry/Echidna harnesses for the dep's functions the TARGET calls
        → Focus on: the integration surface, not the entire dep
        → Key pattern: fuzz the dep with inputs that the target would generate
        → See DEP FUZZING HARNESS GUIDE below for templates
     d) Run 50K-100K iterations per invariant (forge test --fuzz-runs 100000)
     e) If dep is a forked lib: fuzz the DIFF (modified functions only)
     f) If dep has its own fuzz suite: run it, then add target-specific harnesses
     g) Check dep's issue tracker for open security-relevant issues
        → GitHub issues mentioning "rate limit", "DoS", "overflow", "reentrancy"
        → These are confirmed attack surface the dep team acknowledges but hasn't fixed
     h) If Echidna: use assertion mode for complex invariants, property mode for simple ones
        → echidna . --contract DepFuzzHarness --test-mode assertion --test-limit 100000
```

**Universal invariants to ALWAYS test:**
```solidity
// Share accounting
testFuzz_mintRedeemNoProfit(amount)     // mint+redeem ≤ original
testFuzz_totalSupplyMonotonic(time)     // supply never decreases (fee tokens)
testFuzz_pokeIdempotent(times)          // repeated sync = same result

// Auction/pricing
testFuzz_priceMonotonicallyDecreasing(t1, t2)  // price never increases over time
testFuzz_priceNeverBelowEnd(params)             // price ≥ endPrice always

// Fee accounting
testFuzz_feeSharesBounded(supply, fee, time)    // fees < totalSupply
```

**Adaptive gate:**

| Signal | Action |
|--------|--------|
| Fuzzer finds FAILING invariant | **STOP EVERYTHING** — build PoC immediately (potential CRITICAL) |
| 50K runs all pass | Compress to 2 days |
| Slither finds unguarded reentrancy | Manual verification (often false positive with nonReentrant) |
| Custom math lib found | Extra 1-2 days for precision audit |

**Output:** Fuzz test results, Slither report, math audit notes

---

### Phase 3: Cross-Module State Machine (2-7 days, ADAPTIVE)

**Goal:** Find bugs that live BETWEEN contracts.

```
3.1  Trace complete lifecycles end-to-end:
     - Token: mint → transfer → trade → burn
     - Auction: create → bid → settle → distribute
     - Collateral: register → price → default → recollateralize
3.2  For each state transition: what if state changes mid-flight?
3.3  Collateral plugin analysis (if applicable):
     - Oracle manipulation vectors
     - underlyingRefPerTok monotonicity
     - Revenue hiding bypass
3.4  Mainnet fork tests against real deployed contracts
3.5  Attempt to CHAIN findings (A + B = higher severity)
```

**Cross-module patterns to check:**
- State change during external callback (reentrancy across contracts)
- Oracle failure during active trade/recollateralization
- Governance parameter change during active operation
- Token balance divergence between internal tracking and balanceOf

**Adaptive gate:**

| Signal | Action |
|--------|--------|
| Cross-module trace reveals state inconsistency | **EXPAND to 7 days** — build PoC |
| All state machines are clean | Compress to 2 days |
| Mainnet fork reveals deployed-vs-code divergence | **HIGH PRIORITY** investigation |
| Findings from Phase 1 CHAIN with Phase 3 findings | **ESCALATE severity** |

**Output:** State machine diagrams, fork test results, chain analysis

---

### Phase 4: Impact Quantification + Reporting (2-3 days, FIXED)

**Two mandatory gates in this phase, catching distinct failure modes:**

**(1) CHAIN PROOF GATE (D7) — auth-class findings only.** Before writing any report on a finding in the class auth-bypass / hardcoded-credential / signature-forge / JWT-token / session-hijack / IDOR-write / password-reset / account-binding, run `CHAIN-PROOF-GATE.md` Stage 1 hedge grep:

```bash
grep -nE "I did not test|I deliberately did not|inferred from|would access|would authenticate|would receive|deliberately not executed|not executed because|strongly indicates|architectural analysis suggests|documented .* protocol, not from testing|not confirmed whether|I stopped at|I did not attempt|the final link .* is inferred|not tested against|could not verify|assumed to be accepted" "$DRAFT_PATH"
```

If ≥1 match → complete Stage 2 (ethical variant test: forge with fictitious external_id, use our own account, use two controlled accounts, target a file we created, hit metadata-only endpoint) before proceeding to 4.4. If no ethical variant works → downgrade severity and remove hedges. **D7 in PREFLIGHT-CHECK.md is gating** — a failing chain proof blocks submission regardless of total score. See CLAUDE.md rule #36. Reference: WEEX-002 2026-04-13 (Medium/Informative → Critical after chain proof via fictitious external_id returned HTTP 200 + authenticated:true from Zendesk Smooch backend).

**(2) WEIGHT CARD GATE (D8) — all findings claiming severity ≥ Low with dollar impact.** Before writing any report on a finding claiming Critical / High / Medium / Low with dollar impact, populate the Weight Card in REPORT-STANDARD.md "Weight Accounting" section. The hard gate: at least one numerical anchor, either W1 (computed dollar loss with formula + inputs cited from on-chain reads, API counts, or documented limits; or DoS alternative with measured downtime × req/s × affected users) OR W5 (≥1 paid precedent with dollar figure from H1/C4/Cantina/Sherlock). Both W1 and W5 cannot be qualitative.

```bash
# Narrative weight indicator grep (catches the opposite of what D8 requires):
grep -nE "could drain|could extract|could potentially|significant funds|substantial losses|large number of users|many users|many accounts|estimated to|potentially affects|at risk|exposes users to|attacker could extract|could lead to|may result in|would enable loss of|all users|all deposits|all funds" "$DRAFT_PATH"
```

For each match, verify a specific number (dollar amount, user count, TVL percentage) appears in the same section. If the phrase stands alone without accompanying numerical data, populate W1 (run on-chain reads to compute) or W5 (run `~/arsenal/tools/precedent-scan.sh <class>` to get a copy-paste-ready block) OR downgrade severity to Informational. **D8 in PREFLIGHT-CHECK.md is gating** — a failing weight anchor blocks submission at the claimed severity regardless of total score or chain quality. See CLAUDE.md rule #37. Reference: Phemex R2 2026-04-10/13 (chain was proven, draft said "I have not confirmed whether this enables profitable extraction" → marked Informative, 2 rep, $0 — Weight Card would have caught this by forcing either computed W1 or paid W5 precedent before submission).


**Goal:** Maximize value of confirmed findings. Submit honestly.

```
4.1  For each finding: quantify $ impact with concrete numbers
4.2  Test ALL PoCs against mainnet fork
4.3  Check if findings chain (A+B > A+B individually)
4.4  Write report using REPORT-STANDARD.md (Transak voice):
     - Epistemic precision: separate confirmed facts from inferred consequences
     - Anti-pattern naming: name the architectural flaw, not just "missing X"
     - Chain factoring: prove each link independently
     - Baseline test: prove control IS enforced elsewhere (inconsistency, not design)
     - No CVSS in body — describe impact, let reviewer score
     - Enforcement matrix for auth consistency findings
     - Precedent table with H1 report IDs and bounty amounts
4.5  Severity: BE HONEST. Acknowledged Medium > dismissed High.
4.6  Submit strongest finding first (credibility bias)

4.7  **MECHANICAL PREFLIGHT (MANDATORY before submit, enforces CLAUDE.md rules #38 + #39):**
     ~/arsenal/audit-lifecycle/bin/preflight-mechanical.sh findings/{FINDING_ID}-draft.md {FINDING_ID}
     Runs D0-init / D0-finding / D0-commit / D8b TVL-readback / D10 compliance citation / hygiene.
     Exit 0 = PASS (submit authorized). Exit 1 = BLOCKED. LIFECYCLE_ENFORCE=hard for hard-block.

4.8  **ON SUBMIT — record OUTCOMES.jsonl with timestamps + tier commits:**
     ~/arsenal/audit-lifecycle/bin/on-submit.sh {FINDING_ID}

4.9  **ON HOLD — populate held_reason + uncertainty_source at the moment of hold:**
     ~/arsenal/audit-lifecycle/bin/on-hold.sh {FINDING_ID} <held_reason> [uncertainty_source]
     Valid held_reason: rep_gate | deposit_pending | geo_block | awaiting_validation |
                        gate_failed_unresolved | self_uncertainty | framing_unclear
     If self_uncertainty: uncertainty_source = technical_doubt | severity_doubt | scope_doubt
     WATCH: self_uncertainty + framing_unclear > 25% over 30d = gates over-regulating.
```

**Severity decision tree:**
```
Permissionless direct fund theft         → CRITICAL
Fund theft with specific preconditions   → HIGH
Access control bypass + value leakage    → HIGH (if $ quantifiable) / MEDIUM
Griefing / forced unfavorable trade      → MEDIUM
DoS on critical function                 → MEDIUM
Informational inconsistency             → LOW
```

**Output:** Submitted reports with PoCs

---

## HARD STOPS & PIVOTS

```
After Phase 0 (2h):   No unaudited code + saturated → SKIP target
After Phase 1 (5d):   0 findings + clean check matrix → evaluate: fuzz or skip
After Phase 1+2 (10d): 0 findings total → ONE MORE WEEK on Phase 3, then MOVE ON
After Phase 3 (15d):  0 findings → SUBMIT informational if any, MOVE ON
After Phase 4 (18d):  DONE. Submit everything, update memory, next target.
```

**NEVER spend >3 weeks on a single target with 0 findings.**
**ALWAYS submit what you have before moving on — even a Low builds reputation.**

---

## WEB TARGET PATH

When target is web/API (not smart contracts), apply gravedigger methodology BUT with these rules:

1. **Close the chain:** Never report "broken control" without initial access. Find the XSS/redirect FIRST.
2. **Auth session first:** Create test account, capture Bearer token BEFORE any API testing.
3. **Authorization consistency:** Map what requires re-auth vs standard token. The HIGH findings hide here.
4. **CSP is a multiplier, not a finding:** Missing script-src is out of scope on most programs, but amplifies other findings.
5. **8h rule:** If no initial access (XSS/redirect/CORS) after 8h → SKIP web, focus on SC.

---

## ANTI-PATTERNS

1. **Surface scanning with agent swarms** — 30 "criticals" that all die on verification. Use agents for architecture mapping ONLY, not bug finding.
2. **Reporting broken controls without exploitation** — "signature not enforced" + "requires XSS" = informative.
3. **Fuzzing without invariants** — random inputs with no assertions finds nothing.
4. **Ignoring code comments** — "known", "TODO", "not worth the gas" = already documented.
5. **Inflating severity** — $5K Medium sustained > $0 dismissed High.
6. **Skipping mainnet fork tests** — PoC on local ≠ PoC on production. Always fork-test.
7. **Not verifying the effective mitigation before submitting** — Cronos lesson: CircuitBreaker was "bypassed" at Vault level, but the `isLeverageEnabled` gate + atomic enable/disable in PositionRouter._increasePosition made it unexploitable. ALWAYS check if another control covers the same risk before claiming bypass. Trace the FULL execution path including Timelock/keeper patterns.
8. **Re-reading already-audited contracts** — Without PROGRESS.md, context compression causes duplicate work. Track every contract read with line count and verdict.
9. **Not checking upgrade history** — Proxy contracts may have been upgraded. Check `Upgraded(address)` events, compare old vs new bytecodes. Unverified current impls are audit gaps that must be documented even if analysis shows compiler recompilation.
10. **Spending days on dependency 0-days when deps are battle-tested** — Reserve lesson: OZ + Chainlink + Aave = top 3 most audited DeFi deps. Vendor files were direct copies. 0 findings after full dep audit. Run Phase 0.7 FAST: if deps are standard → SKIP in <30min. Only DEEP DIVE deps that are obscure, forked, or custom.
11. **Trusting agent-reported findings without manual verification** — Agents over-report 10:1 on well-audited code. On Reserve, agents flagged ~25 "critical" findings that were ALL false positives (intentional rounding, design choices, acknowledged issues). ALWAYS verify manually before investing time.
12. **Not checking CSP headers for RPC credentials** — The Content-Security-Policy connect-src directive is a goldmine for DeFi targets. GetBlock, QuikNode, and custom RPC proxy URLs with auth tokens are regularly leaked in CSP. Takes 30 seconds to check. Tothemoon finding came from CSP analysis alone.
13. **Submitting fork-feature-absence as vulnerability** — GMTrade lesson: pendingImpactAmount absent from GMX V2 Solana port, valid HIGH, rejected as "feature request." The program accepted 2 findings that demonstrated direct fund theft with PoCs. Rule: can you write a PoC that steals funds using ONLY the code that EXISTS? If the PoC depends on what DOESN'T exist, it's a feature request. Design divergences lose. Implementation bugs win.
14. **Not checking `as` type casts in Rust** — Rust `as` casts SILENTLY truncate. Unlike Solidity 0.8.x which reverts on overflow, Rust wraps without warning. `as u32` on a price calculation that can exceed 4.3B = silent price corruption = fund theft. GMTrade #31: one `as u32` accepted as HIGH, paid bounty. Scan every `as uN` cast in price/amount/fee calculations. This is the #1 Rust-specific fund theft pattern.

---

## PROGRESS.md — Context Persistence Protocol (MANDATORY)

**Problem:** Claude Code compresses context during long audits. Without a persistence file, the audit state (findings, contracts read, proxy map, API keys, next actions) is lost on compression.

**Solution:** Maintain a `PROGRESS.md` file in the workspace that acts as the complete audit state recovery document.

### Setup (Phase 0, immediately after workspace creation)

1. Create `{workspace}/PROGRESS.md` with these sections:
   - Target metadata (program, bounty, workspace path, plan file)
   - API keys and RPC endpoints (so they survive compression)
   - Confirmed findings (with status, root cause, evidence, severity)
   - Contracts audited table (contract, lines, finding/CLEAN)
   - Proxy map (proxy address → implementation address → verified?)
   - Audit gaps (unverified impls, missing source)
   - Completed actions per session
   - Next actions (priority-ordered)

2. Create `{workspace}/CLAUDE.md` with:
```markdown
## CRITICAL: Context Recovery Protocol
On EVERY new session or context compression:
1. Read `PROGRESS.md` FIRST — it contains the complete audit state.
2. Do NOT re-fetch contracts already marked as audited.
3. Continue from the NEXT ACTIONS section.

Before EVERY context compression or end of session:
1. Update `PROGRESS.md` with: new findings, contracts read, gaps discovered, updated next actions.
2. Move completed items out of NEXT ACTIONS.
```

### Update Rules

- **Update PROGRESS.md at the END of every session** — before saying "done" or switching tasks
- **Update after every finding** — immediately document: root cause, severity, evidence, status
- **Update after every contract read** — add to the audited table with line count and verdict
- **Update after every on-chain discovery** — proxy resolution, upgrade events, state reads
- **Update the timestamp** on every edit — `> Last updated: YYYY-MM-DD ~HH:MM UTC (session description)`

### What MUST be in PROGRESS.md

| Section | Purpose | Example |
|---------|---------|---------|
| API Keys | Survive context compression | `Etherscan: XXX`, `Explorer: YYY` |
| RPC Endpoints | Don't re-discover each session | `https://mainnet.zkevm.cronos.org (Chain 388)` |
| Findings | Complete state with severity + evidence | F-001: CB bypass, MEDIUM-HIGH → downgraded to LOW after atomic pattern found |
| Contracts Audited | Prevent re-reading | `Vault (1245 lines) — DIFF COMPLETED, broker fees CLEAN` |
| Proxy Map | Don't re-resolve | `Vault 0xdDDf... → impl 0xB7f4... (verified)` |
| Audit Gaps | Track what's still unknown | `vUSD upgraded to UNVERIFIED impl 0xe151...` |
| Completed per session | Audit trail | `Session 3: VaultUtils, FlpManager, ShortsTracker read` |
| Next Actions | Resume point | `1. Kill gate F-001. 2. Fetch FlpManager. 3. Run check-matrix.` |

### Battle-tested on Cronos zkEVM ($250K bounty)

- 7 sessions across 39 contracts, ~9,300 lines
- PROGRESS.md grew to ~200 lines tracking every contract, finding, proxy, and decision
- Survived multiple context compressions without losing state
- Prevented duplicate work (didn't re-fetch already-audited contracts)
- The `isLeverageEnabled` atomic pattern discovery (which downgraded F-001 from MEDIUM to LOW) was only possible because PROGRESS.md preserved the full context of the CircuitBreaker investigation across sessions

---

## WORKSPACE STRUCTURE

```
{target}-audit/                   # or {target}-recon/
├── CLAUDE.md                     # Context recovery instructions (read PROGRESS.md first)
├── PROGRESS.md                   # ** COMPLETE AUDIT STATE ** — the brain of the audit
├── RECON.md                      # Phase 0 triage results
├── CHECK-MATRIX.md               # Phase 1 check matrix table
├── {protocol}/                   # Source code per protocol
│   ├── CONTRACT-MAP.txt          # Proxy → implementation mapping
│   ├── {Contract}-impl/          # Extracted source files
│   └── ...
├── parents/                      # Parent protocol repos for fork-diff
│   ├── aave-v3/
│   ├── gmx-v1/
│   └── ...
├── pocs/                         # Foundry project for fork-based PoCs
│   ├── test/
│   │   ├── F001_Exploit.t.sol
│   │   └── ...
│   └── foundry.toml
├── evidence/
│   ├── fuzz-results/             # Phase 2 fuzz test outputs
│   └── fork-tests/               # Phase 3 mainnet fork results
├── findings/
│   ├── F-001.md                  # Finding report
│   ├── F-001-kill-gate.md        # Kill gate analysis
│   └── F-001.t.sol               # Finding PoC
└── submissions/
    └── hackenproof-F-001.md      # Platform-formatted submission
```

---

## MEMORY INTEGRATION

After EACH target:
1. Update `project_{target}.md` with final status
2. If methodology produced a new insight → save to `feedback_*.md`
3. If target type was new → update this skill file with lessons learned
4. Update `MEMORY.md` index
5. **Archive PROGRESS.md** — it contains the full audit trail. Reference it in the memory entry.

**During audit (every session):**
1. Read PROGRESS.md at session start
2. Update PROGRESS.md at session end
3. If finding confirmed → update both PROGRESS.md AND memory `project_{target}.md`
4. If finding killed → update PROGRESS.md with downgrade reason and effective mitigation

**This skill evolves.** Each audit teaches something. Update it.

---

## SECOND PASS METHODOLOGY (Post-Phase 3)

When first pass produces zero findings, do a pattern-based second pass ACROSS all contracts instead of contract-by-contract:

| Vulnerability Class | Grep Pattern | What to Check |
|---|---|---|
| Unchecked blocks | `unchecked` | Overflow/underflow in custom code (ignore OZ) |
| Unsafe casts | `int128\(\|int256\(\|uint256(int` | Sign/range before cast |
| Rounding direction | `/ ` (divisions) | Does rounding favor user or protocol? |
| Division by zero | `/ ` where denominator is variable | Zero-check before division? |
| Callback reentrancy | `onERC721Received\|\.call\{value` | nonReentrant on all state-modifying? |
| Unbounded loops | `for.*\.length` | Bounded by caller input or storage? |
| delegatecall | `delegatecall` | Self-only or external target? |
| First depositor | `totalSupply.*==.*0` | MINIMUM_LIQUIDITY or virtual shares? |
| Fee-on-transfer | `safeTransferFrom.*amount` then `+= amount` | Uses balance delta or amount param? |
| Cross-protocol oracle | Compare oracle sources across protocols | Same Chainlink feed? AMM-based? |

This second pass takes ~1-2 hours and catches patterns that line-by-line reading misses because they span multiple contracts.

### Web/API Second Pass (H1 Patterns)

When target includes web application / API surface (most DeFi protocols, HackerOne programs), apply `H1-HUNTING-PATTERNS.md` detection priority matrix:

| Priority | Pattern | Time | Ref |
|---|---|---|---|
| 0 | **RPC namespace probe (Rule 26 v2)** — find RPC URL, get free token, test txpool/debug/sendRawTransaction, sweep chains, mine CSP for credentials | 5 min | CLAUDE.md Rule 26 |
| 1 | API key leak scan (JS bundles, source maps, .env) | 5 min | P-H1-070 |
| 2 | GraphQL introspection + IDOR via node query | 10 min | P-H1-002, P-H1-071 |
| 3 | Auth flow analysis (MFA bypass, session timing, OAuth) | 15 min | P-H1-020 to P-H1-023 |
| 4 | SSRF surfaces (webhooks, PDF gen, imports, avatar URL) | 15 min | P-H1-010 to P-H1-013 |
| 5 | Authorization consistency matrix (all endpoints + auth) | 30 min | P-H1-023, M-H1-002 |
| 6 | IDOR on destructive operations (DELETE, PUT, PATCH) | 30 min | P-H1-003, M-H1-002 |
| 7 | Race condition on financial ops (payments, coupons) | 30 min | P-H1-030 to P-H1-032 |
| 8 | Business logic flow analysis (checkout, KYC) | 30 min | P-H1-060 to P-H1-062 |
| 9 | REST vs GraphQL/WebSocket auth inconsistency | 15 min | P-H1-072 |
| 10 | AI/LLM prompt injection (if AI features) | 30 min | P-H1-100, P-H1-101 |

**ROI guidance from H1-STATISTICS.md:** IDOR+auth bypass now outpay XSS 3:1. Focus on manual logic bugs over automated scanner patterns. Always chain for maximum payout (IDOR read=$1K vs IDOR->ATO chain=$5K-$12K).
