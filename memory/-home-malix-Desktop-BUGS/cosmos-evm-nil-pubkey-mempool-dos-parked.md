---
name: cosmos-evm-nil-pubkey-mempool-dos-parked
description: "cosmos/evm nil-pubkey async-mempool crash — VALID defect, PARKED on reachability+materiality; re-arm when an in-scope chain enables the experimental EVM mempool"
metadata: 
  node_type: memory
  type: project
  originSessionId: 75e0c51f-54bf-4b81-bca7-963696d3ccbc
  modified: 2026-09-06T14:06:09.079Z
---

cosmos/evm nil-pointer DoS: a cosmos tx with omitted `SignerInfo.public_key` passes CheckTx (SetPubKeyDecorator skips nil) then crashes the node on the async cosmos-insert-queue goroutine when `reserveTx → extractEVMAddresses → DefaultSignerExtractionAdapter.GetSigners` dereferences `sig.PubKey.Address()` with no nil-guard. **Guard-escape (real):** `RecheckMempool.Insert` calls `reserveTx` (recheck_pool.go:180) BEFORE `RecheckCosmos` (line 213), so the ante nil-skip never runs. No `recover()` anywhere in the mempool pkg (queue.go/recheck_pool.go/mempool.go, v0.7.3) → panic kills the process.

**Verdict: PARKED, not submittable to Immunefi Cosmos as framed.** Killed by reachability + materiality, NOT validity:
- **Reachability (opt-in, default OFF):** `evmd/mempool.go configureEVMMempool` returns early on `cosmosPoolMaxTx < 0`. Default app.toml ships `mempool.max-txs = -1` (cosmos-sdk `DefaultConfig` MaxTxs:-1; evmd `InitAppConfig` does NOT override). The cosmos-tx crash path only wires when a chain sets `max-txs >= 0`. Corroborated by cosmos/evm issue #735.
- **Materiality (form absent in prod — Decentraland-V4 pattern):** the EVM mempool is experimental, "limited production exposure"; XRPL EVM (flagship, v0.4.1) DELIBERATELY excludes it for consensus stability. No in-scope chain confirmed running v0.7.x with `max-txs >= 0`. Enabling is node-side app.toml, not publicly indexable.
- **Recevability:** cosmos/evm IS in Immunefi Cosmos scope, but program is Primacy-of-Rules and requires "exploitable in an intended deployed environment and configuration" — an experimental default-off feature the flagship excludes is not intended-config. PoC must be a local 4-node network (single-node crash insufficient; Docker was unavailable).
- **Known-class (Gate 4):** PR #1244 (recover() on insertTxs) is UNRELEASED and covers only 1 of 4 goroutine paths; prior trail #772/#730/#545 = "panic/nil if evm mempool used." Team already patching this surface.

**Sink confirmed primary-source (v0.54.3):** `types/mempool/signer_extraction_adapter.go` GetSigners loop `sig.PubKey.Address()` no guard; `x/auth/ante/sigverify.go` SetPubKeyDecorator `if pk==nil { continue }`.

**RE-ARM TRIGGER:** a specific in-scope chain confirmed running cosmos/evm v0.7.x (or later tagged) with `mempool.max-txs >= 0`, OR a tagged release that flips the evmd default to enabled. Then it's a live node-halt DoS. Upstream GHSA drafted regardless (no materiality gate upstream): `BlackBox/submissions/cosmos-evm-nil-pubkey-crash/GHSA-DRAFT.md`. Distinct from [[cosmos-evm-ghost-cache-distinct-from-ghsa-missed-vesting-surface]]. Applies [[feedback-reachability-is-kill-gate-not-severity-modifier]] and [[feedback-prelaunch-audit-hunt-the-path-not-the-current-value]].
