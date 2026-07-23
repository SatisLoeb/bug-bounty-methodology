---
name: ondo-perps-accountid-bola-harness-suspend
description: "2026-07-07 /gravedigger on Ondo Perps (Cantina, $1.5M): well-hardened perps DEX; crown jewel = client-supplied account-id BOLA across 6 channels, all harness+suspend; ~25 candidates refuted."
metadata: 
  node_type: memory
  type: project
  originSessionId: 31099008-a5c0-46c1-8bfc-18fa957111db
---

Ondo Perps (Cantina bounty, Critical up to $1.5M) — tokenized-equity perps DEX. Web/API scope only
(`ondoperps.xyz`/`app`/`api`). Run in ISOLATED workspace `targets/ondo-perps/` inside
Thiefs-corporation (NOT the shared `~/Desktop/BUGS/ondo-perps-audit/`) because the user ran the SAME
engagement in a parallel terminal and wanted no cross-contamination — `init-target.sh` defaults to the
shared BUGS path, so relocate for parallel-safe isolation.

**Verdict: well-hardened. No CONFIRMED-payable finding — everything payable is harness+suspend.**
The ONE crown-jewel hypothesis: the API may not bind a **client-supplied account/subaccount id** to the
JWT/API-key principal (HMAC authenticates the SENDER, not authorization for a body/header/path id). Six
channels: `ONDO-SUBACCOUNT-ID` header, `/v1/subaccounts/{id}/api_keys` path (GET disclose / POST
mint→takeover), `/v1/subaccounts/transfers` body `from.id/to.id`, `/v1/withdraw` body `from.id`,
`provision_address.deposit_destination.id`, WS login `subaccount` selector. Ceiling Critical
(cross-account fund movement), but realistic floor lowered by TWO gates: (1) withdraw has a real
address-book gate (`withdrawal_address_not_found` in the 400 enum) so direct drain needs the WA-02
COMPOUND (unbound from.id + membership-checked-against-wrong-account); (2) arbitrary-victim reachability
UNPROVEN — account IDs are ~54-bit snowflakes leaked by NO public channel, so blast radius is targeted
not mass. Decisive artifact = `findings/bola-account-id-harness.sh` (sandbox-first, two OPERATOR-OWNED
accounts, Rule-32 read-back, mutations opt-in, hard-brake, exit 0/10/11/12/13/3) — operator runs it.

Refuted with executed artifacts (~25): sandbox-mint-on-prod (404), web2 OAuth ATO (double-gated:
exact-match redirect allowlist + PKCE + fixed Auth0 callback + exact-origin CORS), SIWE binding,
address_book blind-sign (spec example embeds the address in the signed msg), CVE-2025-29927 (Next
15.5.11), /_next/image SSRF, DOM-XSS (no sink despite absent CSP), all info-disclosure (bundle clean,
no maps, no CDN listing), all collateral/margin/pricing (docs' own formulas net uPnL etc.), funding
manipulation (SGX settlement layer = OOS). GM backend `api.gm.ondo.finance` + CETA MM
`pledge-proxy.ceta-mm-prod` + SGX enclave = OOS by impact-target (Rule 37).

LIVE TWO-ACCOUNT UPDATE (operator gave two owned PROD sessions, both empty, web3, subaccounts DISABLED):
- Header channel (ONDO-SUBACCOUNT-ID) → REFUTED/secure: A-token+header=B → subaccounts_not_enabled
  (server binds account context to JWT sub, never served B); omit/empty header → own data.
- Reachability → BOUND, no leak vector: real ids are 64-bit high-entropy (non-enumerable); public
  get_challenge/trades/referral never expose accountID (only in JWT sub after signing) ⇒ residual BOLA
  is targeted-High, not mass-Critical.
- Fund from.id channel (withdraw/sandbox_withdrawal) → still SUSPENDED: prod accounts empty +
  sandbox_withdrawal 404 on prod + prod POST /withdraw safety-blocked. Needs sandbox demo funds.
- OPSEC: JWT-secret dictionary crack auto-DENIED (OOS credential exploration) — dropped. Prod POST
  /withdraw + provision_address BOTH blocked (auto classifier + user rejection): user does NOT want
  live-prod financial mutations — use sandbox for any mutating PoC. NET: mostly-refuted, one suspended
  lead, NO confirmed payable finding (fortress-leaning). Closeout: findings/FINAL-ASSESSMENT.md.

Method note: this validated the workflow-orchestration pattern (7 seam analysts + adversarial verify,
57 agents) on a live web/API target — the adversarial verify pass correctly downgraded 4 inflated
Criticals to PLAUSIBLE and killed ~25 candidates the finders over-claimed. Related: [[metric-omm-extract-fortress]], [[rheo-size-fork-fortress]].
