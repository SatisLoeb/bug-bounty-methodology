# SC-PATH-PATTERNS — candidate edges for the firmaudit path graph (smart-contract / cross-chain)

> The SC analogue of `H1-HUNTING-PATTERNS.md` (which is web2/H1). These are the **candidate edges**
> you inject into the path graph (firmaudit Step T4): each is an anti-pattern that turns an
> attacker-reachable node into an asset node. Each pattern: the edge it adds, the grep that finds
> candidates, the reachability question that confirms/kills it, and the dup/edge-fit note.
>
> IDs: `SC-P-NN`. Use them in path write-ups (`P-01: anon →(SC-P-03)→ stale price →→ vault drain`).
> These are durable methodology. Active hypotheses (a specific lib@version suspected) live in
> engagement notes, NOT here (firmaudit META: no hardcoded 0-day / version-pin).

---

## Access-control / privilege edges

### SC-P-01 — Destructive op has weaker auth than the read/benign op
- **Edge:** anon/low-role → state-mutating or fund-moving call that *should* require a higher role.
- **Grep:** compare modifiers across sibling functions — `grep -nE 'function (set|remove|close|kill|migrate|withdraw|sweep|rescue|pause|upgrade)' ` then diff their `onlyRole`/`require` against the read-side.
- **Reachability (Q2):** is the weaker-guarded fn callable by the assumed actor in the DEPLOYED build?
- **Dup/edge:** medium dup (auditors look here). Edge if the asymmetry is subtle (one of N siblings).

### SC-P-02 — initialize / upgrade / proxy-admin reachable or re-runnable
- **Edge:** anon → `initialize()` on an uninitialized impl, or init-if-needed reinitialization, or proxy-admin not the timelock.
- **Grep:** `initialize`, `init_if_needed` (Anchor), EIP-1967 admin slot, `_disableInitializers` absence.
- **Reachability:** is the impl actually uninitialized on-chain? (cast call / read slot). Q7 upgradeability.
- **Dup/edge:** high dup on EVM (well-known); **edge on Anchor init_if_needed** (fewer eyes).

### SC-P-03 — "Trusted" actor is a boundary, not a guarantee — BUT only if program-trust does NOT cover it
- **Edge:** a peer/keeper/relayer the code assumes benign feeds malicious input across the boundary.
- **THE DEPARTURE CRITERION (resolves the Step-T3 ↔ recevability tension):**
  - If crossing the boundary requires **compromising a role the program's threat model DECLARES trusted** (owner, governance, pool manager fully trusted) → **DROP (hard scope-exclusion, admin-trust).** This killed Centrifuge #283 (SyncManager stale price via custom valuation — pool managers fully trusted).
  - If the boundary is crossed by **untrusted input that is actually reachable** (a cross-chain peer message an attacker can forge/influence, a keeper param an attacker controls, an external-protocol callback) → **DIG (real path).** This is the Bridge-Peer-Trust class.
- **Grep:** `lzReceive`, `_lzReceive`, CCIP `ccipReceive`, `onMessage`, peer/trustedRemote mappings, `require(msg.sender == keeper)`.
- **Reachability:** can the attacker actually produce the cross-boundary input, or does it require the trusted key? That answer IS the DROP/DIG verdict.

---

## Cross-chain / messaging edges

### SC-P-04 — Source chain validated but sender not (or vice-versa) — Rule 23
- **Edge:** cross-chain handler validates `srcChainId` OR `sender` but not BOTH → spoofed message executes.
- **Grep:** in the receive handler, check both the chain-id check AND the sender/peer check exist.
- **Edge:** HIGH (cross-chain, thin competition). EID ≠ chainId — cross-reference LayerZero docs (lesson: EID 30332=Sonic, 30367=HyperEVM).

### SC-P-05 — Peer / DVN / config drift across deployments
- **Edge:** a peer set to a wrong/stale address, or DVN config inconsistent across the N chains.
- **Grep:** enumerate `setPeer`/`setConfig` across all deployment scripts; diff per chain.
- **Edge:** HIGH (config periphery, post-audit). LOW dup.

### SC-P-06 — Replay / dedup fail-open across chains or eras — needs an HONEST VICTIM
- **Edge:** a message/nonce/leaf replays, OR a dedup check fails open.
- **CRITICAL gate:** prove an **honest party loses funds**, not just that the message replays. (Hyperbridge F-002 CLOSED INFORMATIVE: flawless replay, no victim grievance — attacker was careless-sender + beneficiary in one run.) Design-intent test must catch this at the gate, not at triage.

---

## Economic / math edges

### SC-P-07 — First-depositor / share-inflation / totalSupply==0 edge
- **Edge:** attacker mints first share, donates to inflate, later depositors round to 0 shares.
- **Grep:** `totalSupply == 0`, share-mint math, `convertToShares`/`convertToAssets`, ERC4626.
- **Dup:** HIGH (textbook). Only edge if a non-standard wrapper reintroduces it post-mitigation.

