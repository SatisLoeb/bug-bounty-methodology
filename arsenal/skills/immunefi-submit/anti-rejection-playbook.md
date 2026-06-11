# Anti-Rejection Playbook — Systematic Research Methodology

This playbook details the exact searches and analysis to perform for the submission pipeline. Every search is designed to produce evidence that directly embeds into the report.

---

## Prerequisites — Environment Capabilities Check

**Run this check at the start of every `/immunefi-submit` invocation. Fail fast if missing.**

| Required Tool | Used In | Check |
|---------------|---------|-------|
| WebSearch | Phase 0.5, 3b, 3c, 3d | Agent has web search access |
| `gh` CLI | Phase 0.3, 3d | `gh auth status` succeeds |
| `cast` | Phase 0.1, 0.4 | `which cast` returns path |
| Grep/Glob | Phase 0.3, 3a | Always available in Claude Code |
| `git` | Phase 0.8 | Target repo is cloned locally |
| `forge` | PoC validation | `which forge` returns path (Solidity targets only) |

```
IF missing(WebSearch): WARN "Phases 0.5, 3b, 3c, 3d will be skipped — no precedent/dependency research"
IF missing(gh):        WARN "Phase 3d degraded — no GitHub issue/PR search for duplicates"
IF missing(cast):      WARN "Phase 0.1, 0.4 skipped — no on-chain vault/proxy verification"
IF missing(git):       FATAL "Phase 0.8 impossible — cannot date vulnerable code"
```

Degraded mode is acceptable (skip unavailable phases, note gaps in output). Missing `git` is fatal — code dating is non-negotiable for the post-audit differentiation argument.

---

## EV Gate — Quantitative Go/No-Go (run before any report writing)

**Every finding must pass this calculation before investing time in report writing.**

```
EV = P(acceptance) × min(payout_tier, vault_balance) - time_cost

P(acceptance) = base_rate × (1 - known_issue_risk) × (1 - scope_risk) × (1 - design_intent_risk)
time_cost = estimated_hours × hourly_opportunity_cost
```

**Input variables:**

- `base_rate`: Start at 0.50 for first submissions. After 15+ entries in OUTCOMES.jsonl, calibrate per program/severity/vuln_class: `grep "protocol" OUTCOMES.jsonl | jq 'select(.outcome=="accepted")' | wc -l` / total
- `known_issue_risk`: 0.0 (no overlap) → 0.9 (exact match in audit/known issues)
- `scope_risk`: 0.0 (asset explicitly listed) → 0.9 (Primacy of Impact argument needed)
- `design_intent_risk`: 0.0 (clear bug) → 0.8 (coherent design justification exists). **NEW after Ethena rejection.**
- `payout_tier`: From program page — Critical/High/Medium/Low ranges
- `vault_balance`: On-chain verified (Phase 0.1)
- `estimated_hours`: Realistic total (use OUTCOMES.jsonl averages after 5+ entries)
- `hourly_opportunity_cost`: $100 default (adjust based on pipeline depth)

**Decision thresholds:**

```
EV > $5,000  → STRONG GO — prioritize
EV $1K-$5K  → GO — submit in normal queue order
EV $200-$1K → WEAK GO — only if pipeline is empty
EV < $200   → SKIP — time better spent on next target
```

**Confidence flag (required):**

```
high   (>70% acceptance) → submit immediately
medium (40-70%)          → 24h cool-off, re-evaluate with fresh eyes before submitting
low    (<40%)            → needs second pass or differentiation angle before submitting
```

**Log the EV calculation in OUTCOMES.jsonl `ev_pre_submit` field for every submission.**
After 15+ entries, recalibrate base_rate and time estimates from actuals.

---

## Phase 0: Program-Level Kill Scan (NEW — Feb 2026)

**Goal:** Identify fatal rejection vectors BEFORE investing time in report writing. This phase was added after a swarm audit of all 12 target programs revealed that 5/12 submissions had >80% rejection probability due to program-level issues that could have been caught upfront.

### 0.1 Vault Balance Verification

```bash
# Check on-chain vault balance (don't trust Immunefi's cached display)
cast balance <vault_address> --rpc-url <chain_rpc>
# For ERC20 vaults:
cast call <token> "balanceOf(address)(uint256)" <vault_address> --rpc-url <chain_rpc>
```

