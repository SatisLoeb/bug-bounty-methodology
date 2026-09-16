---
name: sas-wordlist-impl-2026-09-04
description: "SAS PGP-word encoder (DOX/SAS-WORDLIST-ENCODER-SPEC.md) IMPLEMENTED on source (7 files, 44/44 tests), NOT yet built/deployed — awaiting user's build go-ahead. Zero crypto change (proven by existing hex KATs passing)."
metadata:
  node_type: memory
  type: project
  originSessionId: bbf2978a-50a6-4189-99a6-df3dd04e55e4
  modified: 2026-09-04T20:07:33.998Z
---

SAS word-list encoder per `DOX/SAS-WORDLIST-ENCODER-SPEC.md` — **SHIPPED to prod 2026-09-04**
(artefact `db65545d…`; wasm rebuilt → `static/wasm`, exports `escrow_identity_sas_words` +
`escrow_group_fingerprint_words` confirmed in the served glue). Was: implemented on source, tested** (user is staging changes on another terminal; will signal when to build).

**7 files (exactly the spec §7 table):**
- NEW `wallet/wasm/src/sas_wordlist.rs` — vendored canonical **PGP Word List** (`const EVEN`/`ODD`
  [&str;256]), `sas_words(&[u8;8])` (word[i]=EVEN[b] even / ODD[b] odd) + `format_sas_hex(&[u8;8])`
  (moved hex formatter here) + KAT/integrity/structural tests.
- `identity.rs`: extracted `identity_sas_bytes` → `identity_sas_native` now calls `format_sas_hex`;
  added `identity_sas_words_native` + `#[wasm_bindgen] escrow_identity_sas_words`.
- `escrow_clsag.rs`: same for `group_fingerprint_bytes`/`group_fingerprint_hex` +
  `group_fingerprint_words` + `#[wasm_bindgen] escrow_group_fingerprint_words`. **Only the fingerprint
  fn changed — signing math (sign_first/second, key images) untouched.**
- `lib.rs`: `pub mod sas_wordlist;` + `pub use sas_wordlist::{format_sas_hex, sas_words};`.
- `nexusfinalappdsn/services/wasmService.ts` (2 raw decls + `frostGroupFingerprintWords` wrapper +
  wrapper-return + `WasmModuleWrapper` type), `services/identity.ts` (`identitySasWords`), `App.tsx`
  (words primary as two lines of 4, hex demoted to "or read the code · …"; both SAS + group blocks).

**Zero crypto change — PROVEN:** same 8 keccak bytes; existing hex KATs still pass
(`identity::identity_sas_kat_and_order_independent`, `escrow_clsag::group_fingerprint_matches_independent_vector`).
`cargo test -p wallet_wasm` = **44/44**.

**Word KATs (pinned):** identity bytes `41 2B C7 FA 3D 7E 97 E2` → `cranky Cherokee soybean whimsical
commence insurgent preshrunk tomorrow`; group bytes `17 FA 23 E6 08 55 45 82` → `banjo whimsical
blowtorch trombonist aimless equipment crusade Istanbul`. Table verified 3 ways: 10 anchors
(aardvark/absurd/accrue/Zulu, adroitness/adviser/aftermath/Yucatan, topmost@0xE5, Istanbul@0x82) +
integrity (256/256, no dup within, no shared word across lists) + raw-PDF spot-checks. Source = the
canonical PGP/biometric Word List (Zimmermann/Juola), vendored verbatim (case as published).

**Remaining (on user go — see [[build-coordination-manual-gate]]):**
1. `cd wallet/wasm && wasm-pack build --target web --out-dir ../../static/wasm` (runtime wasm path;
   `-j 2`/CARGO_BUILD_JOBS=2 vs [[build-oom-server-crate]]). Optional: cp the 3 files to
   `nexusfinalappdsn/public/wasm/` for dev parity.
2. `cd nexusfinalappdsn && npm run build` (vite → `static/app`; build is `vite build`, **no tsc** — I
   typecheck separately).
3. Deploy front/wasm-only: `SSH_VIA_TOR=0 ./deploy/deploy-to-vps.sh --no-build` ([[prod-graft3-live-2026-09-03]]).

**GOTCHA:** `wallet/wasm/build.sh` runs `cargo clippy -- -D warnings` first, which currently **FAILS**
on the `nexus-crypto-core` dependency's pre-existing pedantic debt (368: doc_markdown /
uninlined_format_args / missing_errors_doc / must_use_candidate …) — unrelated to SAS. Build the wasm
via `wasm-pack` directly (bypasses the broken clippy gate). Mockups §6 (nexusfinalappdsn/design-sas/*,
design-invite/Verify.dc.html — 6→8 words) DEFERRED (cosmetic canvas copy).