### SC-P-08 — Rounding-direction asymmetry favoring the caller
- **Edge:** mint rounds down / redeem rounds up (or the pair is inconsistent) → drip extraction.
- **Grep:** `Math.Rounding`, `mulDiv(...Floor)` vs `Ceil`, `+1` fudge, custom fixed-point lib.
- **Gate:** quantify per-tx and per-1000-cycle. Centrifuge D18 rounding = ~2000 wei/1000 cycles = **NOT fund-theft level = KILLED.** Honest impact quantification (Rule 15).

### SC-P-09 — Oracle / price integrity (financially exploitable)
- **Edge:** spot/TWAP/Chainlink read manipulable in the same tx (flash-loan) to misprice mint/redeem/liquidation.
- **Grep:** `getReserves`, `latestRoundData`, `slot0`, TWAP window, staleness check absence.
- **Gate:** must be OBSERVED state delta (LP_value_after < before), not arithmetic argument. Invariant-priced LP (sqrt-of-invariant + oracle ratio, à la Curve/Aerodrome) is manipulation-RESISTANT — verify before claiming.

### SC-P-10 — Library-stock vs audit-custom divergence (cross-language drift)
- **Edge:** an off-chain lib (TS/Rust) computes params the on-chain validator rejects (DoS) or accepts-but-wrong (leak); OR a "simplified" custom reimplementation of a standard lib diverges from the canonical one.
- **Grep:** find the off-chain twin of an on-chain validator (e.g. `dtf-rebalance-lib` ↔ `RebalancingLib.sol`); diff rounding model (decimal.js round-half-up vs Solidity mulDiv-floor).
- **Edge:** HIGHEST — Rust/Solidity / off-chain/on-chain drift, very few wardens read both. LOW dup. (Reserve F-OFFCHAIN-001 weight {0,0,1} divergence came from here.)
- **Cross-language line refs are load-bearing:** verify every file:line resolves on BOTH sides at the cited commit.

---

## State-machine / reentrancy edges

### SC-P-11 — Reentrancy / callback window into a non-guarded mutator
- **Edge:** a callback (bidCallback, afterSwap/beforeSwap hook, ERC777/721 hook, flashloan callback) re-enters a fund-moving fn that is NOT nonReentrant.
- **Grep:** enumerate every external mutator's modifiers; map which are NOT `nonReentrant` AND attacker-callable. (Reserve: every attacker-callable mutator WAS nonReentrant → reentrancy closed.)
- **Reachability:** the residual is cross-protocol read-only reentrancy (a sell-token whose external price depends on the victim's balance mid-call) — narrow, needs a specific victim.

### SC-P-12 — Disjoint sets that don't actually interact
- **NEGATIVE pattern (kills false paths):** before claiming "A affects B", verify A and B can coexist. Jupiter Lend: recycled vs liquidated branches DISJOINT → 4h wasted. Always confirm overlap before scoring a path.

### SC-P-13 — saturating_sub / overflow-checks mask the claimed bug
- **NEGATIVE pattern:** `saturating_sub` (Rust) or `overflow-checks = true` (Cargo) or Solidity 0.8 checked math may make the underflow/overflow you're claiming impossible. Verify against the actual build config BEFORE claiming.

---

## Periphery / config edges (post-audit, high edge, low dup)

### SC-P-14 — Post-audit code drift
- **Edge:** vulnerable lines written AFTER the last audit commit → can't be "known from audits."
- **Grep:** `git diff <audit-base>..HEAD` (phase0-intel.sh point 3). git-blame the suspect lines.
- **Edge:** HIGH. The churned files are your priority list.

### SC-P-15 — Incomplete fix of a prior finding (sibling-instruction asymmetry)
- **Edge:** a known finding's fix applied to one instruction/function but NOT its structural sibling.
- **Grep:** find the fix commit; check every sibling that shares the vulnerable pattern.
- **Gate:** if the unfixed sibling is owner/trust-gated → still DROP (admin-trust, SC-P-03). (Reserve F-SOL-001: `start_folio_migration` missing the `new_folio.owner` check that `migrate_folio_tokens` has = real asymmetry BUT owner-gated = OOS.)

### SC-P-16 — Deployed non-production / dormant ($0 vault)
- **NEGATIVE pattern:** non-prod deployment = INSTANT KILL (KILL-GATE Q3). Vault $0 = dormant = SKIP (EV gate). Verify on-chain BEFORE writing.

---

## How to use in the path graph
1. For each entry point × actor, ask "which of SC-P-01..16 could turn this into an asset path?"
2. Inject the matching patterns as candidate edges P-01, P-02, …
3. Run each through the reachability gate (Q2) and the recevability gate (scope/dup/edge-fit/loss=$X).
4. The NEGATIVE patterns (12,13,16) are KILL-FIRST: apply them before investing, to drop dead paths.
