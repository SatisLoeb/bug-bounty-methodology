---
name: decentraland-comms-parcel-sceneid-desync
description: Decentraland /upshift2 engagement (2026-08-12) — the fresh comms-gatekeeper authz desync finding + the in-scope guarded map + scope caveat
metadata: 
  node_type: memory
  type: project
  originSessionId: 65cd947b-0003-49aa-bdf8-b75066e6ecb7
  modified: 2026-08-12T09:08:07.734Z
---

**Engagement (2026-08-12, treat-as-new /upshift2):** fresh hunt of Decentraland Immunefi web/app+API.
Seam = signed-fetch (`@dcl/crypto-middleware` signs `method:pathname:timestamp:metadata`.toLowerCase();
**query+body NOT signed**; returns `auth=signer`, ownership is each backend's job).

**F1 (the one fresh payable finding) — comms-gatekeeper parcel/sceneId authorization DESYNC.**
3 sibling endpoints authorize on `place=getPlaceByParcel(signed.parcel)` → `isSceneOwnerOrAdmin(place,signer)`
but act on `room=getSceneRoomName(signed.serverName,signed.sceneId)` — 3 independent signed-metadata fields,
NO binding. Control **any ONE Genesis parcel** → `POST /scene-stream-access` mints a canPublish LiveKit
ingress into ANY scene's live comms room (→ no-auth `/cast/streamer-token` → broadcast video = defacement);
`POST /scene-bans` → `removeParticipant(victimRoom,target)` (kick any user); `/scene-admin` (transient).
Router `auth` only requires self-asserted `metadata.signer==='decentraland-kernel-scene'` (any wallet sets it).
**Dev-confessed:** the identical bug was fixed in the sibling `generateStreamLink` (`cast.ts:195`,
`getPlaceBySceneId`) with a comment naming the exact attack; these 3 were left. **Live-proven authz-half**
(fresh wallet, no LAND): same sceneId, vary parcel → -1,-1→401 / 5000,5000→500 / 22,-75→401 ⇒ authz is a
pure function of parcel. Full mint PoC needs 1 owned parcel (operator acquiring). Harness +
poc-f1-full.mjs ready in `~/Desktop/BUGS/decentraland-immunefi-audit/`.
**SCOPE CAVEAT (gating):** `comms-gatekeeper.decentraland.org` is NOT in the listed Immunefi assets; no
Primacy-of-Impact clause found → likely OOS by literal asset scope (needs program confirmation). It IS the
comms backend of the in-scope peer/Client/worlds and impact="defacing multiple users" is a listed impact.

**In-scope surface = earned NULL-COÛTEUX** (hand-verified guarded, not reflexive): worlds permissions+deploy
(checkOwnership→nameOwnership; content-validator profile access signer==pointer); auth-server (account-delete
double-gated by signer+Magic-DID same-addr; identity/relay uuid+phishing-gated; `isMobile` only weakens IP
defense-in-depth); marketplace trades bind EIP-712 sig to signer (favorites SQL-null = curation-only low);
builder collections `canUpsert=count0||isOwner` + owner forced to caller (has a legacy `method:path` sig
fallback, no ts/metadata bind — weakened sibling, but per-handler authz holds); social communities use
`verification.auth` as actor + sound role matrix (roles.ts). events attendee list unauth but wallet+name+ts
(intended-public, no email/phone → not payable). **realm-provider + social-service DON'T resolve in public
DNS** under listed names (reachability-blocked). governance SSRF heavily mitigated.

The PRIOR filed finding on this program was the scene-signer case-bypass [[decentraland-casebug-class-immunefi-targets]] — F1 is a DIFFERENT class (authz-desync, not normalization). Composes darkside Door-A (defense-shadow: dev fixed sibling, left twin).
