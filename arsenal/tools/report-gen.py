#!/usr/bin/env python3
"""
report-gen.py — Automated Security Report Generator

Given structured finding data, generates a platform-formatted report
in kayabaNerve prose (no em dash, lowercase, dense blocks).

Usage:
    python3 report-gen.py --finding finding.json [--platform h1|hackenproof|cantina|c4]
    python3 report-gen.py --interactive
"""

import sys
import json
from pathlib import Path
from datetime import datetime


PLATFORMS = {
    "h1": {
        "name": "HackerOne",
        "sections": ["summary", "description", "steps", "impact", "fix"],
        "format": "single_field",
    },
    "hackenproof": {
        "name": "HackenProof",
        "sections": ["vuln_details", "validation_steps"],
        "format": "two_fields",
    },
    "cantina": {
        "name": "Cantina",
        "sections": ["summary", "finding_description", "impact", "likelihood", "poc", "recommendation"],
        "format": "markdown_sections",
    },
    "c4": {
        "name": "Code4rena",
        "sections": ["lines_of_code", "vulnerability_details", "impact", "poc", "tools_used", "fix"],
        "format": "markdown_sections",
    },
}


def generate_h1(finding):
    """Generate HackerOne format report."""
    lines = []

    lines.append(f"# {finding['title']}")
    lines.append("")
    lines.append("## Summary")
    lines.append("")
    lines.append(finding.get("summary", "TODO"))
    lines.append("")
    lines.append("## Description")
    lines.append("")
    lines.append(finding.get("description", "TODO"))
    lines.append("")

    if finding.get("code_refs"):
        for ref in finding["code_refs"]:
            lines.append(f"```{ref.get('lang', 'solidity')}")
            lines.append(ref["code"])
            lines.append("```")
            lines.append("")

    lines.append("## Steps to Reproduce")
    lines.append("")
    for i, step in enumerate(finding.get("steps", ["TODO"]), 1):
        lines.append(f"{i}. {step}")
    lines.append("")

    if finding.get("poc_command"):
        lines.append("```bash")
        lines.append(finding["poc_command"])
        lines.append("```")
        lines.append("")

    if finding.get("poc_output"):
        lines.append("```")
        lines.append(finding["poc_output"])
        lines.append("```")
        lines.append("")

    lines.append("## Impact")
    lines.append("")
    if finding.get("is_risk"):
        lines.append(finding["is_risk"])
    if finding.get("is_not_risk"):
        lines.append("")
        lines.append(finding["is_not_risk"])
    lines.append("")

    if finding.get("fix"):
        lines.append("## Recommended Fix")
        lines.append("")
        lines.append(finding["fix"])
        if finding.get("fix_code"):
            lines.append("")
            lines.append(f"```{finding.get('fix_lang', 'solidity')}")
            lines.append(finding["fix_code"])
            lines.append("```")

    return "\n".join(lines)


def generate_hackenproof(finding):
    """Generate HackenProof format (two separate fields)."""
    vuln = []
    steps = []

    vuln.append(finding.get("description", "TODO"))
    vuln.append("")
    if finding.get("code_refs"):
        for ref in finding["code_refs"]:
            vuln.append(f"```{ref.get('lang', 'solidity')}")
            vuln.append(ref["code"])
            vuln.append("```")
            vuln.append("")

    if finding.get("is_risk"):
        vuln.append(finding["is_risk"])
    if finding.get("is_not_risk"):
        vuln.append("")
        vuln.append(finding["is_not_risk"])

    for i, step in enumerate(finding.get("steps", ["TODO"]), 1):
        steps.append(f"Step {i}: {step}")
        steps.append("")

    if finding.get("poc_command"):
        steps.append("```bash")
        steps.append(finding["poc_command"])
        steps.append("```")

    if finding.get("poc_output"):
        steps.append("")
        steps.append("```")
        steps.append(finding["poc_output"])
        steps.append("```")

    return {
        "vulnerability_details": "\n".join(vuln),
        "validation_steps": "\n".join(steps),
    }


