---
name: wormhole-target-state
description: "Wormhole (Wormchain+Guardian, Immunefi) — 3-pass firmaudit 2026-08-12, measured NULL, fortress on untrusted surface."
metadata: 
  node_type: memory
  type: project
  originSessionId: f72476b8-6624-4ee9-a02b-91b70282c3ab
  modified: 2026-08-12T17:11:50.387Z
---

Wormhole Immunefi (scope = `wormhole-foundation/wormhole` tree/main `wormchain/` + `node/`, Go). 3-pass firmaudit 2026-08-12 (HEAD 3a55db8) → **NULL-COÛTEUX, 0 payable**, RE-SOURCE. 25 candidates across 3 hand-orchestrated fan-outs (dig→adversarial-verify), ALL refuted + operator hand-verified. Workspace: `BlackBox/wormhole/` (FINAL-VERDICT.md carries the full attempt-ledger).

**Decisive structural facts (don't re-derive):**
- **Wormchain is fully PERMISSIONED** — `WormholeAllowlistDecorator` (ante.go:33-56) rejects any tx not from a guardian-validator / guardian-allowlisted addr. So the entire `wormchain/x/` tree is trusted-only; untrusted reach is ONLY via guardian-quorum VAAs.
- **VAA verify airtight** (structs.go:631,644 strict-inc index + addr dedup) → P-BRIDGE-001 dup-sig quorum bypass DEAD on both guardian + wormchain paths.
- The real untrusted surface = guardian off-chain processing of gossip + on-chain events; every High/Critical path there is ECDSA-gated and holds.

**Fresh post-audit surfaces, all hand-verified SOUND** (in-repo audits stop 2023-04 ToB / none for wormchain): delegated-guardian (#4805; p2p.go:1627 sig-bind + non-delegable{Sol,Eth,Wormchain} + threshold-floor + delegate-keys-never-enter-VAA-sigset); governor flow-cancel (clamp governor.go:1132, whitepaper-flagged risk does NOT hold arithmetically); accountant NTT msg-type detection (allow-list gated); notary (own-TV-driven, blackhole admin-only); guardiansigner (no key exposure, no untrusted Sign() oracle, prefixes ≥32B distinct).

**Only residual = Info:** Sui Transfer-Verifier fails OPEN (sui.go:277) vs EVM fail-CLOSED — but the TV is advisory (Anomalous-tags, non-rejecting) and the fail-open is unreachable on insolvent transfers (emitter==bridge needs unforgeable Sui EmitterCap). Not payable.

**Reopen triggers only:** a NEW delegated-guardian chain config, a new NTT/AR emitter onboarding, a fresh `wormchain/x/` module, or a change making an off-chain surface untrusted-reachable. Do NOT re-grind the current core.

Consistent with [[report-no-self-devaluation]] (fortress = measured, not conceded) and the doctrine that SC-fortress cores are picked-clean while payouts live on web/off-chain seams. See [[deployed-code-not-head]] (verified HEAD is what guardians run).
