---
name: protocol-md-stale-vs-escrow-clsag
description: "PROTOCOL.md §6.4 (round-robin, signer 1 sends nonce α) is stale; real threshold signer is wallet/wasm/src/escrow_clsag.rs with additive nonces — confirmed by user 2026-08-28"
metadata: 
  node_type: memory
  type: project
  originSessionId: b2b76f1f-5e61-42d5-8eb2-f4fbede0bcdb
  modified: 2026-08-28T04:07:25.408Z
---

The threshold CLSAG signer actually shipped in the server build is `wallet/wasm/src/escrow_clsag.rs`
(2-party split of the proven custodial math: `x = d + λ₁b₁ + λ₂b₂`, additive nonces `α₁ + α₂`,
D/8 serialized, each browser only handles its own FROST share + own nonce). PROTOCOL.md §6.4
still describes an older round-robin where signer 1 encrypts its nonce `α` for signer 2 — that
description is STALE (user confirmed 2026-08-28: "le code réel c'est le dernier, celui utilisé
dans le build du serveur").

**Why:** The stale spec, read literally, would imply a share leak (signer 2 could solve for λ₁b₁);
the real code does not do this. Docs (README/PROTOCOL/CLAUDE.md) lag the code on this project.

**How to apply:** For any crypto/escrow question, read `escrow_clsag.rs` and
`server/src/services/frost_signing_coordinator.rs` (`verify_and_broadcast_completed_clsag`)
first; treat PROTOCOL.md as a reference for notation/lifecycle only. See [[build-oom-server-crate]].
