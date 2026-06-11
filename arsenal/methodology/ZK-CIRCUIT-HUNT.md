# ZK-CIRCUIT-HUNT — Zero-Knowledge circuits and proving systems

circom, halo2, plonky2/3, arkworks, Nova/Sonobe, Noir (Aztec), Cairo (Starknet).
Bounties massive ($250K-$1M+ across zkSync, Aztec, StarkWare, Aleo, Risc Zero, SP1).
Most Immunefi-gated (OOS). Direct disclosure viable for many.
Knowledge floor = highest of all surfaces. That's the filter — compete against a much smaller pool.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| ZK-001 | Under-constrained signal — `signal` declared but no constraint binds it to claimed semantics → prover forges witness | `grep -rn "signal\s*input\|signal\s*output"` in `.circom`; audit each for corresponding `<==` or `===` constraint |
| ZK-002 | Constraint count off-by-one — loop `for (i = 0; i < N; i++)` with last iteration un-constrained | read loop bodies, check final iteration |
| ZK-003 | Fiat-Shamir transcript missing public inputs — challenge independent of claims → prover tweaks claim | `grep -rn "FiatShamir\|TranscriptHasher\|squeeze_challenge"` — check what's absorbed |
| ZK-004 | Field element boundary — 0, 1, p-1, p, p+1 not handled, overflow at prime | test values at PRIME boundary |
| ZK-005 | Trusted setup leak — ceremony transcript exposes toxic waste, anyone with transcript forges proofs | check setup ceremony artifacts; `grep -rn "ptau\|setup"` |
| ZK-006 | Circuit-verifier mismatch — prove with circuit v1, verify with circuit v2 (same VK hash but semantic diff) | diff VK construction across versions |
| ZK-007 | Public input injection — attacker controls public input that circuit assumes is constrained elsewhere | trace public input flow |
| ZK-008 | Recursion soundness — aggregator circuit doesn't verify inner proof correctness in-circuit | check recursive verification logic |
| ZK-009 | Nullifier forgery — nullifier doesn't bind to secret uniquely → double-spend | check nullifier = H(secret, externalNullifier) binding |
| ZK-010 | Commitment binding — Pedersen / KZG commitment lacks uniqueness, multiple openings pass | check commitment scheme correctness |
| ZK-011 | Range check bypass — `val < 2^N` assumed, constraint missing or bounded wrong | `grep -rn "Num2Bits\|RangeCheck\|range_check"` — audit bit decomposition |
| ZK-012 | Hash preimage bypass — Poseidon / MiMC constants wrong allow preimage collision | check round constants against spec |
| ZK-013 | Aliasing (signal/field element) — `val` constrained as i32 but field holds larger number | check widening / narrowing at field boundaries |
| ZK-014 | Proof replay — proof reused across contexts (chain, user, action) | check proof binding to (chainId, action) |
| ZK-015 | Unsound assumption — circuit claims X → Y, but Y → X not enforced | re-read spec, invert the implication |

## Targets (live bounties)

| Protocol | Bounty | Platform | Circuit system |
|---|---|---|---|
| zkSync Era | Matter Labs $500K direct | Direct | boojum/plonky |
| StarkNet | StarkWare $1M direct | Direct | Cairo prover |
| Aztec | Aztec Labs $250K direct | Direct | Noir / barretenberg |
| Scroll | Scroll $1M | Immunefi OOS | halo2 |
| Polygon zkEVM | Polygon $1M | Immunefi OOS | plonky2 |
| Linea | ConsenSys $1M | Immunefi OOS | arkworks |
| Taiko | Taiko $100K | Taiko direct | sgx+zk hybrid |
| Risc Zero | Risc Zero $100K | Direct | RISC-V zkVM |
| SP1 | Succinct $100K | Direct | RISC-V zkVM |
| Nova / Sonobe | academic | CVE / GHSA | folding schemes |
| Aleo | Aleo $500K | Direct | snarkVM |
| Penumbra | Penumbra $50K | Direct | tmkms + jubjub |
| Railway | Railway $50K | Direct | snarkjs + circom |
| Tornado Cash Nova | deprecated — ghost findings | | |
| circomlib | community | CVE / GHSA | |
| semaphore / hashcloak | Semaphore $50K | Direct | |

## Grep arsenal

