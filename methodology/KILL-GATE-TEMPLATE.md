# Kill Gate Template — 30-Minute False Positive Elimination

**Purpose:** Kill bad findings BEFORE investing time in report writing. Max 30 minutes per finding.

**Rule:** If a finding cannot survive this gate, it dies here. No exceptions. No "let me think about it more."

---

## Finding Metadata

```
Finding ID:     [PROTOCOL-NNN]
Protocol:       [name]
Platform:       [C4 / Sherlock / Direct / Immunefi]
Date:           [YYYY-MM-DD]
Time started:   [HH:MM]
```

---

## Kill Gate Checklist (30 min max)

### Q1: Design Intent Test (<30 seconds)

> Does a coherent design rationale exist for this behavior?

- [ ] Read comments within 50 lines of the vulnerable code
- [ ] `grep -r "intentional\|by design\|not needed\|skip\|expected" <file>`
- [ ] Construct the STRONGEST possible defense of the current behavior
- [ ] If a coherent justification appears in <30 seconds → **HIGH dismissal risk**

**Token Layer Boundary Rule:** Wrapper restrictions typically do NOT extend to the underlying token after conversion. If the "missing check" involves derivative → underlying conversion, this is almost certainly by design.

**Exception — Internal Inconsistency:** If the protocol protects against the same risk ELSEWHERE in the codebase → finding is valid regardless of design intent. Internal inconsistency is the strongest argument.

```
Result: [ ] CLEAR — no obvious design rationale
        [ ] RISK — rationale exists but inconsistency found → PROCEED with caution
        [ ] KILL — obvious design choice, no inconsistency
```

---

### Q2: Code Path Reachability (5 min max)

> Is the vulnerable code reachable from a public entry point in the DEPLOYED build?

- [ ] Identify the deployed binary / contract / build variant
- [ ] Trace: `entry point → ... → vulnerable function`
- [ ] Write the trace here:

```
Entry:  [function_name] (file:line)
  → [intermediate_call] (file:line)
  → [intermediate_call] (file:line)
  → [vulnerable_function] (file:line) ← VULNERABLE CODE
```

**Multi-Binary Warning (Solana/Firedancer):** Check topology. Different build targets wire different message handlers. Verify the handler is present in the SPECIFIC deployed variant.

**Red flags:** "latest [specific variant] release", multiple topology files, conditional compilation (`#[cfg(...)]`, `#ifdef`).

```
Result: [ ] REACHABLE — trace complete
        [ ] UNREACHABLE — no path from entry point → KILL
        [ ] UNCERTAIN — needs deeper analysis (max 10 more min)
```

---

### Q3: Disjoint Sets Test (2 min)

> Are the sets/states involved in the finding actually overlapping?

If the finding claims "A affects B", verify that A and B can coexist:

- [ ] Can the affected entity be in BOTH states simultaneously?
- [ ] Are the sets provably overlapping? (show concrete example)
- [ ] If sets are disjoint → the interaction is impossible

