---
name: ofza-target-state
description: "OFZA (Immunefi CEX Web&App) fan-out result — near-fortress unauth, all payables needs-auth"
metadata: 
  node_type: memory
  type: project
  originSessionId: cba84a85-5226-4703-87f8-5ba46436d533
  modified: 2026-08-22T13:08:23.464Z
---

2026-08-22 : Immunefi `ofza` (CEX VARA-UAE, **Web&App uniquement**, asset = https://ofza.com/, max $10k, KYC+PoC requis). Fan-out 12 agents en collecte (opus-4-8 — Opus 5 IMPOSSIBLE pour sous-agents sec ce jour, cf [[subagent-model-routing]]; MOI Opus 5 = couche jugement/vérif, choix user).

**Surface** = full margin/derivatives exchange (spot/deriv/OTC/OTC-leverage/copy-trading/earn/MT5/collateral/block-trading). Microfrontends Next.js fédérés par **basePath** (/authentication /wallet /spot /orders /profile) sur **Vercel+Cloudflare**. UN seul backend API = **api.ofza.com/api/v1** (`x-api-key: OFZAExchange` = routing statique, PAS secret ; sans key→404, sans session→403). public-api.ofza.com/api/v2 = API pro key-gated. Les sous-domaines auth/orders/profile/spot/wallet/features = FRONTENDS Vercel, pas des APIs.

**VERDICT : surface non-auth NEAR-FORTRESS, 0 clean unauth payable.** Négatif MESURÉ (artefacts) : XSS/metadata (nonce **rotatif**+strict-dynamic, sinks 100% framework, seam weak-CSP `unsafe-inline` sur 404/redirect/static ne reflète RIEN) ; subdomain-takeover (140 hosts tous claimed ; api-docs/institutional/academy=NXDOMAIN dead-refs) ; Next.js (CVE-2025-29927 double-mort : Vercel strip header + auth PAS en middleware = routes protégées 200 shells ; no SSRF `_next/image` off ; no cache-poison) ; client-side (postMessage tous SDK-origin-checked, open-redirect `?continue=` eN-guard `new URL().hostname===`, OAuth redirect same-origin forcé `/{locale}`) ; CORS/CSRF (auth=bearer localStorage PAS cookie → CSRF structurellement impossible ; api echoes only ofza.com no-creds ; `security` cookie = constante statique D088BB65 identique tous users) ; public-API (key-gate uniforme).

**POINT FAIBLE SYSTÉMIQUE (info/amplifier, pas payable seul)** : JWT session **+ refresh** en `localStorage` sous clé AES **HARDCODÉE** `d1ad7557-30ac-450f-abe6-aed72067f62d` (module 47509) → tout XSS same-origin = Critical-ATO persistant. Mais XSS mesuré CLEAN → amplifier LATENT.

**TOUS les payables = NEEDS-AUTH** (2 comptes KYC + proxy = étape opérateur, je ne peux pas créer de comptes sur CEX régulé). TOP-EV : (1) **`user/update-userprofile` body-`id` → email-change ATO** [HIGH — DTO module 53940 forward `{id,phonenumber,email}` que l'UI ne set JAMAIS = smell ; 1 requête-diff] ; (2) **`wallet/tr-pii-data?id=` cross-user travel-rule PII** [CRIT, read-only GET] ; (3) **`bank-account/{id}` path BOLA** update/delete [HIGH] ; (4) **`confirm-withdraw` address-substitution** après OTP [CRIT, besoin dépôt] ; (5) reset-password token↔email swap [HIGH] ; (6) verify-login-otp keyed sur email/phone client cross-acct [HIGH] ; (7) presigned-S3 KYC cross-read via `upload-url` [CRIT]. MED : mass-assign kyc_level/role sur endpoints `getData:e=>e` passthrough ; trusted-device 2FA-skip (device_token=MurmurHash 32-bit attrs publics). Faibles/OOS : OAuth callbacks no-state → login-CSRF/session-forcing (Low, mappe mal aux impacts in-scope) ; source-maps servies (Low, 0 secret).

Ledger complet : scratchpad/ofza/results/LEDGER.md. **Réouvrir** : obtenir 2 comptes KYC → confirmer top-EV (commencer par update-userprofile body-id = plus rapide) ; ou si nouveau code/surface. Dup-risk moyen (classes IDOR/OTP communes sur CEX mûr). Voir [[recevability-gate-before-poc]], [[farmed-program-dup-baserate]].
