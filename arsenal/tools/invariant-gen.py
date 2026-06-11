#!/usr/bin/env python3
"""
invariant-gen.py — Automated Invariant Generator for Foundry Fuzzing

Reads a Solidity codebase and proposes fuzz-testable invariants based on:
- ERC standard compliance (ERC20, ERC4626, ERC721)
- Code comments ("must", "always", "never", "invariant")
- Function pairs (deposit/withdraw, mint/burn, stake/unstake)
- Monotonicity patterns (totalSupply, accumulators)

Usage:
    python3 invariant-gen.py <target_dir> [--output invariants.t.sol]
"""

import sys
import re
from pathlib import Path
from collections import defaultdict


# Known invariants per ERC standard
ERC4626_INVARIANTS = [
    {
        "name": "depositRedeemRoundtrip",
        "description": "deposit then redeem should not create profit",
        "code": '''
    function testFuzz_depositRedeemNoProfit(uint256 assets) public {
        assets = bound(assets, 1e6, 1e24);
        deal(address(asset), address(this), assets);
        asset.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, address(this));
        uint256 redeemed = vault.redeem(shares, address(this), address(this));
        assertLe(redeemed, assets, "INVARIANT VIOLATED: deposit+redeem created profit");
    }'''
    },
    {
        "name": "mintWithdrawRoundtrip",
        "description": "mint then withdraw should not create profit",
        "code": '''
    function testFuzz_mintWithdrawNoProfit(uint256 shares) public {
        shares = bound(shares, 1, 1e24);
        uint256 assetsNeeded = vault.previewMint(shares);
        deal(address(asset), address(this), assetsNeeded);
        asset.approve(address(vault), assetsNeeded);
        vault.mint(shares, address(this));
        uint256 withdrawn = vault.withdraw(vault.maxWithdraw(address(this)), address(this), address(this));
        assertLe(withdrawn, assetsNeeded, "INVARIANT VIOLATED: mint+withdraw created profit");
    }'''
    },
    {
        "name": "previewDepositConsistency",
        "description": "previewDeposit must return <= actual shares from deposit",
        "code": '''
    function testFuzz_previewDepositNotOverestimate(uint256 assets) public {
        assets = bound(assets, 1e6, 1e24);
        uint256 preview = vault.previewDeposit(assets);
        deal(address(asset), address(this), assets);
        asset.approve(address(vault), assets);
        uint256 actual = vault.deposit(assets, address(this));
        assertGe(actual, preview, "INVARIANT VIOLATED: previewDeposit overestimates");
    }'''
    },
    {
        "name": "previewWithdrawConsistency",
        "description": "previewWithdraw must return >= actual shares burned",
        "code": '''
    function testFuzz_previewWithdrawNotUnderestimate(uint256 assets) public {
        assets = bound(assets, 1, vault.maxWithdraw(address(this)));
        vm.assume(assets > 0);
        uint256 preview = vault.previewWithdraw(assets);
        uint256 actual = vault.withdraw(assets, address(this), address(this));
        assertLe(actual, preview, "INVARIANT VIOLATED: previewWithdraw underestimates shares");
    }'''
    },
    {
        "name": "totalAssetsGeDeposits",
        "description": "totalAssets should never decrease without withdrawals",
        "code": '''
    function testFuzz_totalAssetsNonDecreasingOnDeposit(uint256 assets) public {
        assets = bound(assets, 1e6, 1e24);
        uint256 totalBefore = vault.totalAssets();
        deal(address(asset), address(this), assets);
        asset.approve(address(vault), assets);
        vault.deposit(assets, address(this));
        uint256 totalAfter = vault.totalAssets();
        assertGe(totalAfter, totalBefore, "INVARIANT VIOLATED: totalAssets decreased on deposit");
    }'''
    },
    {
        "name": "sharePriceMonotonic",
        "description": "share price should not decrease from deposits alone",
        "code": '''
    function testFuzz_sharePriceNonDecreasingOnDeposit(uint256 assets) public {
        assets = bound(assets, 1e6, 1e24);
        uint256 priceBefore = vault.totalSupply() > 0
            ? (vault.totalAssets() * 1e18) / vault.totalSupply()
            : 1e18;
        deal(address(asset), address(this), assets);
        asset.approve(address(vault), assets);
        vault.deposit(assets, address(this));
        uint256 priceAfter = vault.totalSupply() > 0
            ? (vault.totalAssets() * 1e18) / vault.totalSupply()
            : 1e18;
        assertGe(priceAfter, priceBefore - 1, "INVARIANT VIOLATED: share price decreased on deposit");
    }'''
    },
]

