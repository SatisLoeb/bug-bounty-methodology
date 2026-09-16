---
name: sei-audit-setup
description: Sei Immunefi bug-bounty audit — repo clone locations and structure
metadata: 
  node_type: memory
  type: project
  originSessionId: fe0b1d9d-6445-41ff-9971-4b7b422a8f71
  modified: 2026-08-31T23:03:43.709Z
---

**STATUS: CLOSED 2026-09-01** — hardened fortress, no Critical/High/Medium after 4 adversarial rounds; only residual = the Low EIP-7702 metering item ([[sei-7702-ante-lead]]). Conclusion: `sei-immunefi/04-conclusion.md`. Reusable method: `/home/malix/Desktop/N/METHODE-audit-adversarial-multiround.md` (see [[audit-adversarial-method]]). `sei-js` never audited (only untouched in-scope asset) if ever reopened.

Auditing the **Sei** Immunefi bug-bounty (max $500k). Working dossier: `/home/malix/Desktop/N/sei-immunefi/` (scope, 31/08/2026 FlatKV exclusion, initial leads).

In-scope assets: `sei-protocol/sei-chain`, `sei-protocol/go-ethereum` (Sei fork), `sei-protocol/sei-js`. Out of scope: FlatKV/Giga/Autobahn/EVMone, malicious StateSync peer, 51%/governance/centralization/Sybil.

Local clones (cloned 2026-08-31):
- `/home/malix/Desktop/N/repos/sei-chain` @ `95f6bfbe` — **contains everything nested**: `sei-tendermint/`, `sei-cosmos/`, `sei-db/` are nested Go modules inside it. `sei-tendermint` the standalone repo is **ARCHIVED** (moved into sei-chain); dossier paths like `sei-tendermint/internal/consensus/...` resolve under `sei-chain/sei-tendermint/...`.
- `/home/malix/Desktop/N/repos/sei-go-ethereum` @ `bb451e27` (= PR#97 merge).

Disk is ~98% full (~5GB free) — a full `go build ./...` of sei-chain FAILS on cgo (sei-wasmvm/zstd). Prove findings via code-path tracing + small standalone-Go `go run` probes, not full builds.

See [[sei-geth-txpool-deadcode]], [[sei-7702-ante-lead]].
