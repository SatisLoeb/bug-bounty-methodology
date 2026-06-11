// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Oracle Manipulation PoC
/// @notice Demonstrates price manipulation via flash loan or direct pool manipulation
contract OracleManipulation is Test {
    // TODO: declare protocol, oracle, pool

    address attacker = makeAddr("attacker");

    function setUp() public {
        // Fork mainnet at specific block
        // vm.createSelectFork("mainnet", BLOCK_NUMBER);
        // Fund attacker with flash loan capital
        // deal(address(token), attacker, LARGE_AMOUNT);
    }

    function testOracleManipulation() public {
        // Step 1: Record pre-manipulation price
        // uint256 priceBefore = oracle.getPrice(asset);
        // console.log("Price before:", priceBefore);

        vm.startPrank(attacker);

        // Step 2: Manipulate the price source (AMM pool, TWAP, spot)
        // router.swapExactTokensForTokens(LARGE_AMOUNT, 0, path, attacker, block.timestamp);

        // Step 3: Record manipulated price
        // uint256 priceAfter = oracle.getPrice(asset);
        // console.log("Price after:", priceAfter);
        // assertGt(priceAfter, priceBefore * 2, "Price should be >2x manipulated");

        // Step 4: Exploit the manipulated price
        // protocol.borrow(EXPLOIT_AMOUNT); // Borrow at inflated collateral value
        // OR: protocol.liquidate(victimPosition); // Liquidate at wrong price

        // Step 5: Reverse the manipulation (optional, for profit calc)
        // router.swapExactTokensForTokens(received, 0, reversePath, attacker, block.timestamp);

        vm.stopPrank();

        // Step 6: Calculate profit
        // int256 profit = int256(attacker.balance) - int256(INITIAL_CAPITAL);
        // console.log("Profit:", profit);
        // assertGt(profit, 0, "Attack should be profitable");
    }
}
