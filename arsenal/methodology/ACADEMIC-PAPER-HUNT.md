# ACADEMIC-PAPER-HUNT — Security papers → live protocol hunt

New attack papers publish monthly on eprint.iacr.org, ACM CCS, IEEE S&P, USENIX Security.
Many propose attacks against primitives that LIVE protocols use without mitigation.
First-mover advantage: apply new paper's attack to live deployments before the paper's proposed mitigation propagates.

## Why this works

- Academic papers describe attacks in abstract — "FROST with weak coalition" — without naming deployed protocols
- Papers often mitigation-propose without implementation
- Protocol teams rarely monitor academic crypto venues
- 6-12 month window between paper publication and industry patching
- Novel attacks aren't in existing CVE databases, scanners miss them

## Pipeline

### Step 1: Subscribe sources

```bash
# eprint RSS (IACR preprints)
RSS: https://eprint.iacr.org/rss/rss.xml

# ACM CCS, IEEE S&P — post-conference
# Subscribe to proceedings announcements

# arXiv cs.CR
RSS: http://export.arxiv.org/rss/cs.CR

# Venues with crypto focus
- USENIX Security (yearly, August)
- NDSS (yearly, February)
- ASIACRYPT, EUROCRYPT, CRYPTO (IACR conferences)
- FC (Financial Cryptography, yearly)
- AFT (Advances in Financial Technologies)

# Curated aggregators
- crypto twitter — tpbcsecurity, rachelbythebay (sometimes)
- Blog: ethresear.ch, zkresear.ch, a16z crypto blog
```

### Step 2: Filter

Per paper, score crypto/DeFi relevance (0-10):

| Signal | +Points |
|---|---|
| Attack on standardized primitive (FROST, Schnorr, BLS, PLONK, Groth16) | +4 |
| Names specific protocol/implementation in abstract | +3 |
| Applied cryptography (not pure theory) | +2 |
| DeFi / blockchain specifically | +3 |
| MPC / threshold / wallet related | +3 |
| Oracle / MEV / sandwich related | +2 |
| ZK circuit bugs / soundness | +3 |
| L2 / rollup / DA specific | +3 |
| Cross-chain bridge attack | +3 |
| Compiler / toolchain security | +2 |

Score ≥ 6 → read abstract + intro in full.
Score ≥ 8 → deep read + identify live targets.

### Step 3: Extract attack primitive

For each relevant paper:
- What is the vulnerable primitive (abstract)?
- What are the preconditions for the attack?
- What is the mitigation (if proposed)?
- Is PoC code / math provided?

### Step 4: Find live deployments

For each vulnerable primitive:

```bash
# Example: paper attacks "FROST with biased nonce generation"
# Search for FROST deployments:
gh code search "FROST" "signing_nonce" --language=rust
gh code search "threshold_schnorr" --language=go
# Also: search protocol documentation for "threshold signature"

# Example: paper attacks "PLONK with malleable commitment"
# Find live PLONK verifiers:
gh code search "PlonkVerifier\|verifyProof.*plonk" --language=solidity
```

### Step 5: Test the attack

- Clone the target deployment
- Recreate the paper's preconditions
- Attempt the attack (PoC)
- If successful: severity assessment + disclosure

### Step 6: Disclose fast

First-mover matters here. The protocol team likely hasn't read the paper.

Disclosure framing:
> "Paper [author, venue, URL] describes an attack on [primitive]. This protocol's implementation at [file:line] is vulnerable because [specific match to preconditions]. PoC attached."

## Paper → live protocol matching templates

### Template 1: "Attack on [MPC primitive]"

Find: deployed protocols using the exact primitive (e.g., tss-lib, Serai, Lit, Silence Laboratories).
Check: does implementation include the specific mitigation (often post-dates the paper)?
PoC: replay the paper's attack against the deployed primitive.

### Template 2: "ZK circuit X has soundness flaw"

Find: circuits built using the flawed pattern (circomlib, halo2 recipe, etc.)
Check: live deployments using the circuit
PoC: generate the forgeable proof

