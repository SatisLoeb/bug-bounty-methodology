---
name: decentraland-social-scope
description: In-scope payable surface for the Decentraland social-service-ea Immunefi audit (governs what can pay)
metadata: 
  node_type: memory
  type: project
  originSessionId: 356020ee-d70f-46f0-b012-256db3060b38
  modified: 2026-09-09T18:15:13.263Z
---

Decentraland Immunefi program, fresh assets added 2026-09-04: `social-service-ea.decentraland.org` + `rpc-social-service-ea.decentraland.org` (codebase decentraland/social-service-ea; local clone at ~/Desktop/Decentra/code checked out at the EXACT deployed commit 4db7827 = v1.13.9).

CRITICAL SCOPE CONSTRAINT (verified live + against the 78-asset scope JSON on 2026-09-09): all 78 assets are `isPrimacyOfImpact:false` = Primacy of RULES, so ONLY listed assets pay. The two EA hosts serve ONLY the uWS server: `/status`, `/health/live`, `/metrics` (bearer), `/v1/users/:address/privacy-settings` (UNAUTH GET, returns e.g. {"private_messages_privacy":"all"} for any address), and the WS upgrade → 33 RPC services. The full community/referral REST API (`/v1/communities`, members, bans, posts, mutes, referrals) is served ONLY on `social-api.decentraland.org`, which is NOT in scope; `api.decentraland.org` (which IS listed) does NOT proxy those routes (all /v1/communities, /v1/friendships → 404). So HTTP-community/referral/SQS bugs are OUT OF SCOPE on these assets even though real in the shared codebase.

Payable targets on these assets: Critical = an RPC service that mutates ANOTHER user's state without their interaction, or mints a comms-gatekeeper voice token for a room the caller isn't entitled to (act-as-victim / malicious wallet interaction). High = an RPC/uWS read returning another user's CONFIDENTIAL, non-public data. Community-voice moderation (kick/mute/ban/promote/demote/end) IS reachable via RPC, so it is in scope. Web reward grid was slashed 2026-09-09 (Critical web $3k) — see [[decentraland-program-change-2026-09]] if present.

Prior pass (~/Desktop/Decentra/code/AUDIT_REPORT.md + findings/01-05) found no confirmed Critical/High; only Low/Med (startPrivateVoiceChat presence oracle Finding A in-scope; privacy-settings unauth Finding B in-scope). #87537 (case-sensitive signer in decodeAuthChain) was the prior PAID Critical on this program — see [[engagements-ledger]].
