---
name: zerox-settler-immunefi-sc-surface-prioritize
description: "0x Settler SC program (Immunefi, max $1M, DeFi/DEX/Solidity, PoI + github master/src) — top-down surface prioritization @ cdf29a06. Core framework = engineered fortress (no funds at rest, witness-bound metatx, onlySolver+mandatory-slippage intent, confused-deputy/restricted-target/transient-reentrancy guards, 6+ audits). Fertile class = src/core integration-module validation/arith bugs — but ACTIVELY MINED (Immunefi 78645/88903/89191 + Nethermind). Edge = post-Jan-2026 module delta + per-chain restricted-target completeness ONLY. Verdict: NOT P0. WATCH/tight-timebox the delta, else NO-GO dup-fortress. Distinct from zerox-matcha-target-state (Web&App program, same org)."
metadata:
  node_type: memory
  type: project
---

# 0x Settler — Immunefi SC program — TOP-DOWN SURFACE PRIORITIZATION

**TARGET**: `0xProject/0x-settler` @ `cdf29a06769749674ffe7846e154f1d1566b0cc2` (HEAD 2026-09-16). Scope Immunefi = **Primacy of Impact** + `0x Settler` (`github.com/0xProject/0x-settler/tree/master/src`). | **PLATFORM**: Immunefi 0x, max **$1M**, DeFi/DEX/Solidity, live 2024-07-30, last updated 2026-09-21. | Chains: ETH, Polygon, Avalanche, Arbitrum, Base, BSC, Linea, Mantle, Mode, Optimism, Scroll, Solana(sep), +many (Arc/Monad/Plasma/Tempo/HyperEvm/Sonic/Berachain/Ink/Abstract/WorldChain/RobinHood/Unichain).
**SIZE**: 256 `.sol` in `src/` (~29.4k LOC), but ~90% is per-chain deploy boilerplate (24 chains × 5 files) + univ3fork adapters (34). Core framework = ~10 files (`src/*.sol` + `src/core/Permit2Payment.sol` + `src/core/Basic.sol` + `src/allowanceholder/*`).
**RELATION**: this is the **SC program** (Settler contracts). The prior `zerox-matcha-target-state.md` is the **Web & App program** (matcha.xyz / api.0x.org), same org, measured-exhausted 2026-08-26. On-chain was declared "fermé" there cursorily; this dossier is the actual SC threat-model. NO overlap in payable surface.

---

## ÉTAPE 1 — ASSETS & VALEUR TERMINALE

- **A1 — In-flight user funds during a swap** (the Permit2-authorized sell amount, or AllowanceHolder transient allowance). Max loss = **per-transaction**, bounded by the victim's own signed permit amount / trade size. Settler holds **no TVL and no persistent allowances at rest** (README `# Risk` L853-854), so there is **no pooled drain** — the ceiling is "steal one in-flight order," repeatable across pending orders (0x API dwell time). Severity ceiling = **High/Critical IF a reachable cross-user theft exists**; the constraint is reachability+dup, not value.
- **A2 — Positive slippage / surplus / fees** (`POSITIVE_SLIPPAGE`, fee recipients). $ small, solver/protocol-owned by design.
- **A3 — Solver-list & owner governance** (`SettlerIntent.setSolver`, Deployer `authorized`). Owner-gated → admin-trust.

## ÉTAPE 2 — ENTRY POINTS / TRUST BOUNDARIES (verified, file:line)

