---
name: invite-router-impl-2026-09-04
description: "Invitation router (DOX/INVITATION-ROUTER-SPEC.md) IMPLEMENTED on source, NOT built. Needs FRONT + SERVER rebuild — spec's 'no server change' was WRONG: no SPA catch-all exists, so /e/<code> needs a main.rs route added."
metadata:
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-04T20:07:26.740Z
---

Invitation router per `DOX/INVITATION-ROUTER-SPEC.md` — shareable `onyx-escrow.com/e/<code>` link that
drops the vendor into the escrow. **SHIPPED to prod 2026-09-04** (artefact `db65545d…`; `/e/<code>`
verified live — HTTP 200 serving the SPA, incl. `/e/zzzzbad` → SPA → LinkInvalid client-side). Was: implemented on source, verified** (see
[[build-coordination-manual-gate]]). Stacks with [[sas-wordlist-impl-2026-09-04]] (both edit
`nexusfinalappdsn/`; one `npm run build` covers both).

**Files:**
- `services/identity.ts` — §1 base64url `buildInvite`/`parseInvite` (b64urlEncode/Decode + safeDecode;
  parse tries base64url THEN legacy `atob` for back-compat, then raw `esc_`). Same file as the SAS
  work — landed together. Verified standalone: round-trip, URL-safe (no `+/=`), base64url decode,
  **legacy standard-base64 back-compat**, raw `esc_`, garbage→no inviterPk (6/6).
- `services/route.ts` — NEW, `inviteCodeFromPath()` (`/^\/e\/([^/]+)\/?$/`).
- `components/JoinLanding.tsx` — NEW: `JoinLanding` (mockup 02) + `InviteInvalid` (mockup 04) overlays
  (fixed `z-50`, under AuthModal's `z-[60]`).
- `App.tsx` — imports (QRCode, inviteCodeFromPath, JoinLanding/InviteInvalid); `inviteError`/
  `showJoinLanding` state + `shareLink` memo + `inviteQrRef`; 3 effects (deep-link-on-mount, invite QR
  render, state↔URL replaceState); `handleCopyUplink` copies `shareLink`; the DKG_WAITING "Share
  Uplink" block now shows the link + a QR (reused the existing `qrcode` dep — no new dep); the two
  overlays rendered next to AuthModal.
- `server/src/main.rs` — `.route("/e/{code}", web::get().to(serve_spa))` after `/register`.

**Two spec corrections from tracing first (ANALYZE-FIRST):**
1. **`role` is a `useMemo` derived from `user.role` (auth) — there is NO `setRole`.** The spec's
   `setRole(Role.VENDOR)` doesn't apply; the escrow role is backend-assigned on join. Deep-link shows
   a JoinLanding card (auth-aware: "Sign in to join" → AuthModal when `!user`); join flow unchanged.
2. **NO SPA catch-all in prod.** `server/src/main.rs` `serve_spa` is wired via EXPLICIT routes
   (`/`, `/dashboard`, `/escrow/{id}`, `/login`, `/register`…), NO `default_service`. So `/e/<code>`
   would 404 in prod. Spec §5 authorized adding the route → added. **⇒ this feature needs a SERVER
   REBUILD, not front-only** (contradicts the spec header). Dev (Vite SPA) needed nothing.

**Build scope (on user go):** `cd nexusfinalappdsn && npm run build` (front, covers invite + SAS) +
`cargo build --profile dev-release -p server` (main.rs route; `-j 2` vs [[build-oom-server-crate]]) +
`SSH_VIA_TOR=0 ./deploy/deploy-to-vps.sh --no-build` (ships the rebuilt local server binary + static).
No wasm-pack for THIS feature (only SAS needs it). Verified: my TS type-clean; the 5 `tsc` errors are
PRE-EXISTING `generateLog('ERROR')` bugs (in git HEAD, App.tsx ~3021-3050), unrelated, and esbuild
(vite build) ignores them. No test runner in the front (added none). §7 acceptance is manual/logic.
