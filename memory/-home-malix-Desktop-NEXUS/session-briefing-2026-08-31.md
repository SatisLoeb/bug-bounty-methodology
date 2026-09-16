---
name: session-briefing-2026-08-31
description: "Live state of the NEXUS/Onyx work as of 2026-08-31 — what is deployed, what is local/uncommitted, the mainnet dispute test in progress, exact next steps, and operational gotchas. Read first when resuming."
metadata:
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-08-31T14:07:57.313Z
---

# Where things stand (2026-08-31, ~15:00 UTC)

## Production (VPS 72.62.176.175, onyx-escrow.com, unit `nexus-server`, binary `/opt/nexus/target/dev-release/server`)
- Since 2026-09-01 ~23:49Z: artefact sha256 `41007ef1…` (commit f318f5b) = ALL of the above +
  winner↔arbiter dispute signing + pair-specific pKI + CSRF front + dispute cooldown/no-op fixes.
  Migration 000004 applied remotely (after DB backup). Prod serves bundle `QI3gJ7jG.js`. Provenance
  committed (ea60099). Deploy = `deploy/deploy-to-vps.sh` (now also enables+starts the
  `nexus-wallet-scanner@18087/18088` units — b1bee53); `--no-build` ships the local artefact.
- ⚠ The scanner units (funding detection) were found `disabled`+stopped since 07:59Z (disk
  maintenance) — user asked to run `systemctl enable --now nexus-wallet-scanner@18087
  nexus-wallet-scanner@18088` over ssh (the auto-mode classifier blocks me on prod state changes
  and on running deploy-to-vps.sh; the user runs those via `!`). VERIFY they are active.
