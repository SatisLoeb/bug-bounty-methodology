---
name: feedback-openapi-is-not-the-full-api-surface
description: "Don't conclude \"no auth flow / no token\" from the OpenAPI; auth/SIWE endpoints often live undocumented on the bare host — probe it + mine the prior dossier"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: b884ca02-6db2-4efd-b25a-86eed5d163e8
---

On Upshift (2026-06-24) I concluded "there is no way to get a Bearer token — no `/auth/login`, no nonce,
no SIWE endpoint anywhere in the live spec" after parsing the OpenAPI (51 paths on `api.augustdigital.io/api/v1`,
5 on `api.upshift.finance/v1`). **That was WRONG.** The operator pointed me to the prior dossier
(`upshift-package`), and the auth flow was finding **W16**: `POST /auth/sign` (SIWE) + `GET /users/{addr}/nonce`
— both **LIVE on the BARE host** `https://api.upshift.finance` (no `/v1`) and `backend.fractalprotocol.org`,
**completely absent from the OpenAPI**. Re-verified live: `/auth/sign` mints `{access_token, bearer}`, nonce
still STATIC, registration-gated (fresh wallet 404). W16 (ecrecover-only SIWE, static nonce) is an UNPATCHED
Critical and the untrusted entry that re-weaponizes the whole integrations/* authz + F2 chain.

**Two durable lessons:**
1. **OpenAPI ≠ full API surface.** Auth/SIWE/login/nonce endpoints, admin/debug routes, and bare-host paths
   are frequently undocumented. Never conclude "no auth flow / no token / endpoint doesn't exist" from the spec —
   probe the **bare host** (without the `/v1` or `/api` prefix), the legacy/staging hosts, and the frontend bundle's
   actual fetch calls. The spec is a hint, not the boundary (mirrors Rule 5: source ≠ deployed).
2. **When re-engaging a target that has a prior dossier, MINE IT FULLY before concluding any null.** Twice this
   session the prior `upshift-package` held the answer I'd missed (F2 was their F1; the auth flow was W16). If a
   blind constraint applied earlier, re-read the moment it's lifted. Relates to
   [[feedback-direct-disclosure-no-live-infra-probe]] and [[doctrine-surgical-reports-fight-to-the-end]].