| Balance | Action |
|---------|--------|
| $0 | **FATAL.** Do not submit. Program is functionally dormant. (Beanstalk: $0 vault, 3 submissions wasted.) |
| < $5K | **WARNING.** Payment risk even for valid findings. Flag to user. (StackingDAO: $2,800 vault.) |
| < expected payout | **WARNING.** Program may delay payment pending governance/funding. |
| >= expected payout | **PASS.** Proceed. |

### 0.2 Surgical Exclusion Scan

**Read the Out-of-Scope section WORD BY WORD.** Programs add targeted exclusions.

Common kill patterns found in Feb 2026 audit:

| Pattern | Example | Programs Using It |
|---------|---------|-------------------|
| Frontrunning exclusion | "Impacts that involve frontrunning transactions through the public mempool" | Beanstalk, many others |
| Pipeline/sandbox misuse | "Unexpected outcomes due to misuse of Pipeline and/or Depot" | Beanstalk |
| External stablecoin failure | "Impacts relying on depegging of an external stablecoin where attacker doesn't cause it" | Immunefi general (most programs) |
| File-level exclusion | "`LiquidityBridgeContract.sol` is excluded" | Rootstock |
| Privileged address attacks | "Impacts from privileged address attacks" | Most programs |
| DoS/availability | "DoS attacks against project assets" | Firedancer, others |
| Known audit findings | "All unfixed vulnerabilities from completed audits are ineligible" | CapyFi, most programs |

```
FOR EACH exclusion found:
1. Does my finding match this exclusion's language?
2. Can I reframe my finding to AVOID the exclusion?
3. If not → FATAL for this submission
```

### 0.3 Known Issues Deep Comparison

**Don't just read titles.** Read the full description of each known issue and compare against your finding on 4 axes:

| Axis | If Same | If Different |
|------|---------|-------------|
| Root cause | Likely duplicate → abort | Proceed, build differentiation |
| Trigger mechanism | Likely duplicate → abort | Proceed, emphasize different trigger |
| Affected function/code path | Risk of conflation → build table | Safe |
| Impact type | Risk of conflation → build table | Safe |

**Also check external known issues sources:**
- Google Sheets (CapyFi: `1_vAogDWyY3x1bp6NO7NccKWoNACbPybR0OX39fA0LIM`)
- "False Positive Reports" documents (Rootstock: updated Feb 11, 2026)
- Community bug report pages (Beanstalk: `community.bean.money/bug-reports`)
- CodeHawks competition results for the protocol

### 0.4 Contract Upgradeability Check

If your finding's trigger involves "contract upgrade breaks X":

```bash
# Check EIP-1967 implementation slot
cast storage <contract> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <rpc>
# Check EIP-1967 admin slot
cast storage <contract> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url <rpc>
# Check EIP-1822 (UUPS)
cast storage <contract> 0xc5f16f0fcc639fa48a6947836d9850f504798523bf8c9a3a87d5876cf622bcf7 --rpc-url <rpc>
```

| Result | Meaning |
|--------|---------|
| All slots = 0x0 | **NOT a proxy.** Upgrade-based triggers are IMPOSSIBLE. Rewrite trigger scenario or abort. |
| Implementation slot has address | Proxy. Verify upgrade history on Etherscan. |

**Learned from:** Ethena StakedUSDeV2 (`0x9d39a5de30e57443bff2a8307a4256c8797a3497`) — all EIP-1967 slots are zero. NOT a proxy. The OFT adapter finding's primary trigger (proxy upgrade breaks hasRole) was invalid.

### 0.5 Auditor-Vulnerability Cross-Reference

If the protocol was audited by a firm that has PUBLISHED RESEARCH on your exact vulnerability class:

```
IF auditor_published_blog_about(vulnerability_class) AND auditor_audited(protocol):
    → 90%+ probability they caught it during audit
    → Check audit report carefully, likely a known issue
```

**Example:** CoinFabrik audited StackingDAO AND published "Tx-Sender in Clarity may lead to Vulnerabilities" — the exact `contract-caller` pattern. Almost certainly caught during audit.

### 0.6 Industry-Known Vulnerability Check

Some vulnerability classes are so well-documented they're almost always known issues:

