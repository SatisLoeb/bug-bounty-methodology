# DIFFERENTIAL-FUZZING-METHOD — Same spec, multiple implementations, diff the output

Generic technique that compounds across ALL surfaces (SC forks, blockchain clients, bridge relayers, MPC libs, ZK verifiers, compilers).
Signal: any protocol/primitive with 2+ independent implementations has differential bugs waiting.
TRON $100K finding was this in essence (comparing protection levels across message types — same "implementation" but same spec).

## When this methodology applies

| Surface | Multi-impl example |
|---|---|
| Uniswap V3 | 20+ chain deployments, each a separate recompile. Also Sushi/PancakeSwap forks. |
| Aave V3 | Original + K2 Lend Stellar fork + every AAVE fork |
| Ethereum consensus client | Lighthouse, Prysm, Teku, Nimbus, Lodestar |
| Ethereum execution client | Geth, Reth, Nethermind, Besu, Erigon |
| Solana validator | Agave, Firedancer, Jito-Solana, Sig |
| Bridge relayer | LayerZero DVN implementations (Rust + Go + TS) |
| MPC FROST | frost-core, schnorr-fun, Serai, coinbase/kryptology |
| ZK verifier | snarkjs Groth16, halo2, plonky2 — same PLONK verification |
| EVM bytecode executor | evmone, revm, geth EVM, hyperledger |
| CBOR/JWT parser | pycose, cose-js, go-cose — covered in CONTAINER-LAYER |

## Methodology

### Step 1: Identify the shared spec

- Ethereum consensus: EIP-specs + beacon chain spec
- Bridge message format: protocol whitepaper
- FROST: RFC 9591
- ZK system: PLONK / Groth16 paper
- EVM: Yellow Paper + EIPs

### Step 2: Harvest all independent implementations

- Native client repos (clone locally)
- Language bindings (Rust / Go / TS / Python of the same primitive)
- Forks on different chains (find via etherscan contract verification)

### Step 3: Build a corpus generator

Input format per spec. E.g., FROST:
- `(threshold, signers, message)` tuples
- Include edge cases: threshold=1, signers=threshold, max threshold

ZK verifier:
- `(proof_bytes, public_inputs, verifier_key)`
- Include edge: identity-point inputs, boundary field elements, malformed proofs

### Step 4: Run each input through each implementation

```python
# differential-fuzzer.py skeleton
import subprocess, json, hashlib

IMPLS = {
    "frost-core": "cargo run --release -p frost-core --example sign",
    "schnorr-fun": "cargo run --release -p schnorr-fun --example sign",
    "serai":      "cargo run --release -p serai-frost --example sign",
}

def run(impl_cmd, input_bytes):
    p = subprocess.run(impl_cmd.split(), input=input_bytes, capture_output=True, timeout=5)
    return (p.returncode, p.stdout, p.stderr)

def diff_fuzz(corpus):
    for inp in corpus:
        outputs = {name: run(cmd, inp) for name, cmd in IMPLS.items()}
        hashes  = {name: hashlib.sha256(out[1]).hexdigest() for name, out in outputs.items()}
        unique  = set(hashes.values())
        if len(unique) > 1:
            print(f"DIVERGENCE: input={inp.hex()[:32]}..., outputs={hashes}")
            for name, out in outputs.items():
                print(f"  {name}: rc={out[0]}, stdout_len={len(out[1])}")
            # Save input for manual triage
            with open(f"divergence-{hashlib.md5(inp).hexdigest()[:8]}.bin", "wb") as f:
                f.write(inp)
```

### Step 5: Triage divergences

