---
name: filecoin-immunefi-nogo
description: Filecoin Immunefi ($50k L1) NO-GO — hardened core + Audit-Kit devnet-PoC friction + saturation; go-f3 is the only seam-meets-high vein
metadata: 
  node_type: memory
  type: project
  originSessionId: f046be88-3d7e-4cb0-a436-461655b3ad0c
  modified: 2026-09-17T02:49:00.153Z
---

Filecoin bug bounty (Immunefi, https://immunefi.com/bug-bounty/filecoin/), Primacy of Impact, $50k max, live since 2023-04-14, $428.7k paid, last updated 2026-09-16. Passed through playbook 2026-09-17 → **NO-GO for firm effort**. Dossier: `D-cve/filecoin/PHASE0-go-no-go.md`.

**Why:** the Cosmos profile — hardened core-math L1 (rust-fil-proofs zk-SNARK/Poseidon/Merkle, lotus/ref-fvm/builtin-actors EC+FVM, all multi-audited for years) + maximal devnet-PoC friction (Filecoin Audit Kit, end-to-end on a running node; unit tests / fuzzer crashes / static analysis / theoretical / "AI reports not validated" ALL explicitly OOS) + maximal saturation + high dup. This is the CORE-MATH DURCI the playbook declares dead (28 SC-core → 0 paid). See [[cosmos-evm-no-payable-venue]], [[venue-landscape-2026-09]].

**How to apply:** don't re-evaluate cold. Reward reconciliation (memory: /scope/ fetch mangles $): operative table is $50k/$25k Critical, NOT the stale "$150k/$100k" (fil.org marketing). Critical = "10% funds affected, cap $50k, **floor $25k**" → the $25k floor NEUTRALIZES the Alphix %-cap trap, so Gate 5 is NOT the killer; saturation + PoC friction are. No submission fee (relief). KYC post-validity. USDC payout (stable). If ever engaged against advice, only 3 non-hardened-core veins, each gated by a cheap differential foil before any Audit Kit build: (1) **go-f3 F3↔EC finality reconciliation** — the ONE seam-meets-high tier (chain split/halt), freshest code (mainnet 2025-04-29, FIP-0086, no public go-f3 audit surfaced); (2) FEVM instruction-vs-FIP differential (Medium/Low, FIP=oracle → by-design-proof); (3) networking/propagation DoS graphsync/data-transfer (Medium/Low, needs measured node-fraction not single-node crash). Re-arm only if go-f3 gets a fresh consensus FIP activation or new scope asset. Fits [[feedback-seam-density-is-the-surface-selection-axis]].
