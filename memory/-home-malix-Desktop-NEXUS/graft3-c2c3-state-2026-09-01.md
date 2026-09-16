---
name: graft3-c2c3-state-2026-09-01
description: "Graft 3 C2/C3 (identity-signed + encrypted DKG envelope + blame) — as-built design, file map, KATs, build/verify status as of 2026-09-01 (session nexus-9f). Read with session-briefing-2026-09-01."
metadata: 
  node_type: memory
  type: project
  originSessionId: 6e8f229f-45a7-42dd-b800-65b0833fbf46
  modified: 2026-09-01T00:49:32.611Z
---

# Graft 3 C2/C3 — state (2026-09-01, session nexus-9f / 6e8f229f)

Written ON TOP of C1 commit 01d5754 (other session nexus-38/bbf2978a committed C1; agreed by
cross-session message that it stays off the tree). COMMITTED as bcc918b (2026-09-01 ~02:15, on the user's word) on feat/fcmp-full-pipeline — NOT pushed, NOT deployed, local server NOT restarted.

## Design as built (deviations from plan §4.2/4.3 documented in plan §4.4b)
- ctx32 = Keccak256("NEXUS_DKG_CTX_V1" ‖ escrow_id ‖ buyer_pk ‖ vendor_pk ‖ arbiter_pk ‖ nonce)
  ROLE-ordered (binds index→identity), nonce = server-issued 32B at init (frost_dkg_state.session_nonce).
- R1 envelope {package, enc_pk, sig}: ed25519 identity sig over "NEXUS_DKG_R1_V1"‖ctx‖role‖enc_pk‖package
  (under identity.rs NEXUS_IDENTITY_V1 domain). enc_pk = fresh per-DKG key (serai model), NOT the identity pk.
- R2 envelope {ephemeral_pk, ciphertext, pop, sig}: X=x·G, S=x·B_j, key=Keccak("NEXUS_DKG_ENC_KEY_V1"‖ctx‖s‖r‖X‖B‖S),
  ChaCha20-Poly1305 nonce=0 (per-message key), aad=ctx‖s‖r‖X; PoP c=Keccak→scalar("NEXUS_DKG_POP_V1"‖ctx‖s‖r‖R‖X‖ct),
  s=c·x+r (c‖s); identity sig over "NEXUS_DKG_R2_V1"‖ctx‖s‖r‖X‖pop‖ct.
- Blame: accuser reveals S with DLEQ log_G(B_j)=log_X(S) ("NEXUS_DKG_BLAME_DLEQ_V1"‖ctx‖accuser‖accused‖G‖rG‖B‖X‖rX‖S).
  Verdict AccusedAtFault / AccuserAtFault / Unattributable; share check = frost SecretShare::verify (vss_verify).
- Arbiter identity: ARBITER_IDENTITY_SEED else Argon2id(ARBITER_VAULT_MASTER_PASSWORD, vault salt)→Keccak("NEXUS_ARBITER_IDENTITY_V1").
  Public at GET /api/escrow/frost/arbiter-identity; written to escrows.arbiter_identity_pk at init.
- Client TOFU pins: vendor pins buyer pk from invite; buyer pins vendor pk on first sight; arbiter pk per-device or VITE_ARBITER_IDENTITY_PK.

## KATs (pycryptodome, scratch dkg_kat.py) — all asserted in wallet/wasm/src/dkg_auth.rs tests (11/11 pass)
- ctx("esc_00112233445566aa", 0x11*32, 0x22*32, 0x33*32, 0x44*32) = 82d63e3154d0af663b50c6745298b801aad0a109e6c92412a054b9b79f1f38de
- enc_key(ctx=07*32,1,2,X=aa*32,B=bb*32,S=cc*32) = 829a0cb031ffae56c963aa2a09deb376875ce523d666a2149f559c1d64162a73
- pop_c(ctx=07*32,1,2,R=0a*32,X=0b*32,ct=deadbeef) = 0f02bb61181266c0d176361c74f4259cf785e10e657a1a2e9da2a3455b4b9900
- blame_c(ctx=07*32,acc=2,accd=1, 01..06*32) = 9cdadc217a7d77b28f55b111a7c076cb18726e47666613070d21b289c2006503
- r1_sig(seed 0011..eeff, ctx 07*32, role 2, enc bb*32, pkg 0102030405) = 2f1d6083…2f03 ; r2_sig = c5829ba6…1d00

## Files
- NEW wallet/wasm/src/dkg_auth.rs (+lib.rs mod/re-exports; escrow_clsag::random_scalar pub(crate); frost_dkg.rs check_round2_share + frost_dkg_check_share)
- NEW server/migrations/2026-09-01-000007_dkg_auth (9 cols on frost_dkg_state) — APPLIED to local marketplace.db via sqlcipher (version 20260901000007, backup marketplace.db.bak-*-pre000007). NOT on VPS.
- NEW server/src/config/arbiter_identity.rs (+config/mod.rs, main.rs init after platform-wallet validation)
- server: schema.rs (frost_dkg_state +9), models/frost_dkg.rs (state fields+accessors, DkgStatus new fields + skeleton(), BlameRecord, FrostRole tag/from_index/as_str/ALL),
  services/frost_coordinator.rs REWRITTEN (DkgError Auth/State/Other; init requires identities+nonce; submit_round1/2 verify envelopes; submit_blame; fail_dkg; arbiter r1/r2/r3 sign/encrypt/open/blame),
  services/arbiter_auto_dkg.rs, arbiter_watchdog/key_vault.rs (store/get_dkg_enc_secret, derive_key pub(crate)), handlers/frost_escrow.rs (Round1Request+enc_pk/sig, Round2Request envelopes, BlameRequest, dkg_error_response 400/409/500, POST /{id}/dkg/blame, GET /arbiter-identity)
- front: services/wasmService.ts (11 new exports), apiService.ts (envelope types, submitRound1 sig, submitDkgBlame, getArbiterIdentity, DkgStatus fields), identity.ts (myIdentitySecret, pinOrCompareCounterpartyPk, pinOrCompareArbiterPk), hooks/useEscrowStatus.ts (identity pks), hooks/useFrostDkg.ts REWRITTEN, App.tsx (buyer TOFU pin + mismatch log)
- DOX/HARDENING-PLAN §4.4b as-built.

## Verify/build status — ALL GREEN; committed bcc918b; NOT pushed/deployed. Local server RESTARTED on d8caa07c (2026-09-01 ~02:11 local, user's order): pid + log in THIS session's scratchpad /tmp/claude-1000/-home-malix-Desktop-NEXUS/6e8f229f-45a7-42dd-b800-65b0833fbf46/scratchpad/server.{pid,log}; arbiter identity pk 90431458d5cc31e06a9d4e923a13afb2687de586187ae7451b4b97d4604b7e21 (derived from ARBITER_VAULT_MASTER_PASSWORD); GET /api/escrow/frost/arbiter-identity answers. Start cmd: cd repo; set -a; . ./.env; set +a; RUST_LOG=info MONERO_DAEMON_URL=http://xmr-node.cakewallet.com:18081 SERVER_PORT=8080 setsid nohup ./target/dev-release/server > log 2>&1 < /dev/null & (old server ignored SIGTERM → needed SIGKILL).
- wallet_wasm native tests 40/40 (dkg_auth 11/11); cargo check -p server exit 0; wasm-pack OK (static/wasm + public/wasm, 12 exports);
  npm run build OK (static/app/assets/CzoHQz1K.js); dev-release artefact target/dev-release/server sha d8caa07c (8m02s).
- Server unit test config::arbiter_identity NOT executed (needs a debug test build of server — skipped for time/OOM).
- Next: user restarts local server on d8caa07c (needs ARBITER_VAULT_MASTER_PASSWORD exported), browser smoke test:
  create → invite blob → join → DKG (both tabs log "Identities pinned … Session bound", "Round 1 broadcasts verified",
  "Inbound shares verified…") → address published; then commit + deploy (000006+000007 pending on VPS).
- Old note: see the session recap; pre-existing tsc errors App.tsx:2887+ generateLog('ERROR') are NOT ours (in HEAD).
Build cycle: cargo check -p server -j2 → wasm-pack build --target web --out-dir ../../static/wasm (cd wallet/wasm) → cp to nexusfinalappdsn/public/wasm → npm run build (→static/app) → dev-release artefact (see session-briefing-2026-09-01 §RESUME step 2c). Never 2 cargo at once.
