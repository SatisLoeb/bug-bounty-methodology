---
name: starknet-immunefi-open-target
description: "Starknet (Immunefi, $250K) — GOOD target left OPEN mid-audit; what is already closed by execution and what is still worth opening"
metadata: 
  node_type: memory
  type: project
  originSessionId: 4c7e8c64-208c-48a0-88d4-ad330b0b9f3d
  modified: 2026-08-01T09:33:58.121Z
---

Starknet on Immunefi, max **$250K** Critical (10% of funds affected, capped). Program live since
Oct 2022, **updated 2026-07-30**, and three real findings landed as known issues in July 2026 —
the payer is engaged and the surface produces. Workspace `~/Desktop/BUGS/starknet-audit/`
(`recon/L1-PHASE0.md`, `recon/STARKGATE-PHASE0.md`). Paused 2026-08-01, **NOT a no-go.**

**Scope is much broader than the Immunefi page's first group.** Do not trust a partial scrape: the
real scope is Starknet OS (`starkware-libs/sequencer`, added **8 July 2026**), L1 core contracts +
libraries/interfaces/components (16 March 2026), StarkGate Solidity+Cairo
(`starknet-io/starkgate-contracts` branch `cairo-1`, 16 March 2026), the StarkGate frontend, and
the 32 Cairo common-library files (Oct 2022, saturated). The 2022 library is the *old* part; the
ore is in the March/July 2026 additions.

**Funds:** 18,303 ETH (~$55–73M) in the StarkGate ETH bridge `0xae0Ee0…D419`. The core
`0xc662c410…` holds 0.03 ETH — it is the state/proof anchor, not custody. `programHash()` on the
core is the definitive pin for which OS program may prove.

**Closed BY EXECUTION — do not redo:** core repo-vs-deployed drift (21/21 byte-identical);
"cairo-lang fix not propagated to StarkGate" (inverted — cairo-lang holds the *older* copies);
StarkGate version drift (ETH bridge on TokenBridge base 2.0_4 vs repo 2.0_6, whole delta = 12
lines of ProxySupport→ProxySupportImpl+Roles plus a `getL2Bridge()` getter, **no security fix**);
unguarded-sibling on the core (every `Starknet.sol` entry point is onlyOperator/onlyGovernance and
sequencer/operator exploits are OOS, so the only permissionless core surface is the 4 messaging
functions); **the L1↔L2 encoding seam HOLDS** in both directions (constants 0 on both sides, field
order and u256 low/high serialisation match).

**Killed on the kill-gate:** L1→L2 message fee forfeited on cancellation (design intent, capped,
self-inflicted); `l1ToL2MessageCancellations` never cleared (inert — global monotonic nonce);
`isFelt()` on `message[i]` but not `l2Recipient` (real inconsistency, impact nil, recoverable).

**Still open and worth it:** `WithdrawalLimit.consumeWithdrawQuota` (intraday rate limiter on the
$55–73M bridge — reset boundaries / rounding / the enable-disable transition); the token
enrollment state machine (`enrollToken`/`checkDeploymentStatus`/`StarkgateRegistry`/
`StarkgateManager`); the Starknet OS (50 files / 413 KB, `execution/` is the bulk, `state/aliases.cairo`
is where a July known issue landed); the `starkgate.starknet.io` frontend.

Contrast with [[nuva-immunefi-no-go]]: there the scope was wrong and the payer did not own the
bug; here scope, payer and funds are all correct and only the *depth* is unfinished. See
[[feedback-target-diet-is-the-binding-constraint]].
