# TARGET: Centrifuge Protocol v3.3.0 | PLATFORM: Cantina (bounty) | DATE: 2026-10-03

SCOPE (per Cantina update mail, 2026-10-03): "Core Contracts" at `centrifuge/protocol-v3`
commit `74e16461ca39aadc63ab4f0096d907237ac4d51a` (= tag `v3.3.0`, 2026-09-29, PR #425
"Audit follow-ups"). Hub-and-spoke RWA tokenization: Hub (accounting, holdings, share
classes, policy ledger) / Spoke (escrow custody, vaults, share tokens, hooks) / messaging
(Gateway, MultiAdapter over Axelar, LayerZero, Hyperlane, Chainlink CCIP, Standby).
Reward: Critical up to $250k, High up to $50k, Medium up to $5k, Low/Info $0.
Previously v3.2.0; OOS list, instructions and assets updated with the bump.

Method: xsurface-prioritize (top-down threat model, go/no-go BEFORE deep audit).
Reachability read in-code at the exact commit (clone in session scratchpad). Dup calibrated
against the 30 audit reports shipped in `docs/audits/` and the public commit log.

Prior history on this target (from own notes): report #283 died on admin-trust (SyncManager
stale price via custom valuation, pool managers fully trusted). D18 rounding path killed at
~2000 wei / 1000 cycles. Cantina saturation counter at 480 findings (2026-07 snapshot).

---

## 0. THE TWO FACTS THAT DECIDE THIS TARGET

**Fact 1 — audit density is the highest I have measured on any live bounty.**
30 external reports in `docs/audits/`, 11 of them in 2026: Sherlock (Dec-25, Feb-26, Apr-26,
Aug-26), BurraSec (x5 in 2026 incl. bridge, ShareManager, OnchainPM, v3.3 x2), yAudit (Jan-26,
Jun-26 v3.3), xmxanuel (Dec-25, Mar-26), plus a **Certora formal verification of all of
`src/core/`** (report dated 2026-09-11: Accounting, Holdings, ShareClassManager, HubRegistry,
Hub, HubHandler, Spoke, SpokeRegistry, SpokeHandler, SnapshotQueue, PoolEscrow, EscrowFactory,
MultiAdapter, MessageDispatcher, with mutation testing). The v3.3 Sherlock scope (34 files)
covers every contract I would have called "core". The HEAD commit is itself titled
"Audit follow-ups".

**Fact 2 — the OOS list is a confession map that fences nearly every untrusted-actor path.**
The out-of-scope text in the program is ~5 pages. It is not boilerplate: each line is a
specific accepted finding. Pool managers (hub, balance-sheet, gateway, MultiAdapter managers),
strategists, sentinels, stewards, hook managers, the ops and protocol safes, adapters, relayers
and the message layer itself are all declared trusted or best-effort. What is left as an
in-scope adversary is: an investor through the vaults / VaultRouter, an anonymous caller on
the permissionless entry points, and an honest relayer. Every degradation I could construct
from those actors in this session is already named in the OOS list (see paths below).

Conclusion before any deep reading: the only non-dup surface is the **post-audit delta**
(commits after the Sherlock final commit `ac389fb`, which lives in the private
`protocol-internal` repo; the public mirror shows ~12 src commits from 2026-09-01 to
2026-09-29). I read that delta. It is sound.

---

## ASSETS (terminal value, high -> low)
- A1: Escrow custody per pool (`Escrow.sol`: ERC20/ERC6909 held per share class, reserved vs
  available) — direct theft = Critical. Only reachable through `auth` wards (Spoke, request
  managers). FV-verified invariant "a withdrawal never pays the reserved part".
- A2: Share-token supply integrity (mint/burn via `ShareTokenRegistrar`, hub-side conservation
  ledger in `ShareClassManager`).
- A3: Price / NAV integrity (`SimplePriceManager`, `NAVManager`, `OracleValuation`,
  `Holdings` valuation) — manipulation that moves a sync-deposit or async fulfilment price.
- A4: Fund-lock DoS (vault claims bricked, escrow frozen, message channel stalled).
- A5: Cross-chain message authenticity (adapter peer trust, MultiAdapter quorum, session ids).
- A6: Governance capture (Root, guardians, policy ledger) — Root timelock + safes, OOS-heavy.

## ENTRY POINTS / TRUST BOUNDARIES (confirmed in code at 74e1646)
Permissionless, state-changing, untrusted caller:
- `Spoke.managerCall(poolId, target, payload, ...)` — NO modifier. Anyone sends a
  `ManagerCallFromSpoke` to the pool's hub chain; hub `Envoy.callFromSpoke` calls
  `fromSpoke()` on an attacker-chosen `target` with `sender = msgSender()` (honest, from
  BatchedMulticall transient). Only two `fromSpoke` implementers in src: `NAVManager`
  (checks `manager[poolId][centrifugeId][sender]`) and `OracleValuation` (checks feeder).
