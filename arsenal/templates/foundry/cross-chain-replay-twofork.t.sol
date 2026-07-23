// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Two-fork / capture-and-replay probe (the LANDING harness for V05)
/// @notice Converts the reasoned "domains can't collide / signature is single-use" verdict into an
///         EXECUTED artifact. The First Maxim: the PRESENCE of a nonce/chainId field is not the
///         nullifier — only a captured signature that REJECTS on the sibling deployment / second
///         submission is. Three cost-free replay sub-classes, each demonstrated on a self-contained
///         mock so this file runs as-is; wire ITarget to a real target to reproduce against it:
///           1. cross-chain shared-domain (EIP-712 sansChainId, same factory address) — OKX shape
///           2. off-chain reusable-signature (no on-chain nonce consumed)          — Jupiter shape
///           3. EIP-712 field-omission (a fee/refund/target field not in the digest) — Biconomy shape
///         forge test --match-contract CrossChainReplayTwoFork -vvv
///         See feedback-oracle-replay-refute-first-reflex-fix.

/// @notice Reference wallet reproducing all three defects. Replace with the real target in practice.
///  - DOMAIN_SEPARATOR omits chainId AND is not bound to address(this) -> portable across chains/instances
///  - execute() does NOT consume op.nonce on-chain -> the signature is reusable
///  - `feeBps` is used but NOT part of the signed struct -> attacker sets it freely (field-omission)
contract MockChainlessWallet {
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version)");
    bytes32 public constant OP_TYPEHASH     = keccak256("Op(address to,uint256 amount,uint256 nonce)");
    bytes32 public immutable DOMAIN_SEPARATOR; // cached, sansChainId
    address public owner;
    uint256 public executed;

    constructor(address _owner) {
        owner = _owner;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            DOMAIN_TYPEHASH, keccak256("ChainlessWallet"), keccak256("1")
        )); // NOTE: block.chainid intentionally absent — the bug
    }

    function digest(address to, uint256 amount, uint256 nonce) public view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(OP_TYPEHASH, to, amount, nonce));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    /// @dev feeBps is NOT hashed; nonce is NOT consumed. Both are the defects to expose.
    function execute(address to, uint256 amount, uint256 nonce, uint256 feeBps, bytes calldata sig)
        external returns (bool)
    {
        bytes32 d = digest(to, amount, nonce);
        (bytes32 r, bytes32 s, uint8 v) = _split(sig);
        require(ecrecover(d, v, r, s) == owner, "bad sig");
        // ... would move `amount` to `to`, taking feeBps as an unsigned fee ...
        executed++;
        return true;
    }

    function _split(bytes calldata sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "len");
        r = bytes32(sig[0:32]); s = bytes32(sig[32:64]); v = uint8(sig[64]);
    }
}

interface ITarget {
    function digest(address to, uint256 amount, uint256 nonce) external view returns (bytes32);
    function execute(address to, uint256 amount, uint256 nonce, uint256 feeBps, bytes calldata sig)
        external returns (bool);
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

contract CrossChainReplayTwoFork is Test {
    uint256 ownerPk = 0xA11CE;
    address owner   = vm.addr(0xA11CE);

    function _sign(ITarget t, address to, uint256 amount, uint256 nonce) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPk, t.digest(to, amount, nonce));
        return abi.encodePacked(r, s, v);
    }

    /// SUB-CLASS 1: cross-chain shared-domain. Capture a sig valid on fork A, replay on fork B.
    /// A green pass here is the FINDING (sig accepted on the sibling deployment).
    function test_crossChain_sharedDomain_replays() public {
        // "fork A" (e.g. chainId 1) — same owner, same factory-derived deploy params on both chains
        vm.chainId(1);
        ITarget a = ITarget(address(new MockChainlessWallet(owner)));
        // "fork B" (e.g. chainId 10) — a real two-fork harness uses vm.createSelectFork per chain;
        // here two instances with the same cached sansChainId separator model the same-address deploy.
        vm.chainId(10);
        ITarget b = ITarget(address(new MockChainlessWallet(owner)));

        // The load-bearing check the operator kept reasoning instead of executing:
        assertEq(a.DOMAIN_SEPARATOR(), b.DOMAIN_SEPARATOR(),
            "domains DIFFER -> no cross-chain replay (this is the SAFE case)");

        bytes memory sig = _sign(a, address(0xBEEF), 1 ether, 0);
        vm.chainId(1); assertTrue(a.execute(address(0xBEEF), 1 ether, 0, 0, sig), "valid on A");
        vm.chainId(10);
        bool accepted = b.execute(address(0xBEEF), 1 ether, 0, 0, sig);
        assertFalse(accepted, "VULN: signature captured on chain A REPLAYED on chain B (sansChainId)");
    }

    /// SUB-CLASS 2: off-chain reusable-signature (no on-chain nonce consumed). Same sig submitted twice.
    /// A README "signs per-tx" claim does NOT close this — only a failed second submission does.
    function test_offChain_reusable_noNonceConsumed() public {
        ITarget t = ITarget(address(new MockChainlessWallet(owner)));
        bytes memory sig = _sign(t, address(0xBEEF), 1 ether, 0);
        assertTrue(t.execute(address(0xBEEF), 1 ether, 0, 0, sig), "first use");
        // If the sink consumed a nonce/marked the hash, this reverts. If it swallows -> replay.
        bool second = t.execute(address(0xBEEF), 1 ether, 0, 0, sig);
        assertFalse(second, "VULN: no on-chain nonce consumed -> signature replayable");
    }

    /// SUB-CLASS 3: EIP-712 field-omission. The signed struct omits `feeBps`; attacker sets it freely.
    function test_fieldOmission_unsignedParam() public {
        ITarget t = ITarget(address(new MockChainlessWallet(owner)));
        bytes memory sig = _sign(t, address(0xBEEF), 1 ether, 0);
        // Same signature accepts BOTH feeBps=0 and feeBps=10000 because feeBps is not in the digest.
        t.execute(address(0xBEEF), 1 ether, 0, 0, sig);
        bool manipulated = t.execute(address(0xBEEF), 1 ether, 0, 10_000, sig);
        assertFalse(manipulated, "VULN: feeBps not in the signed digest -> attacker manipulates it");
    }
}
