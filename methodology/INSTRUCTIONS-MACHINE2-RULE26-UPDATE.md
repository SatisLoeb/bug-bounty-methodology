# Instructions Machine 2 — Mise à jour Rule 26 + Arsenal Push

## Contexte

Session du 5-6 avril 2026. Rule 26 (RPC node namespace exposure) a produit 3 findings sur 3 targets en une nuit. La rule a été mise à jour dans CLAUDE.md avec une hunt procedure complète. Il faut maintenant propager les updates vers les skills GraveDigger, MrRobbot, et le DEFI-FULLSTACK-CHECKLIST, puis push sur Arsenal (Forgejo).

## 1. Update GraveDigger Phase 2

Fichier : `~/.claude/skills/gravedigger/RECON-PLAYBOOK.md`

Ajouter dans la section Phase 2 Surface Mapping (après §2.13 RPC node exposure) :

```
2.13b **MANDATORY: RPC namespace deep probe (Rule 26 v2)**
    Upgraded from basic port scan to 6-step hunt procedure.
    
    Step 1: Find the RPC backend URL from JS bundles
      grep -oP 'https://[a-zA-Z0-9._/-]*(rpc|node|json|web3|provider|proxy)[a-zA-Z0-9._/-]*' bundles/*.js | sort -u
    
    Step 2: Check if the endpoint issues free bearer tokens
      Many DeFi proxies have GET /auth/token that returns JWT with zero credentials.
      1inch pattern: proxy-app.1inch.io/v2.0/auth/token → free ES256 JWT
    
    Step 3: Test namespace exposure with the token
      txpool_status, txpool_content, debug_traceTransaction (use real recent tx hash),
      debug_storageRangeAt (against known contract like USDT), admin_peers, personal_listAccounts
    
    Step 4: If txpool exposed, IMMEDIATELY check eth_sendRawTransaction
      The combo txpool_content + eth_sendRawTransaction = MEV sandwich kit.
      No legitimate provider (Infura, Alchemy, QuickNode) colocates these on free/anon tiers.
    
    Step 5: Sweep ALL chain IDs the protocol supports
      (1, 56, 137, 42161, 10, 8453, 43114, etc.)
    
    Step 6: Check error responses for credential leaks
      Call with malformed params, read full error body for leaked RPC URLs with auth tokens.
      Request Finance pattern: persistTransaction error leaked full QuikNode URL.
    
    Internal consistency argument: if admin is blocked but txpool is not → method filter gap.
    
    Three confirmed findings from this pattern:
    - 1inch F01 ($5K-$50K HackenProof) — proxy open namespace, 5 chains, free JWT
    - Request Finance RF2-C01 — QuikNode credential in error response, txpool+debug on Gnosis
    - Tothemoon — GetBlock.io Solana RPC token leaked in CSP header
```

## 2. Update GraveDigger DEEP-ANALYSIS-PLAYBOOK.md

Fichier : `~/.claude/skills/gravedigger/DEEP-ANALYSIS-PLAYBOOK.md`

Ajouter à la section §4.4 (Infrastructure deep dive) :

```
§4.4b RPC proxy namespace audit (Rule 26 v2)
    Auto-trigger: ANY DeFi target with a web frontend that makes blockchain calls.
    
    CSP header mining: The Content-Security-Policy connect-src directive often reveals
    RPC provider URLs with embedded auth tokens. Check CSP for:
    - go.getblock.io/* (GetBlock with token in URL)
    - *.quiknode.pro/* (QuikNode with token in URL)
    - Custom proxy domains (proxy-app.*, rpc.*, web3.*)
    
    Error response mining: Call endpoints with malformed blockchain data.
    The error handler may include the raw RPC URL in the client-facing response.
    
    Free bearer token pattern: DeFi frontends need RPC access for anonymous users
    (price quotes, gas estimation). The auth token endpoint often has zero credentials.
    Get the token, then test ALL json-rpc methods.
    
    debug_storageRangeAt vs eth_getStorageAt: The debug method enumerates consecutive
    storage slots WITHOUT knowing the key hash. eth_getStorageAt requires the exact slot.
    The distinction is directory listing vs file read.
```

## 3. Update MrRobbot Web/API Second Pass

Fichier : `~/.claude/skills/mrrobbot/SKILL.md`

Dans la section "Web/API Second Pass (H1 Patterns)", ajouter comme priority 0 (avant API key leak scan) :

```
| 0 | RPC namespace probe (Rule 26 v2) | 5 min | CLAUDE.md Rule 26 |
```

Et dans la section "ANTI-PATTERNS", ajouter :

```
12. **Not checking CSP headers for RPC credentials** — The Content-Security-Policy
    connect-src directive is a goldmine for DeFi targets. GetBlock, QuikNode, and custom
    RPC proxy URLs with auth tokens are regularly leaked in CSP. Takes 30 seconds to check.
    Tothemoon finding came from CSP analysis alone.
```

## 4. Update DEFI-FULLSTACK-CHECKLIST

Fichier : `~/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md`

