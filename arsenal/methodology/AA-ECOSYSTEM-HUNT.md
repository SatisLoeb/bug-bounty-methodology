# AA-ECOSYSTEM-HUNT — Account Abstraction (ERC-4337 / ERC-7579)

Smart account ecosystem bugs. Bundlers, validators, modules, paymasters.
Bounties $50K-$500K active across Pimlico / Alchemy / Biconomy / Kernel / Candide / Safe.
Knowledge floor filters scanners — few hunters hold 4337 + 7579 + EIP-712 + bundler semantics simultaneously.

## Bug classes

| ID | Class | Detection signal |
|---|---|---|
| AA-001 | UserOp validation bypass — signature valid on validator but wrong scope (entryPoint mismatch, chainId missing, sender not bound) | `grep -rn "validateUserOp\|_validateSignature"` — check signed fields include entryPoint + chainId + sender |
| AA-002 | Paymaster signature replay — paymaster signs without nonce/chainId/context → replay across chains or users | `grep -rn "validatePaymasterUserOp"` — check hash domain covers chain ID + userOp.nonce |
| AA-003 | Module install race — module installed mid-UserOp, validation path changes mid-execution | `grep -rn "installModule\|uninstallModule"` — check reentrancy guard on module registry |
| AA-004 | Session key escalation — session key's signed scope broader than validator's check | `grep -rn "sessionKey\|permissions.*selector"` — trace selector check |
| AA-005 | ERC-7579 executor delegatecall target confusion — module executed in wrong context | `grep -rn "executeFromModule\|execFromExecutor"` — verify target not user-controllable |
| AA-006 | Simulation vs execution divergence — `eth_estimateUserOperationGas` returns X, EntryPoint.handleOps behaves differently → attacker profits | diff bundler simulator trace vs on-chain trace |
| AA-007 | Banned opcode bypass (ERC-7562) — GAS / NUMBER / TIMESTAMP accessed via obscure chain (STATICCALL to helper that uses banned opcode) | static analysis of validator code paths |
| AA-008 | Factory frontrun — CREATE2 initcode deterministic, attacker frontruns deployment with same initcode, different owner | check initcode salt includes caller + chain + owner |
| AA-009 | Paymaster withdrawal drain — revert-in-postOp + reentrancy on paymaster refund | `grep -rn "postOp\|_postOp"` — check effects-before-interactions |
| AA-010 | Cross-module permission confusion — module A grants, module B checks wrong module | `grep -rn "hasPermission\|checkPermission"` — trace the module that's actually consulted |
| AA-011 | Nonce management collision — 2D nonce key reused across unrelated flows | `grep -rn "getNonce\|_validateAndUpdateNonce"` |
| AA-012 | Aggregator signature confusion — BLS aggregated sig includes userOps that shouldn't aggregate together | `grep -rn "IAggregator\|validateUserOpSignature"` |

## Targets with live bounties

| Protocol | Bounty | Platform | Notes |
|---|---|---|---|
| Pimlico (bundler + Kernel) | $100K | Cantina | ZeroDev stack, ERC-7579 |
| Alchemy Smart Accounts | $50K | HackerOne | LightAccount + bundler |
| Biconomy | $75K | HackerOne | BICO ecosystem, ERC-4337 v0.7 |
| Candide | $30K | Cantina | open-source bundler |
| Stackup | $50K | Direct | production bundler |
| Soul Wallet | $25K | Direct | ERC-7579 implementation |
| Safe | $500K via Immunefi | IMMUNEFI OOS | skip |
| Kernel (ZeroDev) | within Pimlico scope | Cantina | |

## Entry points (UserOp flow)

```
Bundler
  eth_sendUserOperation → simulateValidation → simulateHandleOp → mempool
EntryPoint
  handleOps → validateUserOp → (optional) validatePaymasterUserOp → execution
Validator
  validateUserOp(userOp, userOpHash, missingAccountFunds) → returns validationData
Executor
  execute(target, value, data) → delegatecall or call per module
Paymaster
  validatePaymasterUserOp(userOp, userOpHash, maxCost) → returns context + validationData
  postOp(mode, context, actualGasCost) → refund/settle
```

## Grep arsenal

```bash
# Core validation surface
grep -rn "validateUserOp\|_validateSignature\|validatePaymasterUserOp" --include="*.sol"

# Module lifecycle
grep -rn "installModule\|uninstallModule\|isModuleInstalled" --include="*.sol"

# Executor module dispatch
grep -rn "executeFromExecutor\|executeViaExecutor\|IExecutor" --include="*.sol"

# Session key / permission system
grep -rn "sessionKey\|SessionKeyPlugin\|permissionHash" --include="*.sol"

# Nonce management
grep -rn "getNonce\|_validateAndUpdateNonce\|NonceManager" --include="*.sol"

# Aggregator
grep -rn "IAggregator\|validateUserOpSignature\|aggregate(" --include="*.sol"

# Factory
grep -rn "createAccount\|getAddress\|CREATE2" --include="*.sol"
```

## PoC pattern (fork-based)

```solidity
// test/AAExploit.t.sol
pragma solidity ^0.8.23;
import "forge-std/Test.sol";

IEntryPoint constant ENTRY_POINT_V07 = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);

contract AAExploit is Test {
    function setUp() public {
        vm.createSelectFork("mainnet", 19_500_000);
    }

    function test_userOpValidationBypass() public {
        // 1. Deploy target account with known validator
        // 2. Craft UserOp where signed data doesn't bind entryPoint/chainId
        // 3. Replay on a different chain / different entryPoint
        // 4. assert: validator accepts, executor executes an action attacker shouldn't access
    }
}
```

## Methodology (per target, 20-40h)

1. **Identify validator + executor + paymaster** — each protocol ships one or more. Map them.
2. **Trace signed scope** — what fields does the signed hash cover? Missing any of: entryPoint, chainId, sender, nonce, callData? → AA-001 candidate.
3. **Module install flow** — if ERC-7579, can a module be installed mid-validation? Check reentrancy guards.
4. **Session key permission model** — enumerate the scope checks. Compare what the user signs vs what the validator enforces.
5. **Paymaster hash domain** — what fields are in the paymaster hash? Missing userOp.nonce or chainId → AA-002.
6. **Simulation drift** — read bundler's simulator. Does it match on-chain execution path? Check gas estimation edge cases.
7. **Factory determinism** — initcode salt scheme. Frontrunnable?

## Known recent findings (ghost-finding candidates)

- Biconomy 2025: paymaster signature didn't bind chainId, cross-chain replay, patched silently
- Safe module permission bypass: installation guard missing (internal audit)
- ERC-7579 executor module: delegatecall target validation missing in some implementations

## Integration with lifecycle

```bash
TARGET_HINTS="aa-smart-account" \
  ~/arsenal/audit-lifecycle/bin/init-target.sh <target-name>
```

Target-router.sh emits this checklist as mandatory + SC-layer checks.

## Tool requirements

- `aa-userop-tracer.sh` — trace UserOp through EntryPoint call tree, flag simulation/execution diff
- Foundry fork-test templates for UserOp replay, paymaster drain, module race