**Jupiter Lend Lesson (Finding #2):** Recycled branches and liquidated branches were DISJOINT sets. The finding assumed overlap that didn't exist. 4 hours wasted.

```
Set A: [description]
Set B: [description]
Overlap: [ ] YES — [prove it] / [ ] NO → KILL
```

---

### Q4: Existing Guards Check (3 min)

> Does the protocol already have a guard against this exact scenario?

- [ ] Search for `require`/`assert`/`if...revert`/`ensure!` on the same code path
- [ ] Search for modifier guards (`onlyOwner`, `whenNotPaused`, custom)
- [ ] Check if the guard covers the EXACT scenario or a subset

```
Guards found: [ ] NONE — proceed
              [ ] PARTIAL — guard exists but doesn't cover [specific case] → proceed
              [ ] FULL — guard covers this scenario → KILL or reclassify
```

**Counter-exception:** If the guard is ABSENT here but PRESENT on a similar path → **internal inconsistency** → STRONG PROCEED.

---

### Q5: Trigger Feasibility (2 min)

> Are the trigger conditions realistic?

- [ ] What must be true for the bug to fire?
- [ ] How likely is this condition in practice?
- [ ] What's the cost to the attacker to create this condition?

| Trigger Condition | Realistic? | Time to Achieve |
|-------------------|-----------|-----------------|
| [condition 1] | YES/NO | [time/cost] |
| [condition 2] | YES/NO | [time/cost] |

```
Feasibility: [ ] REALISTIC — permissionless, low-cost trigger
             [ ] CONDITIONAL — requires specific market conditions
             [ ] IMPRACTICAL — requires 51% attack / 6-year wait → Low/QA max
```

---

### Q5b: Temporal Reachability / Window-Actor Gate (3 min pre-PoC + a post-quantification recheck)

> Does the exploit need the system to SIT in an intermediate state for a DURATION — and does any actor collapse that state early, refresh it as a byproduct of routine traffic, or front-run your extraction at maturity, before you are paid?

Q2/Q5 ask whether the state is *reachable* and the trigger *affordable*. This asks whether the state **survives long enough to use, and whether YOU — not a faster actor — get the payoff.** A finding can be correct in a frozen snapshot yet require the protocol to REMAIN transient — a pending withdrawal, an un-liquidated unhealthy position, a stale-but-not-yet-refreshed oracle, a vesting/unlock cliff, an epoch boundary, a slowly-accumulating imbalance — for long enough to act. The market is not frozen: MEV searchers, arbitrageurs, liquidators and keepers are **present at t=0**, capital deployed and bots running.

**Two checkpoints — the payoff number does not exist yet, so do not hand-wave SURVIVES on it:**
- **Pre-PoC (now, 3 min):** FLAG the dwell-time dependency and KILL the obvious deaths (state visibly refreshed every block by routine traffic). For an accumulation vein the window LENGTH and harvested VALUE are OUTPUTS of the PoC — Ammalgam's "120 days" and premium rate came from the PoC, not before it — so you usually cannot yet *quantify* the adversary payoff. Flag, don't rubber-stamp SURVIVES.
- **Post-quantification (before submission):** once the PoC yields the REAL window and REAL value, recompute the adversary payoff and re-run this gate on numbers. This second pass is what scores Ammalgam's harvest DEAD; the first could only flag it.

- [ ] Does the exploit require an intermediate state to PERSIST for a non-zero duration? If NO (atomic, single-tx) → not a temporal case — but NOT "clean": an atomic exploit is still mempool-copyable (a bot reads your calldata, outbids gas, extracts first). Route to the **front-run / mempool sister gate** (§5.3 pre-gate / Q5), then skip the rest of Q5b.
- [ ] Name the window: which state must hold, for how long (blocks / hours / days).
- [ ] **Death (i-a) — TARGETED reset:** an actor resets the state FOR a reset payoff. Compute *their* payoff before your window matures.
- [ ] **Death (i-b) — INCIDENTAL reset:** an actor refreshes the state FREE, as a byproduct of unrelated routine profitable activity — a liquidation of a *neighbor* triggers a global update, an arb rebalance pokes the oracle you wanted stale, any deposit/withdraw touches the accumulator. This needs **no payoff of its own** to kill you: if routine traffic resets the state, it dies regardless of any targeted incentive. (Most windows die here, not to a targeted resetter.)
- [ ] **Death (ii) — front-run AT maturity:** even if the window survives to maturity, when you go to extract does a faster actor (liquidation bot, MEV searcher) front-run your extraction and take the payoff? Window intact, you still unpaid.

| Window state | Duration | Death mode | Actor | Payoff / trigger | Kills you? |
|--------------|----------|------------|-------|------------------|-----------|
| [state] | [time] | (i-a) targeted / (i-b) incidental / (ii) front-run | [who] | [$ or "free byproduct"] | YES/NO |

**The t=0 rule (non-negotiable):** MEV / arbitrage / liquidation / keeper activity is a CONSTANT of the environment, live from block zero — never model it as a hazard that "might show up later." If your exploit assumes N days of undisturbed accumulation, you are assuming N days with every bot in the mempool asleep. They are not asleep — and routine traffic does not need to *target* you to reset you.

```
Result (pre-PoC):  [ ] FLAGGED — needs dwell-time, obvious deaths ruled out → re-run post-quantification
                   [ ] N/A — atomic (→ front-run / mempool gate instead, not "nothing to check")
                   [ ] DEAD — routine traffic visibly resets the state every block → KILL now
Result (post-PoC): [ ] SURVIVES — with the REAL window + value: no targeted/incidental reset and no maturity front-run is profitable (show the numbers)
                   [ ] DEAD — a t=0 actor collapses the window (targeted OR incidental) OR front-runs the payoff → KILL before submission
```

**Ammalgam lesson:** a saturation-accumulation finding needed a ~120-day window; MEV bots harvested the state from second zero (harvest WAS the reset — deaths (i) and (ii) coincided there) and the old-saturation value refreshed early every cycle. The pre-PoC pass could only FLAG the dwell-time dependency; the post-quantification pass — real 120-day window, real premium rate, both PoC outputs — is what scores it DEAD. Correct in a static read, dead in a live market.

---

### Q6: Industry-Known Vulnerability Check (2 min)

> Is this a well-documented vulnerability class with >80% chance of being already known?

| Vulnerability Class | Known % | Status |
|-------------------|---------|--------|
| `.transfer()` 2300 gas | 99% | Almost always known |
| First-depositor ERC4626 | 95% | Almost always known |
| ERC777 reentrancy callbacks | 95% | Almost always known |
| Oracle manipulation (flash loan) | 90% | Usually known |
| Approval front-running | 99% | Always known |
| Stale oracle / sequencer downtime | 85% | Usually known |
| Signature replay (EIP-712) | 90% | Usually known |

- [ ] Check known issues list in contest/program
- [ ] Check prior audit reports for this class
- [ ] If Known% >= 90% AND no exception → near-certain dismissal

**Exception conditions that override:**
- Code written AFTER last audit (`git blame`)
- Novel cross-contract path not in standard taxonomy
- Protocol-specific variant with different impact

```
Result: [ ] NOVEL — not a known class
        [ ] KNOWN but differentiated — [explain exception]
        [ ] KNOWN and undifferentiated → KILL
```

---

### Q7: Contract Upgradeability Check (1 min)

> If the finding depends on a proxy upgrade: verify the contract IS actually a proxy.

```bash
# EIP-1967 implementation slot
cast storage <contract> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <rpc>
# EIP-1967 admin slot
cast storage <contract> 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103 --rpc-url <rpc>
```

```
Result: [ ] N/A — finding doesn't depend on upgradeability
        [ ] PROXY CONFIRMED — upgrade-based trigger is valid
        [ ] NOT A PROXY (all slots = 0x0) → upgrade trigger IMPOSSIBLE → KILL
```

---

### Q8: Auditor Cross-Reference (2 min)

> Has the lead auditor published research on THIS vulnerability class AND audited this protocol?

- [ ] Identify auditor(s) from prior audit reports
- [ ] Search for auditor's published research / blog posts on this vuln class
- [ ] If YES to both → 90%+ probability they already caught it

```
Auditor:           [name/firm]
Published on class: [ ] YES — [link] / [ ] NO
Audited protocol:   [ ] YES — [report] / [ ] NO

Result: [ ] LOW RISK — auditor hasn't published on this class
        [ ] HIGH RISK — auditor published + audited → KILL unless code is post-audit
```

---

### Q9: Post-Audit Code Dating (2 min)

> Was the vulnerable code written BEFORE or AFTER the last audit?

```bash
git blame <vulnerable-file> | grep "<vulnerable-line>"
# Compare date to audit report date
```

```
Vulnerable code date: [YYYY-MM-DD]
Last audit date:      [YYYY-MM-DD]
Result: [ ] POST-AUDIT — code is newer than audit → legitimate finding
        [ ] PRE-AUDIT — code existed during audit → higher risk of "already known"
        [ ] NO AUDIT — no prior audit exists → proceed freely
```

---

### Q10: On-Chain State Verification (5 min)

> Is the vulnerable contract deployed in production with real TVL? Is the bug condition active NOW?

**Why this matters:** "Deployed non-production contracts" is an out-of-scope killer. A finding against code that isn't deployed = instant rejection. Conversely, proving the bug condition is LIVE on mainnet with real funds makes the finding impossible to dismiss as "theoretical."

- [ ] Verify contract is deployed on mainnet (not just testnet/staging)
- [ ] Read on-chain state variables that constitute the bug precondition
- [ ] Document current TVL / funds at risk
- [ ] If bug condition is active NOW → document it with block number

**Verification methods:**

```bash
# EVM: Read state variables directly
cast call <vault> "pastEpochsUnclaimedAssets()(uint256)" --rpc-url <rpc>
cast call <vault> "totalAssets()(uint256)" --rpc-url <rpc>

# EVM: Check factory deployments (scan events)
cast logs --from-block <deploy_block> --to-block latest --address <factory> <event_topic> --rpc-url <rpc>

# Solana: Read account data
solana account <program_id> --url mainnet-beta

# MCP tools: evm_call, evm_read_storage, evm_get_logs, evm_resolve_proxy, solana_read_account
```

**Output for report (if bug condition is active):**

```
On-Chain Evidence (block #NNNNN):
| State Variable | Value | Meaning |
| [var1]         | [val] | [why it matters] |
| [var2]         | [val] | Bug condition = [ACTIVE/INACTIVE] |
```

```
Result: [ ] DEPLOYED + BUG ACTIVE — strongest position, include on-chain table in report
        [ ] DEPLOYED + BUG INACTIVE — deployed but condition not currently met, still valid
        [ ] NOT DEPLOYED — code is repo-only → KILL (out of scope)
```

---

## Dismissal Vector Matrix (MANDATORY if PROCEED)

**Fill this BEFORE writing any report. Each "YES" MUST have a pre-emptive defense.**

| # | Vector | Applicable? | Pre-emptive Defense | Evidence |
|---|--------|------------|-------------------|----------|
| 1 | "By design" | YES/NO | [NatSpec/comment auto-incrimination if available] | [code ref] |
| 2 | "Admin-only, trusted" | YES/NO | [frame as missing validation, not admin attack] | [code ref] |
| 3 | "Known issue" | YES/NO | [duplicate check: GitHub, git log, C4, Sherlock, CodeHawks] | [search results] |
| 4 | "Theoretical, no real impact" | YES/NO | [concrete PoC numbers — DELTA before/after] | [PoC output] |
| 5 | "Already mitigated elsewhere" | YES/NO | [code ref showing NO mitigation — symmetry analysis] | [code diff] |
| 6 | "Low impact / informational" | YES/NO | [impact quantification in $ + % TVL] | [calculation] |
| 7 | "On our roadmap" | YES/NO | [current user exposure — count affected deployments] | [on-chain data] |
| 8 | "Won't fix, risk accepted" | YES/NO | [absence of recovery: no pause, no governance, no circuit breaker] | [code ref] |
| 9 | "Prior audit found this" | YES/NO | [6-axis differentiation table] | [comparison] |
| 10 | "Not user's fault" | YES/NO | [external dependency evidence, pause history] | [historical data] |

---

## Q11: Chain-Amplification Check (2 min — severity UP, not a kill)

**Purpose:** before committing the SEVERITY floor, ask once whether this finding *combines* with another
to reach a higher tier. This is the one useful grain from CVSS-chaining: triagers score each report in
isolation, so a chain you can *prove* end-to-end is severity you leave on the table if you don't name it.

**This question can only RAISE severity, never lower it. It is NOT a license to inflate.**

```
Does a SECOND in-scope finding exist that this one pivots into?
  [ ] NO  → score this finding standalone. Done.
  [ ] YES → name it and PROVE the pivot:

  Finding A (this one):     [id + what primitive it gives]
  Finding B (the partner):  [id — must ALSO be in scope, in the SAME program]
  Pivot (the load-bearing step): [the concrete mechanism by which A's output becomes B's input]
```

**Hard gates — the chain dies if ANY fails (then report A and B separately at their standalone tiers):**
- [ ] **Observed, not narrated.** The pivot is demonstrated by a real artifact (PoC output / curl / cast call /
      tx on fork), not the words "could be chained to". A counterfactual chain = an argument = dismissed.
      (Same rule as Dismissal Vector #4. `cost_a − cost_b` is not a chain; `value_after < value_before` is.)
- [ ] **Both legs in scope.** B is not OOS, not a trusted-actor action, not an external protocol. A chain
      through an OOS leg is an OOS chain. (Check B against the program OOS list / SE-P-style clauses NOW.)
- [ ] **Money-flow survives the chain.** The CHAINED impact still produces a `loss = $X` line from observed
      state. A chain of two info-leaks is still an info-leak. Chaining does not manufacture fund-flow that
      neither leg has. (This is the filter that kills most "Medium+Medium=Critical" fantasies.)
- [ ] **One report, one payout.** Most programs pay only the highest-severity finding in a chain
      (SuperEarn rule: "only the highest-severity vulnerability in the chain will be paid"). So the chain is a
      SEVERITY argument for ONE report, not a way to bill two. Report it as: standalone tier for each leg,
      chained tier as the headline, single submission.

**If all four gates pass:**
```
STANDALONE SEVERITY:  [tier of the strongest single leg]
CHAINED SEVERITY:      [higher tier — argued in the report body, committed in SEVERITY-COMMIT as the ceiling]
CHAIN PATH:             [A] --(proven pivot)--> [B] --> [observed final impact + loss=$X]
```
Feed the CHAINED tier into the EV Calculation below. If any gate fails, feed the standalone tier and move on.

**Anti-pattern (the reason this question is gated this hard):** a generic skill that says
"Medium + Medium = Critical, that's where $500 becomes $5K" trains you to *assume* the chain and write the
big number first. That is exactly the inflation that gets reports closed (Superform F-001, the fee-payer-key
"Critical" overturned to Medium). The chain is real only when the pivot is an artifact you can paste.

---

## EV Calculation (MANDATORY)

```
Domain:             [ ] defi / [ ] fintech / [ ] openbanking / [ ] payment_infra
Platform:           [HackerOne/Bugcrowd/Intigriti/Direct/GHSA/C4/Cantina]
Severity:           [Critical/High/Medium/Low]
Estimated payout:   $[amount]

P(acceptance):      [0.00-1.00]
  base_rate:        [from §8.4 domain-calibrated table — SEE BELOW]
  × (1 - known_issue_risk):   [0.00-1.00]
  × (1 - scope_risk):         [0.00-1.00]
  × (1 - design_intent_risk): [0.00-1.00]
  × multiplier:               [regulatory=1.3 | on-chain-proof=1.2 | blast-radius>100=1.2
                                | sandbox-only=0.6 | view-function=0.7 | known-class=0.5]

  Domain base_rates (from OUTCOMES.jsonl calibration):
  ┌──────────────┬──────────────────┬───────────┬────────────────────────┐
  │ Domain       │ Platform         │ base_rate │ Typical payout range   │
  ├──────────────┼──────────────────┼───────────┼────────────────────────┤
  │ defi         │ Direct           │ 0.40      │ $5K-$50K (Critical)    │
  │ defi         │ C4 (High)        │ 0.15      │ $5K-$25K               │
  │ defi         │ C4 (Med)         │ 0.25      │ $1K-$10K               │
  │ defi         │ Cantina bounty   │ 0.30      │ $1K-$25K               │
  │ fintech      │ HackerOne        │ 0.35      │ $500-$25K              │
  │ fintech      │ Bugcrowd         │ 0.30      │ $500-$15K              │
  │ fintech      │ Intigriti        │ 0.25      │ $100-$10K              │
  │ openbanking  │ Direct to bank   │ 0.45      │ €1K-€15K               │
  │ openbanking  │ Via regulator    │ 0.50      │ N/A (compliance fix)   │
  │ payment_infra│ GHSA+downstream  │ 0.60      │ $0 CVE + N×bounty      │
  │ payment_infra│ SDK vendor       │ 0.40      │ $500-$25K              │
  └──────────────┴──────────────────┴───────────┴────────────────────────┘
  NOTE: These rates will be recalibrated quarterly from OUTCOMES.jsonl data.
  Current rates are estimates — update after 20+ outcomes per domain.

Time estimate:      [hours]h × $75/h = $[cost]
Confidence:         [ ] HIGH (>70%) / [ ] MEDIUM (40-70%) / [ ] LOW (<40%)

EV = [P(acceptance)] × $[payout] - $[cost] = $[result]

Decision: [ ] STRONG GO (>$5K)
          [ ] GO ($1K-$5K)
          [ ] WEAK GO ($200-$1K) — fast track only, <4h total
          [ ] SKIP (<$200)

For payment_infra (multiplication model):
  EV_total = EV_cve + Σ(EV_downstream_bounty_i)
  Example: cbor-extract CVE ($0) + @simplewebauthn bounty ($5K) + 2 IoT bounties ($3K each) = $11K total
```

---

## Final Verdict

```
Time spent on gate: [MM] min (max 30)
Kill Gate passed:   [ ] YES → PROCEED to report writing
                    [ ] NO  → KILLED — reason: [Q# that failed]
                    [ ] DOWNGRADE — proceed at lower severity: [new severity]

If KILLED, document WHY (prevents re-investigating the same dead end):
Reason: _______________________________________________
```

---

## Anti-Dismissal Research (launch in parallel if PROCEED — 10-15 min)

| Phase | Task | Tool | Deliverable |
|-------|------|------|-------------|
| 3a | Internal Consistency Scan | Grep/Explore | `try\|defensive\|prevent\|protect` count + instances |
| 3b | Precedent Audit Research | WebSearch | 3+ precedents C4/Sherlock with severity + judge quotes |
| 3c | External Dependency Defense | WebSearch | Pause history, blacklist activity, governance actions |
| 3d | Prior Audit Differentiation | WebSearch + gh CLI | 6-axis table vs each similar finding |

**Output:** Dismissal vector matrix fully populated with evidence.

---

## War Log Reference — Lessons Encoded in This Gate

| # | Lesson | Source | Gate Question |
|---|--------|--------|---------------|
| L1 | Mock-based PoC = instant rejection (Solidity) | Ethena Feb 15 | (PoC phase) |
| L2 | wrapper → underlying conversion = by design | Ethena Feb 16 | Q1 |
| L3 | Code path unreachable in scoped binary | Firedancer Feb 17 | Q2 |
| L4 | Vault $0 = dormant program | Immunefi | EV gate |
| L5 | ERC compliance (optional features) ≠ bug | Beanstalk | Q6 |
| L6 | Verify EIP-1967 before claiming proxy | Ethena StakedUSDeV2 | Q7 |
| L7 | Auditor published on vuln class + audited = 90% known | CoinFabrik | Q8 |
| L8 | Overselling severity = permanent credibility damage | Multiple | EV/Severity |
| L9 | bank-run argument unchecked against `saturating_sub` | Jupiter #3 | Dismissal Matrix |
| L10 | 1-year fantaisiste extrapolation in PoC | Jupiter #4 | Dismissal Matrix |
| L11 | Ignoring surgical Out-of-Scope exclusions | Multiple | Q6/scope |
| L12 | Count affected deployments ("7 across 3 chains") | ENS | Impact |
| L13 | Note absence of recovery mechanisms | ENS | Dismissal Matrix |
| L14 | Strongest finding first → credibility bias | ENS campaign | (submission order) |
| L15 | On-chain state verification = differentiator | Concrete Earn Feb 23 | Q10 |
| L16 | Cross-chain: validate source chain AND address (not just one) | CrossCurve $3M | Q2/Q4 |
| L17 | MEV: pre-gate exclusion check BEFORE analysis | Multiple programs | Q5 pre-gate |
| L18 | Supply chain: devDependencies don't execute in prod | Multiple | Q2 |
| L19 | Proxy chain: trace FULL chain, not just immediate admin | Bybit $1.4B | Q7 |
| L24 | Intermediate-state exploit dies if a t=0 MEV/arb/liq actor resets the window before it matures | Ammalgam saturation (120-day window) | Q5b |

---

## Domain-Specific Kill Gate Extensions

### Supply Chain (§F2.4 / §6b.13)
- **Q2 (Reachability):** Is the malicious/vulnerable package actually imported in the PRODUCTION build? (devDependencies don't count)
- **Q6 (Known):** Already flagged by socket.dev or npm audit? If yes → near-certain known.

### Proxy Upgrade Chain (§6.3 / §F4.1)
- **Q7 (Upgradeability):** EXPANDED — resolve the FULL chain (EOA → Safe → Timelock → ProxyAdmin → Proxy → Impl), not just "is it a proxy?"
- **Q5 (Feasibility):** Can the weakest link in the chain be exploited realistically?

### Cross-Chain Messaging (§3.5)
- **Q2 (Reachability):** Is the vulnerable receiver callable from the source chain without privileged access?
- **Q5 (Feasibility):** Does attacker need to control a relayer/DVN, or can they craft a message directly?

### MEV Structural (§5.3)
- **Custom pre-gate:** Does the program exclude frontrunning/MEV/sandwich? If YES → auto-KILL.
- **Q5 (Feasibility):** Is MEV extraction quantifiably > 0.1% TVL/year?
- **Q5b (Window-Actor):** Does your exploit need a transient state to PERSIST? Then MEV/arb/liq bots resetting it are the DEFAULT, present at t=0 — the finding dies unless you prove the reset is unprofitable for them. Not a future risk; a t=0 constant.

### Off-Chain Infra (§F3.4-F3.6)
- **Q2 (Reachability):** Is the exposed endpoint actually used by the production application?
- **Q5 (Feasibility):** Can the exposure be exploited remotely without physical access?

### Fintech (§FIN-1→4) — NEW
- **Q5 (Feasibility):** Can the bug be triggered with a real (non-sandbox) account? Sandbox-only bugs have lower EV (×0.6 multiplier).
- **Q6 (Known):** Search HackerOne Hacktivity for same platform + vuln class. Fintech programs get many dupes on common patterns (IDOR, rate limit bypass).
- **Q13 (Regulatory Impact):** Does this finding violate PSD2 (Art. 97 SCA, Art. 67 consent), PCI-DSS (Req. 6.5, 8.3), or SOX? Regulatory violations are harder to dismiss → ×1.3 EV multiplier.

### Open Banking (§OB-1→5) — NEW
- **Q13 (Regulatory Impact):** Cite specific PSD2/RTS article violated. Banks face fines up to €5M or 4% turnover for non-compliance.
- **Q14 (Sandbox vs Production):** Is the finding confirmed on production API or sandbox only? Sandbox-only findings have significantly lower value (many sandbox impls differ from prod). If sandbox-only → ×0.6 multiplier but still PROCEED if regulatory violation.

### Payment Infrastructure (§3.2-3.4) — NEW
- **Q15 (Downstream Blast Radius):** Count weekly downloads + direct dependents. Used to compute multiplication model EV: 1 CVE → N downstream bounty reports.
- **Q6 (Known):** Search CVE database + GitHub security advisories for same library + vuln class.
- **Q2 (Reachability):** For SDK findings: is the vulnerable code path reachable via the public API that developers actually call?

| L16 | Prove bug condition is LIVE with block number | Concrete USDT vault $38M | Q10 |
| L20 | Sandbox ≠ production — always verify finding on prod API | Open Banking | Q14 |
| L21 | Regulatory reference (PSD2 Art. X) makes findings undismissable | Open Banking | Q13 |
| L22 | Payment SDK CVE × N downstream bounties = multiplication EV | cbor-extract | Q15/EV |
| L23 | Race conditions on balance checks = fintech-specific critical | Neobank pattern | §FIN-1 |
