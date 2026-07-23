---
name: polygon-labs-web-solo-null-authed-backlog
description: "Polygon Labs H1 web bounty — solo unauth surface EXECUTED-null, 3 prior drafts are credibility-burners (don't submit); only live EV is session-gated authed backlog"
metadata: 
  node_type: memory
  type: project
  originSessionId: 3099182a-dea7-4460-992c-f775e3ee365a
---

Polygon Labs (HackerOne PRIVATE, WEB/API). 8 in-scope assets (staking, staking-api, portal, faucet, api-gateway, gasstation, faucet-api, api-polygon-tokens); SC/node repos (bor/heimdall/heimdall-v2/contracts/matic-cli) INELIGIBLE. **LOW program: Crit $1.2-2k, High $600-1.2k, Med $150-600.** Workspace `polygon-labs-audit/`. H1 handle `malikb31s`.

**2026-07-04 missed-surface sweep (17-agent live workflow + hand-verify): solo UNAUTH surface = earned-null with executed artifacts.** The 3 April drafts (never submitted) are all NON-PAYABLE — **do NOT submit, they burn credibility:**
- F-PL-001 `/faucetBalances` 200-unauth = public on-chain **testnet** data (Amoy/Sepolia) + design-intended faucet display → Informational (drafted "High" was optimism).
- F-PL-002 `polygonag_` key = **VITE_-prefixed publishable frontend key** (shipped to every browser by design), gates only public AML screening `{address,blocked,source}`; quota-abuse = OOS. Hand-verified elevation: gateway has no OpenAPI, portal 6.5MB bundle references it for ONE route (`/api/screening/addresses/{address}`), key 401s elsewhere → elevating needs prohibited fuzzing → null.
- F-PL-003 OAuth `appUrl` open-redirect: `redirect_uri` server-pinned (code can't leak), no token-leak → OOS open-redirect-no-impact.
- Everything else = publishable 3rd-party keys (Infura/Firebase/WalletConnect/Sequence/Socket = OOS), public on-chain data, or OOS classes (static-`*` CORS w/o creds, DoS `limit=999999999`, viem version-leak, :3000 port behind CF).

**Only live EV = the AUTHED surface (session-gated, UNEXECUTED — honestly a backlog, not nulled):**
1. **faucet OAuth token-in-final-redirect** — binary **Medium** (~$600-1.2k): with a real GitHub/Twitter login, complete `/auth/github?appUrl=<attacker>` and check if the final 302 carries a session token/JWT/code to the attacker host (token-in-URL = ATO) vs only an HttpOnly cookie (collapses to OOS). Highest-potential, one observation decides it.
2. staking-api validator-write BFLA (`POST /api/v3/validators/...`) + faucet `registerTransferRequest` param-tamper/replay — Low/testnet, needs a connected wallet.

I cannot create wallet/OAuth sessions solo (need operator's browser via Chrome MCP). **Given the $2k ceiling → SKIP** unless the operator wants the one binary faucet-OAuth session-check. Reusable web-recon lessons: VITE_-prefix = by-design public key (canonical Informational close); public on-chain data ≠ info-disclosure; re-verify stale drafts against the OOS list before submitting. Instance of [[feedback-target-diet-is-the-binding-constraint]] + [[apparatus-is-packaging-not-discovery]] (sweep's value was STOPPING 3 bad submissions).
