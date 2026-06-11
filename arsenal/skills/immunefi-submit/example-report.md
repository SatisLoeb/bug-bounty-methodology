# Example: Correctly Formatted Submission

This is a reference example based on our Bug 02 (schnorr-aggregate-identity) which passed scope validation.

## Immunefi Form Fields

### Field 1: Title
```
Lack of identity point rejection in SchnorrAggregate::read() leads to weakened aggregate verification equation
```

### Field 2: Description
```markdown
## Brief/Intro

`SchnorrAggregate::read()` in `schnorr-signatures` deserializes nonce points (`Rs`) using `Ciphersuite::read_G`, which accepts the identity (zero) point for Ristretto. [...]

## Vulnerability Details

[Code snippets, line numbers, step-by-step explanation]

## Impact Details

[Concrete impact, honest assessment of limitations]

## References

- Vulnerable code: https://github.com/...
- Comparison code: https://github.com/...
```

### Field 3: Proof of Concept
```markdown
## Proof of Concept

### Setup

[Cargo.toml]

### Test Code

[Complete #[test] function]

### Running

[cargo test command]

### Explanation

[2-3 sentences]
```

### Field 4: Gist (optional)
Leave empty — inline PoC is sufficient.

### Field 5: Attachments (optional)
Leave empty unless screenshots are useful.

### Field 6: Acknowledgment
Check the box: "I confirm that my submission includes a clear, original explanation and a working PoC."

## Pre-Submit Validation

Before clicking Submit:
- [ ] Asset selected matches the vulnerable file's crate
- [ ] File path is WITHIN the asset's directory tree
- [ ] Searched GitHub Issues for duplicates
- [ ] Severity matches actual (not theoretical) impact
- [ ] PoC is local-only, no network calls
- [ ] Title follows "[Vuln] in [func] leads to [impact]" format
