#!/usr/bin/env python3
"""
check-matrix.py — Automated Check Matrix Builder

Extracts all public/external functions from Solidity contracts,
lists modifiers, require conditions, state writes, and external calls.
Groups similar functions and highlights INCONSISTENCIES.

Usage:
    python3 check-matrix.py <target_dir> [--output matrix.md]

The technique that found:
- Reserve F-001: bid() checks bidsEnabled, createTrustedFill() doesn't
- Morpho F-001: 1inch divides by 100, Paraswap does .toString(16)
- Coin98: .includes() vs .endsWith() on same whitelist
- Spark: nonReentrant on 3/5 fund movement functions, missing on 2
"""

import sys
import os
import json
import re
from collections import defaultdict
from pathlib import Path

try:
    from slither.slither import Slither
    from slither.core.declarations import Function, FunctionContract
    from slither.core.declarations.solidity_variables import SolidityVariableComposed
    HAS_SLITHER = True
except ImportError:
    HAS_SLITHER = False


def extract_functions_slither(target_dir):
    """Extract function data using Slither's AST analysis."""
    functions = []

    try:
        slither = Slither(target_dir)
    except Exception as e:
        print(f"Slither failed: {e}")
        print("Falling back to regex-based extraction...")
        return extract_functions_regex(target_dir)

    for contract in slither.contracts_derived:
        if contract.is_interface or contract.is_library:
            continue

        for func in contract.functions:
            if func.is_constructor or func.is_fallback or func.is_receive:
                continue
            if func.visibility not in ("public", "external"):
                continue

            # Extract modifiers
            modifiers = [m.name for m in func.modifiers]

            # Extract require conditions (simplified)
            requires = []
            for node in func.nodes:
                for ir in node.irs:
                    ir_str = str(ir)
                    if "require" in ir_str or "revert" in ir_str:
                        requires.append(ir_str[:80])

            # Extract state variables written
            state_writes = [str(v) for v in func.state_variables_written]

            # Extract external calls
            ext_calls = []
            for call in func.external_calls_as_expressions:
                ext_calls.append(str(call)[:60])

            # Extract internal calls
            int_calls = [str(c) for c in func.internal_calls if hasattr(c, 'name')]

            functions.append({
                "contract": contract.name,
                "name": func.name,
                "visibility": func.visibility,
                "modifiers": modifiers,
                "requires": requires,
                "state_writes": state_writes,
                "external_calls": ext_calls,
                "internal_calls": [str(c) for c in int_calls],
                "is_view": func.view,
                "is_pure": func.pure,
                "params": [str(p) for p in func.parameters],
            })

    return functions


def extract_functions_regex(target_dir):
    """Fallback: extract function data using regex (when Slither fails)."""
    functions = []
    sol_files = list(Path(target_dir).rglob("*.sol"))

    # Filter out tests, interfaces, mocks
    sol_files = [f for f in sol_files if not any(
        x in str(f).lower() for x in ["test", "mock", "interface", "node_modules", "lib/"]
    )]

    for sol_file in sol_files:
        content = sol_file.read_text(errors="ignore")

        # Find contract name
        contract_match = re.search(r"contract\s+(\w+)", content)
        contract_name = contract_match.group(1) if contract_match else sol_file.stem

        # Find all function definitions
        func_pattern = re.compile(
            r"function\s+(\w+)\s*\(([^)]*)\)\s*((?:public|external|internal|private)"
            r"(?:\s+(?:view|pure|payable|virtual|override|returns\s*\([^)]*\)|"
            r"\w+))*)\s*(?:\{|returns)",
            re.MULTILINE
        )

        for match in func_pattern.finditer(content):
            name = match.group(1)
            params = match.group(2).strip()
            qualifiers = match.group(3)

            if "internal" in qualifiers or "private" in qualifiers:
                continue

            visibility = "external" if "external" in qualifiers else "public"
            is_view = "view" in qualifiers
            is_pure = "pure" in qualifiers

            # Extract modifiers (words after visibility that aren't keywords)
            keywords = {"public", "external", "view", "pure", "payable", "virtual",
                        "override", "returns"}
            modifier_matches = re.findall(r"\b(\w+)\b", qualifiers)
            modifiers = [m for m in modifier_matches if m not in keywords]

            # Find the function body and extract requires
            func_start = match.end()
            brace_count = 0
            func_body = ""
            for i, char in enumerate(content[func_start:func_start + 5000]):
                if char == "{":
                    brace_count += 1
                elif char == "}":
                    brace_count -= 1
                    if brace_count == 0:
                        func_body = content[func_start:func_start + i]
                        break

            requires = re.findall(r"require\s*\(([^;]{1,100})", func_body)
            requires = [r.strip()[:80] for r in requires]

            # State writes (simplified: assignments to storage-like vars)
            state_writes = re.findall(r"(\w+(?:\.\w+)*)\s*[+\-*/]?=\s", func_body)
            state_writes = list(set(w for w in state_writes if w[0].islower() or w[0] == "_"))

            # External calls
            ext_calls = re.findall(r"(\w+(?:\.\w+)+)\s*\(", func_body)
            ext_calls = [c[:60] for c in ext_calls if "." in c][:5]

            functions.append({
                "contract": contract_name,
                "name": name,
                "visibility": visibility,
                "modifiers": modifiers,
                "requires": requires,
                "state_writes": state_writes[:10],
                "external_calls": ext_calls,
                "internal_calls": [],
                "is_view": is_view,
                "is_pure": is_pure,
                "params": [params] if params else [],
            })

    return functions