- `Spoke.registerAsset` (permissionless by design, OOS line on decimals re-registration).
- `Gateway.retry` / `Gateway.repay` / `Gateway.withBatch` (permissionless by design; retry
  decrements a per-hash failure counter, repay re-funds an underpaid batch).
- `QueueManager.sync(poolId, scId, assetIds[])` + `syncCallback` — anyone flushes the spoke
  snapshot queue to the hub (bounded by `minDelay`, snapshot flag only when queue fully
  drained).
- `NAVManager.updateHoldingValue` — permissionless holding revaluation (acknowledged in
  StdHubPolicy comments and in OOS: baseline anchoring).
- `TokenBridge.send`, `VaultRouter.*` multicall, `AsyncVault.request*`/claims,
  `SyncDepositVault.deposit/mint`, `Spoke.crosschainTransferShares` (holder-initiated bridge).
- `MultiAdapter.handle/vote/execute` — `_resolve` requires `msg.sender == adapter ||
  manager[poolId][msg.sender]`; adapter details keyed by `(centrifugeId, poolId, sessionId,
  adapter)` (Sherlock Aug M-1 fix in place).
- Adapter inbound: `ChainlinkAdapter.ccipReceive` (router + sourceChainSelector + sender
  address), `LayerZeroAdapter.lzReceive` (endpoint + srcEid + sender), `HyperlaneAdapter.handle`
  (mailbox + origin + sender), `AxelarAdapter.execute` (source hash + gateway validate).
  All four validate source correctly on read.
Trusted-boundary (manager / policy / Root): everything else on Hub and Spoke is `enforced(poolId)`
(= manager + installed policy) or `auth`.

## ACTORS
- anonymous | allowed: registerAsset, managerCall (as untrusted sender), retry/repay,
  QueueManager.sync, NAV revaluation, TokenBridge.send of own tokens | boundary cross gives:
  nothing found — every target re-validates sender or operates on caller's own funds.
- investor (vault controller/owner/operator) | request, cancel, claim, bridge own shares |
  cross gives: claims to other receivers (OOS by design), operator reach across linked vaults
  (OOS explicit), stall of per-network issuance read (OOS explicit, see P-09).
- relayer / executor | gas-bounded delivery | OOS wholesale ("best effort", retryable).
- pool manager family (hub/BS/gateway/MultiAdapter/hook/registrar/strategist) | TRUSTED per
  program, with policy delay + sentinel veto as the only (soft) boundary | OOS wholesale.
- adapter peer (remote adapter contract) | authenticates by configured address per lane |
  compromised adapter = OOS ("compromised underlying chain", "blockSession required").
- Root / safes / guardians | OOS wholesale.

