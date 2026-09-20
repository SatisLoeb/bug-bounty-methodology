// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import { Timelock } from "src/timelock/Timelock.sol";

// Target that re-enters the Timelock during execution.
contract ReentrantTarget {
    Timelock public timelock;
    bytes public reenterCall; // encoded call to perform on the timelock mid-execution
    bool public armed;
    bool public swallow; // true = swallow the inner revert (test partial-reentry outcomes)
    bytes public lastInnerRevert;

    constructor(Timelock t) { timelock = t; }
    function arm(bytes calldata call_, bool swallow_) external { reenterCall = call_; armed = true; swallow = swallow_; }

    function poke() external {
        if (armed) {
            armed = false; // single reentry
            (bool ok, bytes memory ret) = address(timelock).call(reenterCall);
            if (!ok) {
                lastInnerRevert = ret;
                if (!swallow) { assembly { revert(add(ret, 0x20), mload(ret)) } }
            }
        }
    }
}

// Invariant handler: random schedule/cancel/execute/warp sequences.
contract TimelockHandler is Test {
    Timelock public timelock;
    address public proposer;
    bytes32[] public scheduled; // unique ids ever scheduled (may be executed/cancelled)
    mapping(bytes32 => bool) internal tracked;

    constructor(Timelock t, address proposer_) { timelock = t; proposer = proposer_; }

    function _op(uint256 seed) internal view returns (address[] memory t_, uint256[] memory v, bytes[] memory p, bytes32 salt) {
        t_ = new address[](1); v = new uint256[](1); p = new bytes[](1);
        t_[0] = address(0xdead); v[0] = 0; p[0] = abi.encodePacked(bytes4(0x12345678), seed % 16); // 16 distinct ops
        salt = bytes32(seed % 16);
    }

    function schedule(uint256 seed) public {
        (address[] memory t_, uint256[] memory v, bytes[] memory p, bytes32 salt) = _op(seed);
        bytes32 id = timelock.hashOperationBatch(t_, v, p, bytes32(0), salt);
        vm.prank(proposer);
        try timelock.scheduleBatch(t_, v, p, bytes32(0), salt, 1 days) {
            if (!tracked[id]) { tracked[id] = true; scheduled.push(id); }
        } catch {}
    }

    function cancelOp(uint256 seed) public {
        (address[] memory t_, uint256[] memory v, bytes[] memory p, bytes32 salt) = _op(seed);
        bytes32 id = timelock.hashOperationBatch(t_, v, p, bytes32(0), salt);
        vm.prank(proposer); // proposer is also canceller in this setup
        try timelock.cancel(id) {} catch {}
    }

    function executeOp(uint256 seed) public {
        (address[] memory t_, uint256[] memory v, bytes[] memory p, bytes32 salt) = _op(seed);
        try timelock.executeBatch(t_, v, p, bytes32(0), salt) {} catch {}
    }

    function warp(uint256 seed) public { vm.warp(block.timestamp + (seed % 3 days)); }

    function scheduledCount() external view returns (uint256) { return scheduled.length; }
    function scheduledAt(uint256 i) external view returns (bytes32) { return scheduled[i]; }
}

