// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Bridge Message Replay / Forgery PoC
/// @notice Demonstrates cross-chain message manipulation
contract BridgeMessageReplay is Test {
    // TODO: declare bridge, endpoint, DVN contracts

    address attacker = makeAddr("attacker");

    function setUp() public {
        // vm.createSelectFork("mainnet", BLOCK_NUMBER);
    }

    function testMessageReplayFromDifferentChain() public {
        // Step 1: Capture a valid cross-chain message
        // bytes memory validMessage = abi.encode(srcChainId, sender, nonce, payload);
        // bytes memory validProof = ...; // DVN attestation

        // Step 2: Replay on the same chain with different context
        // bridge.receiveMessage(validMessage, validProof);
        // VULN if nonce/chainId not validated

        vm.startPrank(attacker);
        // Step 3: Forge a message with attacker-controlled payload
        // bytes memory forgedMessage = abi.encode(srcChainId, attacker, nonce, maliciousPayload);
        // VULN if sender is not validated against the proof
        vm.stopPrank();
    }

    function testDuplicateVerificationInQuorum() public {
        // Step 1: Submit same DVN verification twice
        // dvn.verify(messageHash, dvnSignature);
        // dvn.verify(messageHash, dvnSignature); // same sig, same DVN
        // VULN if quorum counts both as separate verifications
    }

    function testSourceChainSenderValidation() public {
        // Rule #23: validate BOTH source chain AND sender address
        vm.startPrank(attacker);
        // bridge.receiveMessage(
        //   validChainId,    // correct source chain
        //   attackerAddress, // WRONG sender (should be the authorized OApp)
        //   payload
        // );
        // VULN if only chainId is checked, not sender
        vm.stopPrank();
    }
}
