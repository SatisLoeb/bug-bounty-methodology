# POST-AUDIT-DRIFT-PIPELINE — Monitor protocols for security-sensitive commits after formal audits

After a formal audit (C4 / Cantina / Sherlock / Spearbit / Trail of Bits), protocol teams merge fixes and continue feature work.
Window: 30-90 days between the audit report and the next audit.
In that window: panic patches, feature additions, refactors. Each is a candidate bug.
You are the second-pass reviewer for FREE.

## Why this works

1. First-round auditor has moved on to next engagement
2. Fix-regression bugs are the most common introduction path (patching creates new bugs)
3. Net-new features added post-audit are usually unaudited
4. Protocol team has live bounty program → you can submit findings formally

## Pipeline

### Step 1: Audit report ingestion

Watch these sources daily:
- `code-423n4.com/reports` (C4)
- `cantina.xyz/portfolio` (Cantina)
- `audits.sherlock.xyz` (Sherlock)
- `spearbit.com/portfolio` (Spearbit)
- `trailofbits.com/reports` (Trail of Bits)
- `hats.finance/audits` (Hats)
- `code4rena.com/reports/rss` if RSS available
- Protocol announcement channels (Discord, Twitter) for audit completion

Extract: protocol name, audit date, scope (commit hash + file list), findings summary (especially Medium/Low/QA).

### Step 2: Map to live bounty + repo

For each audited protocol:
- GitHub repo + main branch (canonical source)
- Bounty program URL (HackenProof / Cantina / HackerOne / Code4rena)
- Bounty cap (skip if <$10K max)
- Bounty exclusions (MEV? Known issues? Previously-audited code?)

### Step 3: Continuous monitoring via `github-monitor.py`

```bash
# Already exists at ~/arsenal/tools/github-monitor.py
# Extend with post-audit-drift logic:
#   - For each watched repo, track commits since audit_commit_hash
#   - Flag security-sensitive files (contracts/, src/core/, etc.)
#   - Flag security-sensitive patterns in diff (modifier add/remove, require add/remove, math change)
```

### Step 4: Triage flagged commits

For each commit:

**Category A — Fix for audit finding:**
- Read the audit report finding for match
- Check: is the fix complete (root cause) or bandaid (single guard)?
- Bandaid → new finding candidate
- Complete fix → check if adjacent functions received same fix

**Category B — Net-new feature:**
- Apply `/mrrobbot` or `/gravedigger` phase 1 methodology
- Bonus: no prior audit on this code → fresh surface

**Category C — Refactor:**
- Check for behavior changes (modifier moved, state var renamed → storage slot drift on upgradeable)
- Check test coverage diff — did refactor remove tests?

**Category D — Dependency bump:**
- If dep has a known CVE since audit, check live protocol affected

### Step 5: Apply standard lifecycle

```bash
TARGET_HINTS="post-audit-drift smart.contract" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <protocol>-drift
```

Then per flagged commit, treat as finding candidate:
```bash
~/arsenal/audit-lifecycle/bin/on-finding.sh <protocol>-DRIFT-<n>
```

## Signals per commit

Score each commit 0-10 on drift likelihood:

| Signal | +Points |
|---|---|
| Modifies contract (.sol / .rs / .cairo / .move in scope/) | +3 |
| Adds / removes `require` or `assert` | +2 |
| Changes modifier application on existing function | +3 |
| Changes access control (onlyOwner, onlyAdmin, hasRole) | +3 |
| Changes arithmetic (mulDiv, rounding) | +2 |
| Touches upgradeable contract storage layout | +3 |
| Dependency bump on crypto-adjacent lib (ecrecover, keccak) | +3 |
| Commit message contains "fix", "security", "vuln", "CVE" | +2 |
| Commit author is not the main contributor (onboarded dev) | +1 |
| Commit is merge from a branch with "feature" in name | +1 |
| Touches oracle / price feed logic | +3 |
| Touches cross-chain / bridge handler | +3 |

Score ≥ 5 → triage manually.

## Grep patterns for drift-sensitive changes

```bash
# In PR/commit diff:
git diff <audit_commit> HEAD -- "*.sol" | grep -E "^\+.*require\(|^\-.*require\("
git diff <audit_commit> HEAD -- "*.sol" | grep -E "^\+.*modifier\|^\-.*modifier"
git diff <audit_commit> HEAD -- "*.sol" | grep -E "onlyOwner\|hasRole\|onlyAdmin"

# For Rust:
git diff <audit_commit> HEAD -- "*.rs" | grep -E "^\+.*assert!\|^\-.*assert!"
git diff <audit_commit> HEAD -- "*.rs" | grep -E "^\+.*panic!\|^\-.*panic!"
```

## Example flagged commit workflow

Protocol: Morpho
Audited: Cantina Jan 2026 at commit `abc123`
Flagged commit: `def456` (2026-02-15), 3 files changed in src/periphery/

1. Diff `abc123..def456 -- src/periphery/`:
   ```
   + function newFeature(uint256 amount) external {
   +     require(amount > 0, "non-zero");
   +     _processAmount(amount);
   + }
   ```
2. `_processAmount` pre-existing audited function — but its call surface now changed.
3. Kill gate: is `newFeature` reachable permissionlessly? Does it bypass existing access check on other entry points?
4. If yes: apply phase 4 methodology, build PoC.

## Target prioritization

Weight each active audited protocol:

```
priority = (bounty_max / 10000) * (audit_age_days / 30) * commit_activity_weekly
```

Bounty cap of $500K, audited 60 days ago, 5 commits/week → priority ≈ 50 × 2 × 5 = 500
Bounty cap of $50K, audited 10 days ago, 1 commit/week → priority ≈ 5 × 0.3 × 1 = 1.5

Focus top-10 each week.

## Tool requirements

- `post-audit-drift-monitor.sh` — cron-style, watches N repos, emails/logs flagged commits
- Extension of `github-monitor.py` (already exists)
- `commit-drift-scorer.py` — score each flagged commit 0-10 per criteria above
- Integration with OUTCOMES.jsonl — track drift findings separately

## Cadence

- Daily: ingest new audit reports from the 5+ platforms
- Daily: `post-audit-drift-monitor.sh` runs via cron, logs flagged commits
- 2x/week: triage top-scored commits (30 min)
- Weekly: pick 1-2 high-priority drift findings to deep-dive

## Integration with lifecycle

Every drift-candidate is a regular lifecycle finding:
1. `init-target.sh` for the protocol (if not already)
2. `on-finding.sh` per drift-commit
3. Kill gate → severity-commit → draft → preflight → submit

## Bounty disclosure notes

- Drift findings tend to be smaller (QA → Medium) than fresh audit findings
- BUT they're faster to confirm + bounty pays faster
- Strategy: submit drift findings between major audit-hunt campaigns for steady cashflow
- For Critical drift findings: leverage "this is a regression of audit finding X" → protocol teams prioritize

## Known patterns (ghost-finding for post-audit)

- Fix introduced non-atomic state update
- Patch for H-01 didn't cover the analogous M-05 code path
- Net-new feature reuses existing modifier chain but the new function is missing `nonReentrant`
- Dependency bump (OZ 4.x → 5.x) changes `_transfer` hook behavior
- Refactor renamed `_owner` to `_admin` but subgraph / frontend still reads old slot

## Disclosure

Most platforms accept "this is new code post-audit" as a valid submission. No need to claim the auditor missed it — frame it as post-audit-work without prior review. Tone neutrally:

> "This finding applies to code merged after the [audit] report. The vulnerable path is in `<file>:<lines>` introduced by commit <hash>."

Protocol teams appreciate the clean framing.
