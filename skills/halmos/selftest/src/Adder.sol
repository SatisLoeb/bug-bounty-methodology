// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice NUKE/Halmos self-test fixture. DO NOT DEPLOY.
contract Adder {
    function add(uint256 a, uint256 b) external pure returns (uint256) { return a + b; }
    function badMax(uint256 a, uint256 b) external pure returns (uint256) { return a; } // BUG: ignores b
    function mustRevert(uint256) external pure returns (uint256) { revert("always"); }
}
