# Cryptographic Library Hunt Playbook — Mechanical Checklist

Run on any target that depends on a crypto library (ed25519, secp256k1, bls, frost, dkg, threshold, jwt libs, noble, libsodium, blst, arkworks, circom, halo2). One bug = N-way payout across every consumer.

**Template finding:** Arc Ed25519 consensus panic via `ed25519_consensus` ($3K–$15K per consumer).

**Variables:**
```bash
export LIB="ed25519_consensus"    # crate / package name
export LIB_DIR="$HOME/src/$LIB"   # local checkout
export UPSTREAM="$HOME/src/ed25519-dalek"  # reference impl for differential
```

**Time budget:** 8–24h. Higher than SC because harness build takes time — but N consumers × payout.

---

## SECTION A — ENTRY POINT / CONSUMER MAP (30 min)

### A1. Clone target + upstream
```bash
git clone https://github.com/$ORG/$LIB "$LIB_DIR"
cd "$LIB_DIR" && git log --oneline -20
# Post-audit drift: find last audit date
git log --all --grep -i -E 'audit|trail.of.bits|consensys|openzeppelin|spearbit' --format='%ai %s' | head
```

### A2. Enumerate reverse dependencies (the amplifier)
```bash
# Rust
curl -s "https://crates.io/api/v1/crates/$LIB/reverse_dependencies?per_page=100" | jq -r '.versions[].crate_id' | sort -u > /tmp/consumers.txt
# npm
curl -s "https://registry.npmjs.org/-/v1/search?text=$LIB&size=100" | jq -r '.objects[].package.name' >> /tmp/consumers.txt
# PyPI
curl -s "https://libraries.io/api/pypi/$LIB/dependents?api_key=$LIBRARIES_IO_KEY" | jq -r '.[].name' >> /tmp/consumers.txt
# Go
echo "manually check: https://pkg.go.dev/$LIB?tab=importedby"
sort -u /tmp/consumers.txt | wc -l
```
**Hit when:** ≥3 consumers with active bounty programs. Rank by TVL, save list for N-way disclosure.

### A3. Public API entry points
```bash
cd "$LIB_DIR"
# Rust: find pub fn in public modules
rg -n 'pub\s+(fn|async\s+fn)' src/ | grep -vE 'test|bench' | head -50
# Find deserialization surface
rg -n 'fn\s+(from_bytes|decode|parse|deserialize|read|read_G|read_F)' src/ | head -20
```

---

## SECTION B — UNWRAP / PANIC / DOS HUNT (1h — highest ROI)

Arc Ed25519 class. One panic reachable from attacker input = every consumer halts.

### B1. Unwrap census
```bash
cd "$LIB_DIR"
echo "=== .unwrap() ===" && rg -n '\.unwrap\(\)' src/ | grep -v test | wc -l
echo "=== .expect() ===" && rg -n '\.expect\(' src/ | grep -v test | wc -l
echo "=== panic! ===" && rg -n 'panic!' src/ | grep -v test
echo "=== unreachable!() ===" && rg -n 'unreachable!' src/ | grep -v test
echo "=== assert_eq! (non-test) ===" && rg -n 'assert_eq!|assert!' src/ | grep -v '#\[test\]' | grep -v test
```
**Hit candidates:** Any unwrap/expect in code path reachable from a public `fn`. List them with line numbers.

### B2. Index-into-collection panics
```bash
# Array index, slice[N], HashMap.get().unwrap()
rg -n '\[[a-z_]+\]' src/ | grep -vE 'test|\[0\]|\[1\]'
rg -n '\.get\([^)]+\)\.unwrap' src/
rg -n 'as\s+usize' src/  # cast that may overflow then index
```

### B3. Integer overflow / truncation
```bash
# Rule 35 R-011 equivalent for libs
rg -n 'as\s+(u8|u16|u32|u64|i32|i64)' src/
rg -n 'checked_(add|sub|mul|div)' src/  # inverse: absence = candidate
```
**Hit when:** Cast from larger → smaller without bounds check, or arithmetic without checked_.

### B4. Reachability trace (for each candidate from B1-B3)
```bash
# Given candidate file:line containing unwrap
# Find callers:
CANDIDATE_FN="verify_share"  # the function containing the unwrap
rg -n "$CANDIDATE_FN\s*\(" src/ --type rust
# Walk up until a pub fn. That's the attacker entry.
```
**Build PoC:**
```rust
// tests/panic_poc.rs
#[test]
fn reach_panic() {
    let malformed = hex::decode("[crafted bytes]").unwrap();
    let _ = $LIB::public_api(&malformed);  // should panic here
}
```

---