- `Settler.execute` / `executeWithPermit` — taker-submitted, **permissionless** (`Settler.sol:118,132`). `takerSubmitted` sets payer=msg.sender (`Permit2Payment.sol:508`).
- `SettlerMetaTxn.executeMetaTxn` — **permissionless relayer** submits Alice's signed metatx (`SettlerMetaTxn.sol:150`).
- `SettlerIntent.executeMetaTxn` — **`onlySolver`** allowlist (`SettlerIntent.sol:103,251`), override that binds a **weaker** witness.
- `AllowanceHolder.exec` — permissionless, transient allowance path (`src/allowanceholder/*`, Certora-FV'd by Bailsec).
- **Callback/fallback** re-entry from DEX pools (`Permit2Payment.sol:236` fallback dispatches to a transient callback).
- **Each `src/core/*` integration module** pool/callback interface (36 modules: Uni V2/V3/V4, Balancer V3, Curve, Dodo V1/V2, Ekubo V2/V3, Maverick V2, Velodrome, PancakeInfinity, Bebop, Renegade, Hanji, RFQ, MakerPSM, Nucleus/Teller, + bridges Across/CCIP/DeBridge/LayerZeroOFT/Mayan/StargateV2).
- `CrossChainReceiverFactory` (1244 LOC, biggest file) + `BridgeSettler` — cross-chain receiver deterministic deploy.
- `Deployer` / `SafeGuard` / `SafeModule` / ERC1967 UUPS proxy — upgrade/admin plane.

## ÉTAPE 3 — ACTORS

- **Anonymous caller / relayer** : can call taker-submitted + metaTxn entrypoints. Franchissement = execute arbitrary action lists **only within a signature they can present** (their own, or a metatx signed by a victim). Cannot self-authorize a victim's actions (witness binds them).
- **Whitelisted Solver** (`onlySolver`) : franchissement = choose the action list for a victim's *intent* (actions NOT signed) — but bounded by mandatory slippage floor. A malicious solver = **privileged-role-misbehaves = HARD scope exclusion** (see 6a).
- **Owner** (Deployer `authorized`, timelocked/SafeGuard) : sets solvers, upgrades. Admin-trust.
- **Malicious ERC20 / malicious pool** : buyToken/sellToken/pool are signer-chosen (taker or witness) → self-inflicted, not cross-user.

## ÉTAPE 4-5 — CANDIDATE PATHS + REACHABILITY GATE (q2 manual)

Core invariant (README `# Risk` L851-864, verified in code): **the actions performed must originate from the Permit2 signer.** Three enforcement regimes, all read from source:

- **Taker-submitted** (`Settler.sol`): `msg.sender == payer == signer` (transient `_PAYER_SLOT`). Actions self-authorized in the taker's own tx. No witness needed.
- **MetaTxn** (`SettlerMetaTxn.sol:59-72,156`): witness = `keccak(SLIPPAGE_AND_ACTIONS_TYPEHASH, slippage[recipient,buyToken,minAmountOut], keccak(∀actions))` → Permit2 `permitWitnessTransferFrom`. First action MUST be a witness-aware VIP that spends the witness; `checkSpentWitness` (`Permit2Payment.sol:131,625`) forbids skipping auth. **Full action list bound.**
- **Intent** (`SettlerIntent.sol:242-259`): witness = `keccak(SLIPPAGE_TYPEHASH, slippage)` **ONLY — actions NOT bound.** Compensated by (a) `onlySolver` allowlist + (b) `_mandatorySlippageCheck()==true` → `minAmountOut != 0` required (`SettlerBase.sol:95-96`).

Final output enforcement (all flavors): `_checkSlippageAndTransfer` (`SettlerBase.sol:87-116`) reads **real** `buyToken.balanceOf(Settler)`, requires `>= minAmountOut`, sweeps to `recipient`. Comment L88-92 states this is *the* defense against `BASIC`/intents confused-deputy ("the user's want token increase must come directly from us").

- **P-01 — Witness/typehash wiring flaw** (forge a metatx/intent binding less than intended). `reachability = unreachable`: constructors self-assert the exact type strings (`Permit2Payment.sol:551-558,638-641`); distinct `_witnessTypeSuffix` per flavor ("SlippageAndActions…" vs "Slippage…") → distinct EIP-712 struct hash → **cross-flavor replay closed by construction**. Audited (OZ/Dedaub). DROP.
- **P-02 — Signature malleability / replay** (à la Immunefi 78645). `reachability = conditionnel`: the *known* instance (metaTx malleability in `CrossChainReceiverFactory`) is **already reported + fixed + "contract not deployed, no funds at risk"** (CHANGELOG Unreleased L12-15). Residual = fresh instances only. **scope: KNOWN/dup on the reported instance.** Edge = new bridge/cross-chain modules unaudited since Jan-2026.
- **P-03 — Confused-deputy via incomplete `_isRestrictedTarget` (per-chain) or an integration module that calls an attacker target while custody/witness is live.** `reachability = conditionnel(per-chain list completeness)`. The linchpin `Basic.basicSellToPool` (`Basic.sol:23`) DOES `_isRestrictedTarget(pool)` (blocks PERMIT2/ALLOWANCE_HOLDER/self/Bebop) + the "no funds at rest" invariant + `_PAYER_SLOT` reentrancy guard neutralize the classic aggregator residual-approval drain. **Survivor form**: a *new* chain that integrates a settlement contract (Bebop/Renegade-style) into its action set but omits it from that chain's `_isRestrictedTarget` override (each chain overrides independently — `src/chains/<X>/{Common,MetaTxn,Intent,TakerSubmitted}.sol`). This is the operator's config-drift edge. **LOW dup** on the newest chains.
- **P-04 — Intent output-check bypass** (action ordering that moves buyToken out before the floor check, or manipulates the balance the check reads). `reachability = unreachable for non-solver`: requires being a whitelisted solver (`onlySolver`) → **admin-trust HARD exclusion** unless a non-solver entrypoint reaches the same weak-witness code. DROP (soft-watch only).
- **P-05 — `POSITIVE_SLIPPAGE surplusPpm` new arithmetic** (Unreleased delta, `SettlerBase.sol:159-177`, `unchecked`). `reachability = reachable` but **value = surplus only (A2)**; the unchecked `balance*maxPpm` / `balance*surplusPpm` overflows wrap **downward** (less paid out) → griefing/rounding not theft; recipient is signer/solver-chosen. **Low severity.** WATCH.
- **P-06 — `_toCanonicalSellAmount` bridge-wallet codehash gate** (`Permit2PaymentIntent.sol:648-661`): balance-proportional over-sell only honored if `_msgSender().codehash == _BRIDGE_WALLET_CODEHASH` (fixed constant). `reachability = conditionnel(forge codehash)` — hard; niche. WATCH.

## ÉTAPE 6 — RECEVABILITY GATE (front-loaded)

**6a Scope exclusions (HARD):** "malicious solver steals" (P-04) = privileged-role-misbehaves = **no-go** (kills the easy intent path). Cross-chain arbitrage-only = OOS (but fund-theft ≠ arbitrage). The `CrossChainReceiverFactory` metaTx malleability = **already reported (78645) + acknowledged + fixed** → known-issue.

**6b Dup risk — HIGH across the board.** Evidence (verified in CHANGELOG + `audits/`):
- Audits: **OpenZeppelin (Apr 2024), Dedaub (0x-Settler Jan-30-2026 + Timelock-Guard Mar-2025 + CrossChainReceiver Jun-2025 + earlier), Bailsec (SafeGuard ×2, CrossChainReceiver ×2, AllowanceHolder Certora Formal Verification), Ourovoros (Nov-2023), Nethermind** (credited in changelog).
- **Prior Immunefi reports in the exact fertile class**: **78645** (metaTx malleability), **88903** (UniV3_VIP path/permit sell-token encoding), **89191** (BalancerV3 `bps>10_000`). Plus Nethermind: MetaTxn short-actions, MaverickV2 wrong-buyToken revert, EkuboV2 slippage-check. → the src/core integration-module validation/arith class is **real AND actively mined**.
- Flagship, $1M, live since Jul-2024, high visibility → many wardens. Core framework = **picked clean**.

**6c Edge-fit.** Core settlement framework = LOW edge-fit (fortress, audited, dup-high, "per-function class checklist on N-audit code = predetermined null" — see [[feedback-audited-target-hunt-invariant-not-class]]). The ONLY HIGH edge-fit slice = **post-audit periphery**: (i) `src/core` modules added *after* Dedaub Jan-30-2026, (ii) per-chain `_isRestrictedTarget` completeness on the newest chains, (iii) recipient/destination binding in the newest bridge + Renegade actions. Matches [[doctrine-defense-shadow-confession]] / [[feedback-target-diet-is-the-binding-constraint]].

## ÉTAPE 7 — SCORING & DÉCISION

| Path | Value | Reach | Edge | Dup | TIER |
|---|---|---|---|---|---|
| P-01 witness wiring | High | unreachable | Low | High | DROP (self-asserted+audited) |
| P-02 malleability/replay | High | cond. | Med | High(known 78645) | DROP core / WATCH new bridges |
| P-03 restricted-target drift (new chain) | High | cond. | **High** | **Low** | **P2 — sole live edge** |
| P-04 intent output bypass | High | unreachable(non-solver) | Med | High | DROP (admin-trust) |
| P-05 POSITIVE_SLIPPAGE surplusPpm | Low | reachable | Med | Low | WATCH (Low sev) |
| P-06 bridge-wallet codehash | Med | cond.(forge) | Med | Med | WATCH |

**DÉCISION GLOBALE: NOT P0. NOT P1.** The core Settler framework is a measured engineered fortress (no funds at rest; witness-bound metatx; onlySolver + mandatory-slippage intent; confused-deputy + restricted-target + transient-reentrancy guards; 6+ audit firms; 3+ prior Immunefi reports already draining the fertile class). A solo deep-commit on the framework = predetermined dup-null, consistent with the operator's N-audit-flagship priors (Reserve, Symbiotic, Rheo, Alchemy MA2, LI.FI, OKX — all earned-null).

**GO condition (tight-timebox WATCH, P2):** engage depth ONLY on the **post-2026-01-30 delta**, hunting ONE invariant per module — *"does this module route buyToken back into Settler (so the final `_checkSlippageAndTransfer` floor binds) AND restrict its own settlement/callback target AND validate the callback caller == expected pool AND (bridges/Renegade) bind recipient/destination to the signature?"* Concrete freshest surface from CHANGELOG: Renegade (2026-09-03 sig change → recipient/buyToken/maxSellAmount/refund*), FluxPool (BNB), Tsunami UniV4 fork (Ink), Ekubo V3, Hanji, PancakeInfinity forks (Orvex/Alandale), the bridge actions (Mayan/StargateV2/Across/DeBridge/LayerZeroOFT/CCIP), the `POSITIVE_SLIPPAGE surplusPpm` Unreleased arith, and **new-chain `_isRestrictedTarget` completeness** (Arc/Monad/Plasma/Tempo/HyperEvm/Sonic/Ink/Abstract). Do NOT run a per-function class checklist over the 36 modules — trace the recipient/destination/custody seam SOLO per newest module ([[feedback-agent-fanout-recreates-audit-blindspot]]).

**NO-GO condition:** if slot economics favor a lower-dup target, skip. This is a dup-fortress; the edge slice is Low-dup but severity-skews Low (surplus/griefing) unless a reachable cross-user custody-leak (P-03) is proven — which requires the per-chain restricted-target trace to land. **p_bounty on the core = ~0; on the P-03/new-module edge = low-but-nonzero.**

**TEMPS ALLOUÉ (honnête):** ≤ half-day timebox on P-03 (per-chain restricted-target completeness diff, newest chains first) + the post-Jan-2026 `src/core` module recipient/destination-binding trace. If nothing survives that trace → earned-null, RE-SOURCE. Do NOT open a framework-wide audit.

**Artefacts:** read source at `/home/user/0xproject/0x-settler` @ cdf29a06 (shallow clone, this session). Cross-refs: [[zerox-matcha-target-state]] (Web&App sibling program), [[lifi-delta-seam-earned-null]] (aggregator-class: value hinges on receiver+minOut+calldata binding — here CONFIRMED bound in metatx, weaker-but-solver-gated in intent), [[feedback-audited-target-hunt-invariant-not-class]], [[feedback-target-diet-is-the-binding-constraint]].
