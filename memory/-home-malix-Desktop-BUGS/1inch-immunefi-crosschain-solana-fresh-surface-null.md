---
name: 1inch-immunefi-crosschain-solana-fresh-surface-null
description: "1inch (Immunefi $500K SC) — fresh Solana + cross-chain-swap 1.1.0 + cross-VM differential = executed-read NULL-COÛTEUX; mature EVM core saturated; residuals off-chain/known"
metadata:
  node_type: memory
  type: project
  originSessionId: f1a1c109-bacb-4d9a-86f8-2aa9c53f2da9
  modified: 2026-08-15T14:57:45.874Z
---

**1inch Smart Contracts** (Immunefi, max $500K, Impact governs within 8 listed repos, KYC, PoC fork-only, AI-reports prohibited → human-authored deliverable, ~50 USDC fee likely). Live/active (updated 14 Aug 2026). Program applies to **latest tag/releases only** (Rule 5).

**Sourcing call (playbook Phase-0):** 5 EVM repos (`limit-order-protocol`, `fusion-protocol`, `token-plugins`, `farming`, `delegating`) = maximally-saturated mature core → RE-SOURCE, do not grind. Fresh temporal tranche = the 3 assets dated 10 Jun 2026: `cross-chain-swap` (EVM, tag **1.1.0** = 15686f0, Jan 2026), `solana-crosschain-protocol` (tag **1.1.0-release** = b2124f6, Aug 2025), `solana-fusion` (tag **1.0.0-release** = 84ecfdd, Apr 2025). Clones at `~/Desktop/BUGS/1inch-sc/` pinned to those tags.

**Architecture:** Fusion+ cross-chain atomic swap = HTLC escrow (hashlock keccak(secret) + staged timelocks + safety-deposit + whitelisted-resolver + Merkle-tree-of-secrets partial fills), replicated EVM↔Solana. `solana-fusion` = separate single-chain Dutch-auction settlement.

**EXECUTED-READ coverage (full-read, not grep):**
- Solana `cross-chain-escrow-src` (10 handlers + all contexts + merkle_tree + auction + utils) — port fidèle.
- Solana `cross-chain-escrow-dst` (5 handlers + contexts + utils).
- Solana `fusion-swap` (create/fill/cancel/cancel_by_resolver + order_hash + get_dst_amount + get_fee_amounts + Fill/Create contexts).
- Solana `whitelist` (gate HOLDS: register/deregister/set_authority all `authority`-gated; initialize one-shot), `common/timelocks` (packing deployed_at@224, 32-bit stages), `common/escrow` (transfer/payout/rescue).
- EVM `cross-chain-swap` 1.1.0: BaseEscrow, EscrowSrc, EscrowDst, Escrow, ProxyHashLib, TimelocksLib, MerkleStorageInvalidator, BaseEscrowFactory, ImmutablesLib, + zkSync (ZkSyncLib, EscrowFactoryZkSync, EscrowZkSync, EscrowSrc/DstZkSync, MinimalProxyZkSync).

**CROSS-VM DIFFERENTIAL — 5 invariants checked, ALL MATCH (no divergence bug):**
1. Timelocks stage-order + offsets + `get` formula identical.
2. Merkle leaf = keccak(uint64 idx BE || secretHash) both sides.
3. Root truncation: EVM `uint240(root)` == Solana `root[2..]` (both drop top-2 = parts-count).
4. Secret hash = keccak both sides.
5. `_isValidPartialFill`: EVM `+2/+1` reconciles with Solana `+1/+0` because EVM stores `validated.index = idx+1` → both resolve to leaf-index = calculatedIndex (normal) / +1 (completion).
- zkSync address-derivation correctly handled: EscrowSrc/DstZkSync **override** `_validateImmutables` to use `ZkSyncLib.computeAddressZkSync` matching `new MinimalProxyZkSync{salt}` deploy. No wrong-formula freeze/bypass.
- Economic soundness (solana-fusion): `order_hash = keccak(order.try_to_vec() || fee-accts || mints || receiver)` = COMPLETE Borsh binding → taker cannot alter any payout field (diff order → diff escrow PDA). `get_dst_amount` mul_div_ceil (rounds ↑ pro-maker), `get_fee_amounts` mul_div_floor (fees ↓ pro-maker), auction data committed. overflow-checks=true (underflow→revert not wrap).

**VERDICT = NULL-COÛTEUX on the fresh on-chain surface (executed-read).** Faithful, consistent, well-guarded port both sides. Theft/freeze money-paths pierced by full-read.