ERC20_INVARIANTS = [
    {
        "name": "transferConservation",
        "description": "transfer should not create or destroy tokens",
        "code": '''
    function testFuzz_transferConservation(address to, uint256 amount) public {
        vm.assume(to != address(0) && to != address(this));
        amount = bound(amount, 0, token.balanceOf(address(this)));
        uint256 totalBefore = token.balanceOf(address(this)) + token.balanceOf(to);
        token.transfer(to, amount);
        uint256 totalAfter = token.balanceOf(address(this)) + token.balanceOf(to);
        assertEq(totalAfter, totalBefore, "INVARIANT VIOLATED: transfer changed total supply");
    }'''
    },
    {
        "name": "approveSpendConsistency",
        "description": "transferFrom should not exceed allowance",
        "code": '''
    function testFuzz_transferFromRespectsAllowance(address spender, uint256 amount) public {
        vm.assume(spender != address(0));
        amount = bound(amount, 1, token.balanceOf(address(this)));
        token.approve(spender, amount);
        vm.prank(spender);
        token.transferFrom(address(this), spender, amount);
        // Should not revert — amount == allowance
    }'''
    },
]

LENDING_INVARIANTS = [
    {
        "name": "borrowRepayRoundtrip",
        "description": "borrow then repay should leave user with <= original debt",
        "code": '''
    function testFuzz_borrowRepayNoFreeDebt(uint256 borrowAmount) public {
        // TODO: setup collateral first
        borrowAmount = bound(borrowAmount, 1e6, maxBorrowable);
        uint256 debtBefore = pool.getDebt(address(this));
        pool.borrow(borrowAmount);
        pool.repay(borrowAmount);
        uint256 debtAfter = pool.getDebt(address(this));
        assertGe(debtAfter, debtBefore, "INVARIANT VIOLATED: borrow+repay reduced debt (free money)");
    }'''
    },
    {
        "name": "liquidationReducesDebt",
        "description": "liquidation must reduce the borrower's debt",
        "code": '''
    function testFuzz_liquidationReducesDebt(uint256 repayAmount) public {
        // TODO: setup unhealthy position first
        uint256 debtBefore = pool.getDebt(borrower);
        pool.liquidate(borrower, repayAmount);
        uint256 debtAfter = pool.getDebt(borrower);
        assertLt(debtAfter, debtBefore, "INVARIANT VIOLATED: liquidation did not reduce debt");
    }'''
    },
]


def detect_standards(target_dir):
    """Detect which ERC standards are implemented."""
    standards = set()
    sol_files = list(Path(target_dir).rglob("*.sol"))
    sol_files = [f for f in sol_files if "node_modules" not in str(f) and "lib/" not in str(f)]

    for sol_file in sol_files:
        content = sol_file.read_text(errors="ignore")
        if "ERC4626" in content or "convertToShares" in content or "convertToAssets" in content:
            standards.add("ERC4626")
        if "ERC20" in content or "totalSupply" in content:
            standards.add("ERC20")
        if "ERC721" in content or "ownerOf" in content:
            standards.add("ERC721")
        if "borrow" in content.lower() and "repay" in content.lower():
            standards.add("LENDING")
        if "stake" in content.lower() and "unstake" in content.lower():
            standards.add("STAKING")

    return standards


def extract_comment_invariants(target_dir):
    """Extract invariants from code comments."""
    invariants = []
    sol_files = list(Path(target_dir).rglob("*.sol"))
    sol_files = [f for f in sol_files if "node_modules" not in str(f) and "test" not in str(f).lower()]

    keywords = ["must", "always", "never", "invariant", "should not", "should be",
                "cannot exceed", "monotonic", "non-decreasing", "non-increasing"]

    for sol_file in sol_files:
        content = sol_file.read_text(errors="ignore")
        for i, line in enumerate(content.split("\n")):
            line_lower = line.lower().strip()
            if line_lower.startswith("//") or line_lower.startswith("*"):
                for keyword in keywords:
                    if keyword in line_lower:
                        invariants.append({
                            "file": str(sol_file.relative_to(target_dir)),
                            "line": i + 1,
                            "comment": line.strip()[:120],
                            "keyword": keyword,
                        })
                        break

    return invariants


def detect_function_pairs(target_dir):
    """Detect function pairs that imply roundtrip invariants."""
    pairs = []
    pair_patterns = [
        ("deposit", "withdraw"), ("mint", "burn"), ("mint", "redeem"),
        ("stake", "unstake"), ("lock", "unlock"), ("wrap", "unwrap"),
        ("enter", "exit"), ("open", "close"), ("add", "remove"),
        ("borrow", "repay"), ("supply", "withdraw"),
    ]

    sol_files = list(Path(target_dir).rglob("*.sol"))
    sol_files = [f for f in sol_files if "node_modules" not in str(f) and "test" not in str(f).lower()]

    all_functions = set()
    for sol_file in sol_files:
        content = sol_file.read_text(errors="ignore")
        funcs = re.findall(r"function\s+(\w+)\s*\(", content)
        all_functions.update(f.lower() for f in funcs)

    for fn_a, fn_b in pair_patterns:
        has_a = any(fn_a in f for f in all_functions)
        has_b = any(fn_b in f for f in all_functions)
        if has_a and has_b:
            pairs.append((fn_a, fn_b))

    return pairs


