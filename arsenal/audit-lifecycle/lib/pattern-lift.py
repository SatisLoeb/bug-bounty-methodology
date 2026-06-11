#!/usr/bin/env python3
"""
pattern-lift.py — scan a target against the H1 vulnerability patterns database.

Extracts Detection: grep blocks from H1-HUNTING-PATTERNS.md and runs each
against the target workspace. Emits a ranked report of pattern matches.

Usage:
  pattern-lift.py <target>
  pattern-lift.py --recon <workspace>
  pattern-lift.py --pattern P-H1-023 <target>
  pattern-lift.py --category auth <target>

HIT = textual signature matched. Manual verification required.
"""
import argparse
import os
import re
import subprocess
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


CATEGORIES = {
    (1, 9):   "idor",
    (10, 19): "ssrf",
    (20, 29): "auth",
    (30, 39): "race",
    (40, 49): "ssrf-chain",
    (50, 59): "rce",
    (60, 69): "logic",
    (70, 79): "api",
    (80, 89): "cache",
    (90, 99): "takeover",
    (100, 109): "ai",
    (110, 119): "smuggling",
    (120, 129): "disclosure",
}


def categorize(pid: str) -> str:
    # Pattern ID looks like "P-H1-050" — extract the LAST numeric group
    m = re.search(r'(\d+)$', pid)
    if not m:
        return "meta"
    num = int(m.group(1))
    for (lo, hi), cat in CATEGORIES.items():
        if lo <= num <= hi:
            return cat
    return "meta"


def parse_patterns(patterns_file: str):
    with open(patterns_file) as f:
        content = f.read()

    header_re = re.compile(r'^### (P-H1-\d+|M-H1-\d+): (.+?)$', re.MULTILINE)
    matches = list(header_re.finditer(content))

    patterns = []
    for i, m in enumerate(matches):
        pid = m.group(1)
        title = m.group(2).strip()
        start = m.start()
        end = matches[i+1].start() if i+1 < len(matches) else len(content)
        block = content[start:end]

        sev_m = re.search(r'\*\*Severity:\*\*\s*(.+?)(?:\s*\(|$)', block, re.MULTILINE)
        severity = sev_m.group(1).strip() if sev_m else "unknown"

        src_m = re.search(r'\*\*Source:\*\*\s*(.+?)$', block, re.MULTILINE)
        source = src_m.group(1).strip() if src_m else ""

        payout_m = re.search(r'\$([\d,]+)', source)
        payout = int(payout_m.group(1).replace(',', '')) if payout_m else 0

        det_m = re.search(
            r'\*\*Detection:\*\*\s*\n\s*```(?:bash)?\s*\n(.+?)\n\s*```',
            block, re.DOTALL
        )
        if not det_m:
            continue
        detection = det_m.group(1).strip()

        grep_line = None
        for line in detection.split('\n'):
            s = line.strip()
            if s.startswith('grep'):
                grep_line = s
                break
        if not grep_line:
            continue

        quote_m = re.search(r'"([^"]+)"', grep_line)
        if not quote_m:
            continue

        pat = quote_m.group(1).replace(r'\|', '|')

        patterns.append({
            'id': pid,
            'title': title,
            'category': categorize(pid),
            'severity': severity,
            'payout': payout,
            'pattern': pat,
            'grep_line': grep_line,
        })

    return patterns


