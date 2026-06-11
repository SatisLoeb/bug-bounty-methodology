# MPC-THRESHOLD-HUNT — Threshold signatures, DKG, FROST, MPC wallets

FROST, Serai, tss-lib (Binance), cggmp21, Gennaro-Goldfeder, multi-party-ecdsa.
Wallet providers: Fireblocks, Copper, Qredo, Finoa.
MPC custody holds billions. Bugs here = catastrophic or silent.
Knowledge floor = cryptography + distributed systems. Second highest filter after ZK circuits.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| MPC-001 | DKG promote to non-ready party — party promoted before all shares received → state corrupt, subsequent panic / forge | `grep -rn "promote\|finalize_dkg\|Promoted"` — check state validation |
| MPC-002 | Identity point acceptance on deserialize — G element is identity (0), signature trivially verifies | `grep -rn "read_G\|from_bytes\|deserialize.*Point"` — check identity rejection |
| MPC-003 | Schnorr nonce reuse — 2 signatures with same `k` leak private key | check nonce generation — deterministic? seeded with message? If seed scope weak → reuse |
| MPC-004 | FROST round order violation — sign before all commitments received → panic OR invalid signature OR key leak | `grep -rn "SigningCommitments\|SigningNonces"` — check state machine |
| MPC-005 | Signer set inconsistency — signers disagree on active set, threshold triggers wrong | check consensus on signer set per round |
| MPC-006 | Unverified broadcast — sender impersonation in broadcast channel | `grep -rn "broadcast\|publish"` — check sig on broadcasts |
| MPC-007 | Lagrange interpolation — reconstruction formula wrong → recovered secret ≠ original | audit Lagrange coefficient computation |
| MPC-008 | Pedersen commitment opening — reveal opening that passes commit check but hides malicious value | check commitment binding (collision-resistant hash?) |
| MPC-009 | Threshold downgrade — protocol accepts t-1 signatures via off-by-one | `grep -rn "threshold\|t ==\|>=\s*t"` — audit comparison |
| MPC-010 | Rogue key attack — public key aggregation without proof-of-possession, adversarial pk injection | check PoP verification on key registration |
| MPC-011 | GG20 Paillier N — Paillier modulus generated without zero-knowledge proof of correctness | check modulus PoK verification |
| MPC-012 | CGGMP range proof bypass — range proof accepts out-of-range values | audit range proof verifier |
| MPC-013 | Secret share redistribution — resharing protocol allows old threshold signers to reconstruct | check resharing leakage |
| MPC-014 | Side channel on nonce — nonce derivation uses timing-variable ops, leaks bits | check `subtle::ConstantTimeEq` usage |
| MPC-015 | Byzantine fault in 2-round protocol — malicious signer aborts, honest signer proceeds, state desync | audit abort handling |

## Targets

| Protocol / library | Bounty | Platform | System |
|---|---|---|---|
| Fireblocks MPC | $5M program | HackerOne | proprietary MPC custody |
| Qredo | $100K direct | Direct | MPC wallet |
| Copper ClearLoop | $50K direct | Direct | MPC custody |
| Finoa | direct | Direct | MPC custody |
| Anchorage | $100K | Direct | MPC + HSM hybrid |
| Web3Auth (formerly Torus) | $50K direct | Direct | threshold wallet |
| Lit Protocol | $50K direct | Direct | threshold PKP + encryption |
| Silent Shard / Silence Laboratories | direct | Direct | MPC SDK |
| Odsy / dWallet | $100K | Direct | 2PC SDK |
| Serai (we submitted, dismissed) | $100K via Immunefi | IMMUNEFI OOS | FROST DKG implementation |
| tss-lib (Binance, abandoned) | CVE / GHSA path | | GG20 ECDSA |
| multi-party-ecdsa (ZenGo-X) | CVE / GHSA | | GG20 |
| cggmp21 (ZenGo-X) | CVE / GHSA | | 2-party ECDSA |
| schnorr-fun (lloyd fournier) | CVE / GHSA | | Schnorr primitives |
| frost-core (ZF/dalek) | CVE / GHSA | | FROST reference impl |

## Grep arsenal

```bash
# FROST primitives
grep -rn "FROST\|frost_\|dkg_\|distributed_key" --include="*.rs" --include="*.go" --include="*.ts"
grep -rn "SigningNonces\|SigningCommitments\|SignatureShare" --include="*.rs"

# Nonce generation
grep -rn "nonce_pair\|generate_nonce\|rand_nonce" --include="*.rs"

# Identity point check (CRITICAL)
grep -rn "is_identity\|CtOption\|from_bytes" --include="*.rs"

# Lagrange
grep -rn "lagrange\|polynomial_evaluate\|basis_poly" --include="*.rs"

# Threshold arithmetic
grep -rn "threshold\|>=\s*t\b\|num_signers" --include="*.rs" --include="*.go"

# Paillier (for GG20)
grep -rn "paillier\|Paillier\|N_sq" --include="*.rs" --include="*.go"

# Constant time
grep -rn "ConstantTimeEq\|subtle\|ct_eq" --include="*.rs"

# Rogue key / PoP
grep -rn "proof_of_possession\|pok\|PoK" --include="*.rs"
```

