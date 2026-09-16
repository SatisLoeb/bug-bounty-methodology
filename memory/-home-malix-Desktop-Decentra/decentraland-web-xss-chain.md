---
name: decentraland-web-xss-chain
description: The payable Critical chain on Decentraland web apps — XSS anywhere on decentraland.org reads the localStorage identity key = account takeover
metadata: 
  node_type: memory
  type: project
  originSessionId: 356020ee-d70f-46f0-b012-256db3060b38
  modified: 2026-09-10T12:10:02.605Z
---
> **STATUS: CLOSED 2026-09-10 (operator decision).** XSS direction exhausted on the in-scope surface. Phase H2 = survived_leads:0, no XSS, no no-XSS ATO (SSO responder dead). Do NOT re-run the sweep; only the OOS-producer residual (rentals/streaming/rewards) could revive it. See H2 FINAL below.


Pivot target for the Decentraland Immunefi hunt (2026-09-10), after [[decentraland-social-scope]] closed the RPC surface and AI-02 (WS replay) proved non-payable (acquisition closed).

THE CHAIN (impact + exfil already solved; only the XSS is missing): `@dcl/single-sign-on-client` 3.x stores the DCL identity — ephemeral key INCLUDING private key — directly in `localStorage['single-sign-on-<lowercased-address>']` on the consuming app's OWN origin (the pre-3.0 id.decentraland.org iframe model is REMOVED; getKey/getIdentity in core-libs/single-sign-on-client/src/SingleSignOn.ts). And the in-scope web apps are consolidated on ONE origin: account/governance/profile/builder all 301 to `https://decentraland.org/<app>/`, marketplace = `decentraland.org/marketplace`. Same origin => shared localStorage. So ANY XSS under `decentraland.org/*` reads the identity written by any of these apps.

CSP is ABSENT on decentraland.org (verified 2026-09-10: only HSTS + X-Frame-Options:DENY + legacy X-XSS-Protection + nosniff, NO Content-Security-Policy). So a successful XSS has an unrestricted exfil path (no connect-src/img-src limit) to beacon the stolen key. With the key an attacker mints arbitrary signed-fetch chains = full account takeover across ALL Decentraland services (maps to the Critical web row: state-modifying actions on behalf of another user).

So the ONLY bug to find is an XSS (reflected / stored / DOM) anywhere under decentraland.org/*. In-scope web apps: /marketplace /builder /play /governance /account /events /rewards /places /profile /auth (all listed decentraland.org paths), plus builder-api / marketplace-api / api / auth-api / signatures-api / worlds-content-server / peer / realm-provider. Apps are open-source (decentraland/marketplace, builder, account, unified-dao/governance, profile, explorer-website, shared: decentraland-dapps, ui, decentraland-ui). Hunt is SOURCE-DRIVEN: grep sinks (dangerouslySetInnerHTML, innerHTML, markdown/rich-text renderers on proposals/bios/listing-descriptions, SVG upload, href/src injection, postMessage handlers, hash-router reflection). Stored-content sinks: governance proposal markdown, profile bio, marketplace/builder item names+descriptions, event/place descriptions, DCL/ENS name rendering.

---
## H2 progress (2026-09-10, session c66a30a4) — most sinks now MEASURED-DEAD
Deployed bundles on disk at `.../356020ee-.../scratchpad/xss/deployed/` (sites@0.63.1, mkt@8.33.1, gov@2.5.1, auth@5.1.0, builder@8.24.0). Full status: `.../scratchpad/xss/H2-STATUS-2026-09-10.md`.
- **@dcl/sites (landing + /account + /events + /places + /profile + /play): CLEAN** — swept entry + all 288 chunks. Profile links/bio + event/place descriptions are http(s)-only allowlist-gated; blog highlight DOMPurify-limited. acc-index.js is byte-identical to sites-index.js. Kills the events-markdown + places/profile stored residuals.
- **marketplace + builder: BLOCKED** — sinks walled (store-link getIsValidLink gate; builder eval runs in SDK6 scene VM off-origin, web editor deprecated). Store-link cross-app lead REFUTED (store links render only in gated marketplace).
- **EW-01 renderer inject: NOT DEPLOYED** (re-confirmed by grep).
- **Notification href/url render sink: unsanitized + deployed**, but processor copies metadata.link verbatim only from internal SNS; marketplace/events/gov/credits producers all fixed-base. 
- **STILL OPEN:** (1) notif producers rewards-REWARD_ASSIGNED / streaming / referral / worlds / land-rental (producer repos not cloned; a single verbatim URL-forward = one-click stored XSS); (2) auth-site 5.1.0 postMessage/redirect sweep (origin checks present, not fully cleared); (3) proto-pollution/DOM-clobbering; (4) dep-CVE. Cap hit (resets 5pm Africa/Algiers); resume Workflow wf_07327f3d-6ff (3 sweeps cached).

**SSO-responder exfil (no-XSS shortcut): MEASURED-DEAD 2026-09-10** — id.decentraland.org/.zone NXDOMAIN; SingleSignOn.init() called 0x in all 5 deployed bundles (no responder iframe ever created); apps read same-origin localStorage['single-sign-on-<addr>']; client 3.0.1 removed the iframe protocol. Identity theft still REQUIRES an XSS on decentraland.org.

**H2 FINAL (2026-09-10): survived_leads=0, NO XSS.** 12 dims swept + adversarial-verified. Both notif-producer leads killed: REWARD_ASSIGNED renders config.EXPLORER_URL not metadata.link (dead data); LandRented/Streaming render sink IS unguarded+deployed but ingestion is internal-only (bearer+SNS) and readable emitters rebuild the link. Only residual = rentals/streaming/rewards PRODUCER source not on disk (likely OOS). XSS expansion EXHAUSTED on in-scope surface; apps hardened.
