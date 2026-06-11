// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Cross-Contract Reentrancy PoC
/// @notice Exploits state inconsistency between two contracts during external call
contract ReentrancyExploit is Test {
    // TODO: declare target contracts
    // TargetA targetA;
    // TargetB targetB;
    AttackerContract exploiter;

    address attacker = makeAddr("attacker");

    function setUp() public {
        // TODO: deploy or fork
        exploiter = new AttackerContract(/* targetA, targetB */);
        // Fund exploiter
        // deal(address(token), address(exploiter), INITIAL_AMOUNT);
    }

    function testReentrancyDrain() public {
        // uint256 balanceBefore = token.balanceOf(address(targetA));

        vm.prank(attacker);
        exploiter.exploit();

        // uint256 balanceAfter = token.balanceOf(address(targetA));
        // assertLt(balanceAfter, balanceBefore, "VULN: funds drained via reentrancy");
        // console.log("Drained:", balanceBefore - balanceAfter);
    }
}

contract AttackerContract {
    // TODO: store references to targets
    uint256 public reentrancyCount;

    constructor(/* address _targetA, address _targetB */) {
        // TODO: store targets
    }

    function exploit() external {
        // TODO: trigger the vulnerable operation
        // targetA.withdraw(amount);
        // During the ETH transfer callback, re-enter targetB
    }

    receive() external payable {
        reentrancyCount++;
        if (reentrancyCount < 5) {
            // TODO: re-enter during callback
            // targetB.borrow(amount);
        }
    }
}