def group_similar_functions(functions):
    """Group functions that should have the same checks."""
    groups = defaultdict(list)

    for func in functions:
        if func["is_view"] or func["is_pure"]:
            continue

        # Group by contract
        groups[f"contract:{func['contract']}"].append(func)

        # Group by function name prefix (e.g., deposit, withdraw, transfer)
        prefix = re.match(r"([a-z]+)", func["name"])
        if prefix:
            groups[f"prefix:{prefix.group(1)}"].append(func)

        # Group by state variables written
        for sv in func["state_writes"]:
            groups[f"writes:{sv}"].append(func)

    return groups


def find_inconsistencies(groups):
    """Find modifier/check inconsistencies within groups."""
    inconsistencies = []

    for group_key, funcs in groups.items():
        if len(funcs) < 2:
            continue

        # Collect all modifiers used in the group
        all_modifiers = set()
        for func in funcs:
            all_modifiers.update(func["modifiers"])

        if not all_modifiers:
            continue

        # Check each function for missing modifiers
        for modifier in all_modifiers:
            has = [f for f in funcs if modifier in f["modifiers"]]
            missing = [f for f in funcs if modifier not in f["modifiers"]]

            if has and missing and len(has) > len(missing):
                for func in missing:
                    inconsistencies.append({
                        "group": group_key,
                        "function": f"{func['contract']}.{func['name']}",
                        "missing_modifier": modifier,
                        "present_in": [f"{f['contract']}.{f['name']}" for f in has],
                        "severity": "HIGH" if modifier in ("nonReentrant", "onlyOwner",
                                                            "onlyAdmin", "whenNotPaused",
                                                            "requiresAuth", "onlyRole")
                                    else "MEDIUM",
                    })

    # Deduplicate
    seen = set()
    unique = []
    for inc in inconsistencies:
        key = (inc["function"], inc["missing_modifier"])
        if key not in seen:
            seen.add(key)
            unique.append(inc)

    return sorted(unique, key=lambda x: (0 if x["severity"] == "HIGH" else 1, x["function"]))


def generate_matrix(functions, output_file=None):
    """Generate the check matrix as Markdown."""
    lines = []
    lines.append("# Check Matrix\n")
    lines.append(f"Total functions analyzed: {len(functions)}\n")

    # State-modifying functions only
    state_funcs = [f for f in functions if not f["is_view"] and not f["is_pure"]]
    lines.append(f"State-modifying functions: {len(state_funcs)}\n")

    # Collect all unique modifiers
    all_mods = sorted(set(m for f in state_funcs for m in f["modifiers"]))

    if all_mods:
        # Build the table
        header = "| Contract | Function | " + " | ".join(all_mods) + " | State Writes | Ext Calls |"
        separator = "|---|---|" + "|".join(["---"] * len(all_mods)) + "|---|---|"
        lines.append(header)
        lines.append(separator)

        for func in sorted(state_funcs, key=lambda f: (f["contract"], f["name"])):
            mod_checks = []
            for mod in all_mods:
                if mod in func["modifiers"]:
                    mod_checks.append(" ✓ ")
                else:
                    mod_checks.append(" **✗** ")

            writes = ", ".join(func["state_writes"][:3]) or "—"
            calls = ", ".join(func["external_calls"][:2]) or "—"

            line = f"| {func['contract']} | `{func['name']}` | " + "|".join(mod_checks) + f"| {writes} | {calls} |"
            lines.append(line)

    lines.append("")

    # Inconsistencies
    groups = group_similar_functions(state_funcs)
    inconsistencies = find_inconsistencies(groups)

    if inconsistencies:
        lines.append("## ⚠ INCONSISTENCIES FOUND\n")
        for inc in inconsistencies:
            lines.append(f"### [{inc['severity']}] `{inc['function']}` missing `{inc['missing_modifier']}`")
            lines.append(f"- Present in: {', '.join(inc['present_in'][:3])}")
            lines.append(f"- Group: {inc['group']}")
            lines.append("")
    else:
        lines.append("## No inconsistencies found.\n")

    output = "\n".join(lines)

    if output_file:
        Path(output_file).write_text(output)
        print(f"Matrix written to {output_file}")
    else:
        print(output)

    return inconsistencies


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 check-matrix.py <target_dir> [--output matrix.md]")
        sys.exit(1)

    target_dir = sys.argv[1]
    output_file = None

    if "--output" in sys.argv:
        idx = sys.argv.index("--output")
        output_file = sys.argv[idx + 1]

    print(f"Analyzing {target_dir}...")
    print(f"Slither available: {HAS_SLITHER}")

    if HAS_SLITHER:
        functions = extract_functions_slither(target_dir)
    else:
        functions = extract_functions_regex(target_dir)

    if not functions:
        print("No functions found. Check the target directory.")
        sys.exit(1)

    print(f"Found {len(functions)} public/external functions.")
    inconsistencies = generate_matrix(functions, output_file)

    if inconsistencies:
        print(f"\n🚨 {len(inconsistencies)} INCONSISTENCIES FOUND — review above.")
    else:
        print("\n✅ No inconsistencies detected.")


if __name__ == "__main__":
    main()
