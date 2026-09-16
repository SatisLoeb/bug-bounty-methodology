---
name: evmfork
description: >-
  evmfork — the EVM twin of solfork: fork-execute a DEPLOYED EVM target (contract set + the web app that
  drives it) on a local anvil fork to reach and attack the REAL logic instead of reasoning about it
  statically. The execution layer for any EVM bounty target whose real authorization lives on-chain
  (audited contracts treated as OOS) while the in-scope surface is the app that builds the calldata: hash
  the deployed runtime bytecode (provenance truth; resolve the EIP-1967 impl slot for proxies — an impl
  swap is the in-flight-upgrade signal), recover the ABI (Etherscan/Sourcify verified source → else 4byte
  + whatsabi/heimdall selector recovery), locate the constants the gates compare against (immutables in
  bytecode + `cast storage`), then stand up anvil in one of TWO modes — a fresh chain with hand-set state
  (enough to pierce a stateless gate) OR a `--fork-url` state-fork (real registry/oracle/pool state, required
  to reconstruct the real MATH or to replay the app's exact batch). Drive it with raw JSON-RPC via
  scripts/sim.py and read the target's OWN revert reasons + events. The signature move: to test "must be
  called by X", `anvil_impersonateAccount(X)` or `anvil_setCode` a forwarder at X; but a gate that still
  fires from X's address does NOT prove it is forge-proof — you must reverse the ACTUAL predicate (it may
  read tx.origin, a signature, a merkle proof, or attacker-controlled calldata) before writing "gate HOLDS".
  Symmetrically, a gate satisfiable via impersonation is NOT "bypassable on mainnet" unless the REAL caller
  (forked, not impersonated) can be driven to emit it with attacker-favorable params — so THREE verdicts:
  gate-satisfiability / caller-reachability / money-move-separately-gated. Adds one step solfork lacks:
  frontend-batch capture→replay (run the app's own encoder, replay the exact calldata on the fork, read the
  state delta — brick / hijack / wrong-amount). Ships scripts (provenance.sh, recover-abi.py, scan-constants.py,
  sim.py, statefork.py, caller_reachability.py, replay_frontend_batch.py, domain_replay.py). Composes the
  FIRST MAXIM: neither concede a gate you didn't reverse (C1), NOR over-claim a bypass the real caller can't
  reach (C3) or a bug behind a guard you didn't prove bypassable (C2). Activate whenever an EVM bounty target's
  authz is on-chain but the in-scope code is the app/SDK that builds calldata, or when a gate (onlyOwner, a
  role check, a signature, a state guard) blocks a direct call and you must decide if it is attacker-satisfiable.
  Triggers: "/evmfork", "evmfork", "fork this contract", "anvil fork", "state fork mainnet EVM", "replay the
  app batch on a fork", "impersonate the caller", "pierce this onlyOwner", "does this gate hold on mainnet",
  "setStorageAt", "prove this brick/hijack on a fork". Runs AFTER /nuke and pairs with /extract (math veins)
  and /power (authz veins) once the fork lets you execute them for real.
---

# evmfork — deployed-EVM RE + live-fork execution (the solfork twin)

Veine = the DEPLOYED bytecode + on-chain state are the ONLY ground truth (verified source may be absent,
stale, or not match the impl the proxy points at — the hard anchor is keccak256 of the runtime code at the
resolved implementation). Everything below is EXECUTED on a local anvil fork running the real bytecode
against real state, so a verdict is an artifact, never a static-read guess.

[Formalisé 2026-09-08 depuis l'ossature exacte de solfork (même squelette 5-blocs + scripts), motivé par
l'engagement ENS où DEUX leads réels — brick de migration, cap de refund — sont morts sur "vrai bug possible,
pas exécutable depuis une session headless".]

**Harness validated 2026-09-08 (Origin Protocol mainnet fork @ block 25932633, anvil 1.0.0):** sim.py +
statefork.py exercised end-to-end against live in-scope contracts — `sim.call` read OUSD.totalSupply on the
fork (6,223,322 OUSD, matching mainnet); the slot-math (`mapping_slot`/`allowance_slot`) matches Foundry's
`cast index` byte-for-byte; `find_balance_slot` located WETH's balance mapping (slot 3) and WOETH's (slot 0)
EMPIRICALLY, and correctly returned None on OUSD (rebasing/credits-based — the finder refuses to guess a
layout, exactly as designed); `set_erc20_balance` poked a holder and `balanceOf` reflected it; the
`mutate_and_read` snapshot/revert round-trip is non-destructive (verified state restored post-revert). The
EXECUTION layer is proven. What is NOT yet proven is a FINDING — no fork has flipped an Origin lead to a
payable verdict yet. Replace this with a solfork-style "Proven both ways" dated case the first time a fork
turns a real lead into a definitive theft/brick verdict OR a definitive NULL.]