## AUDIT DENSITY (dup calibration)
Per-component coverage by name in the 30 reports: Axelar (10 reports), LayerZero (BurraSec
Aug-25: 26 mentions), Hyperlane (BurraSec Jul-26: 9, Sherlock Aug-26), Standby (BurraSec +
Sherlock Aug-26), TokenBridge (BurraSec bridge Jul-26: 35, Aug-26: 8), OnchainPM (3 dedicated
reports Mar/Apr-26), ShareManager (dedicated BurraSec Aug-26). ChainlinkAdapter is the least
named (1 mention each in BurraSec Jul-26 and Aug-26) and was modified post-Sherlock (#399
CCIP v2/v3 extra args, #408 receive-cost pricing, #425 interface) — see P-07.
=> Any textbook finding on core, vaults, hooks, messaging, policy = HIGH dup.

---

## CANDIDATE PATHS (reachability verified; gates applied)

P-01 [PERMISSIONLESS managerCall -> ARBITRARY HUB TARGET] `Spoke.managerCall` lets anyone route
     `Envoy.callFromSpoke(target=any, sender=self)` on the hub chain.
  reachability: reachable (no modifier, confirmed Spoke.sol:374)
  scope-exclusion: none on the mechanism, but every `fromSpoke` target validates `sender`
     (NAVManager:90, OracleValuation:85). A target without validation would have to be a
     manager-deployed custom contract => admin-trust (DURE).
  dup: Med (design is documented in NAVManager comment "reached via the permissionless
     spoke.managerCall") | edge: High | value: Critical if a hub-side target ever skips the check
  -> DROP today / WATCH: re-grep `function fromSpoke` on every release; a new implementer
     without a sender allowlist is an instant Critical.

P-02 [BatchedMulticall msgSender SPOOF] `msgSender()` returns transient `_sender` when
     `msg.sender == gateway`. Attacker tries to make a victim's address the initiator.
  reachability: UNREACHABLE — `_sender` is set only from `msg.sender` in `multicall`,
     `executeMulticall` is `protected`, nested batch keeps per-contract transient.
  dup: High (FV + Sherlock scope include BatchedMulticall) | -> DROP (verified dead).

P-03 [QueueManager.sync PARTIAL FLUSH -> INTERMEDIATE NAV] anonymous caller flushes a chosen
     subset of assetIds between a manager's deposit tx and issuance tx.
  reachability: reachable (sync is permissionless) BUT a partial flush yields
     `isSnapshot=false` (SnapshotQueue.flushAssets: snapshot only when `delta==0 &&
     queuedAssetCounter==assetCounter`), so the hub does not call `onSync` => no price publish.
     The only exploitable variant (manager splits approve/issue across txs) is OOS verbatim:
     "SimplePriceManager prices are off when an approval and its matching issue or revoke are
     sent separately ... the manager is expected to batch them."
  scope-exclusion: DURE (manager error + explicit OOS line) | dup: High (FV covers the
     consistency flag) | -> DROP.

P-04 [NAV REVALUATION BASELINE ANCHORING] permissionless `NAVManager.updateHoldingValue`
     anchors the StdHubPolicy share-price baseline after a policy swap, narrowing the next move.
  reachability: reachable | scope-exclusion: DURE (OOS verbatim: "anyone may trigger that
     first update to anchor the baseline at a block of their choosing"; yAudit Jun-26 L-2.7.1)
  -> DROP (known, accepted, $0).

P-05 [VAULT CLAIM-PATH AUTHORIZATION] non-member controller claims to a member receiver;
     ERC-7540 operator on the pointed vault reaches sibling linked vaults.
  reachability: reachable | scope-exclusion: DURE (both OOS verbatim; Sherlock Aug M-2
     frozen-investor variant RESOLVED in #360) | dup: High | -> DROP.

P-06 [ERC-7575 POINTER UNBOUND READ — residual of #382] #382 bound `AsyncRequestManager.
     _requestVault` and `VaultRouter.getVault` to `vaultDetails` (isLinked + pool + sc + asset).
     Checked for other consumers of `share.vault(asset)`: none in src besides those two.
  reachability: UNREACHABLE (fix complete at this commit) | -> DROP (verified dead).

P-07 [CCIP V3 EXTRA-ARGS ENCODING / FINALITY LANE — post-Sherlock #399] `ChainlinkAdapter.
     _extraArgs` packs `GENERIC_EXTRA_ARGS_V3_TAG, uint32(gasLimit), requestedFinality,
     bytes7(0)` for non-WAIT_FOR_FINALITY lanes; `getCCVsAndFinalityConfig` returns per-source
     `allowedFinality`. Least-audited adapter, modified 2026-09-22 after the last external review.
  reachability: conditional(a lane wired with requestedFinality != WAIT_FOR_FINALITY on
     mainnet — unverifiable from public repo, `live` branch is April-2026 vintage)
  scope-exclusion: molle→DURE: a mis-encoded send reverts at `ccipSend`, which blocks the
     adapter set's outbound dispatch, and OOS says "Adapters are assumed never to revert, so one
     faulty adapter blocks outbound dispatch for the whole set"; finality narrowing is OOS
     verbatim; wiring is the ops safe's (trusted). Inbound `ccipReceive` validation is correct.
  dup: Low | edge: High | value: Low (liveness, no funds, retryable) | -> DROP / P2 at best.
     Not worth a spike: even if the encoding is off-spec, the payout tier is $0–5k and the
     OOS fence applies.

P-08 [uint256 COUNTER WIDENING — post-Sherlock #415] Holdings increased/decreasedAmount and
     ShareClassManager issuances/revocations widened to uint256; `_amount()` saturates at 0;
     consumers cast `.toUint128()`.
  reachability: an overflow of the uint128 cast needs a 2^128 report = compromised message
     source (OOS verbatim: "a maximum-size report from a compromised message source can
     saturate them"). Note: the OOS text still says "stay 128-bit"; code is now uint256 with
     128-bit views — stale wording, same conclusion.
  -> DROP.

P-09 [INVESTOR-TRIGGERED NEGATIVE PER-NETWORK ISSUANCE -> PRICE CHANNEL STALL] holder on
     spoke A bridges shares (`crosschainTransferShares`, permissionless) before spoke A's queued
     issuance has been synced to the hub; `ShareClassManager.transferShares` drives network A
     revocations > issuances (allowed since #375); `SimplePriceManager.onUpdate` is the only
     reader of `issuance()` and reverts `NegativeIssuance` => that pool's accounting-message
     stream from network A stalls until the manager restores the state.
  reachability: reachable by an ordinary investor (needs only an unsynced queue window, which
     `QueueManager.minDelay` guarantees exists).
  scope-exclusion: DURE — OOS verbatim: "the price manager still reads per-network issuance
     and stalls its pool's reporting channel in that state, since the price-manager side of that
     change is not in this release." The actor is not named but the state and consequence are.
  dup: High (self-reported) | edge: Med | value: Med (DoS, recoverable)
  -> DROP. Best illustration of how tight the fence is: a clean investor-reachable DoS is
     already written into the OOS as deferred work.

P-10 [ESCROW REFACTOR — post-FV #422] `PoolEscrow` + `misc/Escrow` folded into one `Escrow`
     after the Certora run (PoolEscrow verified at protocol-internal 3397d60).
  reachability: n/a — diff read line by line: pure rename + inlining of `authTransferTo`,
     identical semantics, same `auth` gating. -> DROP (verified dead).

P-11 [TRANSFER-HOOK RECLASSIFICATION — post-audit #382/#367/#398] `isCrosschainTransfer` became
     pure (`to <= type(uint16).max`); fast path removed; escrow member-update guard removed.
  reachability: user-controlled `to` can hit the branch, but in FullRestrictions it resolves to
     `isTargetMember(to)` = same as the default transfer branch; the other three hooks do not
     reference it; the escrow guard removal only affects an already-exempt address.
  -> DROP (no behavioural delta).

P-12 [SYNC-DEPOSIT PRICE VIA CUSTOM VALUATION] (= own report #283)
  -> DROP (admin-trust, already died once; OOS verbatim "SyncDepositVault ... quote and executed
     price can differ when a valuation is configured").

P-13 [MESSAGING: retry/repay replay, stale config re-delivery, gas griefing, adapter revert]
  -> DROP (all OOS verbatim: late/out-of-order/racing messages, retried UpdateWard, retried
     SetPolicy, gas best-effort, subsidised funds spam, one faulty adapter blocks the set).

P-14 [D18 / DECIMALS ROUNDING] 0-decimal assets, decimals drift, rounding-unit weight.
  -> DROP (OOS verbatim + own prior kill at ~2000 wei/1000 cycles).

### Confirmed-dead (verified in code) — do not re-spend time here
Envoy sender spoof (honest msgSender); fromHub pool binding (OnOffRamp/Supervisor check
poolId, others are pool-keyed by payload under the trusted Envoy); MultiAdapter cross-pool
adapter claim (M-1 fixed, details keyed by poolId+session); Escrow reserved/available invariant;
Gateway batch reentrancy (`_isSendingBatch`, `lockCallback` must be called by batcher);
Holdings deficit gating (C21/C22 re-landed in #366); FullRestrictions freeze ordering (freeze
checked first on both legs, escrow exempt).

---

## DECISION GLOBALE: NO-GO. Do not enter deep audit. No narrow spike either.

Rationale (no theatre):
- 30 audits + formal verification of the whole core, with the HEAD commit being audit
  follow-ups. Every classic vector is closed and was closed by six different firms.
- The OOS list enumerates the accepted residuals so precisely that two of the three
  untrusted-actor paths I derived independently (P-04, P-09) are quoted there almost word for
  word. The third (P-03) is dead by construction of the snapshot flag.
- The post-audit delta (Sep 1–29) is real but small (~12 src commits) and reads clean: #382 is
  a complete fix, #415 and #422 are semantics-preserving, #410 adds a policy classification,
  #399 is a liveness-only risk on a trusted-wired lane and OOS-fenced.
- The only structurally interesting primitive (P-01: permissionless managerCall to an
  arbitrary hub target) is correctly defended at every current implementer. It is a WATCH
  item for future releases, not work today.
- Payout asymmetry: Medium caps at $5k, Low/Info pay $0, and anything short of fund theft or
  insolvency on this design lands at Medium or below. Cantina saturation on this program was
  480 findings in July.
- Cannot confirm from the public repo which v3.3 contracts are live (the public `live`
  branch is April 2026). Any future engagement must start from the Cantina asset list, not
  the repo.

## TEMPS ALLOUE (honest): 0h deep audit.
- Session cost so far: ~1.5h of top-down triage. That is the budget; stop here.
- Re-arm conditions (cheap, passive, no PoC work):
  1. A new `fromSpoke` implementer appears in `src/` (grep on release tag) without a
     `sender` allowlist -> P-01 becomes a live Critical candidate; verify in <30 min.
  2. The price-manager side of the negative-issuance change ships (OOS line removed) while
     a new reader of `issuance()`/`totalIssuance()` lands -> re-check P-09 class.
  3. A v3.4 scope where OnchainPM / weiroll guards move from "defence in depth" to a declared
     trust boundary -> the CircuitBreakerGuard window-length and pinned-slot items listed in
     OOS become in-scope bugs.
- Do NOT commit a multi-day deep audit of core, vaults, hooks or messaging. It will produce
  dups or OOS hits, as #283 did.
