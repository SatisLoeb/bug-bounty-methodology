---
name: originprotocol-web-scope-fortress-null
description: Origin Protocol Immunefi WEB scope (app.originprotocol.com) = exhaustively-executed NULL-COÛTEUX; payable ore is the excluded SC scope
metadata: 
  node_type: memory
  type: project
  originSessionId: 0e3b0c85-c2e4-4139-ab05-b9fa41f2998f
  modified: 2026-09-03T20:08:08.015Z
---

Origin Protocol Immunefi, **web scope only** (operator constraint 2026-09-03: "on ne va que sur le web scope"). The web scope is a **single asset**: `https://app.originprotocol.com/` (the unified Origin defi dApp — OGN/OETH/Super OETH/OUSD/ARM/governance/staking), added 2026-09-01 (fresh). Max bounty $1M; 40 paid reports / $139.2k historical (conservative payer).

**Verdict: NULL-COÛTEUX, executed.** 8 deep-trace agents + my own live browser testing all NULL. Every web-Critical impact path killed with an executed artifact:
- **Tx integrity** (swap Fly/Kyber/OpenOcean/Metropolis, mint/redeem/wrap, CCIP bridge, Merkl claim): recipient/receiver ALWAYS the connected wallet; spender/target ALWAYS a hardcoded `H.<chain>.*` literal or the aggregator's own router; minOut from user slippage. Confirmed LIVE via a mock EIP-6963 wallet: real ETH→OETH swap emitted `eth_sendTransaction` to the Fly aggregator with order recipient = my own address.
- **Aggregator trust** = third-party (fly.trade/kyber/openocean) = OOS; no attacker-controllable request param. Kyber has an explicit router-consistency guard.
- **URL/hash params** → all display/filter selectors; NONE reaches a tx arg or fetch host.
- **`?impersonate=<addr>`** (only identity-touching param) = INERT — feeds a wagmi `mock` connector the deployed build never registers; confirmed live (page just asks to connect). A mock connector can't sign anyway.
- **Governance**: `proposal.link` validated by `N7` (https + hostname∈{snapshot.org,snapshot.box}); `window.open` uses `noopener,noreferrer`; `castVote` id matches displayed. All fields sanitized by `M7`.
- **EIP-712/permit**: no reachable app-level signing flow; the one `signMessage` is a benign ToS attestation.
- **Dependencies**: deployed build FRESH+patched (viem 2.55.10, wagmi 3.7.5, react-router 7.14.2, axios 1.19.0, @walletconnect/core 2.23.10, react 19.2.8); no vulnerable transitive lib present.
- **Infra**: subdomain/bucket takeover impossible (active CloudFront `d2toga49m730af.cloudfront.net`), valid `*.originprotocol.com` cert, hardened headers, no open-redirect/CRLF.
- **XSS/CSP**: `default-src 'none'; script-src 'self'`; `dangerouslySetInnerHTML` hits are React internals; no cookies/CSRF; `frame-ancestors 'self' app.safe.global` (clickjacking dead); no app-level `postMessage` sink.

**Rule-5 lesson (load-bearing):** the DEPLOYED bundle DIVERGES from the stale public source `github.com/OriginProtocol/origin-defi` (main = 2025-04-10) by being **more hardened** — added router-consistency guard, `noopener`, removed the referral `dataSuffix` feature, newer patched deps. Always judge the deployed `index-*.js` bundle, never the source. See [[feedback-version-match-is-not-code-match-use-selector-discriminator]].

**Payable ore = the SC scope** (64 assets, $126M TVL, $1M max) which the operator excluded. For a NEW web-only critical, p_bounty ≈ 0 here (well-built frontend, hardcoded tx params, strong CSP). Aligns with [[feedback-default-posture-thief-not-fortress-prover]] and [[protocol-fortress-null-hunt]]: this null is EXECUTED, not a reflex. Workspace: `~/Desktop/BUGS/originprotocol-web/` (deployed beautified bundle + origin-defi source).
