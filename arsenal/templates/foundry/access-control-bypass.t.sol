// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Access Control Bypass PoC
/// @notice Demonstrates unauthorized access to privileged function
contract AccessControlBypass is Test {
    // TODO: import and declare target contract

    address admin = makeAddr("admin");
    address attacker = makeAddr("attacker");

    function setUp() public {
        // TODO: deploy or fork
        // vm.createSelectFork("mainnet", BLOCK_NUMBER);
    }

    function testBypassAsNonAdmin() public {
        vm.startPrank(attacker);

        // TODO: call the privileged function as attacker
        // target.privilegedFunction(maliciousParams);

        // Verify the action succeeded (should have been blocked)
        // assertEq(target.state(), attackerControlledValue, "VULN: attacker modified state");

        vm.stopPrank();
    }

    function testControlAdminSucceeds() public {
        vm.startPrank(admin);
        // TODO: same function call succeeds as admin (baseline)
        vm.stopPrank();
    }

    function testControlNonAdminReverts() public {
        vm.startPrank(attacker);
        // TODO: a DIFFERENT privileged function correctly reverts
        // vm.expectRevert();
        // target.otherPrivilegedFunction();
        vm.stopPrank();
    }
}