- UNPUSHED local commits (push only on the user's word): b1bee53 deploy: start (and enable) the wallet-scanner units on every deploy, not just probe them; ea60099 deploy: artefact bd391b7e (abe65bc) shipped to production — dispute cooldown + no-op dispute fixes; abe65bc docs: initiate_dispute cooldown ordering + false-success findings; 168accb fix(dispute): initiate_dispute no longer reports success on a no-op transition; ed51bcd front: rebuild bundle to match App.tsx (dispute reason message)
- Redis on the VPS: localhost, AOF on. SSH direct `ssh root@72.62.176.175` (or Tor ProxyCommand if
  the ISP route is filtered). Hostinger suspension 08-28 unexplained; no off-machine backups.

## Local (this laptop), NOT yet deployed
- Commits `bf2edc1` + `010bf53` (both PUSHED to origin 2026-08-31 ~15:10 UTC; branch in sync): **winner↔arbiter
  signing in the reference scheme** — `wallet_wasm::escrow_clsag` native hex API
  (`nonce_points_hex`, `escrow_sign_second_native`), server depends on `wallet_wasm` natively,
  `server/src/services/arbiter_watchdog/reference_arbiter.rs`, coordinator `init_signing` accepts
  `resolved_*` with pair, `submit_nonce_commitment` signer-set aware, `/sign/nonces` exposes `arbiter`,
  migration 000004 (`frost_signing_state.arbiter_r_public/_prime` — applied locally, NOT yet on VPS),
  front dispute flow publishes winner nonce → waits arbiter nonce → signs first.
- **`010bf53` (committed + pushed): pair-aware partial key images for disputes + live front fixes.**
  Hole found by tracing: pKI = λ·b·Hp(P) is pair-specific; the front used λ{1,2} always, the server
  aggregated buyer+vendor only, nobody produced the arbiter's pKI → a withholding loser blocks the
  winner forever (`init_signing` needs the aggregated KI). Fix: `resolve_dispute` clears stored pKIs
  unless the KI is already aggregated (pair-independent, kept); `ReferenceArbiter::advance` step 0
  publishes the arbiter pKI (λ₃ of {3,winner}, native `wallet_wasm::escrow_clsag::partial_key_image_hex`)
  and aggregates; `key_image_aggregation::try_aggregate_escrow_key_images` picks the pair from
  `dispute_signing_pair` (`signing_pair_roles`); PKI handler rejects the loser after resolution;
  watchdog no longer calls `init_signing` before the KI is aggregated (the winner's front inits);
  front `computeAndSubmitPartialKeyImage(..., signerPair?)`, dispute flow passes {winner, 3}.
  Tests: wasm 23/23 (new `partial_key_images_sum_to_the_same_key_image_for_every_pair`), server lib
  20/20 (key_image_aggregation/arbiter_watchdog/frost_signing filters). Files: escrow_clsag.rs,
  key_image_aggregation.rs, handlers/escrow.rs (resolve + PKI handler), reference_arbiter.rs,
  frostSigningService.ts. Pre-existing unrelated tsc errors in App.tsx ('ERROR' log level) untouched.
- Local stack: server `./target/debug/server` (built 15:04 local with the pKI fix) pid in
  `scratchpad/server.pid` (669822), 127.0.0.1:8080, log `scratchpad/server.arbiter3.log`; wallet-rpc
  18082–18088 against `xmr-node.cakewallet.com:18081` (start script: scratchpad `start-stack.sh`).
  Front served = `static/app/assets/DAwmHCQD.js` (vite outDir `../static/app`). Prod still serves
  `B-680Eaj.js`. Monitor task on the log: b2bq1pjyb (re-arm after restarts).
- Earlier today the artefact server (dev-release a89f22c) had silently kept port 8080 while the
  debug arbiter build failed to bind — always check `/proc/<pid>/exe` of the 8080 listener.

## Graft ordering DECIDED (2026-09-01): 1 (done) → 3 (next) → 2 (last)
- Graft 3 BEFORE Graft 2, per the owner's reasoning: Graft 2 is attribution-only AND narrow — a
  rational malicious signer WITHHOLDS (inherently unattributable), doesn't submit garbage; so Graft 2
  mostly distinguishes an honest client bug (debuggability/UX), not a theft vector. Graft 3 closes
  the active-relay MITM (server plays vendor↔buyer → 2-of-3 shares server-side) = real fund security.
- Graft 2 guardrails when we do it (from the owner): (1) frame as debuggability, withholding is
  unattributable; (2) the Identifier→role map (1/2/3→buyer/vendor/arbiter) must match the Lagrange λ
  exactly or an honest pair fails the check (false-positive attribution, worse than opaque) — KAT
  both signer forms + the mapping. Algebra traced: 1st signer s=α−c_p·(λb+d)−c_c·z_diff, 2nd
  s=α−c_p·(λb) (NO d/z term); verifying shares available server-side from generate_arbiter_round3's
  pub_package (no front change).

## Graft 3 C1 — identity-key foundation DONE (2026-09-01), commit 937467e (1 ahead, unpushed)
- wallet/wasm/src/identity.rs: identity_generate/sign/verify (ed25519-dalek 2.1, was unused),
  domain NEXUS_IDENTITY_V1, native + wasm exports. KAT = pycryptodome/RFC8032 (seed 0011..eeff →
  pub 3ccd241c..654b, deterministic sig) + tamper cases. wasm 28/28. NO wiring, NO wasm rebuild yet.
- C1 REMAINING (analyze done, anchors confirmed): server escrows.{buyer,vendor,arbiter}_identity_pk
  columns + register (buyer at create_escrow user.rs:505, vendor at join_escrow user.rs:691; arbiter
  = platform published pk pinned in client); front — generate/load identity key (IndexedDB like the
  DKG keystore), invite blob = base64(escrow_id ‖ inviter_pk) (today invite = pasted escrow_id, no
  router; handleBuyerInitiate App.tsx:977, handleSellerJoin :999, copy :349), pin counterparty pk +
  compare server's copy (WYSIWYS pattern), SAS = fingerprint of sorted(identity_pks) as a CONTINUUM
  with the shipped group-key fingerprint (identity SAS = pre-DKG, group fp = post-DKG).
- C2 (the MITM kill): sign every DKG round1/round2/complete message under the identity key bound to
  context=H(escrow_id‖sorted(pks)‖dkg_session_nonce); verify in WASM against the pinned peer pk
  before feeding frost part2/part3. C3: encrypt round2 to recipient identity + blame (EncryptionKeyProof+DLEQ).

## Crypto grafting (serai primitives) — Graft 1 DONE

## Crypto grafting (serai primitives) — Graft 1 DONE locally (2026-09-01), NOT deployed
- Plan: DOX/HARDENING-PLAN-crypto-2026-08-31.md (committed d993e5a) — G1 nonce DLEQ, G2 session
  binding, G3 DKG identity/auth (deferred), rho OUT of scope. §2.1b = consumer-verifies-producer.
- P1 verified on-piece: both nonce generators use Hp(P_real) (crypto.rs::generate_nonce_commitment
  ×4 front sites via realRingKey; escrow_clsag::nonce_points_hex for the arbiter).
- Graft 1 committed **84897a0** (5 ahead of origin, with the earlier 1d23a02/757b60b/… front fixes):
  nonce DLEQ proving R=αG ∧ R'=αHp(P_real) share α, session-bound (escrow_id,round_id,message,ring).
  Rejected with attribution before store/aggregate. One impl in wallet/wasm/src/escrow_clsag.rs
  (nonce_dleq_context/prove/verify + hex APIs), server verifies via wallet_wasm native (no mirror).
  Migration 000005 (buyer/vendor/arbiter_nonce_dleq on frost_signing_state) — applied to LOCAL DB,
  NOT on VPS. KAT ctx = 51df85fa… (pycryptodome-independent). wasm tests 26/26; server cargo check OK.
  Front: generate produces DLEQ, submit sends it, signClsagPartial verifies the PEER's DLEQ
  (dispute winner checks the arbiter's nonce). New wasm exports escrow_nonce_dleq /
  escrow_verify_nonce_dleq. wasm rebuilt (static/wasm + public/wasm), front bundle BaHBsG6e.js.
- Graft 1 DEPLOYED to prod 2026-09-01 (artefact 41007ef1, migration 000005 = 3 nonce_dleq columns on
  the VPS, bundle BaHBsG6e.js). Mainnet-accepted: full release esc_ed0f09… tx d68314a0…, both DLEQs
  stored (128 hex), zero invalid-DLEQ rejections on the honest path. Branch pushed, in sync with origin.
- Remaining grafts (own builds): Graft 2 per-partial verification (needs verifying shares stored at
  DKG); Graft 3 C1/C2/C3 DKG identity/auth/encrypt/blame. Deploy of Graft 1 (migration 000005 on VPS)
  pending the user's word.

## Hardening pass (2026-08-31 eve)

## Hardening pass (2026-08-31 eve) — DEPLOYED (artefact 50dcd7ff), 11 commits await PUSH
- Local commits ahead of origin (push on the user's word): 95c01cf (resolve_dispute swallow),
  70df584 (track Cargo.lock), 65bfb4e (reproducible build flags), 7cdd3ff (group-key fingerprint
  blocking gate — item 1), 4f2f466 (monitor balance=0 re-verify), 18e5fbd (escalation replay/false-
  released fix R2), 34b8e96 (arbiter share no-TTL + watchdog GC R1). Front bundle = C2uCYJUD.js;
  WASM rebuilt with escrow_group_fingerprint (static/wasm shipped via rsync, tracked copy in
  nexusfinalappdsn/public/wasm). Full detail: progress.md "Hardening pass (2026-08-31 eve)".
- Artefact `50dcd7ff` built (21m58s, reproducible: 0 /home/ paths, remap to /build,/cargo; markers
  present), smoke-test 400/409/400 PASS on it, deployed via `deploy-to-vps.sh --no-build` (user ran
  it; no migration; remote sha256 verified; nexus-server + both scanners active; health 200; bundle
  C2uCYJUD.js; wasm exports escrow_group_fingerprint). Provenance appended by the deploy script.
- 11 local commits ahead of origin (push on the user's word): 95c01cf 70df584 65bfb4e 7cdd3ff
  4f2f466 18e5fbd 34b8e96 8ff5694 c79a836 52dfe67 7078a99.
- Disk was reclaimed 441M→~7.5G (deleted target/dev-release, target/release, target/wasm32,
  ~/.cargo/registry/src, old logs); a fresh build repopulates target/dev-release (~4.5G).
- DEFERRED to its own build+mainnet cycle: identity keys + signed DKG/session messages (item 2 deep
  part) — rewrites the just-validated DKG transport; design in progress.md "Deferred … item 2".
  The round2 BOLA/IDOR authz is now FIXED (8ff5694); what remains in that build is round2
  CONFIDENTIALITY (encrypt to recipient) + message AUTHENTICITY (identity signatures).

## Mainnet dispute test

## Mainnet dispute test — PASSED 2026-08-31 14:52 UTC (item 1 done locally, NOT yet deployed)
- `esc_d0eacdd677bc4788`: buyer won, tx `faad5183…` mined block 3752312, refund to `47mP1VgU…`,
  KI `696fe2ac…` = buyer+arbiter aggregate, DB `completed` / `arbiter_frost_partial_sig=
  reference-second-signer`. Full server sequence recorded in progress.md ("Item 1 — mainnet dispute
  acceptance PASSED").
- Fixed live in the FRONT during the test (uncommitted, built into `static/app`): "Raise a Dispute"
  on the buyer DELIVERED panel + vendor waiting panel; `fetchApi` sends `X-CSRF-Token` (whoami,
  cached, retry once) — `initiate_dispute`/`resolve_dispute` require it; dispute reason ≥10 chars.
- NOT applied (user interrupted that tool call — ask before redoing): server `initiate_dispute` arms
  the 5-min cooldown before validation → move `session.insert("last_dispute_at")` after the filed
  transition. Also pending: blockchain monitor multi-instance `balance=0` flake.
- Arbiter account for local escrows = `arbiter_system` (f9edebc7…, assigned in `escrows.arbiter_id`;
  the UI dispute list filters by assignment). Password reset locally to `Arbiter-Onyx-2026!QEdT6V`
  (dev DB only; the user ran the reset script themselves — the auto-mode classifier blocks such
  DB writes for me).
- Cooldown fix WAS in 010bf53 after all (the interrupted call had written the file before cargo
  check). Then found: `initiate_dispute` swallowed the inner Err of its web::block → false 200 +
  `escrow.disputed` webhook on a no-op transition (probe on a pending_counterparty escrow). Fixed in
  `168accb` (precise 409 + propagated result), docs in `abe65bc`; bundle rebuilt in `ed51bcd`.
  These three commits are LOCAL (not pushed yet — push on the user's word).
- Artefact v2 (tree 168accb/abe65bc) building in background: log scratchpad `artefact-v2.log`,
  waiter task b9f8ckfpp. Previous artefact `25ae73e8…` (ed51bcd) is obsolete — do not ship it.
- Next: swap local 8080 to `target/dev-release/server` (kill pid in scratchpad/server.pid, start with
  `set -a; . ./.env; set +a; MONERO_DAEMON_URL=http://xmr-node.cakewallet.com:18081 SERVER_PORT=8080
  RUST_LOG=info`), run scratchpad `check-dispute-cooldown.sh` (expect 400 / 409 / 400 = PASS), then
  `SSH_VIA_TOR=0 ./deploy/deploy-to-vps.sh --no-build` (applies migration 000004 on the VPS, records
  provenance in deploy/shipped-artefacts.txt → commit that file after). Disk is ~2 GB free: clean
  `target/debug/deps` superseded files (same-crate-newer-sibling rule) before any big build.
- Worth a sweep later: every `if let Err(e) = web::block(...)` in server/src/handlers (inner Err
  dropped) — same bug class as resolve_dispute/initiate_dispute.

## Test accounts (local only)
- buyer_kat31576 / vendor_kat31576, password `Kat-Passw0rd-31576!` (throwaway, created by acceptance
  scripts). Local escrow `esc_fd050997d2cc469e` is browser-test state (fake view key → benign
  "View key MISMATCH" errors every poll; exclude from monitors). Arbiter UI account: `system_arbiter`.

## User's standing rules (this project)
- French; expert reviewer; every claim must be verified in code ("sur pièces"), never from memory.
- Analyze the full path first, then ONE build (builds take 10-20 min; disk is chronically ~3-6 GB free:
  delete `target/debug/incremental`, stale `*.dwo`, old test binaries before big builds).
- Commit only when asked ("commit"), push only when asked ("push"). Never type passwords in browsers.
- Acceptance tests are all-or-nothing and must run against the shipped artefact.
- Remaining priorities in the user's order: (1) this dispute flow on mainnet; (2) group-key fingerprint
  as a blocking invitation step; (3) buyer/vendor identity keys via the invite link, signed DKG/session
  messages verified in WASM, replay refusal, arbiter key pinned second, reproducible builds; off-machine
  encrypted backups + rebuild drill; Hostinger suspension reason; node needs >96 GB disk.

## Gotchas learned today
- `pgrep -f`/`pkill -f` patterns that appear literally in the same command kill the shell itself
  (exit 144) — use bracket tricks (`dev-releas[e]`) or PIDs.
- Local API POSTs need `Idempotency-Key` header; lobby endpoints need no CSRF.
- Cargo test filters: put multiple filters after `--`. `cargo … | grep` hides cargo's exit code — use
  `${PIPESTATUS[0]}`.
- Monitors/background waits get killed on session restarts; re-arm as needed.
- SQLCipher queries: `KEY=$(grep -E '^DB_ENCRYPTION_KEY=' .env | cut -d= -f2-)`, `PRAGMA key='$KEY';`.