### Template 3: "Oracle attack Y"

Find: protocols reading the oracle described
Check: does oracle consumer implement protection (TWAP, deviation check)?
PoC: replay oracle manipulation with on-chain PoC

### Template 4: "Bridge replay attack Z"

Find: bridges matching the described architecture
Check: message nonce / chain ID binding
PoC: cross-chain replay demonstration

### Template 5: "Consensus fork attack"

Find: consensus clients / blockchains
Check: does client implement the mitigation
PoC: construct the attacker block sequence, test on fork

## Recent paper examples to watch

- **"ROAST: Robust Asynchronous Schnorr Threshold Signatures"** (2022) — canonical source on FROST, each "improvement" in variants is a potential bug surface
- **"Nova: Recursive Zero-Knowledge Arguments from Folding Schemes"** — every Nova-based system is a target
- **"Lookup Arguments: Improvements, Extensions, and Applications to Zero-Knowledge Decision Trees"** — halo2 lookup variants
- Various papers on **MEV attacks on AMMs** — each specific DEX implementation is a target
- **"Bypassing Isolation in eBPF"** and similar — for blockchain nodes using eBPF

## Tool: `~/arsenal/tools/eprint-rss-monitor.sh`

Skeleton:
```bash
#!/bin/bash
# Subscribe eprint RSS, filter by keywords, emit to trackable log
KEYWORDS="FROST|threshold|MPC|PLONK|halo2|Nova|bridge|oracle|MEV|sandwich|rollup|zkEVM"
curl -s https://eprint.iacr.org/rss/rss.xml | \
  xmlstarlet sel -t -m "//item" -v "pubDate" -o " | " -v "title" -o " | " -v "link" -n | \
  grep -iE "$KEYWORDS" > ~/arsenal/tracking/eprint-candidates.log
```

Cron daily. Manual triage weekly.

### LLM-based summarization

```bash
# For each high-score paper:
# - Fetch PDF via eprint link
# - LLM summarizes abstract + intro in 10 lines
# - LLM extracts: attack primitive, preconditions, mitigation, whether PoC given
# - Output to tracking/eprint-triage-YYYY-MM.md
```

## Integration with lifecycle

```bash
TARGET_HINTS="academic-paper-hunt" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <paper>-live-hunt
```

## ROI assessment

- Setup: 2-4h weekly for triage
- Per-paper to-target-to-PoC: 10-40h depending on primitive complexity
- Hit rate: 1 paper in 30 yields a live bug worth disclosing
- Payout per hit: $5K-$500K depending on target (direct disclosure often valued highly)

**Best papers for this method:**
- Papers citing specific deployed protocols
- Papers with PoC code already provided
- Papers on crypto primitives used widely (BLS, Schnorr, FROST, PLONK)

**Skip:**
- Pure theory papers without attack construction
- Papers proposing new primitives (not attacks)
- Papers with mitigations already deployed

## Known recent wins (ghost-precedent)

- **2023 Ethresearch "Sandwich attack variant"** → applied to live DEXes, published as advisory
- **2024 eprint "FROST state machine violation"** → tested against Serai (submitted, dismissed — lesson)
- **2024 "halo2 lookup argument bug"** → checked zkEVMs (zkSync, Scroll) — patches unclear
- **Academic "Oracle manipulation via ERC-20 donation"** → chased protocols using custom TWAP

## Cadence

- Daily: eprint-rss-monitor.sh (automated)
- Weekly: triage top-3 score-6+ papers (2h)
- Monthly: deep-dive 1 high-score paper (40h)
- Continuous: disclose as PoCs confirm

## Disclosure strategy

When a paper proposes an attack, the community knows the attack exists but rarely applies it to deployed systems. Your value = converting abstract attack to concrete PoC on their deployment.

Frame:
> "Paper [title, venue, URL] describes an attack on [primitive]. This protocol's [file/function] matches the preconditions: [specific technical match]. PoC executing the attack attached, running against [current HEAD / fork at block N]."

Disclose to paper authors AS WELL (courtesy, they may already be tracking deployments).
