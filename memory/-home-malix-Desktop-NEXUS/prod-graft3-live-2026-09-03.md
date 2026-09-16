---
name: prod-graft3-live-2026-09-03
description: "PROD (onyx-escrow.com / VPS 72.62.176.175) is on Graft 3 (C1+C2/C3) as of 2026-09-03 — supersedes 'prod=Graft 1'. Artefact e46211a5; deploy needs SSH_VIA_TOR=0 (VPS now blocks Tor)."
metadata: 
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-04T20:07:54.903Z
---

**2026-09-04 (later) — PROD artefact is now `db65545d…`** (29.7 MB, sha256-verified). Shipped 3 UX
features on top of the crypto grafts, in one `SSH_VIA_TOR=0 ./deploy/deploy-to-vps.sh --no-build`
(front `static/app` + `static/wasm` + rebuilt server binary; **no new migration**): invite router
(`/e/<code>` SPA route added to `main.rs` — verified live HTTP 200, incl. `/e/zzzzbad`→SPA), SAS
PGP-word rendering, and the security-state human-copy pass. See [[invite-router-impl-2026-09-04]],
[[sas-wordlist-impl-2026-09-04]], [[security-state-copy-impl-2026-09-04]]. Disk hit 100% pre-build;
safe prunes = `target/debug`+`release`, `~/.cache/go-build`, chrome cache (NEVER `~/.bitmonero`,
Solana toolchains, `node_modules`, or `target/dev-release`).

As of **2026-09-04 PROD runs Grafts 1 + 2 + 3** — the full crypto-hardening plan. Latest artefact
**`b5ea5f5b60dc9a42…`** (commit `5852422`), migration **`000008_verifying_shares`** applied: **Graft 2**
(per-partial CLSAG fault attribution — verifying shares B_i + named reject, attribution-only,
failure-path-only) shipped on top of the 2026-09-03 Graft 3 (`e46211a5`). Graft 2 **site 1** (early
reject of a bad partial at submission time) is DEFERRED as a fast-follow (timing/UX only; safety is
already the reference verifier). Validated on mainnet before ship: full happy-path on `b5ea5f5b`
(escrow esc_3308…, release tx `20b6c14a…`), `verifying_shares_json` populated at DKG, ZERO
attribution noise on the happy path. This whole line supersedes the "prod = Graft 1 only" note in [[session-briefing-2026-09-01]].

- Shipped artefact `e46211a5aec09b00…` (server bin, commit `3b9c90c`); migrations `000006_identity_pk` + `000007_dkg_auth` applied on the prod SQLCipher DB after a timestamped backup. Provenance appended to `deploy/shipped-artefacts.txt`.
- Deploy = `deploy/deploy-to-vps.sh --no-build` (ships local `target/dev-release/server`, rsync sources+static, migrate, sha256-verify, restart nexus-server, probe). HOST `root@72.62.176.175`, APP_DIR `/opt/nexus`, systemd unit `nexus-server`.
- **The VPS now BLOCKS Tor** (Hostinger anti-DDoS): the script's default SSH-via-Tor times out at banner exchange; the DIRECT route works (:22/:443 open, site HTTP 200). So deploy with **`SSH_VIA_TOR=0 ./deploy/deploy-to-vps.sh --no-build`**. The classifier blocks me from running the deploy → the user runs it via `!`.
- Verified live: `GET https://onyx-escrow.com/api/escrow/frost/arbiter-identity` → pk `90431458…604b7e21`, `/api/health` 200. Prod arbiter pk == local (same `ARBITER_VAULT_MASTER_PASSWORD`/seed across envs — config observation).
- Validated on this exact binary before ship (mainnet): happy-path release tx `b75b306f…` and winner↔arbiter dispute co-sign tx `1dcb266b…`.
- Same ship also carried: frontend loser-claim-UI fix (`66d3fe9`), watchdog `init_signing` idempotence, and the [[blockchain-monitor-poll-bottleneck]] optimizations.
- Branch `feat/fcmp-full-pipeline` pushed to origin (`git@github.com:SatisLoeb/NEXUS.git`, private) through `3b9c90c`. `onyx-public` remote (OnyxEscrow/Onyx) is the separate PUBLIC repo — do not push the working branch there.
