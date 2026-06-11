#!/usr/bin/env python3
"""
reverse-lookup.py — Cross-reference target SBOM with research database.

Usage:
  python3 reverse-lookup.py --sbom sbom-npm.txt --db research_db.jsonl
  python3 reverse-lookup.py --sbom sbom-npm.txt --db research_db.jsonl --ecosystem npm --target "TargetName"
  python3 reverse-lookup.py --sbom sbom-npm.txt --db research_db.jsonl --json
"""

import json
import sys
import argparse
from pathlib import Path


def load_research_db(db_path):
    db = {}
    with open(db_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            entry = json.loads(line)
            key = f"{entry['ecosystem']}:{entry['lib']}"
            db[key] = entry
    return db


def parse_sbom(sbom_path, ecosystem):
    deps = []
    with open(sbom_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "@" in line and not line.startswith("@"):
                name, version = line.rsplit("@", 1)
            elif line.startswith("@"):
                parts = line.split("@")
                name = f"@{parts[1]}"
                version = parts[2] if len(parts) > 2 else "unknown"
            else:
                name = line
                version = "unknown"
            deps.append((name.strip(), version.strip()))
    return deps


def lookup(deps, db, ecosystem):
    hits = []
    clean = []
    unknown = []

    for name, version in deps:
        key = f"{ecosystem}:{name}"
        if key in db:
            entry = db[key]
            if entry.get("findings") and len(entry["findings"]) > 0:
                hits.append({
                    "lib": name,
                    "version": version,
                    "findings": entry["findings"],
                    "severity_max": entry.get("severity_max"),
                    "status": entry.get("status"),
                    "patched_version": entry.get("patched_version"),
                    "note": entry.get("note"),
                })
            else:
                clean.append({
                    "lib": name,
                    "version": version,
                    "status": entry.get("status", "CLEAN"),
                    "fuzzer": entry.get("fuzzer"),
                    "tests": entry.get("tests"),
                })
        else:
            unknown.append({"lib": name, "version": version})

    return hits, clean, unknown


def print_results(hits, clean, unknown, target_name):
    print(f"\n{'='*70}")
    print(f"REVERSE LOOKUP: {target_name}")
    print(f"{'='*70}")

    if hits:
        print(f"\nHITS --- {len(hits)} libs with existing findings:")
        print(f"{'~'*70}")
        severity_order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
        for h in sorted(hits, key=lambda x: severity_order.get(x["severity_max"], 4)):
            status_icon = {
                "SUBMITTED": "[TX]",
                "GHSA_READY": "[GHSA]",
                "PATCHED": "[OK]",
                "PARTIAL_PATCH": "[PARTIAL]",
                "DOWNSTREAM": "[DOWN]",
                "DESIGN_DEPENDENCY": "[DEP]",
            }.get(h["status"], "[?]")

            patched = ""
            if h.get("patched_version"):
                patched = f" (patched in {h['patched_version']})"

            print(f"  {status_icon} {h['lib']}@{h['version']}")
            print(f"     Severity: {h['severity_max']}")
            print(f"     Findings: {', '.join(h['findings'])}")
            print(f"     Status: {h['status']}{patched}")
            if h.get("note"):
                print(f"     Note: {h['note']}")
            print()

    if clean:
        print(f"\nCLEAN --- {len(clean)} libs already fuzzed, no findings:")
        print(f"{'~'*70}")
        for c in clean:
            tests = f" ({c['tests']} tests)" if c.get("tests") else ""
            fuzzer = f" [{c['fuzzer']}]" if c.get("fuzzer") else ""
            print(f"  + {c['lib']}@{c['version']} --- {c['status']}{tests}{fuzzer}")

    if unknown:
        print(f"\nUNKNOWN --- {len(unknown)} libs not in research database:")
        print(f"{'~'*70}")
        for u in unknown:
            print(f"  ? {u['lib']}@{u['version']}")

    print(f"\n{'~'*70}")
    total_findings = sum(len(h["findings"]) for h in hits)
    print(f"SUMMARY: {len(hits)} hits ({total_findings} findings), {len(clean)} clean, {len(unknown)} unknown")
    if hits:
        print(f"ACTION: Write {total_findings} downstream reports")
    print()


def main():
    parser = argparse.ArgumentParser(description="Reverse dependency lookup against research database")
    parser.add_argument("--sbom", required=True, help="Path to SBOM file (one dep per line)")
    parser.add_argument("--db", required=True, help="Path to research_db.jsonl")
    parser.add_argument(
        "--ecosystem",
        default="npm",
        choices=["npm", "pypi", "cargo", "go", "maven"],
        help="Package ecosystem",
    )
    parser.add_argument("--target", default="unknown", help="Target name (for display)")
    parser.add_argument("--json", action="store_true", help="Output as JSON")
    args = parser.parse_args()

    db = load_research_db(args.db)
    deps = parse_sbom(args.sbom, args.ecosystem)
    hits, clean, unknown = lookup(deps, db, args.ecosystem)

    if args.json:
        print(json.dumps({"hits": hits, "clean": clean, "unknown": unknown}, indent=2))
    else:
        print_results(hits, clean, unknown, args.target)

    sys.exit(0 if not hits else 2)


if __name__ == "__main__":
    main()
