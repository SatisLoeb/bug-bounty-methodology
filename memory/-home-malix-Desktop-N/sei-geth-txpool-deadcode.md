---
name: sei-geth-txpool-deadcode
description: Sei — the go-ethereum txpool/legacypool is DEAD CODE in seid; kills a class of leads
metadata: 
  node_type: memory
  type: project
  originSessionId: fe0b1d9d-6445-41ff-9971-4b7b422a8f71
  modified: 2026-08-31T20:52:12.618Z
---

In the Sei node (`seid`), the go-ethereum **`core/txpool` / `legacypool` is never instantiated** — dead code. `legacypool.New` is only called from geth's own CLI (`sei-go-ethereum/eth/backend.go` ← `cmd/utils/flags.go`), never from sei-chain (`grep -rn "eth.New\|legacypool.New\|core/txpool" sei-chain` = 0 hits).

**Why it matters:** EVM tx ingress is `evmrpc/send.go` (`eth_sendRawTransaction`) → `MsgEVMTransaction` → the **Cosmos/sei-tendermint mempool**. So go-ethereum bugs are only reachable on the **execution path** actually reached (`applyMessage`/`core/state_transition.go`/`core/vm`/`core/state`), NOT the txpool.

Consequence: the dossier's "legacypool total-cost overflow (PR#97)" lead and any mempool-eviction/griefing bug in geth's txpool are **not exploitable on Sei** — verified & refuted with executed reachability proof. Hunt the geth fork's Sei-authored **execution** hunks instead.

**Why:** avoids re-chasing an entire invalid lead class. **How to apply:** for any go-ethereum finding, first confirm the code is on the execution path, not the txpool/p2p node stack. See [[sei-audit-setup]].