contract AdversarialTimelockTest is Test {
    Timelock timelock;
    ReentrantTarget target;
    TimelockHandler handler;
    address admin = address(0xA11CE);
    address proposer = address(0xB0B);

    function setUp() public {
        vm.warp(30 days);
        vm.prank(admin);
        timelock = new Timelock(1 days, admin);
        vm.startPrank(admin);
        timelock.grantRole(timelock.PROPOSER_ROLE(), proposer);
        timelock.grantRole(timelock.CANCELLER_ROLE(), proposer);
        vm.stopPrank();
        target = new ReentrantTarget(timelock);

        handler = new TimelockHandler(timelock, proposer);
        targetContract(address(handler));
    }

    function _schedule(bytes memory payload, bytes32 salt) internal returns (
        bytes32 id, address[] memory t_, uint256[] memory v, bytes[] memory p
    ) {
        t_ = new address[](1); v = new uint256[](1); p = new bytes[](1);
        t_[0] = address(target); v[0] = 0; p[0] = payload;
        id = timelock.hashOperationBatch(t_, v, p, bytes32(0), salt);
        vm.prank(proposer);
        timelock.scheduleBatch(t_, v, p, bytes32(0), salt, 1 days);
    }

    // Reentering executeBatch(A) during A's own execution must revert the WHOLE tx (no double-exec).
    function test_reenter_same_op_execution_reverts() public {
        (bytes32 id, address[] memory t_, uint256[] memory v, bytes[] memory p) =
            _schedule(abi.encodeCall(ReentrantTarget.poke, ()), "A");
        target.arm(abi.encodeCall(Timelock.executeBatch, (t_, v, p, bytes32(0), bytes32("A"))), false);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(); // outer _afterCall sees Done -> TimelockUnexpectedOperationState
        timelock.executeBatch(t_, v, p, bytes32(0), "A");
        assertTrue(timelock.isOperationReady(id), "op must remain Ready after failed double-exec");
        assertTrue(timelock.getOperationExists(id), "tracking list must still contain the op");
    }

    // Same, but the target swallows the inner result: inner exec re-runs the calls and sets Done,
    // then the OUTER _afterCall must still revert -> full unwind, op stays Ready + tracked.
    function test_reenter_same_op_swallowed_still_reverts_outer() public {
        (bytes32 id, address[] memory t_, uint256[] memory v, bytes[] memory p) =
            _schedule(abi.encodeCall(ReentrantTarget.poke, ()), "B");
        target.arm(abi.encodeCall(Timelock.executeBatch, (t_, v, p, bytes32(0), bytes32("B"))), true);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert();
        timelock.executeBatch(t_, v, p, bytes32(0), "B");
        assertTrue(timelock.isOperationReady(id), "swallowed reentry must not leave op half-executed");
        assertTrue(timelock.getOperationExists(id), "list intact");
    }

    // Cancel(A) re-entered during execute(A) (target holds CANCELLER): outer must revert, state consistent.
    function test_reenter_cancel_during_execute_reverts() public {
        bytes32 cancellerRole = timelock.CANCELLER_ROLE();
        vm.prank(admin);
        timelock.grantRole(cancellerRole, address(target));
        (bytes32 id, address[] memory t_, uint256[] memory v, bytes[] memory p) =
            _schedule(abi.encodeCall(ReentrantTarget.poke, ()), "C");
        target.arm(abi.encodeCall(Timelock.cancel, (id)), true);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert();
        timelock.executeBatch(t_, v, p, bytes32(0), "C");
        assertTrue(timelock.isOperationReady(id), "cancel-in-execute must fully unwind");
        assertTrue(timelock.getOperationExists(id), "list intact");
    }

    // schedule -> cancel -> re-schedule same id -> execute: list and OZ state stay mirrored throughout.
    function test_cancel_reschedule_execute_cycle() public {
        (bytes32 id, address[] memory t_, uint256[] memory v, bytes[] memory p) =
            _schedule(abi.encodeCall(ReentrantTarget.poke, ()), "D");
        vm.prank(proposer); timelock.cancel(id);
        assertFalse(timelock.getOperationExists(id));
        assertEq(timelock.getOperationsCount(), 0);
        vm.prank(proposer);
        timelock.scheduleBatch(t_, v, p, bytes32(0), "D", 1 days);
        assertTrue(timelock.getOperationExists(id));
        vm.warp(block.timestamp + 1 days);
        timelock.executeBatch(t_, v, p, bytes32(0), "D");
        assertTrue(timelock.isOperationDone(id));
        assertFalse(timelock.getOperationExists(id));
        assertEq(timelock.getOperationsCount(), 0);
    }

    // INVARIANT: for every id ever scheduled, list membership <=> OZ state is Pending/Ready (not Unset/Done),
    // and stored Operation payload presence matches membership.
    function invariant_list_mirrors_oz_state() public view {
        uint256 n = handler.scheduledCount();
        uint256 live;
        for (uint256 i; i < n; ++i) {
            bytes32 id = handler.scheduledAt(i);
            bool inList = timelock.getOperationExists(id);
            bool pending = timelock.isOperationPending(id); // Waiting|Ready
            assertEq(inList, pending, "list <=> pending mirror broken");
            assertEq(timelock.getOperationLength(id) > 0, inList, "stored payload <=> membership broken");
            if (inList) live++;
        }
        assertEq(timelock.getOperationsCount(), live, "count mismatch");
    }
}
