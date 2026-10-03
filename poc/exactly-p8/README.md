# P8 — calldata-parsing differential: ProposalManager delay bypass (mechanism PoC)

Target: Exactly Exa App, ExaPlugin (Immunefi, Optimism). Present in deployed v1.0.0
(0x3d73D0fb9e63c49ba8e9cd738964D5E08C047f3e) AND repo HEAD — NOT self-fixed.

## Claim
`ExaPlugin.preExecutionHook` (SINGLE) parses the inner call of `execute` from FIXED byte
offsets: target=callData[16:36], selector=callData[132:136], data=callData[136:]
(ExaPlugin.sol:495-499 in deployed). The Alchemy UpgradeableModularAccount passes RAW
msg.data to the hook (`_preNativeFunction` -> `_allocateRuntimeCallBuffer(msg.data)` ->
`_doPreExecHooks`) and then runs `_exec(target, value, data)` where `data` is the ABI-DECODED
calldata param, i.e. Solidity FOLLOWS the offset pointer at [68:100]. A non-canonical `data`
offset therefore makes the hook validate one (benign) inner selector while the account executes
a different (malicious) inner call => ProposalManager (the anti-theft delay) is never consulted
for the real withdraw. Actor = account owner (execute is owner-validated); this defeats the
delay that exists specifically to contain a compromised passkey.

## What this PoC proves
The novel/doubtful core — that Solidity's calldata decoder accepts a NON-CANONICAL (non-minimal)
offset for a single `bytes` parameter, diverging from a fixed-offset reader — compiled with the
real solc 0.8.26 and executed on a JS EVM. Diff.sol mirrors both parsers in one `execute`.

## Run
    npm install solc@0.8.26 @ethereumjs/evm @ethereumjs/util ethereum-cryptography
    node run.mjs

## Result (observed)
    CANONICAL (offset 0x60):      hook=aaaaaaaa  body=aaaaaaaa   (agree)
    NON-CANONICAL (offset 0xA0):  hook=aaaaaaaa  body=deadbeef   (DIVERGE)

The remaining links are confirmed by source reading, not simulated here:
1. account passes raw msg.data to the hook (UpgradeableModularAccount `_preNativeFunction`);
2. `_exec` calls `target.call(decoded data)` (AccountExecutor._exec);
3. ProposalManager._preExecutionMarketCheck returns (allows) for an unrecognized selector.

A full end-to-end fork PoC (real account+plugin+market showing a delay-free drain) needs
Foundry + an OP fork; foundry.paradigm.xyz is blocked by this environment's egress policy.