| Vulnerability | First Documented | Known % | Exception Condition (proceed if true) |
|--------------|------------------|---------|--------------------------------------|
| `.transfer()` 2300 gas limit | 2019 (ConsenSys) | 99% | Code written post-audit AND uses non-standard pattern (e.g., assembly call instead of .transfer) |
| First-depositor attack (ERC4626) | 2022 | 95% | Custom vault (not OZ ERC4626), OR post-audit code with no virtual shares mitigation |
| Reentrancy on ERC777 callbacks | 2020 | 95% | Novel cross-contract path not in standard reentrancy taxonomy |
| Oracle manipulation via flash loans | 2020 | 90% | New oracle integration post-audit, OR non-Chainlink/TWAP source |
| Approval front-running (ERC20) | 2018 | 99% | Almost never — only if combined with a novel secondary impact |
| Convex/Aura extra reward DoS | 2022 (C4 Concur) | 80% | Vendored wrapper (not original Convex code), OR post-audit wrapper with no try/catch added |
| Stale oracle / sequencer downtime | 2023 (L2 expansion) | 85% | L2-specific path not covered in L1-only audit |
| Signature replay (EIP-712) | 2019 | 90% | Missing chainId or nonce in non-standard signing scheme |

**Usage:** If Known% >= 90% AND Exception Condition is FALSE → near-certain rejection. Abort or find a differentiation angle.
If Known% >= 90% AND Exception Condition is TRUE → proceed with strong differentiation section in report.

If your finding is an industry-known class → CHECK EVERY AUDIT REPORT AND KNOWN ISSUES LIST before proceeding.

### 0.7 Design Intent Test (NEW — Ethena rejection, Feb 16 2026)

**If your finding is a "missing check" or "incomplete restriction", run this test BEFORE proceeding.**

Ask: *"If this behavior was intentional, what would be the protocol's design rationale?"*

```
1. Construct the strongest possible DEFENSE of the current behavior
2. If a coherent design justification exists in <30 seconds → HIGH rejection risk
3. Check if the finding crosses a TOKEN LAYER BOUNDARY (wrapper → underlying)
```

**Token Layer Boundary Rule:**
When a protocol wraps a permissionless token (USDe, ETH, MATIC) with a restricted derivative (sUSDe, stETH, MaticX), access controls on the wrapper typically do NOT extend to the underlying after conversion. This is a design pattern, not a bug.

```
IF finding = "restricted user can still access underlying token after unwrapping/cooldown":
    → Protocol likely considers this INTENTIONAL
    → Underlying token is permissionless BY DESIGN
    → Restriction applies to derivative only
    → ABORT unless you have evidence the protocol explicitly claims otherwise
```

**Key signals that behavior IS intentional (abort indicators):**
- The underlying token has no blacklist/restriction mechanism of its own
- The protocol documentation only mentions restrictions on the derivative token
- The "missing check" is on a function that converts derivative → underlying
- Every other function WITH the check operates on the derivative token layer

**Key signals that behavior is NOT intentional (proceed indicators):**
- Protocol documentation explicitly claims "restricted users cannot access funds in ANY form"
- The underlying token ALSO has restriction mechanisms but they're not called
- The function is clearly a DIFFERENT code path doing the same logical operation as checked functions
- There's a recovery mechanism (like `redistributeLockedAmount`) that's rendered useless by the gap

**Learned from:** Ethena blacklist bypass via `unstake()` — rejected in 16 minutes. Ethena: "Blacklisting only applies to sUSDe. Once cooldown initiated, USDe is permissionless." We built a perfect 4-test fork PoC proving the gap, but the gap was intentional design. $0 payout.

### 0.8 Code Path Reachability Verification (NEW — Firedancer rejection, Feb 17 2026)

**If the target has multiple build variants, binaries, or topology configurations, you MUST verify your vulnerable code path is reachable in the IN-SCOPE binary.**

```
1. Identify which binary/build is in scope (e.g., "Frankendancer" not "Full Firedancer")
2. Find the topology/configuration file for that binary
3. Trace: entry point → message handler → vulnerable function
4. Confirm the link/input that feeds the vulnerable handler EXISTS in the in-scope topology
5. If the code path is ONLY in an out-of-scope build → FATAL
```

