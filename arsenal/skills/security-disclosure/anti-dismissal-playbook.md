# Anti-Dismissal Playbook — Systematic Research Methodology

This playbook details the exact searches and analysis to perform for the disclosure pipeline. Every search is designed to produce evidence that directly embeds into the report.

---

## Prerequisites — Environment Capabilities Check

**Run this check at the start of every `/disclose` invocation. Fail fast if missing.**

| Required Tool | Used In | Check |
|---------------|---------|-------|
| WebSearch | Phase 0.3, 3b, 3c, 3d | Agent has web search access |
| `gh` CLI | Phase 0.3, 3d | `gh auth status` succeeds |
| `cast` | Phase 0.4 | `which cast` returns path |
| Grep/Glob | Phase 0.3, 3a | Always available in Claude Code |
| `git` | Phase 0.8 | Target repo is cloned locally |
| `forge` | PoC validation | `which forge` returns path (Solidity targets only) |

```
IF missing(WebSearch): WARN "Phases 0.3, 3b, 3c, 3d will be skipped — no precedent/dependency research"
IF missing(gh):        WARN "Phase 3d degraded — no GitHub issue/PR search for duplicates"
IF missing(cast):      WARN "Phase 0.4 skipped — no on-chain proxy verification"
IF missing(git):       FATAL "Phase 0.8 impossible — cannot date vulnerable code"
```

Degraded mode is acceptable (skip unavailable phases, note gaps in output). Missing `git` is fatal — code dating is non-negotiable for the post-audit differentiation argument.

---

## EV Gate — Quantitative Go/No-Go (run before any report writing)

**Every finding must pass this calculation before investing time in report writing.**

```
EV = P(bounty) * estimated_bounty + reputation_value - time_cost

P(bounty) adjusted by:
- Protocol has bounty program on any platform: base 0.50
- Protocol has no bounty program: base 0.30
- Protocol ignores prior disclosures: base 0.10

reputation_value = intangible but real:
- CVE credit: +$500 equivalent
- Public acknowledgment: +$300 equivalent
- Reference for future bounties: +$200 equivalent
- Conference talk material: +$1000 equivalent (if novel class)
```

**Input variables:**

- `P(bounty)`: Start with base rates above. After 15+ entries in OUTCOMES.jsonl, calibrate per protocol/severity: `grep "protocol" OUTCOMES.jsonl | jq 'select(.outcome=="bounty_paid")' | wc -l` / total
- `estimated_bounty`: From bounty program (if exists), or estimate: Critical = 5-10% of TVL (capped at $500K), High = $10K-$100K, Medium = $2K-$20K
- `reputation_value`: Sum applicable items from list above
- `time_cost`: estimated_hours * $100/hr (adjust based on pipeline depth)

**Decision thresholds:**

```
EV > $5,000  → STRONG GO — prioritize
EV $1K-$5K  → GO — submit in normal queue order
EV $200-$1K → WEAK GO — only if pipeline is empty
EV < $200   → SKIP — unless reputation value or novel class justifies
```

**Confidence flag (required):**

```
high   (>70% acceptance) → disclose immediately
medium (40-70%)          → 24h cool-off, re-evaluate with fresh eyes
low    (<40%)            → needs second pass or novel angle
```

**Log the EV calculation in OUTCOMES.jsonl `ev_pre_submit` field for every disclosure.**
After 15+ entries, recalibrate base_rate and time estimates from actuals.

---

## Phase 0: Target-Level Assessment (run before any report writing)

**Goal:** Identify fatal dismissal vectors BEFORE investing time in report writing.

### 0.1 TVL & Impact Verification

```bash
# Check protocol TVL
# DeFiLlama: https://api.llama.fi/tvl/<protocol-slug>
# Or visit https://defillama.com/protocol/<slug>

# For smart contracts, check deployment activity
cast code <contract_address> --rpc-url <chain_rpc>
```

| TVL | Action |
|-----|--------|
| $0 / No activity | **WARNING.** Protocol may be abandoned. Disclose only if reputation value justifies. |
| < $100K | **WARNING.** Low impact, low reward probability. Consider skipping. |
| $100K - $1M | **PASS.** Moderate impact. Proceed. |
| > $1M | **STRONG PASS.** High impact. Prioritize. |

### 0.2 Contact Discovery

**Follow the priority order in `contact-research-checklist.md`.** Record:

| Field | Value |
|-------|-------|
| Primary contact | [method + detail] |
| PGP available | [Yes/No + fingerprint] |
| Backup contact | [method + detail] |
| Expected response time | [based on history] |

### 0.3 Prior Disclosure History

