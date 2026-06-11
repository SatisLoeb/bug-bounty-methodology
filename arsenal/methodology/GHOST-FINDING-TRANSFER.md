# GHOST-FINDING-TRANSFER — Cross-protocol severity retargeting

Finding X was Low/QA at protocol A (small TVL, safe composition).
Same class might be High/Critical at protocol B (larger TVL, risky composition).
Protocol B has a live bounty. The audit trail of A is free reconnaissance for B.

## Why this works

- Every C4/Cantina/Sherlock contest produces dozens of Low/QA findings — mostly dismissed
- Forks of audited protocols inherit the audit reports as sunk-cost intelligence
- Severity judgement depends on context (TVL, composition, user count) — context differs across forks
- Triagers respond well to "this class was a Low at X, here it's a High because [specific composition]"

## Pipeline

### Step 1: Build the ghost-finding database

Scrape public audit reports. For each finding (including dismissed Low/QA):

```jsonl
{
  "id": "C4-2024-03-aave-H-01",
  "protocol": "aave",
  "date": "2024-03-15",
  "severity": "High",
  "title": "Liquidation threshold miscalc on isolated assets",
  "class": "liquidation-math",
  "affected_function": "LiquidationLogic.executeLiquidationCall",
  "root_cause": "isolation_debt_accumulator.add() doesn't account for interest",
  "audit_fix": "...",
  "status": "fixed",
  "bounty_paid": "$12000"
}
```

Sources:
- `code4rena.com/reports` (download all, extract findings)
- `cantina.xyz/portfolio`
- `audits.sherlock.xyz`
- OUTCOMES.jsonl (our own history)

### Step 2: Build the fork index

For every protocol with audit findings, enumerate forks:

```
Aave V3 forks: K2 Lend (Stellar), Spark Protocol, Radiant, Benqi, Hundred Finance, ...
Uniswap V3 forks: SushiSwap V3, PancakeSwap V3, ThenaFi, Velodrome V3, ...
Morpho: Morpho Blue forks, Morpho Optimizer derivatives
Compound: Compound V2 forks: Venus, Cream, Hundred Finance
Curve: Curve forks on every chain
```

For each fork: commit hash forked from, TVL, chain.

### Step 3: Match findings to forks

For each audited finding, check all forks of same protocol:

```python
# ghost-match.py
def match_finding_to_forks(finding_record):
    protocol = finding_record["protocol"]  # "aave"
    function = finding_record["affected_function"]  # "LiquidationLogic.executeLiquidationCall"
    forks = query_fork_index(protocol)

    for fork in forks:
        if fork_forked_before(fork, finding_record["fix_commit"]):
            # Fork predates the fix — likely still vulnerable
            relevance = "HIGH: fork predates fix"
        elif fork_has_same_file(fork, function):
            # Fork has the file but forked after fix — check if fix was applied
            relevance = "MEDIUM: verify fix applied"
        else:
            continue

        # Severity upgrade assessment
        fork_tvl = get_tvl(fork)
        original_tvl = finding_record.get("original_tvl", 0)
        if fork_tvl > original_tvl * 3:
            severity_bump = "+1 (TVL 3x higher)"
        elif fork_has_composition(fork, finding_record.get("composition_requirements")):
            severity_bump = "+1 (composition amplifies)"

        yield {"fork": fork, "relevance": relevance, "severity_bump": severity_bump}
```

### Step 4: Verify per candidate

For each match:
1. Clone fork at current HEAD
2. Find the cognate function (file:line)
3. Check: is the vulnerable pattern present?
4. Check: is the audit's fix present?
5. If vulnerable and fix not applied: candidate finding

### Step 5: Severity reassessment

Original Low at protocol A might be:
- **Low** at B if TVL equivalent or smaller
- **Medium** at B if TVL 2-3x larger
- **High** at B if composition triggers (e.g., composed with flash loan, oracle, bridge)
- **Critical** at B if fund theft chain becomes permissionless

Example: reentrancy class was Low at protocol A because paused admin controls existed.
At fork B, admin control removed / paused-immutable → Critical.

### Step 6: Apply standard lifecycle

```bash
TARGET_HINTS="smart.contract ghost-finding-transfer" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <fork>-ghost-audit
```

## Ghost-finding signal examples

### Example 1: Aave V3 isolation mode bug → K2 Lend (Stellar)

- Original: C4 2023, Medium finding on `validateBorrow` missing isolation check
- K2 Lend forked Aave V3 on Stellar — port to Soroban
- Ghost-finding audit: does K2 Lend's Rust port include the isolation guard?
- If not: same class, same impact, likely higher severity because Stellar ecosystem TVL is less mature (more relative impact)

### Example 2: Curve reentrancy (Jul 2023) → Curve forks

- Original: Vyper compiler bug, Curve drained $70M
- Every Curve fork using affected Vyper version is vulnerable
- Most forks patched within days, but some on L2s / appchains didn't
- Ghost-finding scan: find all Curve forks, check Vyper version, test reentrancy

### Example 3: Uniswap V3 tick-spacing bug → V3 forks

- Original: Low finding, specific tick_spacing cause precision loss
- Forks: SushiSwap V3, PancakeSwap V3, Velodrome V3
- Each fork may have the same or different tick_spacing config
- Ghost-finding: check each fork's parametrization

## Tool: `~/arsenal/tools/ghost-finding-scanner.sh`

Wraps the pipeline:
```bash
# Update ghost DB from audit reports
./ghost-finding-scanner.sh --update-db

# For a specific fork target, find applicable ghost findings
./ghost-finding-scanner.sh --fork <protocol>/<fork-name> --tvl-min 10000000

# Emit candidate report
./ghost-finding-scanner.sh --scan <fork> > candidates.md
```

## Integration with lifecycle

```bash
TARGET_HINTS="ghost-finding-transfer" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <target>-ghost
```

Each ghost-match becomes a finding candidate; the `SEVERITY-COMMIT` is populated with the severity upgrade reasoning in artifact_proves.

## ROI assessment

- Setup cost: 40h for initial DB ingest (one-time)
- Per-target cost: 1-2h to run scanner + 3-6h to verify top candidates
- Hit rate: 5-15% of matches yield valid findings
- Payout: Medium range typically ($2K-$20K), but volume compensates

**Best targets for this method:**
- Aave V3 / V2 forks — many forks, many audits
- Uniswap V2/V3 forks — endless
- Compound V2 forks — older but still deployed
- Curve forks — high TVL, Vyper complexity
- Yearn / vault forks — composition-sensitive

## Known patterns

- Aave V3 audit's "isolated borrowing" Medium → Critical on Radiant fork due to cross-chain composition
- Compound V2 "accountLiquidity rounding" Low → Medium on Venus due to larger TVL
- Uniswap V2 "K-invariant precision" Low → Medium on forks with different fee parameterization

## Disclosure strategy

Frame with transparency:

> "This finding matches a class previously reported at [protocol A] as [severity A]. The severity at this protocol is [severity B] due to [specific composition reason]. Reference: [audit report URL]."

Triagers respect this framing — shows research depth, acknowledges precedent, explains why severity differs.

## Cadence

- Monthly: update ghost DB with new audits (2-4h)
- Weekly: scan 2-3 fork targets (8h total)
- Per hit: standard lifecycle + submission
