# INDEXER-DRIFT-HUNT — Indexer vs Contract state drift

The Graph, Goldsky, Envio, Ponder, SubSquid, Synchronous (Pyth), Tenderly.
Every DeFi frontend depends on indexers. Indexer bug = silent fund divergence.
Almost no hunters here because (a) it requires running indexer infrastructure, (b) bounty rarely formal,
(c) it's "frontend adjacent" — looked down on. But the $$ impact is real when frontend calculates withdrawable amount and protocol calcs differ.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| IDX-001 | Schema-contract drift — subgraph assumes field X exists, contract upgrade removed it → frontend shows wrong | compare subgraph schema.graphql to current ABI |
| IDX-002 | Reorg handling — indexer doesn't re-process on chain reorg, state diverges from canonical | check indexer's reorg policy |
| IDX-003 | Event-method mismatch — event emitted with wrong params (not validated on-chain), indexer trusts event | find emit statements in contract that aren't mirrored in method behavior |
| IDX-004 | BigInt overflow in mapping — subgraph AssemblyScript math on huge values | `grep -rn "BigInt.fromString\|BigInt.fromI32"` in mapping.ts |
| IDX-005 | Block-time vs timestamp drift — mapping uses block.timestamp, indexer uses processedAt; vars diverge | diff mapping.ts vs contract timestamp source |
| IDX-006 | Multi-chain aggregation — cross-chain balance sum fails on one chain, total wrong | check aggregation across `ChainId` param |
| IDX-007 | Checkpoint replay — indexer restart replays events, double-credit | check event idempotency via unique event ID |
| IDX-008 | Token decimals mishandling — indexer normalizes with wrong decimals | `grep -rn "decimals\|normalize.*18"` in mapping |
| IDX-009 | RPC data source — indexer fetches via RPC (contract view call), RPC returns stale/manipulated data | find `ethereum.call` in mapping.ts |
| IDX-010 | Frontend trust in indexer — frontend calculates withdrawable based on indexer, user withdraws more than contract allows → contract absorbs loss or reverts user | grep frontend for `subgraph.*withdrawable\|indexed.*balance` |
| IDX-011 | Stale cursor — indexer cursor doesn't advance on events with no relevant data, missed | check cursor update logic |
| IDX-012 | ERC721 transfer indexing — mint/burn vs transfer — indexer miscounts ownership | `grep -rn "Transfer\|TransferBatch"` in mapping |

## Targets

Any DeFi/NFT protocol with a subgraph. Priority:
- **High TVL, complex math:** Aave, Compound, Morpho, Maker, Liquity, Spark, Pendle, Curve
- **NFT finance:** Blur, BendDAO, NFTfi, Arcade, MetaStreet
- **Gaming economies:** Axie, Gods Unchained, Sorare
- **Appchain aggregators:** Polymarket, Stargate, Across (cross-chain)

Bounty path: Usually no direct bounty on indexer bugs. Disclose to protocol team. Some pay $5K-$50K. **Filing via protocol's security@ with POC showing frontend-vs-contract drift is the lever.**

## Grep arsenal

```bash
# Find subgraph in repo
find . -name "subgraph.yaml" -o -name "schema.graphql"

# Mapping handlers
grep -rn "handleEvent\|export function handle" src/*.ts

# BigInt math (overflow risk)
grep -rn "BigInt.fromString\|BigInt.fromI32\|\.plus\(\|\.times\(" src/*.ts

# RPC view calls in mappings
grep -rn "ethereum.call\|.try_.*\.call\|contract.try_" src/*.ts

# Decimals normalization
grep -rn "18\|decimals" src/*.ts

# Frontend subgraph queries
grep -rn "useQuery\|useSubgraph\|gql" frontend/ app/

# Reorg handling
grep -rn "block.number\|block.hash\|reorg" src/*.ts
```

## Methodology (per target, 10-20h — fast)

1. **Clone the subgraph repo** (`thegraph.com/explorer` → repo link).
2. **Run it locally against an archive node** OR use hosted Graph indexer.
3. **Query for known entities** (user balances, positions). Compare to `cast call` on contract.
4. **Fuzz**: for N random users with positions, query indexer vs contract, diff.
5. **Edge case test**: after a reorg, does indexer re-sync correctly?
6. **Frontend audit**: does the dApp use subgraph results to calculate `maxWithdraw` / `liquidation threshold` that is then NOT validated on-chain? → indexer-trust vulnerability.
7. **BigInt overflow**: find mapping.ts arithmetic. Does it handle `type(uint256).max`?

## PoC pattern

```python
# indexer-vs-contract.py
import subprocess, json, requests

SUBGRAPH_URL = "https://api.thegraph.com/subgraphs/name/aave/protocol-v3"
RPC = "https://eth-mainnet.g.alchemy.com/..."

def query_subgraph(addr):
    q = f'{{ userReserves(where: {{user: "{addr}"}}) {{ currentATokenBalance scaledATokenBalance }} }}'
    r = requests.post(SUBGRAPH_URL, json={"query": q})
    return r.json()

def query_contract(addr, atoken):
    # cast call aToken.balanceOf(user)
    result = subprocess.check_output(["cast", "call", atoken, "balanceOf(address)(uint256)", addr, "--rpc-url", RPC])
    return int(result.decode().strip().split()[0])

# For N random users: diff subgraph vs contract
# Any mismatch > 1 wei (accounting for rounding) = candidate finding
```

## Integration with lifecycle

```bash
TARGET_HINTS="indexer subgraph" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh aave-v3-indexer-audit
```

## Tool requirements

- `indexer-vs-contract.py` — fuzz user addresses, diff subgraph vs contract on balances
- `subgraph-schema-drift.sh` — diff current subgraph schema against latest deployed ABI, flag removed/renamed fields
- Integration with post-audit-drift-monitor — after protocol upgrade, auto-diff subgraph

## Disclosure strategy

- **Indexer bug ALONE:** low bounty value, disclose to The Graph team
- **Indexer bug → frontend displays wrong → user transacts:** medium/high impact, disclose to protocol team
- **Indexer bug → protocol relies on indexed state off-chain (e.g., airdrop calculation, rewards distribution) → fund drain:** HIGH/CRITICAL, disclose to protocol team, often with formal bounty
