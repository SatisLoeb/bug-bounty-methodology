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
