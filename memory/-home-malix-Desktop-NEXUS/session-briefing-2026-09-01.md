---
name: session-briefing-2026-09-01
description: "Live resume state of NEXUS/Onyx as of 2026-09-01 — prod = Graft 1 deployed; IN-FLIGHT Graft 3 C1 (identity keys) code-complete but uncommitted/unbuilt. Read FIRST when resuming; supersedes session-briefing-2026-08-31."
metadata:
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-01T00:32:54.050Z
---

# RESUME STATE — 2026-09-01 (read this first; supersedes the 2026-08-31 briefing)

## Production (VPS 72.62.176.175, onyx-escrow.com, unit nexus-server, /opt/nexus/target/dev-release/server)
- Running artefact `41007ef1…` (commit f318f5b) = Graft 1 (nonce DLEQ) + all the hardening-pass fixes
  + earlier front fixes. Migration 000005 (nonce_dleq cols) applied on VPS. Bundle BaHBsG6e.js.
- Branch `feat/fcmp-full-pipeline` pushed through **3754ee6** (origin in sync as of the Graft-1 deploy).
- Deploy = `SSH_VIA_TOR=0 ./deploy/deploy-to-vps.sh --no-build` (ships local target/dev-release/server
  + rsync static + applies pending migrations + restart). The classifier BLOCKS me from running it →
  the USER runs it via `! …`. SSH direct works; Tor ProxyCommand fallback if the ISP route filters.

## Graft ordering DECIDED (owner, 2026-09-01): 1 (DONE, deployed) → 3 (IN PROGRESS) → 2 (last)
- Graft 3 before Graft 2 because Graft 2 is attribution-only AND narrow: a rational malicious signer
  WITHHOLDS (inherently unattributable), doesn't submit garbage → Graft 2 mostly catches an honest
  client bug (debuggability), not a theft vector. Graft 3 closes the active-relay MITM (server plays
  vendor↔buyer → 2-of-3 shares server-side) = real fund security.
