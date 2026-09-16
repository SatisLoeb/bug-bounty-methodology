// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SymTest} from "halmos-cheatcodes/SymTest.sol";
import {Test} from "forge-std/Test.sol";
import {Adder} from "../src/Adder.sol";

// Four canonical outcomes NUKE/Halmos must classify correctly.
contract AdderSymTest is SymTest, Test {
    Adder t;
    function setUp() public { t = new Adder(); }

    // (1) PROVEN — invariant holds on every non-reverting path
    function check_add_commutative(uint256 a, uint256 b) public view {
        assert(t.add(a, b) == t.add(b, a));
    }

    // (2) COUNTEREXAMPLE — badMax ignores b, so it breaks when b > a
    function check_badMax(uint256 a, uint256 b) public view {
        uint256 m = t.badMax(a, b);
        assert(m >= a && m >= b);
    }

    // (3) VACUOUS — contradictory assumptions kill every path (false green)
    function check_vacuous_assume(uint256 a) public view {
        vm.assume(a > 5);
        vm.assume(a < 3);
        assert(t.add(a, a) == 999);
    }

    // (4) VACUOUS — the call always reverts, so assert(false) is never reached (revert-ignore trap)
    function check_vacuous_revert(uint256 a) public {
        t.mustRevert(a);
        assert(false);
    }

    // (5) PASSES normally but the assertion sits in a never-true branch: PARTIAL vacuity.
    //     Halmos reports PASS; only the --canary reachability probe exposes it as a false green.
    function check_partial_vacuous(uint256 a) public view {
        if (a != a) {                       // never true
            assert(t.add(a, 1) == 0);       // assertion site is unreachable
        }
    }
}