**Checklist:**
- [ ] Which binary is in scope? (read program page carefully)
- [ ] Does the in-scope binary's topology wire the input that reaches the vulnerable function?
- [ ] Are there multiple API paths to the same functionality? (e.g., bulk broadcast vs incremental update)
- [ ] Which API does the in-scope binary use?

**Learned from:** Firedancer FDR-001 rejection (2026-02-17). `ci_dest_add_one_unstaked` only reachable via `IN_KIND_GOSSIP` (Full Firedancer, out of scope). Frankendancer uses `IN_KIND_CONTACT` via a completely different API (`dest_add_init/dest_add_fini`) that never calls the vulnerable function. Bug was real but unreachable in the in-scope binary. $0 payout, 23-minute turnaround.

**Red flags that signal multi-binary scope risk:**
- Program says "latest [specific variant] release build" (not "the whole repo")
- Program has explicit "Full [X] is out of scope" language
- Codebase has multiple `topology.c` files or build configurations
- Functions have comments like "only used in [variant]" or conditional compilation

### 0.9 Post-Audit Code Dating (git blame)

```bash
# Check if vulnerable code was written AFTER the last audit
git log --follow -p -- <vulnerable-file> | head -100
git blame <vulnerable-file> | grep -n "<vulnerable-line-content>"
```

| Code Date vs Audit Date | Implication |
|------------------------|-------------|
| Code AFTER audit | Cannot be "known from audit" — strong argument |
| Code BEFORE audit | Audit may have seen it — check report carefully |
| Code existed DURING audit competition | If not flagged, either missed or intentional |

---

## Phase 3a: Internal Consistency Scan

**Goal:** Prove the protocol already knows about this risk class and protects against it elsewhere.

### Search Queries (adapt to target)

```bash
# 1. Find all try/catch patterns in the same directory tree
Grep: pattern="try " path="<vulnerable-file-parent-directory>"

# 2. Find defensive comments
Grep: pattern="(brick|DOS|revert|external|defensive|prevent|protect)" path="<vulnerable-file-parent-directory>"

# 3. Find other contracts handling the same external call pattern
Grep: pattern="<external-function-name>" path="<plugins-or-contracts-directory>"

# 4. Count total defensive instances
Grep: pattern="try " path="<contracts-directory>" output_mode="count"
```

### What to Extract

1. **Exact code snippet** of the protocol's own defensive pattern (with file path and line number)
2. **Exact comment** if they explain WHY they added the protection (gold — quote verbatim)
3. **Count** of defensive instances across the codebase (e.g., "82+ try/catch instances")
4. **List of contracts** that use the defensive pattern vs. those that don't

### How to Write It

```markdown
#### Why this is [Protocol]'s responsibility

This is not a [ExternalProtocol] bug — it is [Protocol]'s decision to vendor/use this
[contract/library] **without adding the same defensive protections they use elsewhere**.
[Protocol]'s own `[DefensiveContract]` explicitly documents this exact risk:

\`\`\`solidity
// [DefensiveContract].sol, line [N]
// [exact comment from their code]
try [externalCall]() {} catch {}
\`\`\`

The comment literally says **"[quoted text]"** — this is the exact same risk that exists
in `[VulnerableContract]` but was not mitigated. The [Protocol] codebase contains
**[N]+ try/catch instances** across [directory]. [VulnerableContract] is a notable
exception that lacks this protection despite having [higher/equal] risk.
```

### Skip Conditions

- If the protocol has NO defensive patterns for this call type → skip section, but note in the Rejection Vector Matrix that "Won't fix / design choice" is a risk
- If the vulnerable code IS the only instance of this pattern → focus on industry standards instead

---

## Phase 3b: Precedent Audit Research

**Goal:** Build a table of 3+ audit findings validating the same vulnerability class.

### Search Strategy (ordered by reliability)

```
# Round 1: Exact pattern match
WebSearch: "[vulnerability pattern] Code4rena finding"
WebSearch: "[vulnerability pattern] Sherlock audit"
WebSearch: "[external protocol] reward revert DOS audit"

# Round 2: Protocol-specific
WebSearch: "[external protocol name] getReward revert blocks"
WebSearch: "[external protocol name] extra reward token DOS"

# Round 3: Generic pattern
WebSearch: "[call pattern] blocks withdrawals smart contract audit"
WebSearch: "pausable token blocks [operation] audit finding"
WebSearch: "external call revert DOS [protocol type] audit"

# Round 4: Platform-specific search
WebSearch: site:github.com/code-423n4 "[vulnerability keyword]"
WebSearch: site:github.com/sherlock-audit "[vulnerability keyword]"
WebSearch: site:github.com/hats-finance "[vulnerability keyword]"
```