**Motivating gap (not yet proof).** solfork converts a strong Solana lead into a definitive verdict by
running the real bytecode on a fork. evmfork exists because the same move is missing for EVM: an app whose
authorization lives in OOS on-chain contracts cannot be adjudicated by reading the frontend — you must fork
the contracts, replay the app's exact batch, and read the state delta. The first real run must record its
executed artifact here, solfork-style, and delete this caveat.

> ## ⚠ THREE VERDICT AXES — read before writing "gate HOLDS", "bypassable on mainnet", or "downstream bug = payable"
>
> **CORRECTION 1 — a gate still firing under `anvil_impersonateAccount` does NOT prove it is forge-proof.**
> Impersonation lets you send FROM any address on the fork, so "the onlyOwner check still rejected my EOA,
> and passed when I impersonated the owner ⇒ HOLDS" is WRONG on its own — you proved the check reads
> msg.sender, not that an attacker cannot satisfy what it reads. Before "HOLDS": (1) hand-reverse the ACTUAL
> predicate from source/decompile — what does it compare, and read from WHERE (msg.sender? tx.origin? an
> ECDSA `ecrecover` over attacker-chosen data? a merkle proof? a mapping keyed by attacker input? a value
> the attacker can pre-set via another entrypoint?). (2) Enumerate the ATTACKER-SATISFIABLE angles and FEED
> each: calldata args (attacker-chosen), a forged/valid signature where the signer is attacker-controlled, a
> crafted proof, a storage slot the attacker can write via a sibling function, `tx.origin` vs msg.sender.
> A "holds" is legal only after every satisfiable angle is fed and still fails, AND you can name the
> genuinely-unforgeable thing the real path provides (a signature by a key the attacker lacks, a value only
> a privileged tx can set) and show it is unforgeable — never inferred from "the fork call still reverted."
>
> **IMPERSONATION caveat (the mechanism behind C1).** `anvil_impersonateAccount(AUTH)` makes msg.sender ==
> AUTH on the fork — a mainnet attacker cannot do this. So an msg.sender / onlyRole gate is SATISFIABLE on
> the fork yet UNFORGEABLE on mainnet. The fork therefore OVER-estimates reachability for caller-identity
> gates: an impersonated "pass" does NOT prove mainnet-reachable. Adjudicate that case on the REAL caller
> (fork it, don't impersonate it — step 8), never on the impersonated test alone. `anvil_setCode` at AUTH
> is the same trap (you planted the code; a mainnet attacker didn't).
>
> **CORRECTION 3 (the mirror C1 opens) — a gate SATISFIABLE via impersonation/planted-code is NOT
> "bypassable on mainnet" unless the REAL caller can be driven to emit the call with attacker-favorable
> params.** Impersonation is a PASSTHROUGH: from AUTH you send any calldata, INCLUDING params the real
> authorized contract at AUTH would never emit. That param-omnipotence is what proves the gate isn't
> forge-proof — and is EXACTLY what disqualifies it from proving YOU can satisfy it on mainnet, where AUTH
> runs its OWN code. "Passes on the fork ⇒ reachable ⇒ hunt" over-claims, symmetric to a false-HOLDS. A
> caller-id gate satisfiable on the fork is bypassable on mainnet ONLY IF the real authorized caller has an
> attacker-reachable entrypoint that emits the required context WHILE pushing attacker-favorable params: a
> faithful forwarder of user calldata (a router/aggregator/multicall) generally does → truly bypassable; a
> caller that validates/clamps/transforms its args before the internal call does NOT → false-bypassable.
> Impersonation cannot decide this — it REPLACED the caller. So THREE verdicts, not two: (1)
> gate-SATISFIABILITY [fork, impersonate — C1], (2) caller-REACHABILITY [fork the REAL caller, drive its
> attacker-reachable route, sweep one attacker input, measure propagation — `scripts/caller_reachability.py`,
> step 8], (3) money-move-SEPARATELY-GATED [C2]. Theft needs all three.
>
> **FORK-AFFORDANCE FILTER (generalizes the impersonation caveat + C3).** Every reachability verdict reads
> on the MAINNET attacker's capability, NEVER on the fork's affordances. anvil lends you powers a mainnet
> attacker lacks, each a false-CALLER_REACHABLE vector: (1) **impersonation / setCode** — be any address /
> plant any code (why step-7 is necessary-not-sufficient); (2) **`anvil_setStorageAt` / `setBalance`** —
> arbitrary state a mainnet path may never reach (a hit that leans on a hand-poked slot is fork-only unless
> a real writer sets it — find that writer); (3) **`eth_call` state overrides** — same, per-call; (4) **a
> pinned stale `--fork-block-number`** — the block's oracle round / timestamps may be inconsistent with a
> `block.timestamp` you advance (a hit leaning on a stale feed is fork-only — refresh or re-pin). SUBTRACT
> each before believing a hit. And the asymmetry: a HIT is cheap (one propagating axis suffices), a NULL is
> EXPENSIVE — a 1-D sweep-null is NOT a manifold-empty proof (may need a multi-input combo or another
> entrypoint); to WALK on a reachability null, reverse from code that no input reaches the branch, never
> infer it from a single slice.
>
> **CORRECTION 2 — a bug found behind a state-overridden guard is payable ONLY if the guard is separately
> proven bypassable on the DEPLOYED contract.** `anvil_setStorageAt` to flip a `paused` flag or grant
> yourself a role lets you STUDY the downstream logic, but if the guard genuinely holds on mainnet, a bug
> behind it is HARDENING, NOT theft — do not submit it as payable. Piercing/removing one gate ≠ theft when
> the money-move is separately gated. The gate verdict is about the GATE; "gate weak" ≠ "theft" and "gate
> holds" ≠ "no theft" — always ask what SEPARATELY gates the money-move (a second check, an allowance, a
> signature, a nonce).

## The pipeline (scripts in `scripts/`; each step feeds the next)

1. **Fetch + PROVENANCE-hash — `scripts/provenance.sh <ADDR> [rpc]`.** `cast code <ADDR>` → keccak256 →
   record code_hash + block to `PROVENANCE.log`. For a PROXY, resolve the implementation first (EIP-1967
   impl slot `0x360894...bbc`, admin slot `0xb531...103`; or a `implementation()`/`_getImplementation`
   call) and hash the IMPL runtime code — the proxy shell is stable, the impl is what you reason about. The
   hash's job: INTRA-SESSION integrity (you drive the exact bytecode you reasoned about across days) plus
   IN-FLIGHT UPGRADE detection — re-run it and a changed impl hash = the proxy was upgraded mid-hunt = your
   fork is stale, re-pin the fork block and re-reason. `cast codesize` = 0 ⇒ EOA or self-destructed.

2. **Recover the interface — `scripts/recover-abi.py <ADDR> [rpc]`.**
   - (A) Verified source: Etherscan/Sourcify `getsourcecode`/`getabi` → `abi.json` (functions, events,
     custom errors, and the exact impl the explorer verified — cross-check its hash against step 1).
   - (B) **FALLBACK when unverified** (the common closed case): recover the dispatch by SELECTORS —
     `selector = keccak256("<sig>")[:4]`; brute a signature wordlist (from 4byte.directory + a name bank
     seeded by any strings/paths) against the selectors present in the bytecode (`whatsabi`, or grep the
     jump table). A hit maps a selector → a real function. Event topics = `keccak256("<Event(types)>")`.
     Custom-error selectors decode the same way; keep a selector→sig map so `sim.py` can name reverts.
     Storage LAYOUT (slot offsets) still comes from source or is determined EMPIRICALLY (step 4/5).

2b. **SATURATION GATE against the DEPLOYED impl (before any depth).** The impl hash from step 1 is your
   anchor; pull the vendor's audit set (`github.com/<org>/audits`, the contest repo, Immunefi/known-issues)
   and match the DEPLOYED impl. "Unverified source" ≠ "un-audited". If the deployed impl is inside the audit
   set (or the app's known-issues doc already carves it), the surfaces they name are dissected → a hit there
   is a dup → RE-SOURCE, do not build the fork. (ENS lesson: 60+ known-issues + 3 audit rounds carved the
   whole frontend money-path; the residual value was on-chain — read the ledger BEFORE forking.)

3. **Decompile — for LOCATING, not authoritative CFG.** `heimdall decompile` / `panoramix` / evm.codes read
   opcodes and are fine to LOCATE a `require`/`if`, an embedded constant, a custom-error revert, an SLOAD of
   a specific slot. But a decompile is lossy: storage packing, proxy delegatecall boundaries, and assembly
   blocks mislead. For SERIOUS reversing use verified source when it exists; otherwise trace the exact path
   on the fork with `sim.py` + a `debug_traceCall` (opcode/SLOAD trace) rather than trusting the decompile.

4. **Constant + storage scan — `scripts/scan-constants.py <ADDR> [rpc]`.** Pull immutables (embedded in the
   deployed bytecode, not in storage) and the storage slots the gates read (`cast storage <ADDR> <slot>`).
   Finds the hardcoded addresses/oracles/roles a gate compares against. A hit only LOCATES the constant — it
   lies about HOW the gate uses it (reverse the compare before concluding, Correction 1). For a role check,
   read the `_roles` mapping slot for the attacker address to see if the fork already grants it (fork
   affordance — subtract it).

5. **Stand up the fork — TWO MODES.**
   - **(a) Fresh anvil + hand-set state** — enough to pierce a STATELESS gate (onlyOwner, a pure calldata
     check). `anvil --port 8545` then `anvil_setBalance`/`anvil_setCode`/`anvil_setStorageAt` to build the
     minimum state.
   - **(b) STATE-fork from a live chain — REQUIRED to reconstruct real MATH or replay the app's batch**
     (`scripts/statefork.py`). `anvil --fork-url $EVMFORK_RPC --fork-block-number <N>`. State is lazy-loaded
     on access — no per-account clone (easier than solfork). PIN the block for determinism. Gotchas: a
     forked oracle round is STALE vs any `block.timestamp` you advance → re-pin or poke the round
     (`statefork.set_storage`); `anvil_impersonateAccount` for msg.sender (turn OFF auto-impersonate so an
     accidental sender isn't silently spoofed); `anvil_setBalance` the sender for gas; for a proxy target,
     poke the IMPL's storage via the PROXY address (delegatecall storage lives in the proxy). Kill anvil by
     PORT, never `pkill -f anvil` (matches the shell's own argv). Foreground `sleep` is blocked → poll
     `until cast block-number >/dev/null 2>&1; do :; done`.

6. **Drive + read the target's OWN reverts + events — `scripts/sim.py`.** Build calldata (selector + ABI
   args — or paste the app's captured calldata) and `sim.call(to, data, from_=..., overrides=...)` /
   `sim.send(...)`. It talks raw JSON-RPC to anvil and DECODES the revert (`Error(string)` 0x08c379a0,
   `Panic(uint256)` 0x4e487b71, and custom-error selectors via your step-2 map) — the analog of solfork
   reading the program's own logs. It GUARDS the silent-failure gotchas: an `eth_call` that reverts returns
   an `error` object (not a false success), overrides are attached correctly, and a 0x-return on a
   non-`view` is flagged. Read emitted events (topics decoded via the ABI) to reconstruct math empirically —
   this is /extract, executed instead of derived.

7. **Pierce a caller/authz gate (FIRST-MAXIM, per Correction 1).** When a check blocks a direct call, prove
   what it demands with executed artifacts AND reverse the predicate:
   - Direct call from an attacker EOA (`sim.send` from a fresh key) — capture the exact revert selector.
   - Call with `anvil_impersonateAccount(AUTH)` — and **feed each attacker-satisfiable angle** (C1): vary
     calldata args, supply an attacker-signed message where the check `ecrecover`s, craft the merkle proof,
     pre-set the storage the check reads via a sibling function. A pass under any angle → the gate is
     SATISFIABLE in principle — NECESSARY, not sufficient (C3): impersonation emits params the real caller
     never would, so this is NOT yet "bypassable on mainnet". Prove CALLER-REACHABILITY on the real caller
     next (step 8). (A pass that relied on being AUTH — impersonation or setCode — is fork-only; a mainnet
     attacker can't be AUTH — re-adjudicate per the impersonation caveat.) If it still fails, reverse the
     ACTUAL compare and name the unforgeable requirement before "HOLDS".
   - To study logic past a guard, `anvil_setStorageAt` the guard's slot (flip `paused`, grant a role). **Per
     Correction 2, a bug found downstream is payable ONLY if you SEPARATELY proved the guard bypassable on
     the deployed contract; otherwise it is hardening, not theft.**

8. **Prove CALLER-REACHABILITY on the REAL caller (Correction 3) — `scripts/caller_reachability.py`.** An
   impersonation pass (step 7) proves the gate is satisfiable IN PRINCIPLE, not that an attacker can satisfy
   it on MAINNET. So state-fork mode (b) and drive the REAL caller contract at its real address (do NOT
   impersonate it and do NOT plant code — that is step 7). Call the caller's attacker-reachable entrypoint
   (the router/multicall/public function) over a sweep of ONE attacker-controlled input, and read the value
   the TARGET receives (from its event or a `debug_traceCall`). Because the top-level tx hits the real
   caller's real code, a pass here is a real mainnet gate-pass. Verdicts: **PARAMS_CONSTRAINED** (received
   value invariant to / moves AGAINST your input → the real caller is the guard impersonation hid →
   false-bypassable; a clamp at a bound IS the finding boundary — quantify it) vs **CALLER_REACHABLE** (the
   target's received param tracks your input favorably → control propagates → genuinely bypassable → NOW
   apply Correction 2). GOTCHA: forward the exact account/args list the real caller expects, or an
   `AccountNotFound`-equivalent revert reads exactly like GATE_UNREACHABLE.

9. **Frontend-batch capture → replay (the step solfork lacks) — `scripts/replay_frontend_batch.py`.** The
   in-scope surface on a web3-app target is the calldata the APP builds. Capture it — run the app's own
   exported encoder (e.g. `buildRevealBatch`, `createMigrationData`) in node, or intercept
   `eth_sendTransaction`/`signTypedData` from a headless playwright session — then replay THAT EXACT calldata
   on the state-fork and read the state delta. This is what turns "displayed ≠ signed", "the migration
   bricks the name", or "the batch registers to the wrong owner" from a static hypothesis into an executed
   verdict (the two ENS leads die or confirm here). Compare pre/post: owner, resolver, balance, records.

10. **Signature / domain replay (two-fork) — `scripts/domain_replay.py`.** For an EIP-712 sink: fork two
    chains (or two deployments sharing a `DOMAIN_SEPARATOR`), capture a signature valid on A, replay on B,
    assert execute-vs-reject; plus a `DOMAIN_SEPARATOR` / chainId diff across the deployment set. Every
    "domains can't collide" claim is REASONED until this executes it (covers the ENS SEC-MGR-010 class: an
    EIP-712 domain that omits chainId/verifyingContract → cross-context replay, proven not asserted).

## Verdict discipline

- Every claim is an executed `eth_call` / `sendTransaction` receipt / decoded revert / event, never a
  source-read or decompile guess.
- **Gate verdict ≠ theft verdict.** A gate is only about the gate; always ask what SEPARATELY gates the
  money-move (an allowance, a second role, a signature, a nonce). "Gate weak" ≠ theft; "gate holds" ≠ safe.
- **Never write "HOLDS" from the impersonation test alone** (Correction 1): reverse the predicate + feed
  every satisfiable angle (calldata, signature, proof, pre-set storage, tx.origin) + name the unforgeable
  requirement. Both opposite failures are fatal — conceding a gate you didn't reverse (diamond in the wall),
  and over-claiming a bypass you didn't prove.
- **Never write "bypassable on mainnet" from an impersonation pass alone** (Correction 3): impersonation
  emits params the real caller never would, so a fork pass proves SATISFIABILITY, not mainnet REACHABILITY.
  Run `caller_reachability.py` (step 8) on the forked REAL caller first. THEFT needs all three axes:
  gate-SATISFIABLE (C1) ∧ caller-REACHABLE (C3) ∧ money-move NOT separately gated (C2).
- **State-fork math verdict (the /extract move, executed):** on a state-fork, mutate ONE input via
  `anvil_setStorageAt` (a pool `sqrtPrice`, an oracle answer, a totalAssets slot), hold the others CONSTANT,
  and compare the target's logged/returned value. Unchanged ⇒ that input doesn't feed the value (NULL);
  changed ⇒ it does (quantify the delta). Direct twin of solfork's Loopscale byte-compare.
- **Frontend-batch verdict (step 9):** replay the app's own calldata, diff owner/resolver/balance/records
  pre vs post. A brick/hijack/wrong-amount is proven by the state delta, never by reading the encoder.
- **FORK-AFFORDANCE FILTER on every hit:** subtract impersonation, setCode, setStorageAt, setBalance, and a
  stale fork block before believing it. A hit leaning on a fork power a mainnet attacker lacks is fork-only.
- A NULL-COÛTEUX records the executed ledger (the byte-identical comparison / the fed-every-angle probe) and
  RE-SOURCEs — it is never awarded from inspection. (nullguard adjudicates the negative verdict.)
- If ALL THREE axes hold — gate satisfiable ∧ caller-reachable ∧ money-move not separately gated — the fork
  now runs /extract (math) and /power (authz) for real against the live target — that is where the payable
  finding is.