def generate_test_file(standards, comment_invariants, function_pairs, output_file=None):
    """Generate a Foundry test file with proposed invariants."""
    lines = []
    lines.append("// SPDX-License-Identifier: MIT")
    lines.append("pragma solidity ^0.8.0;")
    lines.append("")
    lines.append('import "forge-std/Test.sol";')
    lines.append("")
    lines.append("/// @title Auto-Generated Invariant Tests")
    lines.append("/// @notice Generated by invariant-gen.py — review and customize before running")
    lines.append("contract InvariantTests is Test {")
    lines.append("")
    lines.append("    // TODO: declare target contracts and tokens")
    lines.append("    // TODO: implement setUp() with fork or deployment")
    lines.append("")

    count = 0

    # ERC4626 invariants
    if "ERC4626" in standards:
        lines.append("    // ========== ERC4626 VAULT INVARIANTS ==========")
        for inv in ERC4626_INVARIANTS:
            lines.append(f"    /// @notice {inv['description']}")
            lines.append(inv["code"])
            lines.append("")
            count += 1

    # ERC20 invariants
    if "ERC20" in standards:
        lines.append("    // ========== ERC20 TOKEN INVARIANTS ==========")
        for inv in ERC20_INVARIANTS:
            lines.append(f"    /// @notice {inv['description']}")
            lines.append(inv["code"])
            lines.append("")
            count += 1

    # Lending invariants
    if "LENDING" in standards:
        lines.append("    // ========== LENDING INVARIANTS ==========")
        for inv in LENDING_INVARIANTS:
            lines.append(f"    /// @notice {inv['description']}")
            lines.append(inv["code"])
            lines.append("")
            count += 1

    # Function pair roundtrip invariants
    if function_pairs:
        lines.append("    // ========== ROUNDTRIP INVARIANTS (from function pairs) ==========")
        for fn_a, fn_b in function_pairs:
            lines.append(f"    /// @notice {fn_a} then {fn_b} should not create profit")
            lines.append(f"    function testFuzz_{fn_a}Then{fn_b.capitalize()}NoProfit(uint256 amount) public {{")
            lines.append(f"        amount = bound(amount, 1, 1e24);")
            lines.append(f"        // TODO: implement {fn_a}({{}}) → {fn_b}({{}}) roundtrip")
            lines.append(f"        // uint256 before = getBalance(address(this));")
            lines.append(f"        // target.{fn_a}(amount);")
            lines.append(f"        // target.{fn_b}(amount);")
            lines.append(f"        // uint256 after = getBalance(address(this));")
            lines.append(f'        // assertLe(after, before, "INVARIANT VIOLATED: {fn_a}+{fn_b} created profit");')
            lines.append(f"    }}")
            lines.append("")
            count += 1

    # Comment-derived invariants
    if comment_invariants:
        lines.append("    // ========== COMMENT-DERIVED INVARIANTS ==========")
        lines.append("    // These were extracted from code comments — review and implement:")
        for inv in comment_invariants[:10]:
            lines.append(f"    // [{inv['file']}:{inv['line']}] {inv['comment']}")
        lines.append("")

    lines.append("}")

    output = "\n".join(lines)

    if output_file:
        Path(output_file).write_text(output)
        print(f"Invariant tests written to {output_file}")
    else:
        print(output)

    return count


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 invariant-gen.py <target_dir> [--output invariants.t.sol]")
        sys.exit(1)

    target_dir = sys.argv[1]
    output_file = None

    if "--output" in sys.argv:
        idx = sys.argv.index("--output")
        output_file = sys.argv[idx + 1]

    print(f"Analyzing {target_dir}...")

    standards = detect_standards(target_dir)
    print(f"Detected standards: {', '.join(standards) or 'none'}")

    comment_invariants = extract_comment_invariants(target_dir)
    print(f"Found {len(comment_invariants)} comment-derived invariants")

    function_pairs = detect_function_pairs(target_dir)
    print(f"Found {len(function_pairs)} function pairs: {function_pairs}")

    count = generate_test_file(standards, comment_invariants, function_pairs, output_file)
    print(f"\n✅ Generated {count} fuzz test functions")


if __name__ == "__main__":
    main()
