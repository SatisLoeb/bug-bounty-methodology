// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Deliberately vulnerable fixture for NUKE self-test. DO NOT DEPLOY.
///  Seeds one High (controlled delegatecall), reentrancy-eth, tx.origin auth,
///  and unchecked low-level call — so each scanner has something to bite on.
contract VulnBank {
    mapping(address => uint256) public balances;
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // reentrancy-eth: external call BEFORE the state update.
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "insufficient");
        (bool ok, ) = msg.sender.call{value: amount}(""); // low-level call, return unchecked
        balances[msg.sender] -= amount; // effect after interaction
    }

    // tx.origin used for authorization.
    function adminSweep(address payable to) external {
        require(tx.origin == owner, "not owner");
        to.transfer(address(this).balance);
    }

    // controlled delegatecall to arbitrary target with arbitrary data (High).
    function proxyCall(address target, bytes calldata data) external {
        target.delegatecall(data); // unchecked return + attacker-controlled target
    }
}
