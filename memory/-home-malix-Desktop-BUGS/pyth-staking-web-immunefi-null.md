---
name: pyth-staking-web-immunefi-null
description: "Pyth Staking web (Immunefi, staking.pyth.network) — static+dynamic executed NULL; tight static Solana dApp, no backend, no attacker-input→tx path"
metadata: 
  node_type: memory
  type: project
  originSessionId: 0d683fbc-0da4-4fc4-96ca-4ba883ca4500
  modified: 2026-08-22T21:41:52.978Z
---

**Pyth Network — Web & App (Immunefi, `staking.pyth.network`)**, $50K max Critical, Primacy of RULES, single asset. Verdict 2026-08-22: **executed NULL-COÛTEUX (fortress), static + dynamic.**

Next.js/Vercel **static SPA, NO custom backend** — all data-plane = client→Solana RPC / api2.pythnet / amplitude. So server-side Criticals (RCE, /etc/shadow, DB creds) are structurally N/A.

Executed ledger (each listed impact killed):
- **XSS→wallet hijack (Crit):** no app-level HTML sink (`dangerouslySetInnerHTML` framework-only: Next Script/React reconciler/framer-motion), no markdown renderer, NO CSP but no injection point. No server reflection (curl probes) AND no client-side DOM reflection (live: injected `?inj=MARK<b>` / `#MARK<i>` NOT in DOM — app ignores URL params, no app-level `useSearchParams`).
- **Malicious connected-wallet tx (Crit):** NO attacker-controllable input path. Whole DOM has only 2 terms-checkboxes — **no free-text address/pubkey field anywhere**; delegate = on-chain publisher list not free text; program IDs hardcoded (`pytS9TjG1qyAZypk7n8rw8gfW9sUaqqYyMhJQ4E7JCQ`); audited `@pythnetwork/staking-sdk`. All flows user→own-stake-PDA (deposit/withdraw/delegate/vote) → no attacker destination in ANY flow. Tested live with connected throwaway wallet (Fxb7..fYPK, 0 balance) + sign-interceptor.
- **postMessage cross-origin tx (Crit):** handlers origin-checked (`e.origin===endpoint` / `===location.origin`) or wallet-standard lib.
- **Subdomain takeover (Crit/High):** asset = claimed Vercel (`cname.vercel-dns.com`, 200), not dangling; 25 subs enumerated (certspotter — crt.sh 502s), none dangling; adjacent subs OOS (single-asset scope).
- **Persistent/reflected HTML injection (High/Med):** zero reflection server or client side.
- **Open redirect (Med):** framework/wallet-adapter only (phantom.app/solflare universal links w/ encodeURIComponent, `location.assign` gated on `https:`).
- **localStorage tampering (High/Low):** only analytics (amplitude/gcl) + `walletName` — no sensitive/cross-user data.
- **Iframe→state (Low):** NO X-Frame-Options / NO CSP frame-ancestors → iframeable, BUT every state change is a wallet-approved tx in the Phantom popup (un-clickjackable separate context) and funds stay with user → NO demonstrable impact → OOS "missing header without demonstrated impact".

Live intel: OIS rewards PAUSED (OP-PIP-103, rate=0 since 22 Apr 2026); staking/slashing/unstake/withdraw + governance staking active. OIS 682M staked, Governance 1.1B staked.

**RE-SOURCE.** Tight professionally-built static dApp; p_bounty ~0 on web scope. The SC scope (Pyth staking program on Solana, `pyth-network/governance`) is a separate surface if a payer covers it. Workspace `~/Desktop/BUGS/pyth-staking-audit/`. Method note: for static SPAs, curl reflection probes miss client-side DOM handling — the live-browser DOM param test is the one that actually closes DOM-XSS.
