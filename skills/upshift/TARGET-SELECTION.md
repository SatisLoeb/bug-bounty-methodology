---
name: target-selection
description: Candidate profile + triage scoring rubric + manually-curated queue mechanism for Upshift-class targets. Criteria: TVL>$50M, backend that signs on-chain transactions in response to off-chain events, executor/operator wallet pattern, bounty program OR responsive direct-disclosure profile. Triage scoring 0-10 across 5 dimensions. /upshift --triage <target> runs 30-min scoring pass. /upshift --engage <target> on score 7+.
---

# Target selection -- candidate profile + triage queue

## The candidate profile

Upshift-class targets share an architectural shape that makes them disproportionately vulnerable to the 10-vector methodology in SURFACE-ATTACK-PATTERNS.md. The shape:

**Core pattern:** A backend that signs on-chain transactions in response to off-chain events.

**Typical instances:**
- Delta-neutral stablecoins (Ethena, Resolv, USDX, Falcon, Reservoir, Avalon)
- RWA tokenized accounts (Upshift, Veda, Aera, Mellow, Steakhouse Financial)
- Yield aggregators with keepers (Yearn V3, Sommelier, Index Coop, Reserve, Pendle V2)
- LRTs / restaking with executor wallets (Renzo, Kelp, Puffer, Etherfi, Symbiotic, Karak, Lombard)
- Perp DEXes with off-chain matching (Hyperliquid front-end, GMX-Solana, Drift, Orderly, RabbitX)
- Vault curators on Morpho/Euler (Gauntlet, Steakhouse, Re7, Re7 Labs, Apostro, Block Analitica, B Protocol)
- HyperEVM cluster (Felix, Ambit, Hyperdrive, Theo, Hyperdash, Reactor, Looped, Upshift itself)
- Cross-chain liquidity hubs with relayers (Stargate, LayerZero adapters, Across, Wormhole adapters)

**The shared blind spot:** Contracts are audited by a known firm (Spearbit, ChainSecurity, Code4rena, Cantina, Sherlock, OpenZeppelin). The API + infrastructure + frontend + executor wallet layer is treated as a normal web project, audited by no one specific to crypto, often built by a separate team or vendor that has never coordinated with the SC team.

This split-between-disciplines creates the F1-class finding (off-chain → on-chain trigger with no auth) and the W34-class finding (executor credential in public bundle). Both classes are not in any auditor's standard checklist because the SC auditor sees only the contract and the web auditor sees only the frontend. Nobody owns the seam.

## Hard criteria for inclusion in the queue

A target enters the queue if and only if:

