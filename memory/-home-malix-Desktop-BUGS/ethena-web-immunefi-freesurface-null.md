---
name: ethena-web-immunefi-freesurface-null
description: Ethena web/app Immunefi (claim/app/www) — free-surface XSS+CORS+takeover executed-null; payable ore is SIWE-session-gated
metadata: 
  node_type: memory
  type: project
  originSessionId: 5816c513-71ac-44ee-ba44-112895ef87f5
  modified: 2026-08-11T10:41:42.840Z
---

Ethena **web/app** Immunefi program (assets: `claim.ethena.fi` [Primacy-of-Impact], `app.ethena.fi`, `www.ethena.fi`; web-class impacts only — SC is a separate program). Engaged 2026-08-11, operator chose surface = **weak-CSP XSS on app/claim**, scope = **Primacy-of-Impact broad** (any *.ethena.fi counts if it yields a listed impact; confirm PoI is program-wide on live Immunefi page before submit).

**Stack:** Next.js/Vercel; auth = SIWE (mixed transport: bearer `getToken`/`Authorization` on core API → CSRF likely mitigated there, plus some `document.cookie`/`credentials:same-origin`). Wallet = Reown/WalletConnect **AppKit** + TON/Telegram. Tx-screening SDK = `quill.run` (`NEXT_PUBLIC_SECURE_SITE_SDK_URL`, in script-src).

**KEY BOUNDARY (saves re-derivation):** the juicy `/v1/convert/build-transaction`, `/v1/onramp/*`, `/v1/profile/account`, `/v1/messages/tx/`, `/v1/ws/affectionate-immediate-pollux` endpoints are **Reown AppKit's** (routed via `c.W.state`/`projectId`/`caipNetworkId`) → third-party, **OOS**. Ethena's own backend = Next `/api/*` routes on app.ethena.fi + points/referral/leaderboard system on `api.ethena.fi`/`public.api.ethena.fi` (403 without auth).

**CSP asymmetry (real, but no reachable sink):** apex `ethena.fi` = strong `nonce+strict-dynamic`; **`claim`+`app` = `unsafe-inline` `unsafe-eval`**; **`whitelabel.ethena.fi` = NO CSP at all** (different bundler, mostly marketing + auth-gated partner portal).

**EXECUTED NULL-COÛTEUX — free (non-session) surface, ~12 sub-angles each with artifact:**
- No app-level `dangerouslySetInnerHTML:{__html:appvar}` anywhere (all 495 chunks; only Next `htmlEscapeJson` + react-helmet `rootHtml` = safe).
- `.innerHTML=` sinks = PostHog web-experiments (not attacker-reachable) + QR-code (data→rects, not markup) + framework only.
- no `eval`/`new Function` fed data.
- server-side param reflection (join/leaderboard/account/path/ref) → escaped in RSC (`<`); **metadata/OG fully static** (no param reflection, static share.jpg).
- `sanitize-html` = safe library default (strips js:/on*/script); `marked` present but output has no HTML sink → moot.
- leaderboard renders free-text displaynames (e.g. "Jordan Synthetix") to all users but as **escaped text, rows not links**; referral codes are system-gen 5-char.
- socials/website links → **scheme-validated** (`startsWith("https")`,`/^https?/`) → `javascript:` blocked.
- URL params read: NONE of to/recipient/spender/amount/address (only header names + `termsAccepted`/`startapp`[Telegram]/`result_uri`/`georef`) → tx-substitution-via-URL null.
- postMessage handlers → origin-validated (`.origin===` incl `SECURE_SITE_SDK_ORIGIN`); a few `({data})` handlers not per-handler-traced (residual).
- **CORS**: `/api/*` static allowlist (`app.safe.global,walletbot.me`) — no arbitrary-origin reflection; `/api/yields` has `ACAO:* + ACAC:true` but **fail-safe** (browser blocks credentialed wildcard) → Informational only.
- geoblock (`/api/geolocation`→`{"country":..}`) NOT header-spoofable (reads trusted Vercel edge).
- subdomain takeover → null (all live hosts claimed: Vercel/Teamtailor/GitBook/Discourse/Cloudflare/AWS; dev/staging Vercel-SSO-gated; faucet.* NXDOMAIN).

**RE-SOURCE — payable ore is SESSION-GATED (rank):** (1) SIWE-authed API IDOR/PII on api.ethena.fi/public.api (act-on-behalf=Crit, PII=High) — needs throwaway wallet + session token handoff; (2) whitelabel partner portal (no-CSP, multi-tenant cross-tenant) — needs partner login; (3) profile-editor XSS (likely defended by scheme-validation); (4) Telegram mini-app (`startapp`/TON initData). Consistent with [[polymarket-web-relayer-preprod-int]]/[[wallet-tg-telegram-bfla-engagement]]: Ethena-class free surface clean, p_bounty real only on session-gated seam. Bundles saved under scratchpad/ethena/{app,claim}. See [[feedback-openapi-is-not-the-full-api-surface]], [[feedback-webfetch-summarizer-truncates-immunefi-scope]].

---
**UPDATE 2026-08-12 — SIWE-session-IDOR/PII HYPOTHESIS REFUTED (live-tested with a burner wallet).**
Re-engaged the "session-gated" ore with a connected burner (0xac95…ec35). Definitive finding across 3 request captures + browser probes:
- **NO session cookie exists.** Cookie jar (even connected) = only wagmi.*/posthog/adrsbl/termsAccepted. Auth = the connected wallet ADDRESS (public, client-supplied), NOT a SIWE session token.
- **`app.ethena.fi/api/*` client surface is thin + public**: yields, geolocation, `historical-user-defi-balances?address=<ANY>` (returns ANY wallet's balance/rewardsUsdAmount/dailyTotalShards/totalShardsEarned, **no auth** — BOLA-shaped but data is on-chain-derivable + public via leaderboard → **non-confidential → OOS**), `rewards` (echoes queryWallet from session=empty). All referral/claim/profile/delegation/points/kyc routes → 404 (RSC server-side).
- **`api.ethena.fi`/`public.api.ethena.fi` = 403** to browser (server-only, Vercel BFF calls them with a server cred; user never authenticates directly).
- **RSC architecture**: /overview /join /claim make ZERO client /api calls; data fetched server-side keyed by connected address. No URL-param IDOR found.
- **No own-PII**: wallet-based DeFi, no email/KYC of its own; onramp/KYC delegated to third parties (Mt Pelerin, Reown) = OOS.
VERDICT: **measured null** — no session to pierce, no confidential per-user data. The web IDOR/PII ore we're strong at needs a target that HAS real PII + a real auth boundary (CEX/fintech/KYC platform / a partner portal with tenant auth) — a wallet-based DeFi app like Ethena structurally lacks it. Residual only: whitelabel.ethena.fi partner portal (needs partner login — untested) + Telegram mini-app (TON initData). RE-SOURCE. Lesson: [[feedback-verify-before-working-no-theater]] — "session-gated ore" was a hypothesis; live-testing refuted the session's existence.