- Graft 2 guardrails when we do it: (1) frame as debuggability (withholding unattributable);
  (2) Identifier→role map (1/2/3→buyer/vendor/arbiter) MUST match the Lagrange λ exactly or an honest
  pair fails → false-positive attribution (worse than opaque). KAT both signer forms + the mapping.
  Algebra (traced): 1st signer s=α−c_p·(λb+d)−c_c·z_diff ⇒ s₁·G=R₁−c_p·(λB₁+d·G)−c_c·(z_diff·G);
  2nd signer s=α−c_p·(λb) ⇒ s₂·G=R₂−c_p·(λB₂) (NO d/z term). derive()/challenges() in escrow_clsag.rs
  need NO secret → server can recompute c_p=μ_p·c_real, c_c=μ_c·c_real from public + the s-vector +
  aggregated nonce. Verifying shares B_i available server-side from generate_arbiter_round3's
  pub_package (dkg::part3 → (key_package, pub_package); it currently discards pub_package's shares).

## Graft 1 (DEPLOYED) — nonce DLEQ + session binding (closes G1+G2)
- Proves R=α·G ∧ R'=α·Hp(P_real) share α, bound to (escrow_id, round_id, clsag message, ring).
  Rejected with attribution before store/aggregate; consumer-verifies-producer (coordinator checks
  buyer/vendor; signClsagPartial checks the peer → dispute winner checks the arbiter's nonce).
- Code: wallet/wasm/src/escrow_clsag.rs (nonce_dleq_context/prove/verify + *_hex), crypto.rs
  (escrow_nonce_dleq export, param renamed one_time_pubkey_hex), escrow_verify_nonce_dleq export;
  server frost_signing_coordinator.rs (submit_nonce_commitment verifies via wallet_wasm native +
  identity/torsion reject in aggregate_edwards_points), frost_signing.rs (nonce_dleq in request +
  get_nonce_commitments exposes DLEQs), reference_arbiter.rs (arbiter proves role 3);
  front frostSigningService.ts (generate/submit/verify), migration 000005.
- KAT (pycryptodome-independent): nonce_dleq_context("esc_00112233445566aa","00000000-0000-0000-0000-
  000000000001", 0x22*32, ring[key=0x33*32,mask=0x44*32; key=0x55*32,mask=0x66*32]) =
  51df85facbe5d417ae741a125c87f15622f801c9c77d629ad2809d6757f96612. Challenge uses keccak256_to_scalar
  (from_bytes_mod_order — same as CLSAG c_p/c_c, NOT serai wide-reduce). Mainnet-accepted tx d68314a0…

## Graft 3 C1 (identity keys) — COMMITTED (01d5754), NOT built/deployed. PEER nexus-9f doing C2/C3 in this SAME tree.
COORDINATION: peer session nexus-9f is layering Graft 3 C2/C3 (signed+encrypted DKG envelope + blame)
in the same working tree. I committed C1 with EXPLICIT paths (no git add -A), released the target/
lock (ran NO build), and did NOT start C2. Peer owns: wallet/wasm/src/dkg_auth.rs,
server/migrations/2026-09-01-000007_dkg_auth/, server/src/config/arbiter_identity.rs, + edits in
frost_coordinator.rs, frost_escrow.rs, arbiter_auto_dkg.rs, key_vault.rs, models/frost_dkg.rs,
main.rs, lib.rs, frost_dkg.rs, escrow_clsag.rs (pub(crate) helpers), useFrostDkg.ts, and later
wasmService.ts/apiService.ts/App.tsx/identity.ts/schema.rs(frost_dkg_state cols). The combined
C1+C2/C3 build + mainnet test + deploy will come from that thread. Do NOT rebuild/deploy from here
without coordinating with nexus-9f (target lock + shared files).

## (history) Graft 3 C1 — was IN-FLIGHT, now committed as 01d5754 (+ 937467e foundation)
COMMITTED: **937467e** (1 ahead of origin, UNPUSHED) = wallet/wasm/src/identity.rs foundation
(identity_generate/sign/verify, ed25519-dalek 2.1, domain "NEXUS_IDENTITY_V1") + lib.rs mod. wasm 28/28.

UNCOMMITTED C1 wiring (all written, tsc 0 errors, wasm identity tests 3/3, server cargo check was
STILL RUNNING at handoff — VERIFY it passed via task bzr5x8mi3 / re-run `cargo check -p server -j 2`):
- wallet/wasm/src/identity.rs (M): added escrow_identity_sas + identity_sas_native + KAT. SAS =
  Keccak256("NEXUS_IDENTITY_SAS_V1" ‖ sorted(pk_lo,pk_hi))[..8] as XXXX-XXXX-XXXX-XXXX. KAT:
  pk_a=3ccd241cffc9b3618044b97d036d8614593d8b017c340f1dee8773385517654b,
  pk_b=00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff → 412B-C7FA-3D7E-97E2
  (order-independent). ed25519 KAT: seed 0011..eeff → pub 3ccd241c..654b, sig of 0xAA*8 =
  6923477586d26157…c141f80c (pycryptodome RFC8032).
- server/src/models/escrow.rs (M): Escrow struct + 3 fields at END (buyer/vendor/arbiter_identity_pk
  Option<String>); NewEscrow + buyer_identity_pk/vendor_identity_pk.
- server/src/schema.rs (M): escrows table + 3 identity cols at END (after escalated_at).
- server/src/services/escrow.rs (M) + server/src/models/escrow.rs Self builder (M): the TWO
  OTHER NewEscrow constructors — added buyer_identity_pk:None, vendor_identity_pk:None (found by
  the server cargo check; re-check running as bt7phqj1b at handoff).
- server/src/handlers/user.rs (M): CreateEscrowRequest.identity_pk; create_escrow sets creator's pk
  in NewEscrow (validated 64-hex); JoinEscrowRequest{identity_pk} + join_escrow body
  Option<web::Json<JoinEscrowRequest>> + post-update sets joiner's pk on assigned_role.
- nexusfinalappdsn/services/identity.ts (NEW): getOrCreateIdentity (device key in localStorage
  nexus_identity_v1), myIdentityPublic, pin/pinnedCounterpartyPk (nexus_peer_pk_<id>), buildInvite
  (base64("escrow_id:pk")), parseInvite (blob or legacy esc_), identitySas.
- nexusfinalappdsn/services/wasmService.ts (M): identity_generate + escrow_identity_sas exposed (raw
  iface + wrapper obj + wrapper iface).
- nexusfinalappdsn/services/apiService.ts (M): createEscrowLobby(...,identityPk) + joinEscrow(id,
  identityPk) send identity_pk; EscrowDetails + buyer/vendor/arbiter_identity_pk.
- nexusfinalappdsn/App.tsx (M): import identity helpers; handleBuyerInitiate getOrCreateIdentity +
  pass pk; handleCopyUplink copies buildInvite; handleSellerJoin parseInvite+pin+identity+joinEscrow;
  SAS vars (buyer uses escrowStatus.vendor_identity_pk, vendor uses pinnedCounterpartyPk) + SAS panel
  before the group-key fingerprint panel (FUNDING step).
- server/migrations/2026-09-01-000006_identity_pk/ (NEW): 3 ALTER ADD COLUMN. APPLIED to LOCAL DB +
  __diesel_schema_migrations (20260901000006). NOT on VPS.
- DOX/HARDENING-PLAN-crypto-2026-08-31.md (M): §2.1b consumer-verifies-producer (co-edited by user).

### RESUME C1 — DONE: committed 01d5754 (server check green). Remaining C1 build/deploy is folded into
### the peer's C1+C2/C3 combined cycle. Original steps kept below for reference only:
1. Confirm server compiles: `cargo check -p server -j 2` (was running as bzr5x8mi3). Fix any error.
2. Build cycle IN SEQUENCE (shared target/ lock → never 2 cargo at once):
   a. `cd wallet/wasm && wasm-pack build --target web --out-dir ../../static/wasm` (exports
      identity_generate/escrow_identity_sas). Verify: grep -c escrow_identity_sas static/wasm/wallet_wasm.js.
      Then `cp static/wasm/wallet_wasm.{js,d.ts} static/wasm/wallet_wasm_bg.wasm nexusfinalappdsn/public/wasm/`.
   b. `cd nexusfinalappdsn && npm run build` (→ static/app, new bundle hash).
   c. artefact: `CARGO_INCREMENTAL=0 RUSTFLAGS="--remap-path-prefix=$(pwd)=/build --remap-path-prefix=$HOME/.cargo=/cargo --remap-path-prefix=$HOME/.rustup=/rustup" cargo build --locked --profile dev-release --bin server -j 2` (~8-20 min; keep ≥4G disk).
3. Restart local server on the new artefact (kill pid in scratchpad/server.pid — currently 1094008,
   the Graft-1 build; env: MONERO_DAEMON_URL=http://xmr-node.cakewallet.com:18081 SERVER_PORT=8080
   RUST_LOG=info, . ./.env). Tera caches templates → MUST restart for the new bundle. Re-arm the log monitor.
4. Commit C1 (identity.rs SAS, server files, migration 000006, front files, identity.ts). Then a
   browser smoke test: create → the invite (copy) is a base64 blob; vendor pastes → joins; at FUNDING
   BOTH tabs show the SAME "Identity check (SAS)" code (buyer from server vendor_identity_pk, vendor
   from pinned buyer pk) + the group-key fingerprint. Deploy (migration 000006 on VPS) on user's word.
5. Then C2 (the MITM kill): sign every DKG round1/round2/complete msg under the identity key bound to
   context=H(escrow_id‖sorted(pks)‖dkg_session_nonce); VERIFY IN WASM against the pinned peer pk
   before frost part2/part3. C3: encrypt round2 to recipient identity + blame (EncryptionKeyProof+DLEQ).

## Local stack
- Server target/dev-release/server pid in scratchpad/server.pid (1094008 = Graft-1 artefact 41007ef1
  until the C1 rebuild). wallet-rpc 18082-18088 on xmr-node.cakewallet.com:18081. Redis local (PONG).
  Front served from static/app (Rust serves /wasm from static/wasm, /assets from static/app/assets;
  index.html via Tera → RESTART server after a front rebuild).
- Group-key fingerprint (shipped) = Keccak256("NEXUS_GROUP_FP_V1"‖group_pubkey)[..8]; identity SAS is
  the pre-DKG continuum of it.

## Standing rules / gotchas
- French; expert reviewer; verify every claim in code ("sur pièces"). Commit only when asked; push
  only when asked; deploy only when asked (user runs deploy/ssh; classifier blocks me). Never type
  passwords in browsers.
- Analyze-first → ONE build (server build 8-20 min). Disk chronically tight: delete target/debug
  (~11G, not used by dev-release), target/wasm32, superseded target/*/deps; NEVER touch a dir a
  running build uses (target/dev-release + ~/.cargo/registry/src during a build).
- pgrep/pkill patterns matching own cmdline kill the shell (exit 144) — bracket tricks / PIDs.
- Two cargo invocations share the target/ lock — run wasm/server builds sequentially.
- SQLCipher: KEY=$(grep -E '^DB_ENCRYPTION_KEY=' .env|cut -d= -f2-|tr -d "\"'"); PRAGMA key='$KEY';
- Compound bash + `(` in remote ssh one-liners breaks eval — use ssh 'bash -s' <<'REMOTE' heredocs.
- GitGuardian may re-flag bundles (decorative CLSAG hex in the footer ticker) — false positive, repo private.
