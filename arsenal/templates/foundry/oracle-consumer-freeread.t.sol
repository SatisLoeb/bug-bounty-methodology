// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

/// @title Oracle CONSUMER free-read probe (the LANDING harness)
/// @notice The cost-free oracle class: the price is ALREADY wrong (stale / zero / negative /
///         minAnswer-clamped / wrong-decimals / sequencer-down) and the attacker only READS it —
///         no price pushed, no fork of a DEX, no P&L. This probe does NOT test the oracle wrapper's
///         own isStale() (the wrong layer, and the mistake in the old DepOracleFuzz). It mocks the
///         feed to each pathological tuple and asserts the CONSUMER entrypoint (borrow/mint/liquidate)
///         REJECTS it. A test that FAILS = the consumer swallowed a bad value = the finding.
/// @dev    Wire IPriceConsumer + the setter path to the real target, then run:
///         forge test --match-contract OracleConsumerFreeRead -vvv
///         Severity: usually MEDIUM (volume play); HIGH/Crit only when the swallowed value feeds a
///         mint/borrow/liquidation/quorum directly. See feedback-oracle-replay-refute-first-reflex-fix.

// --- Chainlink AggregatorV3 shape (the feed the consumer reads) ---
interface IAggregatorV3 {
    function decimals() external view returns (uint8);
    function latestRoundData()
        external view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

/// @notice Settable mock feed + an aggregator-level min/max clamp (the LUNA / Venus circuit-breaker).
contract MockChainlinkFeed is IAggregatorV3 {
    uint8  public dec = 8;
    int256 public answer = 2000e8;
    uint256 public updatedAt;
    uint80 public roundId = 1;
    uint80 public answeredInRound = 1;
    int192 public minAnswer = 1e8;      // circuit-breaker floor
    int192 public maxAnswer = 1_000_000e8;

    constructor() { updatedAt = block.timestamp; }
    function decimals() external view returns (uint8) { return dec; }
    function setDecimals(uint8 d) external { dec = d; }
    function set(int256 a, uint256 u) external { answer = a; updatedAt = u; }
    function setRound(uint80 rid, uint80 air) external { roundId = rid; answeredInRound = air; }
    function clampFloor() external { answer = int256(minAnswer); } // feed pinned to floor during a crash
    function latestRoundData()
        external view
        returns (uint80, int256, uint256, uint256, uint80)
    { return (roundId, answer, updatedAt, updatedAt, answeredInRound); }
}

/// @notice L2 sequencer-uptime feed (Arbitrum/Optimism). answer==1 => sequencer DOWN.
contract MockSequencerFeed is IAggregatorV3 {
    int256 public status = 0;      // 0 = up, 1 = down
    uint256 public startedAt;      // last status change
    constructor() { startedAt = block.timestamp; }
    function setDown() external { status = 1; startedAt = block.timestamp; }
    function decimals() external pure returns (uint8) { return 0; }
    function latestRoundData()
        external view
        returns (uint80, int256, uint256, uint256, uint80)
    { return (1, status, startedAt, startedAt, 1); }
}

/// @notice The target under test. Wire this to the real consumer's price-reading action.
interface IPriceConsumer {
    /// @dev the entrypoint that READS the price and acts on it (borrow / mint / liquidate / value()).
    ///      MUST revert on a bad feed tuple; if it returns a usable number, that is the bug.
    function actionThatReadsPrice() external returns (uint256 pxOrValue);
}

contract OracleConsumerFreeRead is Test {
    MockChainlinkFeed feed;
    MockSequencerFeed seq;
    IPriceConsumer consumer;

    uint256 constant HEARTBEAT = 1 hours; // the consumer's assumed max staleness

    function setUp() public virtual {
        feed = new MockChainlinkFeed();
        seq  = new MockSequencerFeed();
        // TODO: deploy the real consumer wired to `feed` (and `seq` on L2), e.g.:
        // consumer = IPriceConsumer(address(new TargetConsumer(address(feed), address(seq))));
    }

    /// @dev sanity: with a healthy feed the consumer MUST succeed (proves the harness is wired right).
    function test_baseline_healthyFeed_ok() public {
        if (address(consumer) == address(0)) { emit log("wire IPriceConsumer in setUp()"); return; }
        feed.set(2000e8, block.timestamp);
        uint256 v = consumer.actionThatReadsPrice();
        assertGt(v, 0, "healthy feed should produce a usable value");
    }

    /// @dev THE LANDING INVARIANT: for every pathological tuple, the consumer must REVERT.
    ///      A green run = safe. A failing run names the exact free-read class the consumer swallows.
    function testFuzz_consumerRejectsBadFeed(uint8 which, int256 a, uint256 skew, uint8 d) public {
        if (address(consumer) == address(0)) return; // no-op until wired
        which = uint8(bound(which, 0, 5));

        if (which == 0) {                                  // STALENESS: updatedAt older than heartbeat
            skew = bound(skew, HEARTBEAT + 1, 30 days);
            vm.warp(block.timestamp + skew);               // now - updatedAt > heartbeat
        } else if (which == 1) {                           // ZERO / NEGATIVE answer
            feed.set(int256(bound(a, type(int256).min, 0)), block.timestamp);
        } else if (which == 2) {                           // minAnswer CLAMP floor (LUNA/Venus)
            feed.clampFloor();
        } else if (which == 3) {                           // WRONG DECIMALS (feed 18 vs assumed 8, etc.)
            feed.setDecimals(uint8(bound(d, 0, 27)));
            feed.set(2000 * int256(10) ** feed.decimals(), block.timestamp);
        } else if (which == 4) {                           // ROUND INCOMPLETE (answeredInRound < roundId)
            feed.setRound(5, 4);
        } else {                                           // L2 SEQUENCER DOWN (+ grace period)
            seq.setDown();
        }

        try consumer.actionThatReadsPrice() returns (uint256 v) {
            // Did not revert -> the consumer accepted a wrong price. That IS the finding.
            emit log_named_uint("VULN: consumer swallowed bad feed class", which);
            emit log_named_uint("  returned value", v);
            assertTrue(false, "consumer must reject a bad feed tuple, not swallow it");
        } catch { /* GOOD: consumer rejected the bad tuple */ }
    }
}