## Entry points per MPC system

**FROST (RFC 9591):**
- Round 1: each signer → SigningNonces (private) + SigningCommitments (public)
- Round 2: coordinator aggregates commitments, challenges signers
- Round 2 response: each signer → SignatureShare
- Aggregation: coordinator combines shares into final sig

Bug areas: state machine enforcement (MPC-004), nonce secrecy (MPC-003, MPC-014), identity point in commitment (MPC-002).

**GG20 ECDSA (tss-lib, multi-party-ecdsa):**
- Phases 1-4 for signing, 6-phase for keygen
- Paillier encryption used for share blinding
- Complex MtA (Multiplicative-to-Additive) with range proofs

Bug areas: range proof soundness (MPC-012), Paillier N correctness (MPC-011), rogue key (MPC-010).

**CGGMP21 2-party:**
- Simplified for 2-party only
- Easier to reason about
- Look for nonce generation, commitment binding

**Shamir Secret Sharing + custom DKG:**
- Lagrange interpolation (MPC-007)
- Threshold comparison off-by-one (MPC-009)
- Resharing (MPC-013)

## PoC patterns

```rust
// Rust: attack FROST via identity point in commitment
use frost_core::round1;

fn exploit_identity_commitment() {
    // Craft a SigningCommitments where D = identity, E = identity
    // Does the aggregator accept and produce a forgeable sig?

    // Expected: library rejects on deserialize (MPC-002 defense)
    // Actual bug pattern: ciphersuite's read_G doesn't reject identity
}
```

```rust
// Attack DKG promote with missing shares
fn exploit_premature_promote() {
    // 1. Simulate DKG with t=3, n=5
    // 2. Party 1 sends shares to 2, 3, 4 but not 5
    // 3. Coordinator promotes 4 parties (below n=5 but >= t=3)
    // 4. Check: does the key derivation panic / produce wrong key?

    // Serai pattern: promote panicked on unwrap because party was missing shares
}
```

## Methodology (per library, 40-80h)

1. **Read the protocol paper** — FROST RFC 9591, CGGMP21 paper, GG20 paper. Understand invariants.
2. **Map state machine** — for each party, what's the state at each round? Which state transitions are legal?
3. **Identity point audit** — every deserialize of a curve point. Does it reject identity?
4. **Nonce secrecy audit** — every `gen_nonce`. Is it truly random? Does it cover the whole message space? Is it wiped after signing?
5. **Threshold comparison** — every `>= t`, `< t`, `== t`. Off-by-one check.
6. **Broadcast authentication** — every broadcast message. Signed by sender?
7. **Commitment binding** — commitments opened exactly once? Uniqueness?
8. **Range proof verification** — for GG20-family, audit each range proof verifier.
9. **Resharing** — if protocol supports resharing, test old-share-reconstruction attack.
10. **Side channel** — timing on nonce use, ct_eq on comparisons.

## Integration with lifecycle

```bash
TARGET_HINTS="mpc threshold frost dkg" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh fireblocks-mpc-audit
```

## Tool requirements

- `frost-state-fuzzer.py` — generate random FROST round transitions, check state machine enforcement
- `dkg-promote-fuzzer.py` — drop random shares, trigger promote, check panics / invariants
- `mpc-range-proof-audit.sh` — given GG20-family range proof impl, fuzz with out-of-range values
- Integration with differential fuzzer (FROST round reference vs tested impl)

## Academic paper triggers

Subscribe eprint:
- "FROST" — new analysis of the reference
- "Threshold Schnorr" — attacks on variants
- "CGGMP" / "GG20" — range proof / Paillier attacks
- "Secure Multiparty Computation" — new attack taxonomies

Each paper → check live libraries for the mitigation.

## Disclosure notes

- **MPC library bugs:** GHSA/CVE path, direct to maintainer. Many libs abandoned (tss-lib).
- **MPC custody providers:** Fireblocks/Qredo/Copper via their bounty programs. High-touch disclosure.
- **Crypto wallet providers using MPC:** Web3Auth, Lit — direct disclosure.
- **Protocol-level MPC usage (Serai):** Immunefi-gated (boycotted), direct disclosure the only path. Serai dismissed our findings — document lesson.
