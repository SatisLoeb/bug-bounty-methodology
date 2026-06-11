# Audit Scope Wisdom — Patterns for Production-Scope Security Research

## Production Scope: What's Deployed = What's In Scope

Unlike bounty-program scope (defined by asset listings), direct disclosure scope is determined by what's actually deployed and affecting users.

### Production Scope Rules

```
IF code is deployed AND reachable from user input → IN SCOPE
IF code is in repo but not deployed → OUT OF SCOPE (theoretical only)
IF code is deployed on one chain but not another → scope per-chain
IF code is behind a proxy and upgradeable → both current and upgrade path are relevant
```

### Multi-Chain Awareness

Many protocols deploy across multiple chains. A vulnerability may exist on:
- All chains (same bytecode everywhere)
- Specific chains (different deployments, different configs)
- Only L2s (different assumptions about block time, gas, sequencer)

**Always check:**
1. Which chains is the contract deployed on?
2. Is the bytecode identical across chains?
3. Are there chain-specific configurations that affect the vulnerability?
4. Does the vulnerability require chain-specific conditions (e.g., sequencer downtime)?

### Workspace Structure (Rust Crates)

When auditing Rust workspaces:

| Pattern | Scope Implication |
|---------|-------------------|
| Separate Cargo.toml | Separate crate — may have different deployment status |
| `[workspace.members]` | All listed members are part of the workspace |
| `path = "../other-crate"` | Dependency — changes in dependency affect dependents |
| Feature flags | Code behind feature flags may not be compiled in production |
| `#[cfg(test)]` | Test-only code — NOT in production |

**Check:** Does the vulnerable function get compiled into the production binary? Feature flags and conditional compilation can exclude code.

### Smart Contract Verification

Before claiming a contract is vulnerable:

```bash
# Verify deployed source matches repo
# Compare on block explorer (Etherscan verified source)

# Check proxy status
cast storage <addr> 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc --rpc-url <rpc>

# Check if contract is active (has recent transactions)
cast age <addr> --rpc-url <rpc>
```

## Duplicate Detection

### Where to Check

1. **GitHub Issues** — `gh issue list -R <repo> --search "<keyword>"`
2. **GitHub PRs** — `gh pr list -R <repo> --search "<keyword>"`
3. **Git log** — `git log --oneline --all --grep="<keyword>"`
4. **GitHub Security Advisories** — `gh api repos/<org>/<repo>/security-advisories`
5. **CVE Database** — Search NVD for the protocol/library name
6. **CodeHawks competitions** — Search `codehawks.cyfrin.io` for the protocol name
7. **Code4rena reports** — Search `code4rena.com/reports` for the protocol
8. **Sherlock contests** — Search `audits.sherlock.xyz` for the protocol
9. **Community bug report pages** — Some protocols publish past reports
10. **Protocol blog** — Post-mortems and security updates

### Keywords to Search

- Function name (`complete`, `verify`, `read_G`, `getReward`, `unstake`)
- Error type (`unwrap`, `panic`, `identity`, `revert`)
- Crate/package name (`dkg-promote`, `schnorrkel`)
- Contract name (`ConvexStakingWrapper`, `StakedUSDeV2`)
- Concept (`validation`, `participant`, `nonce`, `reentrancy`)
- Vulnerability class (`try/catch`, `DoS`, `freeze`, `blacklist bypass`)

### De-duplication Decision Tree

```
Has this EXACT root cause been reported before?
├── YES → Is it fixed?
│   ├── YES → Check if regression. If new code reintroduces → VALID (new finding)
│   └── NO → Duplicate. Do not disclose.
├── SIMILAR but different root cause → Build differentiation table. Proceed if distinct.
└── NO → Novel. Proceed.
```

## Known Vulnerability Classes (Industry-Wide)

Some vulnerability classes are so well-documented that disclosing them without novel context will be dismissed:

| Vulnerability | Status | When It's Still Valid |
|--------------|--------|---------------------|
| `.transfer()` 2300 gas | Commodity | Post-audit code, non-standard call pattern |
| First-depositor (ERC4626) | Commodity | Custom vault without standard mitigations |
| ERC777 reentrancy | Commodity | Novel cross-contract path |
| Oracle flash loan manipulation | Commodity | New oracle integration post-audit |
| ERC20 approval front-running | Dead | Almost never valid anymore |
| Signature replay (EIP-712) | Semi-commodity | Missing chainId/nonce in custom scheme |
| Stale oracle / sequencer down | Semi-commodity | L2-specific path not in L1 audit |

**Rule:** If the vulnerability class is "Commodity" and no exception applies → not worth disclosing unless combined with a novel secondary impact.

## Severity Wisdom

### ERC Standard Compliance

| Standard | Required (MUST) | Optional (MAY) |
|----------|----------------|-----------------|
| ERC-1155 | `setApprovalForAll` | Per-token approval (ERC-1761) |
| ERC-20 | `approve`, `transferFrom` | Permit (ERC-2612) |
| ERC-721 | `approve`, `setApprovalForAll` | — |

**NOT implementing an optional feature is NOT a vulnerability.**

### "Permanent" vs "Temporary" Impact

| Condition | Classification |
|-----------|---------------|
| No governance recovery, no pause, no circuit breaker | Permanent (Critical) |
| Governance can refresh/switch | Temporary (High) |
| External condition may self-resolve | Temporary (High) |
| Admin emergency function exists | Temporary (High) |

### Design Intent Indicators

**Signals that behavior IS intentional (be cautious):**
- Underlying token is permissionless by design
- Protocol docs only mention restrictions on derivative
- Missing check is on derivative → underlying conversion
- Every other checked function operates on derivative layer

**Signals that behavior is NOT intentional (proceed):**
- Protocol docs claim "restricted users cannot access funds in ANY form"
- Underlying token ALSO has restriction mechanisms but unused
- Function is a different code path doing same logical operation as checked functions
- Recovery mechanism is rendered useless by the gap

### Code Path Reachability

**Red flags for multi-binary scope risk:**
- Multiple build configurations in the repo
- Different `topology.c` files or entry points
- Functions with comments like "only used in [variant]"
- Conditional compilation flags
- Multiple `main()` functions or binary targets
