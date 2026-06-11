#!/usr/bin/env python3
"""
differential-fuzzer.py — same spec, N implementations, diff the outputs.

Phase A skeleton. Phase B: richer corpus generation + automatic minimization.

Usage:
    ./differential-fuzzer.py \\
        --corpus ./corpus/ \\
        --impl "geth:geth --exec ..." \\
        --impl "reth:reth run --exec ..." \\
        --impl "nethermind:Nethermind.Runner ..." \\
        --timeout 10 \\
        --output divergences.jsonl

Each line of divergences.jsonl records one input that produced divergent outputs
across implementations.

See ~/arsenal/methodology/DIFFERENTIAL-FUZZING-METHOD.md for methodology.
"""

import argparse
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import time


def parse_impl(spec):
    """Parse --impl NAME:COMMAND format."""
    name, _, cmd = spec.partition(":")
    if not cmd:
        sys.exit(f"Invalid --impl format: {spec!r}. Expected NAME:COMMAND")
    return name, cmd


def run_impl(name, cmd, input_bytes, timeout):
    """Run one implementation with the input, collect output+rc."""
    try:
        p = subprocess.run(
            cmd,
            shell=True,
            input=input_bytes,
            capture_output=True,
            timeout=timeout,
        )
        return {
            "impl": name,
            "rc": p.returncode,
            "stdout_hash": hashlib.sha256(p.stdout).hexdigest(),
            "stderr_hash": hashlib.sha256(p.stderr).hexdigest(),
            "stdout_len": len(p.stdout),
            "stderr_len": len(p.stderr),
            "stdout_head": p.stdout[:256].hex(),
            "stderr_head": p.stderr[:256].decode(errors="replace")[:256],
        }
    except subprocess.TimeoutExpired:
        return {"impl": name, "rc": -1, "timeout": True}


def iter_corpus(corpus_path):
    """Yield (name, bytes) for each file in corpus directory."""
    root = pathlib.Path(corpus_path)
    if not root.exists():
        sys.exit(f"Corpus directory not found: {corpus_path}")
    for f in sorted(root.rglob("*")):
        if f.is_file():
            yield f.relative_to(root).as_posix(), f.read_bytes()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", required=True, help="directory of input files")
    ap.add_argument("--impl", action="append", required=True, help="NAME:COMMAND (repeatable)")
    ap.add_argument("--timeout", type=int, default=10)
    ap.add_argument("--output", default="divergences.jsonl")
    ap.add_argument("--min-divergence", type=int, default=2,
                    help="min number of distinct output hashes to flag as divergence")
    args = ap.parse_args()

    impls = [parse_impl(s) for s in args.impl]
    if len(impls) < 2:
        sys.exit("At least 2 implementations required for differential fuzzing")

    out = open(args.output, "a", buffering=1)
    divergences_found = 0
    inputs_processed = 0

    print(f"[diff-fuzz] {len(impls)} impls, corpus={args.corpus}, timeout={args.timeout}s", file=sys.stderr)

    for input_name, input_bytes in iter_corpus(args.corpus):
        inputs_processed += 1
        results = [run_impl(name, cmd, input_bytes, args.timeout) for name, cmd in impls]
        unique_hashes = {r.get("stdout_hash", "TIMEOUT") for r in results}

        if len(unique_hashes) >= args.min_divergence:
            divergences_found += 1
            record = {
                "input": input_name,
                "input_size": len(input_bytes),
                "input_hash": hashlib.sha256(input_bytes).hexdigest(),
                "results": results,
                "ts": time.time(),
            }
            out.write(json.dumps(record) + "\n")
            print(f"[DIVERGENCE] {input_name}: {len(unique_hashes)} distinct outputs", file=sys.stderr)

    out.close()
    print(f"[diff-fuzz] done — {inputs_processed} inputs, {divergences_found} divergences → {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
