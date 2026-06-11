# Machine 2 Setup Guide — Arsenal Security Research Platform v2.0

## Why This Matters

This arsenal was built from 30+ real bug bounty investigations across HackerOne, HackenProof, Cantina, and Code4rena. Every tool, pattern, and template exists because we lost time, lost rep, or missed money without it.

**Revenue context:** These tools are the difference between $150/day surface scanning and $2,000/day deep hunting. The check-matrix tool found the same bug in 30 seconds that took 2 hours manually on Multipli ($367M TVL). The pattern scanner checks 128 vulnerability patterns in 2 seconds. The bounty monitor catches new programs before other researchers see them.

---

## Quick Start (5 minutes)

```bash
# 1. Clone arsenal
git clone http://<machine1-ip>:3000/malix/arsenal.git ~/arsenal

# 2. Install dependencies
pip install slither-analyzer requests --break-system-packages
# Also need: solc, forge (foundry), cast

# 3. Make tools executable
chmod +x ~/arsenal/tools/*.sh ~/arsenal/tools/*.py

# 4. Setup bounty monitor cron
(crontab -l 2>/dev/null; echo "*/30 * * * * ~/arsenal/tools/bounty-monitor.sh --notify >> /tmp/bounty-monitor.log 2>&1") | sort -u | crontab -

# 5. Verify everything works
~/arsenal/tools/pattern-scan.sh /path/to/any/solidity/project --type all --lang sol
python3 ~/arsenal/tools/check-matrix.py /path/to/any/solidity/project
python3 ~/arsenal/tools/invariant-gen.py /path/to/any/solidity/project
```

---

## 9 Tools — What, When, Why

### Tool 1: `pattern-scan.sh` — 128 Pattern Grep Scanner
**Command:** `./pattern-scan.sh <dir> --type vault|dex|bridge|lending|staking|all --lang sol|rs|go`
**When:** Phase 0 — FIRST thing after cloning. Before manual review.
**Why:** 128 vulnerability patterns from C4 reports, each with false positive signals. Finds candidates in 2 seconds that take 2 hours manually.
**Time saved:** 2h → 2s per target

### Tool 2: `check-matrix.py` — Automated Check Matrix Builder
**Command:** `python3 check-matrix.py <dir> --output matrix.md`
**When:** Phase 1 — run on EVERY smart contract target. No exceptions.
**Why:** This is our signature technique. It found Reserve F-001 ($10M bounty), Morpho F-001, Coin98 F-001, Spark F-008. Extracts all functions, maps modifiers, highlights inconsistencies. Two functions that do the same thing but differ in checks = bug.
**Time saved:** 2h → 30s per target
**Verified:** Found missing nonReentrant on Multipli removeFundsNative — same bug we found manually.

### Tool 3: `invariant-gen.py` — Fuzz Test Generator
**Command:** `python3 invariant-gen.py <dir> --output invariants.t.sol`
**When:** Phase 2 — generates Foundry fuzz tests automatically.
**Why:** Most researchers skip fuzzing because inventing invariants is hard. This tool proposes invariants from ERC standards, code comments, and function pairs. Customize TODOs and run with `forge test --fuzz-runs 50000`.
**Time saved:** 1h → 2s per target

### Tool 4: `report-gen.py` — Multi-Platform Report Generator
**Command:** `python3 report-gen.py --finding finding.json --platform h1|hackenproof|cantina|c4`
**When:** Phase 4 — after confirming finding. Speed = primacy in contests.
**Why:** Report writing takes 30-60 min. In contests, first submission wins. This generates formatted reports from structured JSON data.
**Time saved:** 30min → 5min per finding

### Tool 5: `fork-diff.sh` — Security-Focused Fork Diff
**Command:** `./fork-diff.sh <local_fork_dir> <parent_repo_url>`
**When:** Phase 0 — when target is a fork (80% of DeFi protocols).
**Why:** The diff between fork and parent = where bugs live. Filters cosmetic changes, highlights security-relevant modifications (transfer, approve, mint, auth, etc.).
**Time saved:** 1h → 30s per fork target

### Tool 6: `bounty-monitor.sh` — New Program Alerts
**Command:** Auto via cron, or manual `./bounty-monitor.sh`
**When:** Background — every 30 minutes.
**Why:** First mover advantage on new programs. Checks Cantina, HackenProof, C4, Sherlock, Hats.
**Time saved:** Passive — catches opportunities you'd otherwise miss

### Tool 7: `vuln-propagate.py` — Cross-Protocol Vulnerability Propagator
**Command:** `python3 vuln-propagate.py --parent "Aave V3" --file "Pool.sol" --pattern "liquidation"`
**When:** Phase 4 — after confirming a finding. One bug → 30 forks → 30 payouts.
**Why:** When you find a bug in Protocol A, 50+ forks might have the same bug. This finds them via DeFiLlama and checks each automatically.
**Time saved:** 4h → 5min per propagation

### Tool 8: `github-monitor.py` — Repo Commit Watcher
**Command:** `python3 github-monitor.py` (cron every hour)
**When:** Background — watches repos with active bounties.
**Why:** Window between vulnerable commit and discovery = highest value. Alerts when security-relevant code changes in watched repos.
**Time saved:** Passive — zero-day window exploitation

