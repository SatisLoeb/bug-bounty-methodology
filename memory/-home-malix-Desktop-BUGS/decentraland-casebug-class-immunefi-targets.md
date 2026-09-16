---
name: decentraland-casebug-class-immunefi-targets
description: The Decentraland case-sensitivity signed-auth bug generalized into a class + the ranked Immunefi analog targets that can host it
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0f40804f-42c9-469c-8520-53f0dfa30241
  modified: 2026-08-11T08:17:45.486Z
---

**The bug (BlackBox/submissions/decentraland/web1-scene-signer-case-bypass.md):** 5 Decentraland
off-chain services reject scene-originated AuthChains via a case-sensitive `=== 'decentraland-kernel-scene'`,
but the signature is verified over a `.toLowerCase()`-normalized payload (`createPayload` in
decentraland-crypto-middleware). One uppercase char → same signature, gate defeated. Critical, filed under the
Immunefi standardized web/app line *"Taking state-modifying authenticated actions on behalf of other users
without any interaction."*

**The generalized class to replicate:** *normalization desync between the signed payload and the authz
decision.* Payload normalized (case/trim/unicode/JSON-canon) BEFORE verify, but the security check reads the
RAW field. + 4 siblings: (1) denylist-of-one-literal (fail-open) vs allowlist (fail-closed); (2) signature
doesn't bind host/body/chain-id → cross-host replay + body substitution; (3) client signing-oracle
(`getHeaders`/`signedFetch` returns signed headers to untrusted code for an attacker-chosen URL/method, no host
allowlist); (4) one control re-implemented in N services → root defect multiplied. **The bug lives OFF-CHAIN
(server/SDK), not in the contracts** → target must have Web/App assets in scope.

**Enumeration technique (Immunefi is a Next.js SPA, list virtualized + lazy-loaded → scroll-harvest freezes /
times out):** `fetch('/bug-bounty/',{credentials:'omit'}).then(r=>r.text())` returns the full SSR HTML with all
186 programs in the flight payload (inline `<script>`, cleared after hydration so fetch a fresh copy). Unescape
`\\"`→`"`, split on `"slug":"`, per-chunk regex `maxBounty`/`kyc`/`projectType`/`updatedDate`. Then per candidate
`fetch('/bug-bounty/<slug>/scope/')` and grep: `websites_and_applications` (web in scope), `github.com/<repo>`
(OSS = source-verifiable like DCL), and the Critical line `websites_and_applications","severity":"critical",
"title":"Taking state-modifying authenticated actions`. The exact DCL Critical impact line is STANDARD
boilerplate across every web/app-scope program — so rank by (web-in-scope × uses-signed-request-auth × bounty×p_bounty × OSS × no-KYC).

**Ranked Immunefi analog targets (surveyed 2026-08-11):**
- **ENS** — $250k, NO KYC, OSS (`ens-app-v3`, `ens-metadata-service`, `ens-contracts`), exact Critical auth
  line, `signature:2/bypass:4`. Naming normalization (ENSIP-15 case/unicode) is the native habitat: hunt
  namehash-normalized-label vs off-chain service/gateway/app reading raw label. #1 pick.
- **0x** — $1M, KYC, exact Critical auth line, gasless/RFQ signed-order API in web scope (`0xProject/0x-settler`).
- **galagames** — $50k, KYC, exact Critical auth line, CLOSED; `walletsrv.gala.games`/`app.gala.games`/
  `node.gala.games` = Decentraland-twin (client→wallet-service→authz), black-box only.
- **1inch-business/-web** — $100k/$50k, KYC, account-takeover impacts, `business.1inch.com`/`api.1inch.com`
  auth:38/session:8 + Fusion EIP-712 signed orders. User already has `1inch-business-audit/` in workspace.
- Tier-2 signed CLOB/RFQ (web+API in scope, mostly closed → black-box): **aster** $200k noKYC, **hashflow**
  $50k noKYC (signed RFQ quotes), **hibachi** $20k, **edgex** $10k (StarkEx), **exodus** $18k (wallet backend).

**decentraland is itself on Immunefi** ($500k, KYC, updated 2026-08-05) — the bug was filed there.
See [[feedback-openapi-is-not-the-full-api-surface]], [[gated-is-not-a-verdict]] siblings.

**LANDED 2026-08-13:** this class produced Immunefi #87537 on Decentraland itself — CONFIRMED Critical (case-sensitive signer check in decodeAuthChain → act-as-user), awaiting payment. See [[decentraland-critical-decodeauthchain-confirmed]].