def generate_cantina(finding):
    """Generate Cantina format report."""
    lines = []

    lines.append("## Summary")
    lines.append("")
    lines.append(finding.get("summary", "TODO"))
    lines.append("")
    lines.append("## Finding Description")
    lines.append("")
    lines.append(finding.get("description", "TODO"))
    lines.append("")

    if finding.get("code_refs"):
        for ref in finding["code_refs"]:
            lines.append(f"```{ref.get('lang', 'solidity')}")
            lines.append(ref["code"])
            lines.append("```")
            lines.append("")

    lines.append("## Impact Explanation")
    lines.append("")
    lines.append(finding.get("is_risk", "TODO"))
    if finding.get("is_not_risk"):
        lines.append("")
        lines.append(finding["is_not_risk"])
    lines.append("")

    lines.append("## Likelihood Explanation")
    lines.append("")
    lines.append(finding.get("likelihood", "TODO"))
    lines.append("")

    lines.append("## Proof of Concept")
    lines.append("")
    if finding.get("poc_command"):
        lines.append("```bash")
        lines.append(finding["poc_command"])
        lines.append("```")
        lines.append("")
    if finding.get("poc_output"):
        lines.append("```")
        lines.append(finding["poc_output"])
        lines.append("```")
        lines.append("")

    for i, step in enumerate(finding.get("steps", []), 1):
        lines.append(f"{i}. {step}")
    lines.append("")

    lines.append("## Recommendation")
    lines.append("")
    lines.append(finding.get("fix", "TODO"))
    if finding.get("fix_code"):
        lines.append("")
        lines.append(f"```{finding.get('fix_lang', 'solidity')}")
        lines.append(finding["fix_code"])
        lines.append("```")

    return "\n".join(lines)


def interactive_mode():
    """Interactive finding input."""
    finding = {}
    print("=== Report Generator — Interactive Mode ===")
    print("")

    finding["title"] = input("Title: ").strip()
    finding["severity"] = input("Severity (Critical/High/Medium/Low): ").strip()

    print("\nPlatform:")
    print("  1. HackerOne")
    print("  2. HackenProof")
    print("  3. Cantina")
    print("  4. Code4rena")
    platform_choice = input("Choose (1-4): ").strip()
    platform_map = {"1": "h1", "2": "hackenproof", "3": "cantina", "4": "c4"}
    platform = platform_map.get(platform_choice, "h1")

    finding["summary"] = input("\nSummary (1-3 sentences): ").strip()

    print("\nDescription (paste, then empty line to finish):")
    desc_lines = []
    while True:
        line = input()
        if line == "":
            break
        desc_lines.append(line)
    finding["description"] = "\n".join(desc_lines)

    print("\nSteps to Reproduce (one per line, empty to finish):")
    steps = []
    while True:
        step = input(f"  Step {len(steps)+1}: ").strip()
        if step == "":
            break
        steps.append(step)
    finding["steps"] = steps

    finding["poc_command"] = input("\nPoC command (or empty): ").strip() or None
    finding["poc_output"] = input("PoC output (or empty): ").strip() or None

    finding["is_risk"] = input("\nWhat IS at risk: ").strip()
    finding["is_not_risk"] = input("What is NOT at risk: ").strip()

    finding["fix"] = input("\nRecommended fix: ").strip()

    finding["likelihood"] = input("Likelihood explanation: ").strip()

    return finding, platform


def main():
    if "--interactive" in sys.argv:
        finding, platform = interactive_mode()
    elif "--finding" in sys.argv:
        idx = sys.argv.index("--finding")
        finding_file = sys.argv[idx + 1]
        finding = json.loads(Path(finding_file).read_text())
        platform = "h1"
        if "--platform" in sys.argv:
            pidx = sys.argv.index("--platform")
            platform = sys.argv[pidx + 1]
    else:
        print("Usage: python3 report-gen.py --finding finding.json [--platform h1|hackenproof|cantina|c4]")
        print("       python3 report-gen.py --interactive")
        sys.exit(1)

    output_file = None
    if "--output" in sys.argv:
        oidx = sys.argv.index("--output")
        output_file = sys.argv[oidx + 1]

    if platform == "h1":
        result = generate_h1(finding)
    elif platform == "hackenproof":
        result = generate_hackenproof(finding)
        result = f"**VULNERABILITY DETAILS:**\n\n{result['vulnerability_details']}\n\n---\n\n**VALIDATION STEPS:**\n\n{result['validation_steps']}"
    elif platform == "cantina":
        result = generate_cantina(finding)
    else:
        result = generate_cantina(finding)  # default to Cantina format

    if output_file:
        Path(output_file).write_text(result)
        print(f"Report written to {output_file}")
    else:
        print(result)


if __name__ == "__main__":
    main()