```bash
# circom
grep -rn "signal\s*input\|signal\s*output\|signal\s*private" --include="*.circom"
grep -rn "<==\|===\|<--" --include="*.circom"   # constraint operators
grep -rn "template\|component" --include="*.circom"

# halo2
grep -rn "meta.advice_column\|meta.instance\|meta.fixed_column" --include="*.rs"
grep -rn "meta.query_advice\|meta.query_instance" --include="*.rs"
grep -rn "create_gate\|configure_selector" --include="*.rs"

# Noir
grep -rn "constrain\|assert_eq\|assert(" --include="*.noir"
grep -rn "pub\s*fn\|unconstrained\s*fn" --include="*.noir"

# arkworks / Plonky
grep -rn "AllocatedNum\|FpVar\|CircuitVar" --include="*.rs"
grep -rn "cs.enforce\|cs.new_variable" --include="*.rs"

# Fiat-Shamir
grep -rn "TranscriptHasher\|FiatShamir\|squeeze\|absorb" --include="*.rs"

# Field boundary
grep -rn "PRIME\|MODULUS\|FIELD_SIZE" --include="*.rs" --include="*.circom"
```

## Entry points by system

**circom circuit → snarkjs → Solidity verifier:**
- Audit `.circom` template for un-constrained signals
- Audit snarkjs wasm build parameters
- Audit Solidity verifier for public input binding

**halo2 custom gate → PLONK verifier:**
- Audit `configure()` method for selector correctness
- Audit `synthesize()` for advice-column assignment logic
- Audit gate arithmetic against claimed relation

**Noir `main()` → barretenberg → UltraPlonk / Honk verifier:**
- Audit `main` param types (`pub` = public, default = private)
- Audit constrain patterns
- Audit recursion (Noir `std::verify_proof`)

**Cairo program → prover → StarkNet verifier:**
- Audit `felt252` arithmetic (prime = 2^251 + 17 * 2^192 + 1)
- Audit hint injection vectors

**zkVM (Risc Zero / SP1) → Rust guest → verifier:**
- Audit guest/host syscall boundary
- Audit memory commitment scheme
- Audit syscall input validation (spoofing)

## PoC pattern (under-constrained signal)

```circom
// vuln.circom — canonical under-constrained bug
template VulnerableCheck() {
    signal input a;
    signal input b;
    signal output c;
    // BUG: `c` is declared but never constrained to any predicate
    // Prover can set c to anything and proof still verifies
}

component main = VulnerableCheck();
```

Test:
```bash
# Generate a witness where c = 999 (arbitrary)
node generate_witness.js vuln.wasm input.json witness.wtns
# Generate proof
snarkjs groth16 prove vuln.zkey witness.wtns proof.json public.json
# Verify — passes despite c being unconstrained
snarkjs groth16 verify verification_key.json public.json proof.json
# RESULT: proof verifies, no constraint on c enforced
```

Productive fuzzer: write a Python harness that generates N random `input.json`, computes witnesses, checks if any witness violates the intended spec but passes verification.

## Methodology (per target, 40-80h)

1. **Read the spec FIRST** — what does the circuit claim to prove?
2. **Map public vs private** — which signals are public (claim) vs private (witness)?
3. **Enumerate constraints** — every `===` / `<==` in circom, every `cs.enforce` in halo2, every `constrain` in Noir. Does the set of constraints fully determine the claimed relation?
4. **Fiat-Shamir audit** — what's in the transcript hash? If any public input is missing → ZK-003.
5. **Field boundary testing** — for each numeric signal, test 0, 1, p-1, p (if reachable).
6. **Recursion** — if the circuit recursively verifies a proof, audit the inner verification logic.
7. **Off-circuit interactions** — Solidity verifier's `verifyProof(pubInputs, proof)` — is `pubInputs` fully derived from binding context (chainId, user)?

## Integration with lifecycle

```bash
TARGET_HINTS="zk-circuit circom" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh aztec-noir-audit
```

## Tool requirements

- `zk-undercon-fuzzer.py` — for a circom / Noir circuit, generate witnesses that violate intended predicate, check if proof verifies
- `zk-fiat-shamir-audit.py` — parse transcript construction, check public input coverage
- circomspect integration (circom-specific linter)
- halo2-specific gate-coverage tool
- Noir prover.nr audit helpers

## Academic paper triggers

Subscribe `eprint.iacr.org` RSS, filter: halo2, PLONK, Nova, folding, Fiat-Shamir, lookup argument.
Each new attack paper → check live protocols implement the mitigated primitive.

## Known recent patterns

- 2024 halo2 lookup argument: improper lookup table binding → forgery (patched in zcash-halo2)
- 2024 Nova folding: "on the security of Nova" paper showed malleability
- 2023 circomlib: Num2Bits edge case (n=0) allowed arbitrary values
- 2023 snarkjs: trusted setup ceremony contribution verification bug
