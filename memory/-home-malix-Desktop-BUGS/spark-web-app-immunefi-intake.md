---
name: spark-web-app-immunefi-intake
description: Spark (Sky) Immunefi WEB/APP scope — EXECUTED NULL-COÛTEUX; Vite SPA exposed-sourcemaps source-null; notifications email-OTP backend live-probed and hardened; Bitly link.spark.fi takeover was a false-positive
metadata: 
  node_type: memory
  type: project
  originSessionId: f717a0bf-10c1-4266-a602-aaf51119ad21
  modified: 2026-08-13T08:45:17.571Z
---

Spark WEB & APP Immunefi (PoI) intake via /nullguard, 2026-08-13. Disjoint from the SC scope (see
`spark-immunefi/SCOPE-FRESH.md`, sparklend+aave-fork saturated-SKIP) and from the 2026-04-13 agent-hallucination kill.

**RESOLVED 2026-08-13 = executed NULL-COÛTEUX → RE-SOURCE.** Operator authorized live probing of BOTH the
notifications backend and the Bitly takeover; both HELD under executed testing (onboarded via mail.tm/mail.gw
throwaways + curl):
- Notifications backend (backend.spark.fi oRPC `@sparkdotfi/backend`): OTP account-takeover NULL — 6-digit
  OTP but wrong verifyOtp attempts INVALIDATE it (timing-controlled: 20-wrong→real FAILED vs 20-dummy-delay→
  real=SESSION, expiry ruled out) + requestOtp per-email 429 (2-min cooldown). IDOR NULL (JWT-bound identity,
  auth.me/addresses.list return caller-only, HS256 secret not weak vs 28 defaults). unsubscribe token NULL
  (garbage/UUID/forged-JWT/email all → uniform reject, no oracle).
- **Bitly link.spark.fi = FALSE POSITIVE**: `/spark` 302s to a real live Spark campaign link → ACTIVELY-
  CONFIGURED Spark-owned BSD, not dangling. Lesson: generic bitly landing on `/` ≠ unconfigured; check PATHS
  before claiming a Bitly takeover.
- Residual (OOS/low): requestOtp no per-IP cap = email-send amplification (DDoS-bucket, no content injection);
  telegram.link token un-probed (low ceiling). Full ledger: spark-immunefi/WEB-SCOPE-FRESH.md.

**Ground truth (Rule 43/5):** in-scope `marsfoundation/spark-app` 404s (rebranded → `sparkdotfi`).
`sparkdotfi/spark-interface` is a DECOY (pkg `aave-ui`, Next.js, June-2025, NOT deployed). Deployed
app.spark.fi = **Vite SPA, source private, but SOURCEMAPS EXPOSED** (`/assets/index-VpPFncQa.js.map` = 200)
→ full TS source reconstructed. The sourcemap is THE unlock — always check `.js.map` on Vite/Vercel dApps.

**Source-null (no live probing needed):** XSS (React-escaped; 17 dangerouslySetInnerHTML all static
framework/Radix); address-substitution/malicious-tx Crit (221 bundled addresses; swap is fixed-path PSM
dssLitePsm/psm3 with bundled tx-target + receiver=account, NO external aggregator/quote); open-redirect
(static legacyRoutes/links.appSky consts).

**Payable ore = live/consent-gated (HARNESS-SUSPENDED, not null):** a **notifications subsystem** with its
own email-OTP→Bearer-session auth (`@sparkdotfi/backend` oRPC at backend/api-v2.spark.fi `/v1/rpc`):
requestOtp/verifyOtp/auth.me/addresses.{add,delete,list,update}/telegram.link/**user.delete**/**unsubscribe(bare
unauth)**. Guard-strength (OTP entropy+rate-limit, server authz on addresses/user.delete, unsubscribe-token
forgeability) is ALL server-side = the guard layer is UNAUDITED-from-source. Impacts if broken: email PII
disclosure (High), change others' details (High), delete account on-behalf (Crit), 1-click unauth
disable-notifications (Med). Plus **link.spark.fi = unconfigured Bitly BSD → subdomain-takeover candidate
(in-scope High)**, claim step = the exploit (needs Bitly acct + scope confirm).

Same shape as [[ethena-web-immunefi-freesurface-null]] / [[lombard-offchain-web-surface-map]] /
[[desyn-onchain-inert-shell-offchain-frontier]]: free surface null, payable ore SIWE/session-gated. Full
map: `spark-immunefi/WEB-SCOPE-FRESH.md`, source at /tmp/spark-src. Verdict = CONTINUER; operator decides
whether to fund live probing of the notifications backend and/or the Bitly claim.