### Tool 9: `enrich-finding.py` — On-Chain Impact Quantification
**Command:** `python3 enrich-finding.py --address 0x... --chain ethereum --type vault`
**When:** Phase 4 — before writing report.
**Why:** "$50M TVL at risk" gets Critical. "Some funds at risk" gets Medium. Queries DeFiLlama TVL + on-chain state (totalAssets, totalSupply, share price) to quantify impact.
**Time saved:** 30min → 2min per finding

---

## Pattern Databases

### 128 Solidity Patterns (`methodology/C4-HUNTING-PATTERNS.md`)
From 43 C4 reports (2025-2026). Categories: DEX (7), Lending (65), Vault (19), Bridge (8), Consensus (4), Options (3), Wallet (2), Math (2), Launchpad (2), Governance (2), Meta-patterns (5). Each with detection grep + false positive signal.

### 28 Multi-Language Patterns (`methodology/MULTI-LANG-PATTERNS.md`)
- **Rust** (10): unwrap panics, overflow in release mode, unsafe blocks, missing zeroization, Soroban TTL/auth, Solana signer/PDA
- **Go** (8): goroutine races, mutex contention (TRON $100K pattern), defer ordering, interface nil, unbounded input, XFF trust bypass
- **Cairo** (5): felt252 overflow, storage collision, L1-L2 reentrancy, l1_handler auth bypass
- **Move** (3): object ownership, shared object race, abort DoS

---

## The MrRobbot Methodology (`skills/mrrobbot/SKILL.md`)

4-phase adaptive framework. Read the full file. Key points:

**Phase 0 (Triage):**
1. Clone → `pattern-scan.sh` → `fork-diff.sh` (if fork)
2. Count audits PER COMPONENT (not protocol total — 60 audits = skip)
3. Search prior C4/Sherlock/Cantina audits for the protocol
4. Decision gate: unaudited code found → PROCEED. 10+ audits all audited → SKIP.

**Phase 1 (Check Matrix):**
1. `check-matrix.py` on every target
2. Read every line of unaudited code
3. Each inconsistency → Foundry test to confirm

**Phase 2 (Fuzzing):**
1. `invariant-gen.py` → customize → `forge test --fuzz-runs 50000`
2. Failing invariant = STOP EVERYTHING, build PoC

**Phase 4 (Reporting):**
1. `enrich-finding.py` for impact quantification
2. `vuln-propagate.py` to check forks
3. `report-gen.py` for platform-formatted report
4. Pre-submission risk assessment: map rejection vectors BEFORE writing

---

## Critical Lessons (Encoded in Memory)

### Reports Get Accepted When:
- PoC proves FULL chain from attacker to impact (not synthetic dispatch)
- Evidence in report body, arguments reserved for dispute
- IS/IS NOT risk split is honest
- Strongest finding submitted first (credibility bias)

### Reports Get Rejected When:
- Admin-configured extension point = "delegation by design" (Centrifuge)
- Desktop app local file access = out of scope (Agent-X)
- Trusted actor abuse = out of scope (Orderly, Centrifuge)
- Frontend source exposure without backend exploit = informational (Ring)
- GraphQL introspection = informational on most programs (Neon)

### Skip These Targets:
- 60+ audits (Euler V2), 14+ audits + 882 researchers (Liquity v2)
- 9 audits + $2M competition (pump.fun)
- 500+ submissions + $0 paid (Whitechain)
- Immunefi (blacklisted)
- Closed-source Solana with 5+ audits (IDL false positives)

---

## Infrastructure

| Resource | Access | Purpose |
|----------|--------|---------|
| VPS | `ssh root@85.31.236.148` (pw: Trader310@malik) | Callback server on port 8888 |
| Callback URL | `http://85.31.236.148:8888/your-tag` | SSRF/blind XSS testing |
| Arsenal repo | `http://<machine1-ip>:3000/malix/arsenal.git` | `git pull --rebase` before every session |
| Bounty monitor log | `/tmp/bounty-monitor.log` | `tail -f` for alerts |
| Daily email briefing | `xvush310@gmail.com` at 8am | Automated Claude remote trigger |

---

## Daily Workflow

```
Morning:
  1. Check email for Daily Bounty Briefing
  2. git pull --rebase on arsenal
  3. tail -20 /tmp/bounty-monitor.log (any new programs?)
  4. python3 github-monitor.py (any security commits?)

Starting a new target:
  1. /mrrobbot <target>  (Claude Code executes full methodology)
  2. Tools run automatically per Phase 0-4
  3. Findings → kill gate → preflight check → submit

After finding confirmed:
  1. enrich-finding.py (quantify impact)
  2. vuln-propagate.py (check forks)
  3. report-gen.py (format for platform)
  4. Map rejection vectors BEFORE submitting
  5. Submit strongest finding first
```

---

## Arsenal v2.0 — March 31, 2026
9 tools | 156 patterns | 6 templates | 1 adaptive methodology | 16 encoded lessons
