# DA-LAYER-HUNT — Data Availability Layer + Light Client Bridge

Celestia, EigenDA, Avail, Near DA, Polygon AvailDA.
Nascent infrastructure, huge TVL downstream (every rollup using them),
very few hunters because class requires DA sampling + Merkle + fraud proof + validator set rotation understanding.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| DA-001 | Blob commitment forgery — KZG / Merkle proof accepted for data that wasn't posted | `grep -rn "verifyCommitment\|verifyBlob\|kzgVerify"` — check proof scheme binds to (namespace, height, root) |
| DA-002 | DAS under-sampling — fraction sampled too low, adversarial blob passes with probability p | static analysis of sample count parameter |
| DA-003 | Attestation quorum bypass — (n/2+1) threshold miscalc, fewer sigs accepted | `grep -rn "quorumThreshold\|stakeThreshold"` — check arithmetic |
| DA-004 | Namespace parsing confusion — rollup A reads rollup B's blob because namespace bytes ambiguous | check namespace length + prefix bytes parsing |
| DA-005 | Expiration / pruning bypass — stale blob claimed as fresh because retention window miscalc | check block height comparison direction |
| DA-006 | Validator set rotation — old validator sigs accepted after rotation | `grep -rn "rotateValidators\|updateValidatorSet"` — check activation block |
| DA-007 | Blobstream relayer injection — relayer can inject forged commitment without quorum | `grep -rn "submitDataRoot\|updateLightClient"` — check sigs required |
| DA-008 | Fraud proof window off-by-one — challenge period < expected, attacker wins by 1 block | compare challenge window constants to spec |
| DA-009 | Long-range attack via sparse sync — skip blocks accepted, long-range attack via old keys | `grep -rn "skipBlocks\|sparseHeader"` — check weak subjectivity |
| DA-010 | EigenDA bitmap inclusion — operator set bitmap with wrong semantics (bit 0 = first vs skipped) | check bitmap reading direction |
| DA-011 | Signed root vs actual root — committee signs root, different root used for inclusion | `grep -rn "dataRoot\|stateRoot"` — verify single source |
| DA-012 | Cross-DA bridge — same blob attested on DA A, claimed as DA B | check chain-of-custody proof |

## Targets

| Protocol | Bounty path | Notes |
|---|---|---|
| EigenDA | EigenLayer $1M Immunefi (OOS) | direct via security@eigenlabs.xyz |
| Celestia | direct security@celestia.org | core team responsive |
| Avail | Avail direct | |
| Near DA | Near $200K HackenProof | |
| Blobstream on Ethereum | Celestia + client downstream | each rollup that reads it = separate target |
| Polygon AvailDA | Polygon $1M Immunefi (OOS) | |
| zkSync Era (uses Celestia/custom DA) | Matter Labs direct | |
| Mantle Network (uses EigenDA) | Mantle $200K via HackenProof | |
| Arbitrum AnyTrust | Offchain Labs direct | |

## Grep arsenal

```bash
# Commitment verification
grep -rn "verifyCommitment\|verifyBlob\|verifyInclusion\|kzgVerify" --include="*.sol" --include="*.rs" --include="*.go"

# Attestation
grep -rn "verifyAttestation\|validateQuorum\|verifyDataRoot" --include="*.sol" --include="*.rs"

# DAS sampling
grep -rn "sampleCount\|sampleProbability\|numSamples" --include="*.rs" --include="*.go"

# Validator set
grep -rn "validatorSet\|activeSet\|quorum" --include="*.sol" --include="*.rs"

# Namespace
grep -rn "Namespace\|namespace_id\|namespaceVersion" --include="*.rs" --include="*.go"

# Blobstream
grep -rn "Blobstream\|updateDataRoot\|dataRootTupleRoot" --include="*.sol"

# Fraud proof window
grep -rn "challengePeriod\|fraudProofWindow\|disputePeriod" --include="*.sol"
```

## Entry points by layer

**Layer 1 (DA Producer):** node posts blob, generates commitment
**Layer 2 (Attestation):** committee signs commitment with threshold sigs
**Layer 3 (Relayer):** bridge contract on Ethereum accepts attested commitment
**Layer 4 (Consumer):** rollup/protocol reads blob via proof against attested commitment

Bugs concentrated at L3-L4 interfaces (where attestation → on-chain verification happens).

## PoC pattern

```rust
// Rust: differential fuzz the attestation verifier
// Provide the verifier with a forged commitment + random quorum signatures
// Check: does any arrangement of signatures below threshold pass?

// Or Foundry for Ethereum-side Blobstream:
contract BlobstreamExploit is Test {
    function test_forgedDataRootAccepted() public {
        vm.createSelectFork("mainnet", BLOBSTREAM_BLOCK);
        // Craft dataRootTuple that doesn't match any posted blob
        // Craft attestation with sub-threshold signatures
        // Call Blobstream.updateDataRoot
        // Assert it reverts (or find the case where it doesn't)
    }
}
```

## Methodology (20-40h per DA target)

1. **Read spec** — what are the invariants? (data posted ↔ light client accepts, quorum threshold exact, namespace parse unambiguous)
2. **Map attestation flow** — producer → committee → relayer → consumer
3. **Find the threshold arithmetic** — find EVERY `>= threshold` check in the codebase. Off-by-one here = catastrophic.
4. **Namespace parsing** — construct blobs with adversarial namespace bytes. Does client A parse them as its own?
5. **Validator rotation** — trace the activation block logic. Can old keys sign new blocks?
6. **Fraud proof window** — compare to spec. The Aztec $1B? issue (L1 challenge window too short) is canonical.
7. **Cross-chain attestation** — if bridge accepts attestation from DA, does it bind chainId?

## Integration with lifecycle

```bash
TARGET_HINTS="da-layer celestia" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh celestia-blobstream
```

## Tool requirements

- `da-attestation-fuzzer.py` — generate random attestations, test against on-chain verifier
- Merkle proof differential testing (client implementations: Rust / Go / Solidity)

## Key papers (academic paper hunt trigger)

- "Fraud and Data Availability Proofs" (Celestia whitepaper)
- "Danksharding and KZG" (Ethereum roadmap)
- "EigenDA Rollup Bridge" design docs
- Cryptoeprint 2024 DAS sampling papers
