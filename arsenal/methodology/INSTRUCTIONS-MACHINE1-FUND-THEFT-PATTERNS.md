# Instructions Machine 1 — Fund Theft Patterns + Rule 26 v2 Propagation

## Context

Session du 5-6 avril 2026. Three CRITICAL findings submitted to HackenProof (1inch, Zest, Dexalot). GMTrade bounty results received: 2/25 accepted, our pendingImpactAmount rejected as "feature request." Five mandatory fund theft patterns extracted and encoded across all methodology files.

## What changed on Machine 2

| File | Changes |
|------|---------|
| `methodology/C4-HUNTING-PATTERNS.md` | +META-011 (partial state commitment TOCTOU), +META-012 (cross-market payout mismatch), +META-013 (silent type truncation), +META-014 (feature request dismissal rule) |
| `methodology/MULTI-LANG-PATTERNS.md` | +R-011 (silent `as uN` truncation, GMTrade #31), +R-012 (cross-market accounting, GMTrade #45), +R-013 (assert/panic on peer data, Monad/TRON) |
| `skills/gravedigger/RECON-PLAYBOOK.md` | +Rule 26 v2 RPC namespace deep probe in Phase 2 exit checklist |
| `skills/gravedigger/DEEP-ANALYSIS-PLAYBOOK.md` | +Rule 26 v2 RPC proxy namespace audit (CSP mining, error mining, free bearer token) |
| `skills/mrrobbot/SKILL.md` | +5 mandatory fund theft checks before check matrix, +anti-patterns #13 (fork-feature-absence) and #14 (Rust `as` casts), +priority 0 RPC namespace probe |

## What Machine 1 needs to do

### 1. Pull and verify

```bash
cd ~/arsenal
git pull origin main
```

### 2. Sync skills (if not hardlinked)

```bash
# Only needed if skills are copies, not hardlinks
cp skills/gravedigger/RECON-PLAYBOOK.md ~/.claude/skills/gravedigger/
cp skills/gravedigger/DEEP-ANALYSIS-PLAYBOOK.md ~/.claude/skills/gravedigger/
cp skills/mrrobbot/SKILL.md ~/.claude/skills/mrrobbot/
```

### 3. Update CLAUDE.md with new rules

Add to CLAUDE.md after rule #33 (lock contention):

```
34. **MANDATORY: 5 fund theft checks on every SC target (30 min)** -- These patterns produced the only accepted findings on heavily-audited bounty programs. Run BEFORE the check matrix.
    (1) Silent type truncation: `grep "as u32\|as u64" *.rs` -- can source exceed target max? Price * precision is highest-risk. GMTrade #31: `as u32` on price, CRITICAL accepted.
    (2) Cross-market payout mismatch: trace swap routing credit vs payout debit. Different market = phantom LP credit = double extraction. GMTrade #45, CRITICAL accepted.
    (3) Partial state commitment TOCTOU: find stateHash, list settlement math variables, check if denominator (totalSupply) is live-read vs committed. OFT bridge between finalize/settle = manipulation. Dexalot DXLTOVDD-336.
    (4) Branch asymmetry: if/else computing same formula, compare side by side. Missing multiplier in one branch = one-line CRITICAL. Zest ZESTPSC-11, confirmed by triage in hours.
    (5) assert!/panic! on peer data: error message names external actor = crash via peer input. Main executor = persistent crash loop. Monad #167, TRON-C01.
    **Decision rule for forks:** Can you write a PoC that steals funds using ONLY the code that EXISTS? If PoC depends on what DOESN'T exist, it's a feature request. Implementation bugs win. Design gaps lose. (GMTrade lesson: pendingImpactAmount rejected as "feature request" despite valid HIGH.)
```

### 4. Verify the patterns are in pattern-scan.sh

Check if `pattern-scan.sh` includes the new Rust patterns (R-011, R-012, R-013). If not, add detection commands:

```bash
# R-011: Silent type truncation
grep -rn "as u8\|as u16\|as u32\|as u64" --include="*.rs" | grep -v test | grep -v "#\[cfg(test)]"

# R-012: Cross-market accounting
grep -rn "record_transferred_out\|record_transferred_in\|transfer_out\|shared.*vault\|pool.*balance" --include="*.rs"

# R-013: Assert on peer data
grep -rn "assert!\|panic!" --include="*.rs" | grep -v test | grep -v "#\[cfg(test)]"
```

## Key outcomes from this session

- **Zest Protocol ZESTPSC-11**: CRITICAL confirmed by triage. Missing reserve factor in one branch of if/else. $15K-$100K range.
- **1inch 1INWEB-67**: CRITICAL per calculator. txpool+debug RPC namespace via free JWT, 5 chains.
- **Dexalot DXLTOVDD-336**: CRITICAL submitted. OFT bridge TOCTOU on totalSupply between finalize and settle. PoC 3/3 with real OmniVaultShare contract.
- **GMTrade**: 2/25 accepted. Our finding rejected as "feature request." Lesson encoded.
- **Transak**: #1 All Time on program. 3 CRIT paid max + 2 more in pipeline.
