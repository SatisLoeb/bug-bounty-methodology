// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.26;

// Mirrors the ExaPlugin pre-exec-hook vs account-body calldata parsing.
// Returns (hookSelector, bodySelector). If they differ for the same call,
// the fixed-offset hook can be fooled while the body executes something else.
contract Diff {
  // Same signature the account's execute has; `data` is the inner call.
  function execute(address target, uint256 value, bytes calldata data)
    external view returns (bytes4 hookSelector, bytes4 bodySelector)
  {
    // (a) HOOK view: exactly ExaPlugin.preExecutionHook SINGLE fixed offsets.
    //     callData here == msg.data of this execute() call.
    hookSelector = bytes4(msg.data[132:136]);
    // (b) BODY view: the normally-decoded `data` calldata param.
    bodySelector = bytes4(data[0:4]);
    target; value;
  }
}