## SECTION C — DESERIALIZATION VALIDATION GAPS (1h)

Curve points / scalars / sigs must be validated. Absence = forgery/malleability.

### C1. Identity point acceptance (Ed25519 / FROST)
```bash
rg -n 'fn\s+from_bytes|fn\s+read_G|fn\s+decompress' src/ | head -10
# For each, open and check if is_identity() is called
for f in $(rg -l 'from_bytes|read_G' src/); do
  echo "=== $f ==="
  grep -A 20 'fn\s\+\(from_bytes\|read_G\)' "$f" | grep -E 'is_identity|is_zero|is_small_order|CompressedEdwardsY|decompress' | head -5
done
```
**Hit when:** No `is_identity()` / `is_small_order()` / torsion check. Serai pattern.

### C2. Scalar range / canonical form
```bash
rg -n 'fn\s+(from_canonical_bytes|from_bytes)' src/ | head -10
rg -n 'check_scalar_canonical|sc_minimal' src/
```
**Hit when:** Scalar deserialization doesn't enforce s < L (RFC 8032 §5.1.7).

### C3. ECDSA low-s enforcement (secp256k1 / k256)
```bash
rg -n 'low_s|normalize|enforce_low_s' src/
rg -n 'fn\s+verify' src/ | head -5
```
**Hit when:** `verify()` doesn't reject high-s sigs = malleability. Also check if consumer relies on signature uniqueness.

### C4. Signature bounds (R on curve, s in [1, n-1])
```bash
# For each verify function, grep inside for range check
for f in $(rg -l 'fn\s\+verify' src/); do
  sed -n '/fn\s\+verify/,/^}/p' "$f" | grep -E 'is_identity|is_zero|>= order|< order|\bCurveOrder\b'
done
```
**Hit when:** Missing `R != identity` or `s ∈ [1, n-1]` check.

### C5. Trait layering inconsistency (Serai pattern)
```bash
# Find deserialize methods in different traits
rg -n 'impl\s+.+\s+for\s+' src/ | grep -E 'read_G|from_bytes|decode' | head
# Compare validation logic across layers — same primitive, different checks?
```
**Hit when:** Outer trait (`Ciphersuite`) calls inner (`Curve`) but outer path is used by public API, bypassing inner validation.

---

## SECTION D — FROST / THRESHOLD / DKG SPECIFIC (1h, if applicable)

### D1. Aggregate-to-identity attack
```bash
rg -n 'fn\s+aggregate' src/
# In aggregate fn: is the result checked against identity?
for f in $(rg -l 'fn\s\+aggregate'); do
  sed -n '/fn\s\+aggregate/,/^}/p' "$f" | grep -E 'is_identity|is_zero|return Err'
done
```
**Hit when:** Aggregated point/sig can be identity without error → cancellation forgery.

### D2. Lagrange coefficient binding
```bash
rg -n 'lagrange|polynomial' src/
# Check: does coefficient computation bind to the ACTUAL participant set used in signing?
```
**Hit when:** Coefficient is computed against a wrong set → t-of-n becomes any-of-n.

### D3. Nonce reuse detection
```bash
rg -n '(nonce|commitment|preprocess).*(HashMap|BTreeMap|Vec)' src/
# Search for state machine: is nonce consumed exactly once per session?
rg -n 'fn\s+sign' src/ | head
```
**Hit when:** No marking of used nonces → reuse → secret key extraction (CVE class).

### D4. Commitment/nonce exchange fields (Option<T> panic)
```bash
# FROST: SigningNonces, SigningCommitments wrapped in Option → .unwrap() out of order = panic
rg -n 'Option<SigningNonces|Option<SigningCommitments|Option<Preprocess' src/
# Where are they unwrapped?
rg -n '\.unwrap\(\)' src/ | grep -iE 'nonce|commit|preprocess'
```
**Hit when:** Unwrap on these fields without state-machine invariant enforced.

---

## SECTION E — JWT / JOSE LIBRARIES (30 min, if applicable)

Target: `authlib`, `pyjwt`, `jsonwebtoken`, `jose`, `jose4j`.

### E1. alg:none acceptance
```bash
rg -n 'alg.*none|"none"' src/ | head
rg -n 'fn\s+verify' src/ | head
# Check: does verify() reject alg=none even if cfg allows it by default?
```

### E2. Alg confusion (RS256 → HS256)
```bash
# Find where alg header controls which key type is used
rg -n 'algorithm|alg\s*=' src/ | head
# Hit: if alg header chooses verification key without type check
```

### E3. JWK header auto-trust (RFC 8725 §2.4)
```bash
rg -n '"jwk"|"jku"|"x5u"|"x5c"' src/
# If any found and used to VERIFY without pre-allowlist = Critical
```

