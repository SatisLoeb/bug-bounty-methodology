---
name: chainlink-immunefi-ccip-v2-2026-09-29
description: "Chainlink (Immunefi $3M) — CCIP v2.0.0 EVM (mainnet 2026-09-28, 1 day old) day-1 breadth-null across 5-agent fanout (CCV forgery core, codecs, pools+LockBox, source/fee, MCMS gov) all clean with guards+differentials; Aptos = receivability WALL (only beta tag); live SOLO leads = Sui MCMS mcms_registry callback-consumption + Sui CCIP drift-anchored"
metadata:
  node_type: memory
  type: project
  originSessionId: session_01GAy4kKaY6C67n6TzYXH2Xz
---

**Chainlink** (Immunefi, max $3M SC Critical $100k floor, PoC+KYC, Primacy of Impact limited to Critical/High).
Dossier: `methodology/targets/chainlink-immunefi-2026-09-29.md`. 25 assets / 34 impacts; node+LibOCR+CCIP OCR
plugins+relayers classified Web&App (=$100k ceiling, not SC). No known-issues/audit list published. Code4rena
covered CCIP v1.x only; NO public competition on v2.

**Surface picked: CCIP v2.0.0 EVM** — release contracts-ccip-v2.0.0 (2026-06-18), on mainnet 2026-09-28 (1 day
before audit). New model: permissionless CCVs (verifiers) + Executors, Pools v2 + ERC20LockBox, Custom Finality
(FTF), chain-agnostic MessageV1 (messageId = keccak(raw calldata)). Scope anchor git-verified: all core files
IDENTICAL release vs HEAD. HEAD-only = OUT (only in v2.1.0-beta = pre-release): SuccinctZKVerifier, CCTP/Lombard/
RMN deltas, Sui fast_mcms/*.

**Day-1 result: BREADTH-NULL across a 5-agent generate-first fanout** (CCV forgery core / codecs / pools+LockBox /
source+fee+RMN / MCMS governance). Every hypothesis killed with exact guard + (codecs) 20k-case decode differential.
Load-bearing invariants that hold: required-CCV set never empties (address(0) marker → guaranteed-non-empty owner
defaults + unconditional lane-mandated CCVs); decode canonical (length prefixes + final-offset); dest RE-COMPUTES
the required CCV set from dest state (source under-spec = liveness not safety); getRequiredCCVs scales UP with the
same amount that mints; curse subject deterministic + permissioned; MCMS role unforgeable through the merkle
metadata leaf. Residuals = owner/admin-trust (OOS: LockBox split-ownership full-drain, rate-limit-admin ≈ disable)
or config foot-guns (FTF bucket fallback, offchainTokenData="" migration freeze) or revenue nuance (Lombard
pre-fee amount to verifier, High, verifier OOS).

**Receivability decisions:** Aptos = WALL (only v2.21.0-beta17-internal, a pre-release → excluded; get written
scope confirmation before ANY Aptos work). Sui CCIP = drift risk (Feb-2026 tag ≠ Sep deployed; 34 prod modules
changed — a bug in drifted lines faces "not in a release"). Sui MCMS (contracts/mcms/mcms) + Sui LINK + ccip-owner
(EVM v0.2.1) = cleanly IN. Caveat: sui-v1.0.0 is a bare git tag (no Release object) — could be contested if the
program reads "release" strictly.

**Live SOLO leads (breadth done, now trace the seam solo — [[feedback-agent-fanout-recreates-audit-blindspot]]):**
- P0: Sui `contracts/mcms/mcms/sources/mcms_registry.move` (494 L, in scope, identical at release) — the
  ExecutingCallbackParams hot-potato execution-order / callback-consumption logic; can params be partially
  consumed, duplicated, or reordered across target modules? The one deep spot the fanout did not exhaust.
- P1: Sui CCIP drifted modules only where vulnerable lines exist at the sui-v1.0.0 tag.
- P1: whether real per-role MCMS signer sets overlap (needs on-chain deployed config; RPC blocked in-container).

**Lessons:** (a) a day-1 fanout on a freshly-launched bridge gives breadth (no class bug) but NOT depth — the
finding, if any, is in the one seam the fanout flagged un-exhausted, traced solo; resist logging the breadth-null
as the verdict. (b) the release-rule ("part of a release, pre-releases excluded") is the FIRST Phase-0 filter on a
multi-repo program: it killed Aptos and cast doubt on Sui CCIP before any code was read. (c) egress-blocked EVM RPC
/ Etherscan / docs means no deployed-config or private-audit read from the container — every "needs live config"
lead is parked, not closed. Related: [[feedback-audited-target-hunt-invariant-not-class]],
[[feedback-default-posture-thief-not-fortress-prover]], [[xoxno-lending-soroban-nogo-2026-09]].
