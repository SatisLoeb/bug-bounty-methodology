---
name: project-push-chain-dualdefense
description: "Push Chain L1 DualDefense (HackenProof) audited & closed 2026-07-13 — F-A01 SVM emitter-binding Critical prepared (operator-gated), F-B01 TSS held High, Surface D null. Don't re-audit from scratch."
metadata: 
  node_type: memory
  type: project
  originSessionId: 23c2ad63-ea6a-4ea6-bb7a-7c534409af1f
---

Push Chain L1 "DualDefense" bug bounty (HackenProof, $70K pool HAI / $15K cap, Critical-only from pool). Repo `push-chain-node` @ commit `0648551`; in-scope Critical target = the **universalClient** (off-chain observer), impact realized in Cosmos `x/uexecutor`. Audited & closed 2026-07-13. Workspace: `/home/malix/Desktop/BUGS/push-chain-l1/`. OUTCOMES id `push-chain-l1-dualdefense-2026-07-13`.

**F-A01 (Critical, PREPARED — operator-gated, not submitted at close).** SVM inbound listener has no emitter binding: `getSignaturesForAddress(gateway)` (`svm/event_listener.go:228`) returns any tx merely referencing the gateway pubkey (incl. read-only), the listener reads `tx.Meta.LogMessages` FLAT (`:299-308`), classifies by prefix+discriminator only (`determineEventType :399-423`), never checks the emitting program. A non-gateway program emits a forged `send_funds` log → honest UVs decode an attacker `Inbound` → quorum → `depositPRC20` mints unbacked PRC20. EVM path binds emitter via `eth_getLogs Addresses:[gateway,vault]` (`evm/event_listener.go:271-283`); SVM doesn't — the asymmetry is the bug. No `LiquidityCap` on the mint path. 3 green Go PoCs incl. the real-listener e2e ([[feedback-execute-the-central-link]]); RPC read-only behavior verified live on devnet; dup-differentiated from F-2026-16876; devnet-honest impact defended by commit-anchored scope ([[feedback-commit-anchored-scope-pays-deployment-impact]]). Report `findings/REPORT-F-A01.md`, form `findings/SUBMISSION-F-A01.md`.

**F-B01 (HELD at High, NOT pool-eligible).** TSS sign-scope binding break: honest party VERIFIES announced hash H1 (`sessionmanager.go:186-197`) but SIGNS setupData-embedded H2 (`:701-732`, `dkls/sign.go:73`) — no check `hash_inside(Payload)==SigningHash`. A malicious coordinator (lone rotating validator) announces H1, embeds H2=hash(attacker_tx), assembles a valid TSS sig over H2 → full custody drain. REAL mechanism, hand-verified. Held High because irreducibly validator-gated: universal-validator set is admin-gated/CLOSED (verified via `HandleBaseValidatorBonded` — only revives status of already-registered UVs, no permissionless path). Pool pays Critical only. Flips to a second Critical IFF the validator set becomes permissionless. PoC `tss/dkls/poc_signscope_binding_test.go` drop-in but needs the private `dkls23-rs` lib. Register: `SURFACE-B-FINDINGS.md`. Deferred: write as its own submission if scope clarifies.

**Surface D (push-chain-evm fork-diff) = NULL.** D-1 out-of-scope gate; D-2/D-3 refuted (incl. my nonce-desync freeze hypothesis, retracted after the adversarial-verify fan-out proved `state_transition.go:466-492` only touches nonce in the contractCreation branch). `SURFACE-D-NEGATIVE.md`.

**Surface B unprivileged razzia = null-couteux.** No unprivileged Critical: peerID libp2p-authenticated (Noise/TLS, can't spoof coordinator), outbound forge emitter-gated (`create_outbound.go:32`), DoS handlers sender-checked / panic-guarded, amplified-flood bounded (Low, `handleSignatureBroadcast` no sender auth).

Don't re-audit from scratch. If revisited: the only fresh Critical lever is F-B01 going pool-eligible (validator set permissionless), or a new inbound source-chain added without emitter binding.