### What to Extract Per Finding

1. **Protocol name** and year
2. **Platform** (Code4rena, Sherlock, Hats, Immunefi)
3. **Severity** assigned by judges
4. **Issue URL** (GitHub link)
5. **1-line summary** of the finding
6. **Judge quote** if available (especially Sherlock where judges write reasoning)

### How to Write It

```markdown
#### Real-world precedent

This is not a theoretical risk. The exact pattern ([description]) has been confirmed
as a valid finding across **[N] separate audits on [M] protocols**:

| Protocol | Year | Platform | Severity | Issue |
|----------|------|----------|----------|-------|
| [Name] | [Year] | [Platform] | [Sev] | [1-line summary] |
| ... | ... | ... | ... | ... |

The [Platform] judging for [Protocol] explicitly confirmed: *"[judge quote]"*.
```

### Minimum Thresholds

- **3+ precedents** → Strong argument ("industry-recognized vulnerability class")
- **1-2 precedents** → Acceptable (include but don't oversell)
- **0 precedents** → The finding may be novel. Don't include a precedent section — instead emphasize the technical argument. Novel ≠ invalid.

---

## Phase 3c: External Dependency Defense

**Goal:** Prove the external condition is realistic, not theoretical.

### Research Checklist

For EACH external dependency in the attack path:

```
[ ] Does the external token/contract have a pause function?
    → Search: "[token name] pause function" OR read the contract's source
[ ] Has the pause function ever been used?
    → Search: "[token name] paused frozen" + year
[ ] Does the external token/contract have a blacklist?
    → Search: "[token name] blacklist freeze addresses"
[ ] Is the external token/contract upgradeable?
    → Search: "[token name] proxy upgradeable"
[ ] Can third-party governance modify the dependency?
    → Search: "[protocol] add reward token governance" OR "[protocol] rewardManager"
[ ] Has the external protocol had any incidents?
    → Search: "[protocol name] incident exploit emergency"
[ ] Is the dependency permissionlessly configurable?
    → Search: "[protocol] permissionless reward" OR "[protocol] add_reward"
```

### Concrete Evidence to Collect

| Scenario Type | What to Find | Example Evidence |
|---------------|-------------|------------------|
| Token pause | Contract has `whenNotPaused` | "USDT has `whenNotPaused` on `transfer()`" |
| Blacklist activity | Number of addresses frozen + total value | "Tether froze $3.3B across 7,268 addresses (2023-2025)" |
| Governance action | Who can add/remove the dependency | "Convex `rewardManager` can call `addExtraReward()`" |
| Permissionless config | Anyone can trigger the condition | "Since Oct 2022, Curve factory gauge admins can `add_reward()`" |
| Historical incident | Past failures of the exact dependency | "[Protocol] had [incident] on [date]" |
| Emergency shutdown | Protocol has emergency halt mechanism | "MakerDAO emergency shutdown halts DAI transfers" |

### How to Write It

```markdown
#### Concrete failure scenarios

Extra reward tokens on [ExternalProtocol] pools include [TOKEN1], [TOKEN2], [TOKEN3],
and others added by [governance role]. Failure scenarios:

1. **[Token] global pause** — [Token]'s contract has a `whenNotPaused` modifier on
   `transfer()`. If activated, ALL transfers revert. [Evidence with numbers].
2. **[Token] blacklist** — [Issuer] blacklists specific addresses. If the wrapper's
   address is blacklisted, `safeTransfer()` reverts.
3. **Token upgrade bug** — [Token] is an upgradeable proxy. A buggy upgrade could
   break `transfer()`.
4. **Governance token migration** — [Token] may migrate to new contracts, breaking
   the old token's `transfer()`.
5. **Permissionless reward addition** — Since [date], [anyone/admins] can call
   `[function]()` to add arbitrary reward tokens.
```

### Skip Conditions

- If the finding does NOT depend on external conditions → skip entirely
- If the external condition requires a global catastrophe (e.g., "Ethereum halts") → don't include, it weakens the argument

---

## Phase 3d: Prior Audit Differentiation

**Goal:** Make it impossible for the reviewer to confuse your finding with a known issue.

### Search Strategy

```bash
# 1. Find all prior audits of the target
WebSearch: "[protocol name] audit Code4rena"
WebSearch: "[protocol name] audit Sherlock"
WebSearch: "[protocol name] security audit report"

# 2. Search for findings on the same contract
WebSearch: "[contract name] [protocol name] finding"
WebSearch: "[contract name] vulnerability audit"

# 3. Search the repo directly
gh issue list -R [repo] --search "[contract name]"
gh pr list -R [repo] --search "[contract name]"
```

### Differentiation Table Template

For EACH potentially confusable finding:

```markdown
#### Distinction from [Prior Finding ID]

This is a **completely different finding** from [Platform] [ID] ([Year]):

| Aspect | [Prior Finding] | This Finding |
|--------|----------------|--------------|
| **Trigger** | [what triggers it] | [what triggers this] |
| **Impact** | [what happens] | [what happens here] |
| **Root cause** | [missing check/logic] | [different missing check] |
| **Attack vector** | [who/what triggers] | [who/what triggers this] |
| **Affected operations** | [which functions] | [which functions here] |
| **Recovery** | [can governance fix?] | [can governance fix this?] |
```

### Rules

- EVERY row must be different. If 2+ rows are identical, your finding may actually be a duplicate.
- If you can't fill the table with meaningful differences → reconsider whether this is truly a new finding.
- Be honest — if there IS overlap, acknowledge it and explain the delta.

---

## Phase 3e: Rejection Vector Matrix (Internal Tool)

**Goal:** Pre-build counter-arguments for every plausible rejection.

### Template

```
| # | Rejection Vector | Their Argument | Your Counter | Evidence |
|---|-----------------|----------------|--------------|----------|
| 1 | Out of scope | "This is in vendor/" | "Path is plugins/assets/.../vendor/, not contracts/vendor/" | Directory listing |
| 2 | Known issue | "Same as C4 H-03" | "Different trigger, impact, root cause" | Differentiation table |
| 3 | External condition | "Requires token pause" | "USDT pause exists, $3.3B frozen" | On-chain data |
| 4 | Design choice | "We chose not to use try/catch" | "You use it in StargateWrapper for the same reason" | Code quote |
| 5 | Low severity | "Only affects rewards" | "Affects ALL transfers — permanent fund freeze" | PoC test results |
| 6 | Won't fix | "Low probability" | "8 audit findings confirm this class" | Precedent table |
```

### Usage

- This matrix is NOT pasted into the report
- It guides WHICH arguments to embed in each section
- Every row with a filled "Evidence" column becomes a paragraph in the report
- Empty "Evidence" cells → weak argument, consider dropping or flagging as a risk

---

## Execution Order

When running `/immunefi-submit`, execute in this order:

1. **Scope validation** (Step 1) — 1 minute
2. **Duplicate check** (Step 2) — 2 minutes
3. **Anti-rejection research** (Step 3) — 10-15 minutes (launch sub-agents in parallel):
   - 3a: Internal consistency scan (Explore agent)
   - 3b: Precedent audit research (WebSearch agent)
   - 3c: External dependency defense (WebSearch agent)
   - 3d: Prior audit differentiation (WebSearch + GitHub CLI agent)
4. **Build rejection vector matrix** (Step 3e) — 2 minutes (synthesize results)
5. **Severity classification** (Step 4) — 1 minute
6. **Write report** (embedding anti-rejection arguments) — 5 minutes
7. **Output** — formatted blocks ready to paste

Total: ~20-25 minutes per submission (vs. ~5 minutes without anti-rejection = 4x more effort, 2x+ higher acceptance rate).

---

## Phase 4: Pre-Submission Quality Gate — Grading Rubric (22 points)

**Every submission MUST score 20/22+ before pasting on Immunefi. Score below 20 = fix before submitting.**

Run this checklist AFTER the report is written, BEFORE submission.

### A. PoC Quality (7 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| A1 | Fork-based, zero mocks | Uses `vm.createSelectFork()`, calls real deployed contract | Uses mocks, local deployments, or simulations |
| A2 | All tests pass (N/N) | `forge test` shows 0 failed | Any test fails or is skipped |
| A3 | Strongest attack variant demonstrated | Most devastating variant leads (e.g., universal forgery > single forgery, on-the-fly > precomputed) | Only shows weakest variant, or redundant tests that dilute impact |
| A4 | Baselines prove contract works normally | At least 1 baseline test shows normal operation succeeds | No baseline — reviewer can't tell if contract is just broken for everything |
| A5 | Impact tests show realistic scenario | Tests demonstrate real-world trigger (e.g., legitimate user action, documented format) | Only abstract/synthetic triggers |
| A6 | Test code in submission md matches actual .t.sol | Embedded code is identical to tested code | Stale code, missing tests, or desync between md and .t.sol |
| A7 | Expected Output is reviewer-proof | Test names and PASS/FAIL status shown, gas values omitted or marked `(gas varies)` | Exact gas values that will differ on reviewer's machine → unnecessary friction |

### B. Report Argumentation (7 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| B1 | Brief/Intro is assertive, not defensive | Leads with "is broken / is exploitable / does not X" | Leads with "could potentially" or hedging language |
| B2 | Root cause cites exact code (file + line) | `RSASHA256Algorithm.sol line 41` with code block | Vague reference to "the verify function" |
| B3 | Verbatim citations from source | Contract comments, documentation, specs quoted character-for-character | Paraphrased or approximate citations that can be contested |
| B4 | "Not domain/user's fault" argument (when applicable) | Proves the trigger is the contract's own documented behavior or external factor outside user control | Missing — leaves door open for "user misconfiguration" dismissal |
| B5 | Prior audit differentiation | Explicit comparison table/list showing THIS finding != any prior finding | No mention of prior audits, or dismissive "not found in prior audits" without evidence |
| B6 | Real-world precedents with verified links | 2-3 accepted C4/Sherlock/Immunefi findings in the same vulnerability class, links manually verified live | Fabricated links, dead links, or findings that don't match the description |
| B7 | Mitigating factors disclosed honestly | Acknowledges limitations (e.g., "no current TLD uses e=3") without undermining the finding | Hides mitigating factors (reviewer finds them → trust destroyed) OR over-hedges (kills severity) |

### C. Submission Hygiene (4 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| C1 | No markdown tables (Immunefi rendering) | All structured data uses bullet lists or code blocks | Tables that render broken on Immunefi |
| C2 | Recommended fix is complete and correct | Fix addresses root cause, shows exact code, is compilable | No fix, or fix that introduces new bugs, or "add a check" without code |
| C3 | Impact section matches Immunefi severity criteria | Uses exact Immunefi language ("Smart contract unable to operate", "Direct theft of user funds") | Generic impact description that doesn't map to a severity tier |
| C4 | Setup instructions are copy-paste-run | `mkdir && forge init && forge test` works from zero on a clean machine | Requires unstated dependencies, env vars, or manual steps |

### D. Strategic Positioning (4 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| D1 | Strongest argument leads | Most devastating variant / most irrefutable evidence is in the first paragraph, not buried | Buries the killshot in section 5 |
| D2 | Rejection vector matrix completed internally | Every plausible rejection has a pre-built counter-argument with evidence | Submitted without considering how it could be rejected |
| D3 | EV gate passed | EV > $1K, confidence flag assigned, calculation logged in OUTCOMES.jsonl | No EV calculation, or EV < $1K without explicit override justification |
| D4 | Code path reachability verified in in-scope binary | Traced entry point → handler → vulnerable function in the SPECIFIC in-scope build/binary. Topology/config confirms the link exists. | Assumed code in repo = reachable in production. Did not check build variant topology. |

### Scoring

```
22/22 — Submit immediately
20-21 — Submit after fixing flagged items (minor issues)
17-19 — Significant gaps. Fix ALL failing criteria before submitting.
<17   — Report needs major rework. Do not submit.
```

### Calibration Log

Track scores vs outcomes to calibrate which criteria actually predict acceptance:

```
| Date | Finding | Pre-Score | Outcome | Notes |
|------|---------|-----------|---------|-------|
| (fill after each submission result) |
```

After 10+ entries: drop criteria that don't correlate with acceptance, add new criteria from rejection patterns. Target: every criterion in the rubric should have >0.3 correlation with acceptance/rejection.