### E4. DER key algorithm confusion (CVE-2024-33663 class)
```bash
rg -n 'from_der|parse_der|SubjectPublicKeyInfo' src/
# Does decoder check AlgorithmIdentifier matches expected curve/alg?
```

### E5. kid injection (path traversal / SQL / LDAP)
```bash
rg -n '"kid"|kid\s*=' src/
# Is kid sanitized before lookup?
```

---

## SECTION F — DIFFERENTIAL FUZZING (4–24h, background)

### F1. Harness skeleton
```bash
mkdir -p "$LIB_DIR/fuzz/fuzz_targets"
cat > "$LIB_DIR/fuzz/fuzz_targets/diff.rs" <<'EOF'
#![no_main]
libfuzzer_sys::fuzz_target!(|data: &[u8]| {
    if data.len() < 96 { return; }
    let (msg, rest) = data.split_at(32);
    let (pk, sig) = rest.split_at(32);
    let t = target_lib::verify(pk, msg, sig);
    let u = upstream_lib::verify(pk, msg, sig);
    assert_eq!(t.is_ok(), u.is_ok(), "divergence: {:02x?}", data);
});
EOF
cargo +nightly fuzz run diff -- -max_total_time=86400
```
**Hit when:** Assertion fails → divergence = bug candidate.

### F2. Wycheproof corpus
```bash
git clone https://github.com/google/wycheproof /tmp/wp --depth 1
ls /tmp/wp/testvectors/ | grep -iE "$LIB|ed25519|ecdsa|jws"
# Run each testvector file through the target
```

### F3. RFC compliance diff
```bash
# For each MUST in RFC 8032 (Ed25519), grep target for enforcement
grep -nE "MUST|SHALL|REQUIRED" /tmp/rfc8032.txt | head
rg -n 'canonical|low_order|cofactor|subgroup' "$LIB_DIR/src"
```

---

## SECTION G — CONSUMER-SIDE REACHABILITY (1h per consumer)

Bug matters only if reachable in a consumer. For each top-3 consumer:

### G1. Pin the version they use
```bash
cd "$CONSUMER_DIR"
grep -r "$LIB" Cargo.lock package.json go.sum 2>/dev/null | head
```

### G2. Trace consumer's entry to library's vulnerable fn
```bash
# Rust: find consumer code calling the bug-containing path
rg -n "$LIB::public_fn|use\s+$LIB" "$CONSUMER_DIR/src"
```
**Hit when:** Consumer reaches the bug path with attacker-influenced input.

### G3. Severity per consumer
```bash
# Consensus node → Critical (liveness halt)
# Wallet → Critical/High (signing / ATO)
# Aux tool → Medium
# Tabulate in a matrix before writing reports
```

---

## SECTION H — N-WAY DISCLOSURE TIMELINE

| Day | Action |
|-----|--------|
| 0   | Report to library maintainer (reserve CVE) |
| 0   | Report to top-1 consumer (highest TVL + active bounty) |
| +3  | Report to top-2 and top-3 consumers |
| +7  | Broad disclosure to remaining consumers |
| +14 | Relance all non-responders |
| +30 | Escalation — public CVE coordination |
| +90 | Public disclosure if no fix |

**Rules:**
- Each consumer gets a report tailored to THEIR use (consensus / wallet / auth / indexer).
- Cite CVE once assigned in every consumer report.
- DO NOT blast-disclose — maintainer silent-patches, late consumers dismiss as dup.

---

## SUBMISSION CHECKLIST (per consumer)

- [ ] Library + version specified in title
- [ ] CVE ID cited (even if pending)
- [ ] Consumer-specific impact quantified ($ + user count)
- [ ] PoC runs against consumer's version (not just lib standalone)
- [ ] Recommended fix as unified diff
- [ ] Disclosure coordination note ("primary disclosure to {lib maintainer} on {date}; this is the {N}th consumer report of {total} affected")
- [ ] Chain proof: consumer entry → lib bad path → fund/liveness impact

---

## HIT PRIORITY

1. **Panic reachable from unauth input on a consensus lib** → Critical (chain halt) — Arc Ed25519
2. **Forgery via identity/low-order point acceptance** → Critical — Serai class
3. **Alg confusion / JWK auto-trust in JWT** → Critical (ATO across SaaS) — Authlib class
4. **Nonce reuse / key extraction** → Critical
5. **Signature malleability / replay** → High
6. **Trait-layer validation inconsistency** → High/Critical depending on reach
7. **DoS via algorithmic complexity (long sig, oversized proof)** → Medium/High
