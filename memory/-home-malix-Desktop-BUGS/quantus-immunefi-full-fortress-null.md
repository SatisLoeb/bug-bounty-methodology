---
name: quantus-immunefi-full-fortress-null
description: "Quantus (Immunefi audit-comp, $20K) — entire 7-asset scope executed fortress-null across on-chain/ZK/crypto AND web/app"
metadata: 
  node_type: memory
  type: project
  originSessionId: 13fbb7de-b762-43e7-ba0c-fa1083b3320d
  modified: 2026-08-12T10:26:26.771Z
---

Quantus Immunefi audit competition (audit-comp-quantus, $20K USDC pool, 12–25 Aug 2026, Immunefi-triaged, KYC-free, vault $19,991 funded). Substrate PoW L1: post-quantum ML-DSA-87/65 sigs, Poseidon2 hash, Plonky2 aggregation, zk-wormhole private transfers (EIP-7503). Frozen comp repos at github.com/immunefi-team/audit-comp-quantus-{chain@3b243b87, qp-zk-circuits@2a6914e, qp-poseidon@f885ad5, qp-rusty-crystals@94dfe6e (dilithium+hdwallet subdirs; threshold OOS), apps@d5fc4d6 (quantus_sdk+mobile-app subdirs)}. Working tree ~/Desktop/BUGS/quantus-audit/scope/, full ledger in NOTES.md.

**VERDICT: all 7 assets = executed fortress-null.** Coverage: 24 breadth-agents (0 candidates, deep executed-disconfirmer ledgers) + ~13 solo seam/gate traces + full qp-plonky2-vs-upstream diff (8 clusters) + dedup vs **4 audits** (Eiger wormhole, Neodyme dilithium, PoW+Poseidon review, Equilibrium substrate) + **Lean formal proofs** (WormholeSpec) + a **"V12" AI-auditor sweep** (10-part, on both chain and plonky2 fork). Every payable class pierced: inflation/ZK-soundness (wormhole leaf+aggregation circuits, gadgets, Poseidon2 gate fully-constrained, zk-tree↔circuit leaf-hash seam matches), theft (dilithium dual-scheme signer-binding sound; signing-payload binding sound), freeze/insolvency (mining-rewards emission no over-mint; recorder leaf-partition airtight), chain-split/shutdown (qpow fork-work=Σtarget-difficulty → no reorg edge sans 51%; header digest-truncation gated), web theft/auth-on-behalf (client WYSIWYS + multisig authz + deep-link all null).

**Why it was a fortress (the lesson):** this is the "picked-clean N-audit core" — 4 human audits + formal verification + an AI-auditor sweep + a genuinely secure Flutter app (FlutterSecureStorage, scrubbed TelemetryDeck, fail-closed deep-links, SS58 prefix-189 + checkphrase WYSIWYS). Confirms [[feedback-depth-is-an-edge-only-where-ore-remains]] and [[feedback-target-diet-is-the-binding-constraint]]: even exhaustive depth (this was among the most thorough passes ever run) pays $0 on a comprehensively-hardened target. EV-honest close = RE-SOURCE, not dig harder.

**OOS that saved dead-ends:** threshold module (qp-rusty-crystals), voting module (qp-zk-circuits), upstream substrate+deps, upstream plonky2 (only Quantus mods in), rust-transaction-parser (compiled into OOS Keystone firmware, not the mobile app), backends sub2/qrc-1/snt.quantus.com, malicious genesis, account-reaping-replay, privileged Technical-Collective, miner↔node plaintext, physical/local-access.

**ONE conditional re-open trigger (not submittable now — fails reachability kill-gate):** multisig UI decodes a co-signer's proposed inner call against BUNDLED metadata (specVersion 136) while the chain executes vs LIVE runtime; unreachable while bundled==live + the `specMatchesBundled` guard holds. RE-ARM only if a future index-shifting runtime upgrade ships before a metadata-bundle update AND the proposal-detail UI hides `specMatchesBundled==false`.