**Residual candidate threads (all weak — Gate-1 / off-chain / known):**
1. Timelock stage-ordering NOT validated on-chain (neither EVM nor Solana `create`) → malicious maker crafts `SrcCancellation < SrcWithdrawal` to trap resolver. Critical-looking BUT Gate-1: resolver opt-in by filling; defense = resolver off-chain diligence + they set dst timelocks themselves; fundamental atomic-swap property = almost certainly known/by-design.
2. `safety_deposit`-too-low liveness (dev-confessed TODO: src lib.rs L80 / dst L43 "verify safety_deposit enough to cover public_withdraw/public_cancel"). Maps to "temporary freezing" (High) BUT reachability gated by off-chain relayer (OOS) that must refuse to reveal secret; TODO targets tx-cost coverage not theft.
3. Last-fill sweep (create_escrow L216-219 transfers full order_ata balance) → last-filler gets any donated excess; depends on voluntary donation, low.

**EXECUTED disconfirmer on the partial-fill accounting (2026-08-15, solana-program-test harness, real programs):** wrote 3 adversarial probes against `is_valid_partial_fill`. Probe1 (fill 75000 presenting index-0 secret) REJECTED on-chain; Probe3 (complete order with a non-completion index) REJECTED — guard holds. Probe2 (reuse index 0 for a 2nd fill) returned `Ok(())` → looked like a bypass, but INSTRUMENTED verification (state-diff) proved it a **test-harness tx-dedup artifact, NOT a double-book**: FILL2 PDA == FILL1 PDA (identical seed → identical byte tx w/ reused blockhash → runtime returns cached result, never re-executes), `order.remaining_amount` UNCHANGED at 75000, escrow balance UNCHANGED at 25000, total locked 25000 not 50000. Cardinal-rule catch: the state-diff, not the `Ok`, is the signal. Partial-fill vein now EXECUTED-null (earned, not predicted). Test file: `programs/cross-chain-escrow-src/tests/test_adversarial_partial_fill.rs`. Harness baseline: 54/54 existing tests pass. NOTE: harness registers ONE escrow program per context (setup() line 624) = production mirror (src/dst escrows live on different chains, never interact on-chain) → confirms timelock-trap is off-chain.

**LESSON (encode):** a solana-program-test / BanksClient tx submitted byte-identical with a reused blockhash is DEDUPED and returns a cached `Ok` WITHOUT executing — a false "bypass" that only a state-diff (balances + counters unchanged) exposes. Never trust the tx `Ok`; assert the observed state delta. See [[feedback-predicting-executed-null-before-executing-is-a-negative-posture]].

**EXECUTED money-path disconfirmers #2 (2026-08-15, `test_adversarial_moneypaths.rs`, state-delta asserts):** (A) `cancel_order_by_resolver` with `reward_limit = u64::MAX` on an expired native order → resolver gain asserted EXACTLY == `calculate_premium(...)` (101964, maker-set cap), maker gets rent+order_amount-premium. `min(premium, reward_limit)` correctly caps; NO over-extraction via reward_limit. (SPL variant PASS; Token2022 variant fails at order-creation with `IncorrectProgramId` = harness misconfig, native mint `So111..112` is classic-SPL not Token2022, and the program correctly rejects the mismatch — NOT a finding.) (B) full-fill withdraw value conservation → taker += exactly escrow_amount tokens + (ata_rent + escrow_rent) lamports, escrow + escrow_ata both closed, no leak — PASS on SPL AND Token2022. Three richest on-chain money-paths (partial-fill accounting, resolver-cancel lamport arithmetic, withdraw conservation) are now EXECUTED-null with observed state-delta assertions, not read-level. Test files kept in the src program tests dir.

**RE-SOURCE recommendation:** high saturation (1inch multi-audit; Solana had ~1yr for audits; EVM 1.1.0 post-audit). Per track record (28 SC-cores → 71% null, $0; payouts came from web/API/off-chain seams). 1inch's payable ore, if any, is likely off-chain (resolver/relayer infra — OOS here) or a future fresh-launch. Park 1inch in WATCH: re-open on a NEW in-scope asset / new chain integration / new tag. Related: [[feedback-depth-is-an-edge-only-where-ore-remains]], [[protocol-fortress-null-hunt]], [[feedback-target-diet-is-the-binding-constraint]].

**composition_skills_applied:** nuke (referenced), nullguard (verdict discipline). No OUTCOMES row yet (no submission; NO-GO/RE-SOURCE close).