1. **TVL > $50M** (DeFiLlama or protocol's own TVL endpoint). Below $50M, ex-gratia ceiling is too low to justify the engagement depth.

2. **Backend signs on-chain transactions in response to off-chain events.** Concrete signals:
   - Existence of an `executor`, `operator`, `keeper`, `relayer`, `bot`, or `manager` EOA on-chain that submits transactions
   - Existence of a public-facing API at `api.target.com` or similar that triggers contract calls
   - Frontend bundle that contains environment variables suggesting backend integration (`VITE_*`, `NEXT_PUBLIC_*`, `process.env.*`)
   - Documentation mentioning "automated rebalancing", "dynamic allocation", "off-chain signing", "centralized matching"

3. **Direct disclosure path exists.** Either:
   - Bug bounty program on Immunefi/HackenProof/Cantina/Sherlock/H1 (NB: user has Immunefi boycott; use other platforms instead)
   - `security@target.com` or `security.txt` with a real contact
   - CTO/CEO publicly reachable (LinkedIn, X, GitHub) and historically responsive

4. **NOT in active V12 AI-auditor coverage** (per CLAUDE.md preflight). Check `~/arsenal/audit-lifecycle/bin/ai-bot-check.sh <owner/repo>` -- if the target's main repo has the v12-auditor / Olympix / Cantina AI bot installed, V12-class findings (access control, input validation, reentrancy, unchecked arithmetic) have structurally high dupe risk. The Upshift methodology is largely orthogonal to V12 (off-chain primitives, chain construction, mirror invariant audits) -- but the finding mix needs adjustment in this case.

## Triage scoring rubric (0-10 per dimension, 30-min pass)

When `/upshift --triage <target>` is invoked, score the target on 5 dimensions. Total score 35-50 = engage. Below 35 = park.

### Dimension 1: Architectural mollesse (0-10)

How "soft" is the off-chain layer architecturally? Higher = more findings.

| Score | Signal |
|---|---|
| 10 | OpenAPI schema publicly exposed at `/openapi.json` or `/docs`; admin routes visible in JS bundle |
| 8 | Backend documented in protocol docs with full endpoint list |
| 6 | Backend exists but undocumented; routes must be enumerated from JS bundle |
| 4 | Backend partially abstracted behind a CDN/edge function (Cloudflare Workers, Vercel Edge) |
| 2 | Backend fully abstracted, routes only inferable from frontend behavior |
| 0 | No backend (pure on-chain protocol) |

### Dimension 2: Surface size (0-10)

How many distinct services, subdomains, and routes does the protocol expose?

| Score | Signal |
|---|---|
| 10 | 5+ subdomains (api, app, docs, staging, dev, etc.) + 50+ routes inferable |
| 8 | 3-4 subdomains + 30+ routes |
| 6 | 2-3 subdomains + 15-30 routes |
| 4 | 1-2 subdomains + 5-15 routes |
| 2 | Single subdomain + <5 routes |
| 0 | No web surface |

### Dimension 3: Executor pattern presence (0-10)

How clearly does the protocol exhibit the executor/operator/keeper EOA pattern?

| Score | Signal |
|---|---|
| 10 | Operator EOA explicitly named in docs + visible in tx history + holds privileged on-chain roles + appears to be single-key (no multisig) |
| 8 | Operator EOA visible on-chain but role split across 2-3 EOAs |
| 6 | Operator role exists but routed through a Safe with low threshold (1-of-2, 2-of-3) |
| 4 | Operator role exists but routed through a Safe with reasonable threshold (3-of-5+) |
| 2 | Operator role exists but routed through a Timelock + Safe combo |
| 0 | No executor pattern (admin actions are user-initiated only) |

### Dimension 4: Audit recency (0-10) -- INVERTED

How recently was the protocol audited? Lower recency = higher score (more drift accumulated since audit).

| Score | Signal |
|---|---|
| 10 | Last audit >12 months ago, codebase has shipped features since |
| 8 | Last audit 6-12 months ago, multiple post-audit commits |
| 6 | Last audit 3-6 months ago, few post-audit commits |
| 4 | Last audit 1-3 months ago |
| 2 | Last audit <1 month ago |
| 0 | Currently in audit (active engagement) |

### Dimension 5: Bounty signal (0-10)

How likely is the protocol to pay (formal or ex-gratia) on a substantive disclosure?

| Score | Signal |
|---|---|
| 10 | Active bounty program with publicly-paid bounties in the last 6 months at Critical tier |
| 8 | Active bounty program but no recent payouts visible OR strong direct-disclosure history (acked previous disclosures within 14 days, paid ex-gratia) |
| 6 | No bounty program but CEO/CTO publicly engaged with security researchers (responded to Twitter mentions, attended DefCon, etc.) |
| 4 | No bounty program, no public security engagement, but VC-backed protocol (capital available) |
| 2 | No bounty program, no engagement, indie/community-driven |
| 0 | Protocol abandoned (no recent commits, no active team) |

### Total score interpretation

| Total | Action |
|---|---|
| 40-50 | STRONG ENGAGE -- prioritize, allocate full immortal-mode session |
| 35-39 | ENGAGE -- standard engagement, monitor for surprises |
| 25-34 | PARK -- watch the queue, re-triage in 60 days if no movement |
| 15-24 | LOW PRIORITY -- only engage if hunter has spare capacity |
| 0-14 | DO NOT ENGAGE -- score does not justify the effort |

## How to triage a new target (30-min pass)

```bash
# Invoked via /upshift --triage <target>
# Outputs: ~/Desktop/BUGS/<target>-recon/TRIAGE.md

TARGET="$1"  # e.g., "ethena"

mkdir -p ~/Desktop/BUGS/${TARGET}-recon
cd ~/Desktop/BUGS/${TARGET}-recon

# Step 1: TVL check (5 min)
curl -s "https://api.llama.fi/protocol/${TARGET}" | jq '.tvl[-1].totalLiquidityUSD' > tvl.txt

# Step 2: Backend discovery (10 min)
# Find subdomains
amass enum -passive -d ${TARGET}.com 2>/dev/null | sort -u > subdomains.txt
amass enum -passive -d ${TARGET}.io 2>/dev/null | sort -u >> subdomains.txt
amass enum -passive -d ${TARGET}.fi 2>/dev/null | sort -u >> subdomains.txt
sort -u subdomains.txt > tmp && mv tmp subdomains.txt

# Find OpenAPI / docs
for sub in $(cat subdomains.txt); do
  for path in "/openapi.json" "/docs" "/api/docs" "/swagger.json"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" "https://${sub}${path}")
    [ "$status" = "200" ] && echo "${sub}${path}" >> openapi-found.txt
  done
done

# Step 3: Frontend bundle scan (5 min)
curl -s "https://app.${TARGET}.com" | grep -oE 'index-[A-Za-z0-9]+\.js' | head -1 > bundle-name.txt
BUNDLE_NAME=$(cat bundle-name.txt)
curl -s "https://app.${TARGET}.com/assets/${BUNDLE_NAME}" > bundle.js
grep -cE '(VITE_|NEXT_PUBLIC_|process\.env)' bundle.js > env-var-count.txt
grep -cE '0x[a-fA-F0-9]{40}' bundle.js > address-count.txt

# Step 4: Operator wallet discovery (5 min)
# (Manual: read protocol docs, find named operator/executor EOA)
echo "MANUAL: read docs, identify operator/executor address" > operator-todo.txt

# Step 5: Audit recency (3 min)
# Check protocol's audit page; alternative: check GitHub for /audits or /reports folder
echo "MANUAL: confirm last audit date" > audit-todo.txt

# Step 6: Bounty check (2 min)
# Check Immunefi (boycotted, but use for recon), HackenProof, Cantina, H1, Sherlock
echo "MANUAL: bounty platform check" > bounty-todo.txt

# Output triage card
cat > TRIAGE.md <<EOF
# Triage card -- ${TARGET}

## Hard criteria
- [ ] TVL > $50M: $(cat tvl.txt)
- [ ] Backend signs on-chain (operator/executor pattern visible): ?
- [ ] Direct disclosure path: ?
- [ ] NOT under v12-auditor coverage: ?

## Scoring
- Dimension 1 (Architectural mollesse): _/10
- Dimension 2 (Surface size): _/10
- Dimension 3 (Executor pattern presence): _/10
- Dimension 4 (Audit recency): _/10
- Dimension 5 (Bounty signal): _/10
- TOTAL: _/50

## Action
- [ ] STRONG ENGAGE (40-50)
- [ ] ENGAGE (35-39)
- [ ] PARK (25-34)
- [ ] LOW PRIORITY (15-24)
- [ ] DO NOT ENGAGE (0-14)

## Raw evidence
- Subdomains: $(wc -l < subdomains.txt) found
- OpenAPI exposure: $(wc -l < openapi-found.txt 2>/dev/null || echo 0) endpoints
- Frontend bundle env vars: $(cat env-var-count.txt) hits
- Frontend bundle addresses: $(cat address-count.txt) hits
EOF

echo "Triage card ready at: ~/Desktop/BUGS/${TARGET}-recon/TRIAGE.md"
```

## Initial queue (v1: Upshift only, manually curated per user's explicit instruction)

The queue lives at `~/.claude/projects/-home-malix-Desktop-BUGS/memory/upshift_target_queue.md`. v1 contains only Upshift (the source-of-methodology engagement, currently in `engagement_active` state).

Future targets are added manually after triage. The user explicitly chose "alimentation manuelle" -- automated triage of new candidates is OUT OF SCOPE for v1. v2 may add an automated discovery feed pulling from DeFiLlama + bounty platform indexers.

## Candidate pool (NOT queued, kept here for reference)

The following protocols match the architectural shape and are candidates for future triage. They are NOT in the queue until manually scored. Listed in roughly descending TVL order:

### Tier 1 candidates (TVL > $1B, executor pattern confirmed)

- **Ethena** (USDe / sUSDe) -- delta-neutral stablecoin, off-chain hedging via centralized exchanges, keeper bots for rebalancing
- **Renzo** (ezETH) -- LRT, executor wallet for delegation rebalancing
- **Kelp DAO** (rsETH) -- LRT, similar executor pattern to Renzo
- **Puffer Finance** (pufETH) -- LRT with native restaking
- **Etherfi** (eETH / weETH) -- LRT, large executor footprint across multiple chains
- **Symbiotic** -- restaking primitive with vaults curated by external operators
- **Karak** -- restaking layer with reward distributor pattern
- **Lombard** (LBTC) -- BTC LRT with off-chain custodian + on-chain mint/burn
- **Pendle V2** -- yield trading protocol with operator-managed pools

### Tier 2 candidates (TVL $200M-$1B)

- **Resolv** (USR / RLP) -- delta-neutral, similar to Ethena
- **Falcon Finance** (USDf) -- delta-neutral stablecoin
- **Reservoir** -- delta-neutral
- **Avalon Finance** -- BTC LRT
- **Mellow Protocol** -- LRT vault curator infrastructure
- **Veda** -- vault curation with multi-strategy execution
- **Aera** -- vault management with off-chain rebalancing
- **Sommelier** -- yield aggregator with strategist execution
- **Index Coop** -- on-chain index funds with rebalancing
- **Reserve Protocol** -- RToken architecture with auctions
- **MorphoBlue Curators** (Gauntlet / Steakhouse / Re7) -- vault curators with allocation execution
- **Gauntlet vaults** -- managed vaults across Aave/Compound/Morpho

### Tier 3 candidates (TVL $50M-$200M, HyperEVM cluster)

- **Felix** (HyperEVM) -- LRT on Hyperliquid
- **Ambit** -- HyperEVM lending
- **Hyperdrive** -- HyperEVM perp aggregator
- **Theo** -- HyperEVM yield protocol
- **Hyperdash** -- HyperEVM analytics with executor wallets
- **Reactor** -- HyperEVM yield
- **Looped** -- HyperEVM looping vaults
- **Upshift / August Digital** -- ALREADY IN QUEUE (engagement active)

### Tier 4 candidates (cross-chain infrastructure adjacent)

- **Across Protocol** -- cross-chain bridge with relayer pattern
- **LayerZero adapters** (any high-TVL OFT) -- relayer + executor pattern
- **Stargate** -- bridge with relayer pattern
- **Wormhole adapters** -- guardian + relayer pattern
- **Hyperlane** -- modular interop with validator+relayer pattern
- **Connext / Chain.link CCIP** -- cross-chain messaging with executors

## Workflow: from candidate pool to queue

```
Candidate pool (this file)
    ↓ (user decides to triage)
/upshift --triage <target>
    ↓ (30-min triage pass produces TRIAGE.md)
Score 35+? 
    ↓ YES                                ↓ NO
Add to queue (memory/upshift_target_queue.md)    Park, re-triage in 60 days
    ↓
/upshift --engage <target>
    ↓ (full immortal-mode engagement begins)
Move queue entry from "ready" → "active"
    ↓ (engagement runs through Pass 1-4 + disclosure stages 1-4)
Engagement closed
    ↓
Move queue entry from "active" → "alumni"
```

## Anti-pattern: chasing TVL alone

A high TVL with a hard architectural surface (e.g., Aave, Maker, Liquity) is NOT an Upshift-class target. Those protocols have:
- No executor wallet (admin actions are governance-only)
- No off-chain → on-chain trigger backend (everything is user-initiated)
- Hardened web layer (no API, no operator)

These are auditor-saturated targets. The Upshift methodology does not apply. Do not waste an immortal-mode session on them.

The Upshift methodology specifically targets protocols where the architectural shape creates the F1+W34 class of finding. If the shape is not present, the methodology is irrelevant.
