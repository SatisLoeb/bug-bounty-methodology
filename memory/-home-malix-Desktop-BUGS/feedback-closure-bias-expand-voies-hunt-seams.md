---
name: feedback-closure-bias-expand-voies-hunt-seams
description: "When you catch yourself re-running disconfirmers to PROVE NULL on one surface, you've stopped hunting — expand to new voies + attack the intersections, don't grind one voie"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: f12acb52-984f-4c4b-91ce-9b64dd53c682
---

**The failure mode (operator caught it live on Rogo, 2026-06-29, twice in one session):** I locked onto ONE voie (the unauth web edge of app.rogo.ai, the routes I already knew) and each "deeper" pass was a *disconfirmer to PROVE the null*, not a search to FIND. Operator: *"on attaque cette target par une seule voie et on s'obstine à recommencer pour prouver qu'il n y a rien pas pour essayer de trouver quelque chose"* then *"certaines vulns vivent dans les intersections."*

**Why it's insidious:** running disconfirmers is GOOD methodology (the anti-novel-reading fix) — but the *meta-goal* silently flips from "find a way in" to "demonstrate the wall holds." A thief doesn't audit the wall he sees; he circles the building for the door nobody watches. Re-confirming a known surface feels like rigor while being the opposite of hunting.

**The tell:** you're re-probing the SAME surface/host/route family with variations, and your framing is "is it really null?" instead of "what surface have I NOT touched?" The moment you write the 3rd disconfirmer on one voie, STOP and EXPAND.

**How to apply — when you catch the tell, do BOTH:**
1. **EXPAND VOIES** (cold-poke new surfaces, [[feedback-apparatus-is-packaging-not-discovery]]): enumerate the FULL route/page manifest (not just bundle-referenced routes — `_buildManifest.js` gave Rogo's whole map incl. a second `/api/*` server layer I'd never probed); CT-log subdomain enum (revealed Rogo's entire per-tenant + data-backend + internal-ArgoCD topology the single-voie pass never saw — same as the Injective admin-api cold-poke win); robots/sitemap; mobile flow; different protocols (WS/SSE/gRPC-web/H3); the second/third server layer behind the same origin.
2. **HUNT THE INTERSECTIONS** ([[doctrine-seam-rattachement-is-the-value]], upshift2): the bug lives where two systems hand off and each assumes the other guards it. Concrete seams to always test: edge/proxy↔backend identity-header trust (does the gateway strip client-supplied `x-auth-request-user`/`x-forwarded-user`/`x-user-id`?), CSP-trusted-host↔app (dangling-subdomain takeover + cookie-domain scope), dual-server-same-origin (Next `/api/*` ↔ NestJS `/nest/*`, different auth postures), frontend↔internal (SSRF via logo/image proxy → metadata/internal hosts), IdP↔callback (org-mapping on email/sub), app↔OOS-backend (token scoping).

**The expansion is ALSO what answers "why does a hardened target even have a bounty"** — on Rogo, expanding proved the bounty is pinned to the hardened shell (`app.rogo.ai`) and *deliberately walls off* the real surface (per-bank `<bank>.rogo.ai`, `rogodata.com` data backends, staging, internal ArgoCD — all OOS). The single-voie null was correct, but only the expansion gave the CONCRETE reason + the direct-disclosure map. A null on one voie is not a null on the target until you've expanded the voies and swept the seams. See [[rogo-program-parked-access-gated]].
