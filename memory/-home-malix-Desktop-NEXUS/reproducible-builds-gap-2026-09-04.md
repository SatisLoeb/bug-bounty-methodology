---
name: reproducible-builds-gap-2026-09-04
description: "Reproducible builds NOT achieved: prod binary shipped via --no-build carries build-machine paths (not remapped); WASM (user-run) has no repro/SRI/published-hash. Groundwork exists in deploy BUILD=1 path only."
metadata: 
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-04T00:53:38.057Z
---

Open gap as of 2026-09-04: **reproducible builds are set up but not achieved**, and the trust-critical part (WASM) has no verifiability at all.

**Groundwork that EXISTS (good) — but only in the `deploy/deploy-to-vps.sh` full-build path (BUILD=1):**
- pinned toolchain `rust-toolchain.toml` = 1.97.1 (minimal, wasm32); deps pinned (`--locked` + `Cargo.lock`).
- `CARGO_INCREMENTAL=0` + `RUSTFLAGS=--remap-path-prefix=$PWD=/build --remap-path-prefix=$HOME/.cargo=/cargo --remap-path-prefix=$HOME/.rustup=/rustup`.
- `[profile.dev-release]` tuned deterministic: `incremental=false`, `lto=false`, `codegen-units=8`.

**Why it is NOT achieved:**
1. The prod binaries actually running (`e46211a5`, then `b5ea5f5b`) were built by hand (`cargo build --profile dev-release`, NO remap RUSTFLAGS) and shipped with **`--no-build`** → the BUILD=1 remap path was bypassed. `strings target/dev-release/server | grep -c /home/malix` = **842** build-machine paths baked in → a clean BUILD=1 rebuild gives a DIFFERENT hash. FIX: deploy via BUILD=1 (or rebuild with the remap) so the shipped binary is path-free.
2. **WASM (wallet_wasm / nexus_crypto_wasm served to browsers) has NO repro story** — the `--remap-path-prefix` is applied only to the server binary, not to `wasm-pack`; **no SRI** (`integrity=`), **no published expected hash**. Users cannot verify the WASM they execute == audited public source. This is the real hole in the "don't trust the server" thesis (users RUN the wasm; they don't run the server binary). `wasm-opt` is already disabled (VALIDATION.md), which is repro-friendly.
3. Deploy `sha256` = **integrity** (local↔prod identical), NOT reproducibility (no third-party rebuild → same hash).

**How to apply / next steps:** binary — always deploy BUILD=1 (rebuild of the running `b5ea5f5b` via BUILD=1 is DEFERRED to the next build, user's call 2026-09-04 — do it THEN rather than shipping another `--no-build` binary; it's a one-line deploy change). WASM — the scoped chantier is written up in `DOX/HARDENING-PLAN-wasm-verifiability.md` (deterministic wasm build: pin wasm-pack + wasm-bindgen, remap, reference container; publish expected .wasm hash tied to a git tag; runtime SRI or in-browser hash-check before instantiate; CI repro-assert). See [[prod-graft3-live-2026-09-03]]. 3 wasm modules exist (wallet_wasm signing = priority, nexus_crypto_wasm, reputation_wasm).
