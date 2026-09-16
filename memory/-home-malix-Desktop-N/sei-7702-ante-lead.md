---
name: sei-7702-ante-lead
description: "Sei — live audit lead: EIP-7702 unmetered auth-recovery in EVM ante + pre-association differential"
metadata: 
  node_type: memory
  type: project
  originSessionId: fe0b1d9d-6445-41ff-9971-4b7b422a8f71
  modified: 2026-08-31T22:59:51.196Z
---

**AUDIT CONCLUDED (4 adversarial workflow rounds, ~46 agents): Sei is a hardened fortress on the reachable in-scope surface (sei-chain + go-ethereum). No Critical/High/Medium confirmed.** This EIP-7702 metering item is the ONLY real residual, and it is **LOW / likely Informational** (does not cleanly map to a payable Immunefi impact — the "crash" was refuted; it's bounded/recoverable/direct-RPC-only, ~2x generic flood). `sei-js` was never audited (the one untouched in-scope asset).

Below = the confirmed-mechanism detail (severity Low/Info).

`x/evm/ante/preprocess.go:112` `associateAuthorizationAuthorities` runs in ante decorator **#2 (EVMPreprocess)**, BEFORE `Basic` (#3, intrinsic gas) and `FeeCheck` (#4, balance) — ordering in `app/ante.go:91-101`. Its loop (`preprocess.go:135`) calls `helpers.AuthorityToPreAssociate` per EIP-7702 authorization = **2 ecrecovers** (`RecoverAddressesFromAuthorization` + `auth.Authority()`) + `CacheContext` + `AssociateAddresses` write. **No count cap** (`x/evm/types/ethtx/semantic_validation.go:50` only rejects an empty list). Attacker needs **zero balance**; runs in **CheckTx**. Divergence from upstream go-ethereum, which gates intrinsic-gas before touching authorities. → unmetered unpaid-CPU DoS; severity Low↔High hinges on: is the CheckTx-failing tx gossiped (propagated=HIGH) or direct-only (Medium), and does it degrade validator block production.

Coupled deeper lead — **pre-association differential → chain-halt (HIGH hypothesis)**: `preprocess.go:~145` writes the pre-association ONLY on `err==nil`, so an `AssociateAddresses` failure silently skips it while the EVM still applies the authorization → a **mutable direct-cast** EVM→Sei mapping → `delegate` → `addr.associatePubKey` remap → orphaned staking/distribution record → **unconditional panic in `sei-cosmos/x/distribution/keeper/hooks.go:~110` (`BeforeDelegationSharesModified`)**, which (unlike the hardened withdraw-addr setter at `hooks.go:~60`) is NOT guarded. If that panic fires in a **block-lifecycle** path (BeginBlock/EndBlock/FinalizeBlock) it is unrecovered → chain halt. (A panic in a user DeliverTx is recovered by baseapp → not a halt: that distinction is the crux.)

**Why:** this is where a real HIGH/Critical most likely sits on Sei. **How to apply:** resume here; verify the panic's block-lifecycle reachability with an executed artifact. See [[sei-audit-setup]], [[sei-geth-txpool-deadcode]].