Per divergence:
1. Is one impl crashing, other succeeding? → potential DoS or bypass
2. Are they returning different results on same input? → semantic bug in one
3. Are they rejecting in different ways? → input parsing diff (one accepts, one doesn't)

### Step 6: Minimize + build PoC

For each triaged divergence:
- Minimize input to simplest trigger
- Build PoC that shows the correct-spec-claim
- Identify which impl is wrong (compare to reference if any)

## Surface-specific harness templates

### EVM client diff (geth vs reth vs nethermind)

Run same block at same height across clients, diff state root after each tx:

```bash
# Geth
geth --rpc --http --http.api debug,eth,web3 --http.port 8545 &
# Reth
reth --rpc.http --http.port 8546 &
# Nethermind
Nethermind.Runner --config mainnet --JsonRpc.Port=8547 &

# For each block: debug_traceBlockByNumber on each
# Diff traces — state root per tx, gas usage, storage modifications
```

### Uniswap V3 cross-chain diff

Same pool params (feeTier, tick_spacing) across chains. Same swap input. Do outputs match?

```solidity
// UniswapV3DiffFuzz.t.sol
address pool_eth = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // ETH-USDC 0.05%
address pool_arb = 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443; // same on Arbitrum

function testFuzz_swapInvariant(uint256 amountIn) public {
    vm.createSelectFork("mainnet", 19_000_000);
    uint256 outEth = swap(pool_eth, amountIn);

    vm.createSelectFork("arbitrum", 180_000_000);
    uint256 outArb = swap(pool_arb, amountIn);

    // Prices differ, but trade amount should behave proportionally
    // Divergence in tick crossing logic = bug in one impl
    assertApproxEq(outEth * arbPrice, outArb * ethPrice, tolerance);
}
```

### FROST impl diff

```rust
// frost-diff.rs
fn diff_sign(message: &[u8], threshold: u16, signers: Vec<usize>) {
    let sig_frost_core = frost_core::sign(threshold, signers.clone(), message);
    let sig_schnorr_fun = schnorr_fun::sign(threshold, signers.clone(), message);

    // Both should produce a valid signature verifying under same public key
    // Divergence in: byte layout, aggregation order, nonce derivation
    assert_eq!(sig_frost_core, sig_schnorr_fun, "divergence on input {:?}", signers);
}
```

### Bridge relayer diff (LayerZero DVN)

Same message, multiple DVN implementations (Rust, Go, TS). Do they all produce the same DVN signature? Same state transition?

## Integration with lifecycle

```bash
TARGET_HINTS="differential-fuzzing smart.contract" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh uniswap-v3-cross-chain-diff
```

The lifecycle supports this — just commit the differential runner + corpus in `evidence/`, log divergences as findings.

## Tool: `~/arsenal/tools/differential-fuzzer.py`

Generic Python runner:
```bash
./differential-fuzzer.py --corpus ./corpus/ \
  --impl "geth:geth ..." --impl "reth:reth ..." --impl "nethermind:Nethermind.Runner ..." \
  --timeout 10 --output divergences.jsonl
```

Each line of `divergences.jsonl`: `{input, impl_outputs: {name: {rc, stdout_hash, stderr_hash}}, triage_pending: true}`

## ROI assessment

- Setup cost: 8-16h per domain (build harness, corpus)
- Run cost: continuous background (CPU cycles)
- Hit rate: 1 bug per 100-500 input divergences (most are non-bugs: rounding, different timing semantics)
- Payout per hit: $10K-$500K depending on surface

**Best-ROI surfaces for this method:**
1. Bridge relayers (LayerZero DVN, Axelar, Wormhole) — low competition, critical paths
2. MPC FROST / threshold sigs — high filter, long cycle, huge payout
3. Cross-chain DEX forks (Uniswap V3 on L2s) — commercial-grade usage, fast cycle
4. zkVM / ZK verifier implementations (Risc Zero vs SP1 vs Nova) — cutting edge
5. Ethereum clients at consensus layer — massive stakes

**Skip for this method:**
- Web API endpoints (only one impl usually)
- Smart contracts with single deployment (no diff possible)

## Cadence

- Background: 10h/week on one harness. Target 2-3 harnesses in rotation.
- Immediate triage on detected divergences (not all are bugs)
- Deep-dive per confirmed bug: 3-6h PoC + report

## Known wins (pattern-precedent)

- Uniswap V2 TWAP: cross-chain oracle diff → arbitrage windows
- geth vs parity state root divergence 2016 (DAO fork era)
- PLONK verifier bugs across impls (2023-2024)
- LayerZero V1 DVN cross-chain divergence (internal finding, patched)
