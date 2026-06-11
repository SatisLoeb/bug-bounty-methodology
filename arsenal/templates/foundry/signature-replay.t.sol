// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Signature Replay / Cross-Chain Replay PoC
/// @notice Demonstrates reuse of a valid signature in unauthorized context
contract SignatureReplay is Test {
    // TODO: declare target

    uint256 signerPk = 0xA11CE; // test private key
    address signer = vm.addr(signerPk);

    function setUp() public {
        // TODO: deploy or fork
        // Register signer as authorized
    }

    function testReplayOnDifferentChain() public {
        // Step 1: Create valid signature on chain A
        bytes32 digest = keccak256(abi.encodePacked(
            // TODO: match the protocol's signing domain
            // "\x19\x01", domainSeparator, structHash
        ));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);

        // Step 2: Use the same signature on chain B (different chainId)
        // vm.chainId(OTHER_CHAIN_ID);
        // bool success = target.executeWithSignature(params, v, r, s);
        // assertTrue(success, "VULN: signature replayed cross-chain");
    }

    function testReplayAfterNonceConsumption() public {
        // Step 1: Create and use valid signature
        // target.execute(params, signature); // nonce consumed

        // Step 2: Replay the same signature
        // vm.expectRevert(); // SHOULD revert
        // target.execute(params, signature); // VULN if this succeeds
    }

    function testReplayOnDifferentContract() public {
        // Step 1: Sign for contract A
        // Step 2: Submit to contract B with same interface
        // VULN if contract address is not in the signed digest
    }
}