Ajouter dans la section F3 (Infrastructure) :

```
F3.4b RPC Proxy Namespace Audit (Rule 26 v2, 5 min)
    [ ] Find RPC backend URL from JS bundles or CSP connect-src
    [ ] Check if free bearer token is issued (GET /auth/token pattern)
    [ ] Test txpool_status + txpool_content
    [ ] Test debug_traceTransaction with real tx hash
    [ ] Test debug_storageRangeAt against known contract
    [ ] Test eth_sendRawTransaction (combo with txpool = sandwich kit)
    [ ] Sweep all supported chain IDs
    [ ] Check error responses for credential leaks (QuikNode, GetBlock URLs)
    [ ] Check CSP connect-src for hardcoded RPC tokens
    [ ] Internal consistency: admin blocked + txpool not = method filter gap
    
    Confirmed findings: 1inch ($5K-$50K), Request Finance, Tothemoon
```

## 5. Push to Arsenal Forgejo

```bash
cd ~/arsenal

# Update the methodology files
cp ~/.claude/skills/gravedigger/RECON-PLAYBOOK.md methodology/
cp ~/.claude/skills/gravedigger/DEEP-ANALYSIS-PLAYBOOK.md methodology/
cp ~/Desktop/BUGS/DEFI-FULLSTACK-CHECKLIST.md methodology/

# Add the Rule 26 v2 as standalone reference
cat > methodology/RULE-26-RPC-NAMESPACE-HUNT.md << 'EOF'
# Rule 26 v2 — RPC Namespace Exposure Hunt Procedure

## When to run
Every DeFi target with a web frontend. 5 minutes max per target.

## Procedure
1. Find RPC backend URL (JS bundles or CSP connect-src)
2. Check for free bearer token (GET /auth/token)
3. Test namespace exposure: txpool_status, txpool_content, debug_traceTransaction, debug_storageRangeAt
4. If txpool exposed: IMMEDIATELY check eth_sendRawTransaction (combo = sandwich kit)
5. Sweep all chain IDs
6. Check error responses for credential leaks

## Internal consistency argument
If admin namespace is blocked (-32604) but txpool is not → method filter with a gap, not design.

## Key differentiators
- debug_storageRangeAt = storage ENUMERATION (no key knowledge needed)
- eth_getStorageAt = targeted read (exact slot hash required)
- No legitimate provider exposes txpool_content on free/anon tiers
- Combo txpool + sendRawTransaction on same endpoint = zero-cost MEV kit

## CSP mining
Check Content-Security-Policy connect-src for:
- go.getblock.io/<TOKEN> (GetBlock)
- *.quiknode.pro/<TOKEN> (QuikNode)  
- Custom proxy domains with auth in URL

## Confirmed findings (3)
1. 1inch F01 — proxy-app.1inch.io, 5 chains, txpool+debug+sendRawTransaction, free JWT, CORS *
2. Request Finance RF2-C01 — gnosis.gateway.request.network, credential in error response
3. Tothemoon — GetBlock.io Solana token leaked in CSP header
EOF

# Commit and push
git add -A
git commit -m "Rule 26 v2: RPC namespace hunt procedure with 3 confirmed findings

Updated from single-line rule to 6-step hunt procedure based on
1inch ($5K-$50K), Request Finance, and Tothemoon findings.

- GraveDigger Phase 2 §2.13b: full hunt procedure
- GraveDigger Deep Analysis §4.4b: CSP mining + error mining
- MrRobbot: added as priority 0 in web/API second pass
- DEFI-FULLSTACK-CHECKLIST F3.4b: 10-item checklist
- New standalone reference: RULE-26-RPC-NAMESPACE-HUNT.md

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"

git push origin main
```

## 6. Update research_db.jsonl

```bash
# Add the three findings to the research database
cat >> ~/arsenal/tracking/research_db.jsonl << 'EOF'
{"lib":"1inch-proxy-app","version":"v2.0","ecosystem":"web","status":"finding","finding":"txpool+debug namespace exposure via free JWT","severity":"HIGH","date":"2026-04-05","target":"1inch","bounty":"$5K-$50K","notes":"5 chains, CORS *, zero rate limit, eth_sendRawTransaction enabled"}
{"lib":"request-network-gateway","version":"v1","ecosystem":"web","status":"finding","finding":"QuikNode RPC credential leaked in error response","severity":"HIGH","date":"2026-03-09","target":"Request Finance","bounty":"$1K+","notes":"txpool_content+debug on Gnosis, token not rotated 32 days"}
{"lib":"getblock-io","version":"v1","ecosystem":"web","status":"finding","finding":"GetBlock.io Solana RPC token leaked in CSP header","severity":"MEDIUM","date":"2026-04-05","target":"Tothemoon","bounty":"n/a","notes":"Solana mainnet, valid token, zero rate limit"}
EOF
```

## Vérification

Après le push, vérifier sur Forgejo :
```
http://localhost:3000/malix/arsenal/src/branch/main/methodology/RULE-26-RPC-NAMESPACE-HUNT.md
```