def scan_target(target: Path, pattern: str, recon_mode: bool = False):
    if recon_mode and (target / 'bundles').exists():
        roots = [str(target / 'bundles')]
    else:
        roots = [str(target)]

    exclude_dirs = [
        'node_modules', '.git', 'vendor', 'target', 'dist', 'build',
        '__pycache__', '.venv', 'venv', '.next'
    ]

    cmd = ['grep', '-rE', pattern]
    for d in exclude_dirs:
        cmd.extend(['--exclude-dir', d])
    cmd.extend(roots)

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=20)
    except subprocess.TimeoutExpired:
        return (0, [])

    lines = [l for l in result.stdout.split('\n') if l.strip()]
    hit_count = len(lines)

    if hit_count == 0:
        return (0, [])

    files = []
    seen = set()
    for line in lines:
        if ':' in line:
            fname = line.split(':', 1)[0]
            if fname not in seen:
                seen.add(fname)
                files.append(fname.replace(str(target) + '/', ''))
        if len(files) >= 3:
            break

    return (hit_count, files)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('target')
    ap.add_argument('--recon', action='store_true')
    ap.add_argument('--pattern')
    ap.add_argument('--category')
    ap.add_argument('--patterns-file',
                    default=os.path.expanduser('~/arsenal/methodology/H1-HUNTING-PATTERNS.md'))
    args = ap.parse_args()

    target = Path(args.target).resolve()
    if not target.is_dir():
        print(f"ERROR: target not found: {target}", file=sys.stderr)
        sys.exit(1)

    if not os.path.exists(args.patterns_file):
        print(f"ERROR: patterns file not found: {args.patterns_file}", file=sys.stderr)
        sys.exit(1)

    patterns = parse_patterns(args.patterns_file)
    if not patterns:
        print("ERROR: no patterns parsed", file=sys.stderr)
        sys.exit(1)

    if args.pattern:
        patterns = [p for p in patterns if p['id'] == args.pattern]
    if args.category:
        patterns = [p for p in patterns if p['category'] == args.category]

    now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    mode = 'recon' if args.recon else 'code'
    report_path = target / 'PATTERN-LIFT-REPORT.md'

    print(f"[pattern-lift] loaded {len(patterns)} patterns")
    print(f"[pattern-lift] target: {target}")
    print(f"[pattern-lift] mode:   {mode}")

    results = []
    for p in patterns:
        count, files = scan_target(target, p['pattern'], recon_mode=args.recon)
        if count > 0:
            results.append({**p, 'count': count, 'files': files})

    results.sort(key=lambda r: (-r['payout'], -r['count']))

    with open(report_path, 'w') as f:
        f.write(f"# Pattern Lift Report\n\n")
        f.write(f"**Target:** `{target}`\n")
        f.write(f"**Scan time:** {now}\n")
        f.write(f"**Mode:** {mode}\n")
        f.write(f"**Patterns evaluated:** {len(patterns)}\n")
        f.write(f"**Patterns with matches:** {len(results)}\n")
        f.write(f"**Source:** `{args.patterns_file}`\n\n")
        f.write("---\n\n")
        f.write("## Methodology note\n\n")
        f.write("HIT = textual signature matched. HIT is NOT a confirmed vulnerability. ")
        f.write("Operator must manually verify each HIT by reading matched code in context.\n\n")
        f.write("**Rule M-H1-009:** Automated tools saturate surface-level patterns. ")
        f.write("Manual logic bugs (IDOR, auth-bypass, race conditions) pay 3:1 more.\n\n")
        f.write("---\n\n")

        if results:
            f.write("## Match Summary (ranked by payout)\n\n")
            f.write("| Pattern | Category | Severity | Payout | Hits | Files |\n")
            f.write("|---------|----------|----------|--------|------|-------|\n")
            for r in results:
                files_str = ', '.join(f'`{x}`' for x in r['files']) if r['files'] else '-'
                payout_str = f"${r['payout']:,}" if r['payout'] else '-'
                f.write(f"| {r['id']} | {r['category']} | {r['severity']} | {payout_str} | {r['count']} | {files_str} |\n")

            f.write("\n---\n\n")
            f.write("## Pattern Details (manual verification required)\n\n")
            for r in results:
                f.write(f"### {r['id']} — {r['title']}\n\n")
                f.write(f"- **Category:** {r['category']}\n")
                f.write(f"- **Severity:** {r['severity']}\n")
                if r['payout']:
                    f.write(f"- **Source payout reference:** ${r['payout']:,}\n")
                f.write(f"- **Match count:** {r['count']}\n")
                if r['files']:
                    f.write(f"- **Top 3 files:**\n")
                    for fl in r['files']:
                        f.write(f"  - `{fl}`\n")
                f.write(f"- **Detection signature:** `{r['pattern']}`\n\n")
                f.write(f"**Manual verification:**\n")
                f.write(f"```bash\n")
                f.write(f'grep -rnE "{r["pattern"]}" "{target}" --exclude-dir=node_modules --exclude-dir=.git | head -20\n')
                f.write(f"```\n\n")
                f.write("---\n\n")
        else:
            f.write("## No patterns matched\n\n")
            f.write("Target may be clean, signatures may not fit, or recon workspace lacks codebase.\n\n")

        by_cat = defaultdict(int)
        for r in results:
            by_cat[r['category']] += 1
        if by_cat:
            f.write("## Match distribution by category\n\n")
            for cat, n in sorted(by_cat.items(), key=lambda x: -x[1]):
                f.write(f"- **{cat}:** {n} pattern(s) matched\n")
            f.write("\n")

        f.write("---\n\n")
        f.write("## Next steps\n\n")
        f.write("1. Review top 5 highest-payout matches manually.\n")
        f.write("2. For each HIT: run the manual verification command, read in context.\n")
        f.write("3. Genuine surface → `on-finding.sh --stage 1 <id>` to open scope-check.\n")
        f.write("4. False positives → skip. Do NOT escalate textual matches to findings.\n")

    print(f"[pattern-lift] scan complete")
    print(f"[pattern-lift] report: {report_path}")
    print(f"[pattern-lift] {len(results)} / {len(patterns)} patterns matched")

    if results:
        print(f"\nTop 5 matches by payout:")
        for r in results[:5]:
            payout_str = f"${r['payout']:,}" if r['payout'] else '-'
            print(f"  {r['id']:<12} {r['category']:<12} {r['severity']:<15} {payout_str:>8}  {r['count']:>4} hits")


if __name__ == '__main__':
    main()
