---
name: solfork
description: >-
  solfork — reverse-engineer AND live-execute a CLOSED-SOURCE Solana/Anchor program (no source, deployed
  BPF only) on a local fork, to reach and attack the REAL logic instead of guessing from strings. The
  execution layer for any Solana target whose source is not public: hash the deployed .so (provenance
  truth), recover the on-chain Anchor IDL from its "anchor:idl" PDA — or, when a deliberately closed team
  skipped `anchor idl init`, RECONSTRUCT the dispatch by brute-forcing discriminators (sha256("global:<ix>")
  [:8]) against an ix-name wordlist pulled from the source paths strings gave you; then locate the
  constants gates compare against, and stand up solana-test-validator in one of TWO modes — a fresh fork
  with hand-built accounts (enough to pierce a stateless gate) OR a mainnet STATE-fork (--clone/--account,
  real config PDAs + oracles + a live account holding the target state) which is required to reconstruct
  the real math. Drive it with solders + raw JSON-RPC and read the program's own logged values. The
  signature move: to test "must be called by program X", redeploy a CPI-forwarder AT X's own address; but
  a gate that still fires from X's address does NOT prove it's forge-proof — you must reverse the ACTUAL
  predicate (it may be checking the attacker-controlled top-level DATA / discriminator / instruction index)
  before writing "gate HOLDS". Symmetrically, a gate SATISFIABLE via that forwarder is not "bypassable on
  mainnet" unless the REAL authorized caller (state-forked, not spoofed) can be driven to emit it with
  attacker-favorable params — so THREE verdicts, not two: gate-satisfiability / caller-reachability /
  money-move-separately-gated. Ships scripts (recover-idl.py, scan-pubkeys.py, sim.py, statefork.py,
  caller_reachability.py, fwd/). Composes the FIRST MAXIM: neither concede a gate you didn't reverse (C1),
  NOR over-claim a bypass the real caller can't reach (C3) or a bug behind a guard you didn't prove
  bypassable (C2). Activate whenever a Solana bounty target is
  closed-source / deployed-only, or when a gate (InvalidCaller, Unauthorized, a signer/PDA check) blocks a
  direct call and you must decide if it's attacker-satisfiable. Triggers: "/solfork", "closed-source
  solana", "no source, only the program id", "decompile this solana program", "dump the BPF", "reverse
  this anchor program", "recover the IDL", "local fork solana", "state fork mainnet", "simulate against the
  deployed program", "pierce this caller gate", "sBPF", "fd3n". Runs AFTER /nuke and pairs with /extract
  (math veins) and /power (authz veins) once the fork lets you execute them for real.
---

# solfork — closed-source Solana RE + live-fork execution

Veine = the deployed BPF program is the ONLY ground truth (npm/source may not exist or may not match —
Rule 43 + Rule 5; the hard anchor is the sha256 of the dumped .so — `project-injective-swap-deployed-example-010`).
Everything below is EXECUTED on a local fork running the real bytecode, so a verdict is an artifact.

**Proven both ways (2026-07-21):** Jupiter RFQ v2 `fd3n` — bypassed the `InvalidCaller` guard on the fork,
reversed the fill math (sound, conserving), verdict NULL-for-theft because the money-move was SEPARATELY
gated (token-owner constraint + per-tx maker signature). Loopscale `1oopBoJG` — state-forked a LIVE
CLMM-collateral loan, mutated the pool `sqrt_price` ×1.5 with Pyth held constant, collateral value
BYTE-IDENTICAL to 24 decimals ⇒ valuation is Pyth-fair, over-borrow NULL. In BOTH the fork flipped a
strong lead to a definitive verdict — that is the whole point.