```bash
# Check GitHub Security Advisories
gh api repos/<org>/<repo>/security-advisories --jq '.[].summary'

# Check published CVEs
# WebSearch: "CVE [protocol name]"

# Check bounty platform history
# WebSearch: "[protocol name] bug bounty paid"
```

| History Signal | Implication |
|---------------|-------------|
| Published CVEs + acknowledgments | Professional team, high P(reward) |
| Active bounty program with payouts | Established process, medium-high P(reward) |
| Bounty program but no visible payouts | Unknown, medium P(reward) |
| No security program, no history | Unknown, low-medium P(reward) |
| Known for ghosting/ignoring | **WARNING.** Very low P(reward). Document everything for potential public disclosure. |

### 0.4 Contract Upgradeability Check

If your finding's trigger involves contract upgrade or admin action:

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
| All slots = 0x0 | **NOT a proxy.** Upgrade-based triggers are IMPOSSIBLE. |
| Implementation slot has address | Proxy. Verify upgrade history on block explorer. |

### 0.5 Industry-Known Vulnerability Check

Some vulnerability classes are so well-documented they're almost always known:

| Vulnerability | First Documented | Known % | Exception Condition (proceed if true) |
|--------------|------------------|---------|--------------------------------------|
| `.transfer()` 2300 gas limit | 2019 (ConsenSys) | 99% | Code written post-audit AND uses non-standard pattern |
| First-depositor attack (ERC4626) | 2022 | 95% | Custom vault (not OZ ERC4626), OR post-audit code |
| Reentrancy on ERC777 callbacks | 2020 | 95% | Novel cross-contract path not in standard taxonomy |
| Oracle manipulation via flash loans | 2020 | 90% | New oracle integration post-audit |
| Approval front-running (ERC20) | 2018 | 99% | Almost never |
| Stale oracle / sequencer downtime | 2023 | 85% | L2-specific path not covered in L1-only audit |
| Signature replay (EIP-712) | 2019 | 90% | Missing chainId or nonce in non-standard scheme |

**Usage:** If Known% >= 90% AND Exception Condition is FALSE → near-certain dismissal. Abort or find differentiation.

### 0.6 Design Intent Test

**If your finding is a "missing check" or "incomplete restriction", run this test BEFORE proceeding.**

Ask: *"If this behavior was intentional, what would be the protocol's design rationale?"*

```
1. Construct the strongest possible DEFENSE of the current behavior
2. If a coherent design justification exists in <30 seconds → HIGH dismissal risk
3. Check if the finding crosses a TOKEN LAYER BOUNDARY (wrapper → underlying)
```

**Token Layer Boundary Rule:**
When a protocol wraps a permissionless token with a restricted derivative, access controls on the wrapper typically do NOT extend to the underlying after conversion. This is a design pattern, not a bug.

```
IF finding = "restricted user can still access underlying token after unwrapping/cooldown":
    → Protocol likely considers this INTENTIONAL
    → ABORT unless you have evidence the protocol explicitly claims otherwise
```

### 0.7 Code Path Reachability Verification

**If the target has multiple build variants, binaries, or topology configurations, you MUST verify your vulnerable code path is reachable in the PRODUCTION deployment.**

```
1. Identify which binary/build is deployed
2. Find the topology/configuration file for that build
3. Trace: entry point → message handler → vulnerable function
4. Confirm the link/input that feeds the vulnerable handler EXISTS in the deployed topology
5. If the code path is ONLY in an alternative build → FATAL
```

### 0.8 Post-Audit Code Dating (git blame)

```bash
# Check if vulnerable code was written AFTER the last audit
git log --follow -p -- <vulnerable-file> | head -100
git blame <vulnerable-file> | grep -n "<vulnerable-line-content>"
```

| Code Date vs Audit Date | Implication |
|------------------------|-------------|
| Code AFTER audit | Cannot be "known from audit" — strong argument |
| Code BEFORE audit | Audit may have seen it — check report carefully |
| Code existed DURING audit | If not flagged, either missed or intentional |

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
3. **Count** of defensive instances across the codebase
4. **List of contracts** that use the defensive pattern vs. those that don't

### How to Write It

```markdown
#### Internal evidence of oversight

This is not a [ExternalProtocol] bug — it is [Protocol]'s decision to use this
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

- If the protocol has NO defensive patterns for this call type → skip section, but note in the Dismissal Vector Matrix that "Feature not bug" is a risk
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

# Round 3: Generic pattern
WebSearch: "[call pattern] blocks withdrawals smart contract audit"

# Round 4: Platform-specific search
WebSearch: site:github.com/code-423n4 "[vulnerability keyword]"
WebSearch: site:github.com/sherlock-audit "[vulnerability keyword]"
```

