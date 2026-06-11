# Scope Pitfalls — Known Rejection Patterns

## Directory Scope is EXACT, Not Recursive Into Sub-Crates

Immunefi assets specify a directory path. Only files WITHIN that exact directory tree are in scope.

### Serai DEX Example (learned the hard way)

| Asset Name | Asset Path | What's IN | What's OUT |
|-----------|-----------|-----------|------------|
| dkg | `crypto/dkg/src` | `crypto/dkg/src/*.rs` | `crypto/dkg/promote/src/*`, `crypto/dkg/musig/src/*`, `crypto/dkg/recovery/src/*` |
| dkg-musig | `crypto/dkg/musig` | `crypto/dkg/musig/src/*.rs` | `crypto/dkg/src/*` |
| modular-frost | `crypto/frost` | `crypto/frost/src/*.rs`, `crypto/frost/src/**/*.rs` | — |
| schnorr-signatures | `crypto/schnorr` | `crypto/schnorr/src/*.rs` | — |
| frost-schnorrkel | `crypto/schnorrkel` | `crypto/schnorrkel/src/*.rs` | — |

### Reserve Vendor Directory Trap (Feb 2026)

| Path | Status | Why |
|------|--------|-----|
| `contracts/vendor/` | **OUT OF SCOPE** | Explicitly excluded on program page |
| `contracts/plugins/assets/curve/cvx/vendor/` | **IN SCOPE** | Under `contracts/plugins/assets/` tree, NOT the excluded `contracts/vendor/` |

**The "vendor" directory name is a trap.** The exclusion is for the TOP-LEVEL `contracts/vendor/` directory. Nested vendor directories under in-scope plugin paths are technically in scope. But under Primacy of Rules, the protocol WILL argue "vendor = out of scope." Preempt this in the report.

### File-Level Exclusions Override Primacy of Impact

| Program | Excluded File | Impact on Submissions |
|---------|--------------|----------------------|
| Rootstock | `contracts/LiquidityBridgeContract.sol` | FATAL — the file is explicitly named and excluded. Even Primacy of Impact doesn't save you when the file was "listed and then explicitly excluded" (different from "unlisted"). |
| Rootstock | `contracts/Quotes.sol` | FATAL — same. |
| Reserve | `contracts/vendor/` directory | Partial — only top-level vendor. Nested vendor under plugins is arguable. |

### Rule of Thumb

```
If the Cargo.toml of the vulnerable crate is NOT inside the asset's directory → OUT OF SCOPE
If a Solidity file is explicitly named in Out-of-Scope → OUT OF SCOPE even under Primacy of Impact
If a directory name matches an exclusion but the FULL PATH differs → arguable, prepare defense
```

Check: `ls <asset-path>/Cargo.toml` — if the vulnerable code's crate has a DIFFERENT Cargo.toml location, it's a different crate and potentially out of scope.

## Duplicate Detection

### Where to Check

1. **GitHub Issues** — `gh issue list -R <repo> --search "<keyword>"`
2. **GitHub PRs** — `gh pr list -R <repo> --search "<keyword>"`
3. **Git log** — `git log --oneline --all --grep="<keyword>"`
4. **Immunefi report history** — You can't see others' reports, but Kayaba will tell you the duplicate ID (e.g., "duplicate of 59428")
5. **CodeHawks competitions** — Search `codehawks.cyfrin.io` for the protocol name. Read ALL submissions, including Invalid/Low ones — they create "known issue" precedent.
6. **Code4rena reports** — Search `code4rena.com/reports` for the protocol. Check all severities including QA.
7. **Sherlock contests** — Search `audits.sherlock.xyz` for the protocol.
8. **Community bug report pages** — Some protocols publish past bug reports (e.g., `community.bean.money/bug-reports`)

### Keywords to Search

- Function name (`complete`, `verify`, `read_G`, `getReward`, `unstake`)
- Error type (`unwrap`, `panic`, `identity`, `revert`)
- Crate name (`dkg-promote`, `schnorrkel`)
- Contract name (`ConvexStakingWrapper`, `DepotFacet`, `StakedUSDeV2`)
- Concept (`validation`, `participant`, `nonce`, `reentrancy`, `extra reward`)
- Vulnerability class (`try/catch`, `DoS`, `freeze`, `blacklist bypass`)

## Severity Traps

### DoS/Griefing Automatic Downgrade (Immunefi v2.3)

```
IF attacker_profit == 0 AND protocol_damage > 0:
    severity = MEDIUM (griefing)
    NOT High, even if the damage is significant
```

**Exception:** If the DoS causes fund freezing for > 7 days (604800 seconds), it may qualify as High under "temporary freezing of funds." Check the protocol's specific `secondsToDeadline` or equivalent parameter.

### "Permanent" vs "Temporary" Freezing

| Condition | Classification |
|-----------|---------------|
| No governance recovery, no pause, no circuit breaker, external fix unlikely | Permanent (Critical) |
| Governance can refresh basket / switch collateral | Temporary (High) |
| External condition may self-resolve (token unpause) | Temporary (High) |
| Admin can call emergency function | Temporary (High) |

### ERC Standard Compliance

| Standard | Required (MUST) | Optional (MAY) |
|----------|----------------|-----------------|
| ERC-1155 | `setApprovalForAll` | Per-token approval (ERC-1761 extension) |
| ERC-20 | `approve`, `transferFrom` | Permit (ERC-2612) |
| ERC-721 | `approve`, `setApprovalForAll` | — |

**NOT implementing an optional feature is NOT a vulnerability.** This killed the Beanstalk ERC-1155 submission (95% rejection probability).