> ## ⚠ THREE VERDICT AXES — read before writing "gate HOLDS", "bypassable on mainnet", or "downstream bug = payable"
>
> **CORRECTION 1 — a gate still firing from the spoofed-caller address does NOT prove it's forge-proof.**
> The "gate resists direct + arbitrary-CPI + caller-address-spoofed-CPI ⇒ HOLDS/PDA-signer" reasoning is
> WRONG on its own and it made me concede fd3n as a "fortress/PDA" — the diamond was in the wall. The real
> `InvalidCaller` predicate was a PLAIN introspection check: top-level program-id == JUP6Lkb **AND
> top-level data[0..8] ∈ {route discriminators}**. My spoofed-caller forwarder failed only because it
> carried the FILL discriminator as top-level data, not a route disc — feed the route disc and it PASSES.
> So: the three CPI constructions are NECESSARY probes, never SUFFICIENT for a verdict. Before "HOLDS":
> (1) hand-reverse the ACTUAL compare from disasm — what bytes, read from WHERE (caller program-id? the
> top-level DATA / discriminator? an instruction index? an instructions-sysvar field?). (2) Enumerate the
> ATTACKER-SATISFIABLE introspection angles and FEED each: top-level data (discriminators + args are
> attacker-chosen), instruction position/index, any sysvar-readable field, the immediate-vs-top-level
> caller distinction. A "holds" is legal only after every satisfiable angle is fed and still fails, AND you
> can name the genuinely-unforgeable thing the real caller provides (a PDA signer via `invoke_signed`, a
> real Ed25519 signature) and show it's unforgeable — never inferred from "the fork test still failed."
>
> **PDA-signer caveat (the mechanism behind Correction 1).** Redeploying `fwd` AT `AUTH_ADDR` inherits
> AUTH's PDA-signing authority — on the fork your forwarder IS program `AUTH_ADDR`, so it can `invoke_signed`
> any `find_program_address(seeds, AUTH_ADDR)` once you supply the seeds (usually literal strings visible in
> `strings`/disasm). So a PDA-signer gate is FORGEABLE on the fork yet UNFORGEABLE on mainnet (an attacker
> cannot deploy at AUTH). The fork therefore OVER-estimates reachability for PDA-signer gates: an
> AUTH-redeploy "pass" does NOT prove mainnet-reachable, and a "fail" may only mean you didn't feed the right
> seeds. Adjudicate that case on MAINNET — can any reachable path make the REAL AUTH `invoke_signed` on
> attacker-chosen args? — never on the fork test alone.
>
> **CORRECTION 3 (the mirror C1 opens) — a gate SATISFIABLE via the forwarder is NOT "bypassable on
> mainnet" unless the REAL caller can be driven to emit it with attacker-favorable params.** The
> forwarder-at-AUTH is a PASSTHROUGH: it emits any disc + any params, INCLUDING params the real authorized
> caller would never emit. That param-omnipotence is what lets it prove the gate isn't forge-proof — and is
> EXACTLY what disqualifies it from proving YOU can satisfy the gate on mainnet, where you do not control
> AUTH's code (the REAL caller runs there, with its own param logic). "Passes on the fork ⇒ reachable ⇒
> hunt" over-claims in the direction exactly symmetric to the v1 false-HOLDS. A top-level introspection gate
> satisfiable on the fork is bypassable on mainnet ONLY IF the real authorized caller has an
> attacker-reachable path that emits the required context (program-id + disc) WHILE pushing
> attacker-favorable params into the CPI: a faithful forwarder of user params (an aggregator like Jupiter)
> generally does → truly bypassable; a caller that validates/clamps/transforms its params before invoking
> does NOT → false-bypassable. The forwarder cannot structurally decide this — it is what REPLACED the
> caller. So THREE verdicts, not two: (1) gate-SATISFIABILITY [fork, forwarder — C1], (2) caller-REACHABILITY
> [state-fork the REAL caller, drive its attacker-reachable route, sweep one attacker input, measure
> propagation into the CPI param — `scripts/caller_reachability.py`, step 8], (3) money-move-SEPARATELY-GATED
> [C2]. Theft needs all three. C1 kills the false-HOLDS, C3 kills its mirror the false-BYPASSABLE, C2 kills
> the false-THEFT.
>
> **FORK-AFFORDANCE FILTER (generalizes C1's PDA-caveat + C3).** Every reachability verdict reads on the
> MAINNET attacker's capability, NEVER on the fork's affordances. The fork lends you ≥3 powers a mainnet
> attacker lacks, each a false-CALLER_REACHABLE vector: (1) **deploy-at-AUTH** — a forwarder at AUTH
> `invoke_signed`s AUTH's PDAs and passes any caller-id gate (why step-7 is necessary-not-sufficient);
> (2) **`sigVerify:false`** — sim skips every Ed25519 sig the driven route needs, so a hit leaning on a
> skipped maker/relayer signature is fork-only (pass them to `required_signers=`); (3) **arbitrary
> setup-state** — cloned/hand-built accounts may encode a state no honest mainnet path reaches. SUBTRACT
> each before believing a hit. And the step-8 mirror of C1: a HIT is cheap (one propagating axis suffices),
> a NULL is EXPENSIVE — a 1-D sweep-null is NOT a manifold-empty proof (it may need a multi-input combo or
> another caller route); to WALK on a reachability null, reverse from code that no input reaches the branch,
> never infer it from a single slice.
>
> **CORRECTION 2 — a bug found behind a patched-out guard is payable ONLY if the guard is separately
> proven bypassable on the DEPLOYED program.** Binary-patching a guard out (step 7) lets you STUDY the
> downstream logic, but if the guard genuinely holds on mainnet, a bug behind it is HARDENING /
> defense-in-depth, NOT theft — do not submit it as payable. Trigger-reachability: piercing/removing one
> gate ≠ theft when the money-move is separately gated (fd3n: guard bypassable, yet funds pinned by the
> token-owner constraint + per-tx signature ⇒ NULL for theft anyway). The gate verdict is about the GATE;
> "gate weak" ≠ "theft" and "gate holds" ≠ "no theft" — always ask what SEPARATELY gates the money-move.

## The pipeline (scripts in `scripts/`; each step feeds the next)

1. **Dump + PROVENANCE-hash.** `scripts/provenance.sh <PID> prog.so` → `solana program dump`, `sha256sum`,
   record the code_hash + last-deployed slot to `PROVENANCE.log`. A Solana scope pins a program-id, not a
   slot (and you can rarely reproducible-build the .so from a commit), so the hash's job is INTRA-SESSION
   integrity — you drive the exact bytecode you reasoned about across days — plus IN-FLIGHT UPGRADE detection:
   re-run it and a changed live hash = the program was redeployed mid-hunt = your fork is stale. `file prog.so`
   → sBPF ("unknown arch 0x107"). `strings -n5 prog.so` → custom error messages, account names, `msg!` log
   formats, and source paths (`programs/<x>/src/instructions/<name>.rs`) — name the surface AND seed the IDL
   fallback.

2. **Recover the interface — `scripts/recover-idl.py <PID> prog.so`.**
   - (A) On-chain Anchor IDL: fetch the `anchor:idl` PDA (`create_with_seed(find_program_address([],PID)[0],
     "anchor:idl", PID)`), strip 8-disc+32-authority+4-len, `zlib.decompress` → `idl.json` (ix args, account
     structs, discriminators, error codes). No anchor CLI needed.
   - (B) **FALLBACK when the IDL PDA is EMPTY** (a team that ships closed-source on purpose skips
     `anchor idl init` — the common case): the script brute-forces discriminators —
     `ix = sha256("global:<name>")[:8]`, `account = sha256("account:<Name>")[:8]` — over an ix-name wordlist
     built from the step-1 source paths, and greps the .so for each; a hit maps a name → a real handler.
     This recovers the DISPATCH; account borsh LAYOUTS still come from disasm or a community deserializer
     (e.g. Loopscale's `@exponent-labs/loopscale-deserializer` on npm), with field offsets determined
     EMPIRICALLY (step 5), because a recovered-IDL struct size can be off from deployed.

2b. **SATURATION GATE against the DEPLOYED version (before any depth).** The IDL/version + code_hash from
   steps 1–2 are your anchor; pull the vendor's audit set (`github.com/<org>/audits`) and match the DEPLOYED
   version. "No public source" ≠ "un-audited". If the deployed version is inside the audit set (or audits
   extend beyond it), the fresh modules the audits name are already dissected → any hit there is a dup/FP →
   RE-SOURCE, do not build the fork. Proven on Meteora DLMM: 4 firms on the exact deployed v0.12.0 killed the
   "money-left-on-table because no-source" hypothesis with an executed audit-set retrieval, not a fork.

3. **Disassemble — for LOCATING, not authoritative CFG.** `llvm-objdump-19 -d --triple=bpfel prog.so >
   disasm.txt` reads opcodes and is fine to LOCATE a compare / an embedded constant / an error-code store.
   But sBPF ≠ stock BPF: llvm-objdump does NOT resolve syscall hashes (sBPF calls syscalls by a **Murmur3
   hash** of the name — you see `call <hash>`, not `call sol_log_`), handles `call`/`lddw` (2-slot) loosely,
   and its linear listing is not a real CFG. For SERIOUS reversing or branch-flipping (step 7 patch-out), use
   **Ghidra with the sBPF processor module** or the **rbpf** disassembler/interpreter — not llvm-objdump. File
   line ≠ `.text` address; never conflate them. (capstone 5.x is present for scripted decode.)

4. **Embedded-pubkey scan — `scripts/scan-pubkeys.py prog.so [extra_ids...]`.** Finds the hardcoded
   program-ids/oracles/mints a gate compares against. A hit only LOCATES the constant — it lies about HOW
   the gate uses it (fd3n embedded JUP6Lkb but the predicate also required a route discriminator in the
   top-level data). Hand-reverse the compare before concluding anything (Correction 1).

5. **Stand up the fork — TWO MODES.**
   - **(a) Fresh fork + hand-built accounts** — enough to pierce a STATELESS gate (InvalidCaller etc. don't
     depend on real state). `solana-test-validator --reset --bpf-program <PID> prog.so --rpc-port 8899`;
     build mints/token-accounts with `spl-token` (explicit `--fee-payer kp.json -u <RPC>` — config isn't
     inherited).
   - **(b) STATE-fork from mainnet — REQUIRED to reconstruct the real MATH** (`scripts/statefork.py`).
     Reconstructed math on dummy accounts may not match prod, so for /extract you MUST pull real state:
     `--clone <ADDR> --url m` (or `statefork.fetch_accounts(...)` → `--account <pk> accts/<pk>.json`, needed
     because public RPCs 429/403 the bulk `--clone` — use a real key via `SOLFORK_RPC=<helius…>`). Clone the
     config PDAs, oracles, the counterparty program's state, AND a LIVE account holding the target state
     (find one via `getProgramAccounts` on the account discriminator + decode; offsets EMPIRICAL). Plumbing
     gotchas proven on Loopscale: SHORT `--ledger` path (long trips `SUN_LEN`); a referenced PDA that is
     uninitialized on mainnet (Anchor `event_authority`) → `statefork.empty_stub` or you get `AccountNotFound`;
     cloned oracles are STALE vs the fork clock → `statefork.refresh_pyth` (refresh timestamp, HOLD the
     price); raise CU (CLMM/oracle math > 200k) → `sim.simulate(..., cu=1_400_000)`; the fee payer must exist
     → `sim.ensure_payer`. Kill the validator by PORT, never `pkill -f <name>` (it matches the shell's own
     argv → self-kill). Foreground `sleep` is blocked → `until solana cluster-version; do sleep 2; done`.

6. **Drive + read the program's OWN logs — `scripts/sim.py`.** Build the instruction (discriminator + borsh
   args, metas in IDL order) and `sim.simulate(program_id, data, [(pk,is_signer,is_writable),...])`. It
   forces `encoding:base64 + sigVerify:false + replaceRecentBlockhash` (without base64 the RPC errors and
   `result` is ABSENT → a false `err:None`) and guards that silent failure. Read the program's own logged
   values (`Fill executed: …`, `maintenence_weighted_collateral_value: …`) to reconstruct math empirically —
   this is /extract, executed instead of derived.

7. **Pierce a caller/authz gate (FIRST-MAXIM, per Correction 1).** When a body-level check blocks a direct
   call, prove what it demands with executed artifacts AND reverse the predicate:
   - Direct top-level call (vary fee-payer / signer order / instruction index). Anchor account constraints
     (`ConstraintTokenOwner` 2015, `ConstraintAddress` 2012) fire BEFORE the body check — use that ordering
     to prove the check is body-level.
   - CPI from an arbitrary forwarder (`scripts/fwd/`, `cargo-build-sbf` → `fwd.so`; if the platform-tools
     tarball is a truncated download, `rm -rf ~/.cache/solana/vX` and rebuild).
   - CPI from a forwarder redeployed **AT the authorized-caller's address** (`--bpf-program <AUTH_ADDR>
     fwd.so`) — and **feed each attacker-satisfiable introspection angle** (Correction 1): set the top-level
     data to the expected discriminator (`fwd/` STRIP prefix), try each instruction index, etc. If it PASSES
     under any angle → the gate is SATISFIABLE in principle — NECESSARY, not sufficient (Correction 3): the
     forwarder emits params the real caller never would, so this is NOT yet "bypassable on mainnet". Prove
     CALLER-REACHABILITY on the state-forked real caller next (step 8) before hunting downstream. (A pass that
     relied on AUTH's own PDA-signing power is fork-only anyway — a mainnet attacker can't deploy at AUTH —
     re-adjudicate per the PDA-signer caveat.) If it still fails, reverse the ACTUAL compare from disasm and
     name the unforgeable requirement before "HOLDS".
   - To study logic past a guard, binary-patch it out (the Anchor error code is an immediate store,
     `*(u32*)(r10-off)=0x<code>`; NOP/flip the branch — use Ghidra/rbpf, step 3). **Per Correction 2, a bug
     found downstream is payable ONLY if you SEPARATELY proved the guard bypassable on the deployed program;
     otherwise it is hardening, not theft.**

8. **Prove CALLER-REACHABILITY on the REAL caller (Correction 3) — `scripts/caller_reachability.py`.** A
   forwarder pass (step 7) proves the gate is satisfiable IN PRINCIPLE, not that an attacker can satisfy it
   on MAINNET — the passthrough emits params the real authorized caller never would. So use STATE-fork mode
   (b): `--clone` the REAL caller program at its mainnet address (NOT a forwarder — that is step 7), plus the
   target + every config/oracle/state account both touch. Drive the caller's attacker-reachable route (the
   route disc) top-level over a sweep of ONE attacker-controlled input, and read the value the TARGET logs
   receiving on the CPI. Because the top-level IS the real caller (cloned, not spoofed), a pass here is a real
   mainnet gate-pass, not a fork artifact. Verdicts: **PARAMS_CONSTRAINED** (received value invariant to / moves
   AGAINST your input → the real caller is the guard the forwarder hid → false-bypassable for theft; a clamp at
   a bound IS the finding boundary — quantify it) vs **CALLER_REACHABLE** (the target's received param tracks
   your input favorably → control propagates through the real caller → genuinely bypassable → NOW apply
   Correction 2). Same single-input-mutation discipline as the Loopscale null, aimed at REACHABILITY instead of
   valuation. GOTCHA: `metas` must include the target program-id + every account the caller forwards via CPI (a
   Solana CPI can only use accounts already in the top-level tx) — build that list from the CALLER's interface,
   not the target's, or an `AccountNotFound` reads exactly like GATE_UNREACHABLE.

## Verdict discipline

- Every claim is an executed simulateTransaction / on-chain log, never a strings guess.
- **Gate verdict ≠ theft verdict.** A gate is only about the gate; always ask what SEPARATELY gates the
  money-move (token-owner constraint, a real signature, a nonce). "Gate weak" ≠ theft; "gate holds" ≠ safe.
- **Replay: a no-nonce sink makes the OFF-CHAIN signing flow the PRIMARY vein, not OOS.** When the on-chain
  sink consumes NO nonce/request-state and the money-move rides an off-chain maker/relayer/operator signature,
  do NOT concede "OOS infra" (the Jupiter retreat). Produce an EXECUTED artifact before any NULL: capture one
  real signed message and attempt (a) resubmission inside its validity window (a Solana blockhash is valid
  ~150 slots / 60-90s — a real window a docs "signs per-tx" claim ignores), (b) re-wrap under a decoy
  route/caller, (c) submission to a sibling deployment. A README claim never closes it; only a failed executed
  replay does. See [[feedback-oracle-replay-refute-first-reflex-fix]].
- **Two-live-fork cross-chain replay mode.** Stand up the same program/contract on two forks (or two
  deployments/versions sharing a `DOMAIN_SEPARATOR`), capture a signature valid on fork A, replay it on fork B,
  assert execute-vs-reject — plus a `DOMAIN_SEPARATOR`-diff step across a multi-deployment address set. Every
  "domains can't collide" verdict (OKX 7-mainnet sansChainId, Across `[0u8;64]` prefix, Stackup useChainId) was
  REASONED, never executed; this mode converts the hypothesis into the First-Maxim artifact the rest of the
  skill demands.
- **Never write "HOLDS" from the spoofed-caller test alone** (Correction 1): reverse the predicate + feed
  every satisfiable introspection angle + name the unforgeable requirement. Both opposite failures are fatal
  — conceding a gate you didn't reverse (diamond in the wall), and over-claiming a bypass you didn't prove.
- **Never write "bypassable on mainnet" from a forwarder pass alone** (Correction 3): the passthrough emits
  params the real caller never would, so a fork pass proves SATISFIABILITY, not mainnet REACHABILITY. Run the
  caller-reachability probe (`caller_reachability.py`, step 8) on the state-forked REAL caller first. THEFT
  needs all three axes: gate-SATISFIABLE (C1) ∧ caller-REACHABLE (C3) ∧ money-move NOT separately gated (C2).
- **State-fork math verdict (Loopscale pattern):** clone a LIVE account holding the target state, mutate ONE
  input (a pool `sqrt_price`, an oracle price), hold the others CONSTANT, and byte-compare the program's
  logged value. Unchanged ⇒ that input doesn't feed the value (NULL); changed ⇒ it does (quantify the delta).
- A NULL-COÛTEUX records the executed ledger (the byte-identical comparison / the fed-every-angle gate probe)
  and RE-SOURCEs — it is never awarded from inspection.
- If ALL THREE axes hold — gate satisfiable ∧ caller-reachable ∧ money-move not separately gated — the fork
  now runs /extract (math) and /power (authz) for real against the live program — that is where the payable
  finding is.
