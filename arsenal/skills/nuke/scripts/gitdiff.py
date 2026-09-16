#!/usr/bin/env python3
"""Emit the changed .sol files and their HEAD-side line ranges for a git range.
Usage: gitdiff.py <repo-root> <range>   (range = BASE | BASE..HEAD | BASE...HEAD)
Prints JSON: {"range","files":[relpaths],"ranges":{basename:[[start,end],...]}}
"""
import json
import os
import re
import subprocess
import sys


def git(root, *args):
    return subprocess.run(["git", "-C", root, *args], capture_output=True, text=True).stdout


def main():
    root, rng = sys.argv[1], sys.argv[2]
    listed = git(root, "diff", "--name-only", "--diff-filter=ACMR", rng, "--", "*.sol")
    files = [f for f in listed.splitlines() if f.strip()]
    ranges = {}
    for f in files:
        out = git(root, "diff", "--unified=0", rng, "--", f)
        rs = []
        for line in out.splitlines():
            if line.startswith("@@"):
                m = re.search(r"\+(\d+)(?:,(\d+))?", line)  # head-side +start,count
                if m:
                    s = int(m.group(1))
                    c = int(m.group(2)) if m.group(2) else 1
                    rs.append([s, s] if c == 0 else [s, s + c - 1])
        ranges[os.path.basename(f)] = rs
    json.dump({"range": rng, "files": files, "ranges": ranges}, sys.stdout, indent=2)


if __name__ == "__main__":
    main()
