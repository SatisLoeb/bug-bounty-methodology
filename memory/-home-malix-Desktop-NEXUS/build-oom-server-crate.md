---
name: build-oom-server-crate
description: "Compiling the full NEXUS `server` crate can OOM this machine; cap cargo jobs"
metadata: 
  node_type: memory
  type: project
  originSessionId: b55c32d4-2e76-4b2c-8ede-8e4459f15ad9
---

Compiling the whole `server` crate (pulls in diesel + actix) on this machine
**exhausts RAM and aborts** — `cargo test -p server` died with `memory allocation
failed` / SIGABRT while compiling `diesel` (observed 2026-07).

**How to apply:** for any `server` (or full-workspace / WASM) build, limit
parallelism: `cargo build -j 2` or `CARGO_BUILD_JOBS=2 cargo test -p server ...`.
Prefer testing crypto in the light `nexus-crypto-core` crate (no diesel/actix,
compiles in ~28s) when the logic lives there or can be mirrored — see the
single-signer CLSAG spike in `nexus-crypto-core/src/clsag/verify.rs`
(`mod single_signer_spike`). Also: `cargo ... 2>&1 | tail` hides cargo's real
exit code (you get `tail`'s 0) — don't trust exit 0 from a piped cargo run.
