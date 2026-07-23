---
name: project-nuke-rust-toolchain-pin-gotcha
description: NUKE Rust barrage — CosmWasm/Solana repos pin a minimal rust-toolchain.toml that breaks cargo-audit/deny/geiger; NUKE now forces a working toolchain. Fixed 2026-07-14 on the Injective swap-contract.
metadata: 
  node_type: memory
  type: project
  originSessionId: 57f794ea-c79f-4e82-a039-ae933c905aa5
---

Real trap hit running the new [[project-nuke-static-barrage-skill]] Rust barrage on the Injective
swap-contract (`~/Desktop/BUGS/injective-bbp-audit/repos/swap-contract`, HEAD 1.1.2): the repo pins
`rust-toolchain.toml` → channel **1.78.0, profile "minimal"** (no cargo/clippy component). rustup honors
the pin, tries to provision the missing components, the download fails → cargo-audit/cargo-deny/
cargo-geiger all produce EMPTY output (their stderr is rustup's "component download failed", not tool
JSON). First barrage = 0 signals — NOT a loader bug; the tools never ran.

**Fix (câblé dans nuke.sh `run_barrage_rust`):** cargo-audit/deny read only Cargo.lock (toolchain-agnostic)
and clippy/geiger just need A working toolchain, so all cargo-* invocations now run under
`env RUSTUP_TOOLCHAIN="$TC"` where TC = rustup default (or `$NUKE_RUST_TOOLCHAIN` override), bypassing the
project pin. Proof: forcing RUSTUP_TOOLCHAIN=stable made cargo-deny emit 13 diagnostics; the full re-run
gave **239 signals → 32 clusters** (25 clippy::arithmetic_side_effects, 7 unwrap_used, cargo-deny
supply-chain incl a real BytesMut::reserve overflow vuln + atty unmaintained).

**Lesson for any pinned Rust target (CosmWasm/Solana):** a minimal or uninstalled `rust-toolchain.toml`
silently zeroes the mechanical barrage. NUKE now handles it automatically and prints
"toolchain: le repo épingle un rust-toolchain — barrage forcé sous '<tc>'". If clippy accuracy for the
project's exact toolchain matters, set `NUKE_RUST_TOOLCHAIN=<channel>` (and install it fully).

**Refinement (2026-07-21, Meteora DBC/DAMM-v2 Anchor):** `RUSTUP_TOOLCHAIN=default` is **INVALID** — rustup toolchain names are `stable`/`nightly`/`1.93.0`, never the literal `default`. Setting it to `default` is ignored, the repo pin (here 1.93.0, NOT installed) wins, and cargo-audit/deny/clippy report "manquant" + only 3 scanners run. Correct invocation on a pinned Anchor repo: `RUSTUP_TOOLCHAIN=stable NUKE_RUST_TOOLCHAIN=stable nuke <target>` (a REAL installed toolchain) → all 6 scanners fire. Also: nuke.sh detects the container dir has no Cargo.toml — run it per-program (dbc/, dammv2/), not on the parent. Meteora barrage was mechanically CLEAN: cargo-deny = only OOS dep RUSTSEC/unmaintained, clippy = 650/636 style lints (arithmetic_side_effects on safe-math ops, 0 corroborated), solana-lints = 0, geiger empty (build). Negative-space (22 Solana theft classes) fully closed by hand-audit → NUKE corroborated the [[project-meteora-dbc-damm-intake]] null.

**Swap-contract barrage takeaway (2026-07-14):** the curated CosmWasm negative-space worklist maps onto
the contract's REAL architecture — it's an atomic-order (SubMsg::reply_on_success + fn reply/match msg.id
at swap.rs:144 / contract.rs:69, STEP_STATE saved across the submsg boundary). So the fresh angle is the
**reply/state-machine composition** ([[project-injective-swap-deployed-example-010.md]] /extract
spread-vein already NULL), not the queries.rs value-math clippy lit up. overflow-checks=true is set (raw
arithmetic panics, not silent-drains). Deployed = 0.1.0 example, repo audited = HEAD 1.1.2 — provenance caveat.