### What to Extract Per Finding

1. **Protocol name** and year
2. **Platform** (Code4rena, Sherlock, Hats, direct disclosure)
3. **Severity** assigned by judges
4. **Issue URL** (GitHub link)
5. **1-line summary** of the finding
6. **Judge quote** if available

### Minimum Thresholds

- **3+ precedents** → Strong argument ("industry-recognized vulnerability class")
- **1-2 precedents** → Acceptable (include but don't oversell)
- **0 precedents** → Novel finding. Focus on technical argument. Novel != invalid.

---

## Phase 3c: External Dependency Defense

**Goal:** Prove the external condition is realistic, not theoretical.

### Research Checklist

For EACH external dependency in the attack path:

```
[ ] Does the external token/contract have a pause function?
[ ] Has the pause function ever been used?
[ ] Does the external token/contract have a blacklist?
[ ] Is the external token/contract upgradeable?
[ ] Can third-party governance modify the dependency?
[ ] Has the external protocol had any incidents?
[ ] Is the dependency permissionlessly configurable?
```

### Concrete Evidence to Collect

| Scenario Type | What to Find | Example Evidence |
|---------------|-------------|------------------|
| Token pause | Contract has `whenNotPaused` | "USDT has `whenNotPaused` on `transfer()`" |
| Blacklist activity | Number of addresses frozen + total value | "Tether froze $3.3B across 7,268 addresses" |
| Governance action | Who can add/remove the dependency | "Convex `rewardManager` can call `addExtraReward()`" |
| Historical incident | Past failures of exact dependency | "[Protocol] had [incident] on [date]" |

### Skip Conditions

- If the finding does NOT depend on external conditions → skip entirely
- If the external condition requires a global catastrophe → don't include, it weakens the argument

---

## Phase 3d: Prior Audit Differentiation

**Goal:** Make it impossible for the team to confuse your finding with a known issue.

### Search Strategy

```bash
# 1. Find all prior audits of the target
WebSearch: "[protocol name] audit Code4rena"
WebSearch: "[protocol name] security audit report"

# 2. Search for findings on the same contract
WebSearch: "[contract name] [protocol name] finding"

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

- EVERY row must be different. If 2+ rows are identical, may actually be a duplicate.
- If you can't fill the table with meaningful differences → reconsider whether this is truly new.

---

## Phase 3f: On-Chain Evidence Collection (MANDATORY for deployed contracts)

**Goal:** Prove the bug exists on deployed contracts with real funds, ideally with the bug condition active NOW.

**Why:** On-chain evidence is the single strongest differentiator in competitive audits. Out of 200+ submissions, most provide only PoC against local forks. Proving live state makes your finding unforgettable.

### What to Collect

| Data Point | How | Why |
|-----------|-----|-----|
| Deployed contract addresses | Factory events, Etherscan, protocol docs | Proves production deployment |
| Current TVL / balances | `cast call`, `balanceOf`, DeFiLlama | Quantifies real impact |
| Bug precondition state vars | Direct state reads via `cast call` or MCP `evm_call` | Proves bug condition is active NOW |
| Number of affected deployments | Factory event scan | "8 vaults deployed, 3 with active funds" |
| Block number snapshot | `cast block-number` | Verifiability — anyone can reproduce |

### Methodology

```bash
# 1. Find deployed instances (scan factory events)
cast logs --from-block <deploy_block> --to-block latest \
  --address <factory> <Deployed_event_topic> --rpc-url <rpc>

# 2. Read bug-relevant state on each instance
cast call <contract> "stateVar()(uint256)" --rpc-url <rpc>

# 3. Check if bug condition is ACTIVE
# Example: pastEpochsUnclaimedAssets > 0 means locked assets exist
cast call <vault> "pastEpochsUnclaimedAssets()(uint256)" --rpc-url <rpc>

# 4. Get snapshot block
cast block-number --rpc-url <rpc>
```

### MCP Tools (when available)

```
evm_call        — read any view function
evm_read_storage — read raw storage slots
evm_get_logs    — scan events (factory deployments, state changes)
evm_resolve_proxy — check if contract is proxy
evm_multi_call  — batch multiple reads on same contract
```

### Report Output Format

```markdown
## On-Chain Verification (Mainnet)

[Contract type] is deployed in production via [factory/deployer] `0x...`.
**N instances exist on mainnet**, M with active deposits totaling ~$XM.

**[Largest Instance]** (`0x...`) — **$XM TVL:**

| State Variable | Current Value | Meaning |
|---|---|---|
| `varName` | value | [interpretation] |
| `bugCondition` | **value** | Bug condition **active/inactive** |

*Snapshot: Ethereum mainnet block ~NNNNN ([date]). All values verifiable via `cast call`.*
```

### Skip Conditions

- If target is Rust/Solana with no on-chain state relevant to the bug → skip
- If contract is not yet deployed (audit contest on pre-deployment code) → skip, note in report

---

## Phase 3e: Dismissal Vector Matrix (Internal Tool — EXPANDED)

**Goal:** Pre-build counter-arguments for every plausible dismissal. **10 vectors minimum.**

### Template (Full 10-Vector Matrix)

```
| # | Dismissal Vector | Applicable? | Their Argument | Your Counter | Evidence |
|---|-----------------|------------|----------------|--------------|----------|
| 1 | "By design" | YES/NO | [design rationale] | [NatSpec/comment auto-incrimination if dispo] | [code ref] |
| 2 | "Admin-only, trusted" | YES/NO | [admin path only] | [frame as missing validation, not admin attack] | [code ref] |
| 3 | "Known issue" | YES/NO | "Same as audit finding H-03" | "Different trigger, impact, root cause" | [6-axis diff table] |
| 4 | "Theoretical, no real impact" | YES/NO | "Can't happen in practice" | [concrete PoC numbers — DELTA before/after] | [PoC output] |
| 5 | "Already mitigated elsewhere" | YES/NO | "Guard exists at layer X" | [code ref showing NO mitigation on THIS path — symmetry analysis] | [code diff] |
| 6 | "Low impact / informational" | YES/NO | "Impact is minimal" | [impact quantification in $ + % TVL] | [calculation] |
| 7 | "On our roadmap" | YES/NO | "We plan to fix in v2.1" | [current user exposure — count affected deployments] | [on-chain data] |
| 8 | "Won't fix, risk accepted" | YES/NO | "Cost of fix exceeds risk" | [absence of recovery: no pause, no governance, no circuit breaker] | [code ref] |
| 9 | "Prior audit found this" | YES/NO | "Auditor X already flagged" | [6-axis differentiation table] | [comparison] |
| 10 | "Not user's fault" | YES/NO | "Users shouldn't do that" | [external dependency evidence, pause history, permissionless trigger] | [historical data] |
```

### Usage

- This matrix is NOT included in the report verbatim
- It guides WHICH arguments to embed in each section
- Every "YES" with filled "Evidence" → becomes a paragraph in the report
- Every "YES" with empty "Evidence" → weak argument, either find evidence or drop the counter
- **Rule from Jupiter Lend:** Finding #3 had "bank-run" counter-argument that was invalidated by `saturating_sub`. Every counter MUST be verified against the actual code before embedding.

### Anti-Dismissal Research (Parallel — 10-15 min)

Launch these in parallel for each finding that passes the Kill Gate:

| Phase | Agent | Deliverable | Time |
|-------|-------|-------------|------|
| 3a: Internal Consistency Scan | Explore | grep `try\|defensive\|prevent\|protect` + count instances | 3-5 min |
| 3b: Precedent Audit Research | WebSearch | 3+ precedents C4/Sherlock with severity + judge quotes | 5-7 min |
| 3c: External Dependency Defense | WebSearch | Pause history, blacklist activity, governance actions | 3-5 min |
| 3d: Prior Audit Differentiation | WebSearch + gh CLI | 6-axis table vs each similar finding | 5-7 min |

**Output:** Dismissal vector matrix fully populated with evidence.
**Sequential time:** ~45 min. **Parallel time:** ~15 min. Always parallelize.

---

## Execution Order

When running `/disclose`, execute in this order:

1. **Target assessment** (Step 0) — 5 minutes
2. **Production reachability** (Step 1) — 2 minutes
3. **Duplicate check** (Step 2) — 2 minutes
4. **Anti-dismissal research** (Step 3) — 15-20 minutes (launch sub-agents in parallel):
   - 3a: Internal consistency scan (Explore agent)
   - 3b: Precedent audit research (WebSearch agent)
   - 3c: External dependency defense (WebSearch agent)
   - 3d: Prior audit differentiation (WebSearch + GitHub CLI agent)
   - 3f: On-chain evidence collection (cast/MCP — for deployed contracts)
5. **Build dismissal vector matrix** (Step 3e) — 2 minutes (synthesize results)
6. **Severity classification** (Step 4) — 1 minute
7. **Write report** (embedding anti-dismissal arguments + on-chain evidence) — 5 minutes
8. **Quality gate** (22-point rubric) — 3 minutes
9. **Output** — formatted disclosure email ready to send

Total: ~25-30 minutes per disclosure.

---

## Phase 4: Pre-Disclosure Quality Gate — 24-Point Rubric

**Every disclosure MUST score 22/24+ before sending. Score below 22 = fix before sending.**

**Full rubric with detailed checks:** See `~/Desktop/BUGS/PREFLIGHT-CHECK.md`

Run this checklist AFTER the report is written, BEFORE sending. ~15 minutes.

### A. PoC Quality (7 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| A1 | Reproducible without modification | Run from scratch, zero edits needed | Requires tweaks |
| A2 | Concrete numbers, not "significant loss" | "$47,231 loss" with specific values | "Significant funds at risk" |
| A3 | Trigger conditions realistic and documented | Each condition individually achievable | "Attacker waits 6 years" |
| A4 | PoC shows DELTA (before/after) | Baseline measurement + post-exploit measurement | Only "it reverts" |
| A5 | Fork-based (Solidity) / test-based (Rust) | Zero mocks, real contracts/code | Mock-based or simulated |
| A6 | No mock hiding a problem | PoC works against REAL dependency | Mock coincidentally avoids prerequisite |
| A7 | Honest about PoC limitations | Simplifications explicitly stated | Hidden assumptions |

### B. Argumentation (7 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| B1 | Internal consistency argument present | Code refs from BOTH sides (protected + unprotected) | Missing or N/A not stated |
| B2 | Dismissal vector matrix complete (10 vectors) | Every YES vector has pre-emptive defense with evidence | Incomplete or missing |
| B3 | Impact quantified in $ or % | "$12M TVL across 3 vaults" | "All deposits" |
| B4 | Severity justified, not oversold | If <0.001% TVL/year → says "Medium MAX" proactively | Lets reviewer discover minimal impact |
| B5 | Recommended fix with code | Exact code diff addressing root cause | "Add a check" |
| B6 | Code references with exact lines | File path + line number + permalink | "In the contract..." |
| B7 | No invalidatable argument | Every claim verified against actual code | Argument disproven by reading code (Jupiter #3: saturating_sub) |

### C. Hygiene (4 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| C1 | Title < 80 chars, descriptive | "[Type] in [component] allows [impact]" | Vague or too long |
| C2 | No repetition between sections | Each section adds NEW information | Same sentences repeated |
| C3 | Format correct for platform + CVSS vector | Follows C4/Sherlock/email template, CVSS 3.1 string | Wrong format or no CVSS |
| C4 | No credibility-reducing errors | Zero typos in function names, correct line numbers | Wrong names, broken markdown |

### D. Strategic (6 points)

| # | Criterion | Pass (1pt) | Fail (0pt) |
|---|-----------|------------|------------|
| D1 | Verified not duplicate / known issue | Searched GitHub, C4, Sherlock, CodeHawks, known issues | No search documented |
| D2 | Code path traced entry → bug | Complete trace with intermediate calls | "This function is vulnerable" |
| D3 | Guards documented (or absence) | Existing guards explained as insufficient, OR "no validation exists" | Guards not mentioned |
| D4 | Worst-case AND realistic-case separated | Both stated explicitly | Only one perspective |
| D5 | No unverifiable claims | Every claim verifiable with info provided | "We observed..." without proof |
| D6 | IS/IS NOT risk split | Explicitly states what IS and what is NOT at risk | Only states risk |

### Scoring

```
24/24 — Send immediately
22-23 — Send after fixing flagged items (<30 min fixes)
19-21 — Significant gaps. Fix ALL failing criteria before sending.
<19   — Major rework needed. Do NOT send.
```

### Jupiter Lend Retroactive Scoring

| Finding | Would-fail criteria | Impact |
|---------|-------------------|--------|
| #2 (Branch Recycling) | Kill Gate Q3 (disjoint sets) | Would have been KILLED in 30 min, saving 4h |
| #3 (Bank-run) | B7 (invalidatable argument: saturating_sub) | bank-run counter invalidated post-review |
| #4 (Magnifier) | A2 (concrete numbers), B4 (oversold extrapolation) | 1-year extrapolation was unrealistic |
| #5 (Downgraded) | B4 (severity oversold) | Submitted as Medium, downgraded to Low/QA |
| #1 (Oracle) | ALL PASSED | Internal consistency argument decisive |

### Calibration Log

Track scores vs outcomes to calibrate which criteria actually predict acceptance:

```
| Date | Finding ID | Pre-Score | Final Severity | Outcome | Failed Criteria | Notes |
|------|-----------|-----------|---------------|---------|----------------|-------|
| (fill after each disclosure result) |
```

After 10+ entries: drop criteria that don't correlate, add new ones from dismissal patterns.
