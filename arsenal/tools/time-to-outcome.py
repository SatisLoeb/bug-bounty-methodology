#!/usr/bin/env python3
"""
time-to-outcome.py — ROI analysis by finding class.

Reads OUTCOMES.jsonl (global + per-workspace) and groups findings by class.
Outputs median / p90 days_to_accepted, acceptance_rate, avg reward per class.

Classes are inferred from:
  - Explicit "class" field if present
  - "tags" array heuristics
  - Finding text keywords (auth, oracle, bridge, etc.)

Usage:
  time-to-outcome.py                  # Terminal table
  time-to-outcome.py --json           # JSON output
  time-to-outcome.py --class auth     # Filter to one class
  time-to-outcome.py --since 30       # Only last N days
"""

import argparse
import json
import os
import sys
import time
import glob
from datetime import datetime
from pathlib import Path

BUGS_ROOT = Path.home() / "Desktop" / "BUGS"

CLASS_KEYWORDS = {
    "auth-bypass-web": [
        "auth bypass", "authentication", "jwt", "session", "oauth", "sso", "mfa",
        "webauthn", "2fa", "api key", "authorization", "idor",
    ],
    "sc-fund-theft": [
        "fund theft", "drain", "withdraw", "steal funds", "unauthorized transfer",
        "balance", "mint", "redeem", "vault", "share inflation",
    ],
    "crypto-signature": [
        "signature", "ecdsa", "schnorr", "frost", "ed25519", "keccak",
        "signing", "merkle", "zk", "proof", "dkg",
    ],
    "info-disclosure": [
        "information disclosure", "leak", "exposed", "public", "stored key",
        "rpc", "namespace", "debug", "source map",
    ],
    "oracle-manipulation": [
        "oracle", "price feed", "chainlink", "pyth", "manipulation",
    ],
    "bridge-cross-chain": [
        "bridge", "cross-chain", "relay", "layerzero", "wormhole",
        "cross chain", "message replay",
    ],
    "access-control": [
        "access control", "permission", "role", "modifier", "onlyOwner",
        "admin", "governance bypass",
    ],
    "dos-griefing": [
        "dos", "griefing", "exhaustion", "unbounded", "denial of service",
        "resource exhaustion", "unreachable",
    ],
    "reentrancy": [
        "reentrancy", "reentrant", "cei ", "checks-effects-interactions",
    ],
    "logic-math": [
        "overflow", "underflow", "truncation", "rounding", "precision", "math",
        "as u8", "as u32", "as u64",
    ],
    "mev-timing": [
        "mev", "sandwich", "frontrun", "race condition", "timing",
    ],
}


def classify(finding_text: str, tags, explicit_class: str = None):
    """Return best-guess class, or 'unknown'."""
    if explicit_class and explicit_class != "n/a":
        return explicit_class
    text = (finding_text or "").lower()
    if isinstance(tags, list):
        text += " " + " ".join(str(t).lower() for t in tags)
    elif isinstance(tags, str):
        text += " " + tags.lower()

    scores = {}
    for cls, keywords in CLASS_KEYWORDS.items():
        score = sum(1 for kw in keywords if kw in text)
        if score > 0:
            scores[cls] = score
    if not scores:
        return "unknown"
    return max(scores, key=scores.get)


def parse_date(s):
    if not s:
        return None
    s = s[:10]
    try:
        return datetime.strptime(s, "%Y-%m-%d")
    except Exception:
        return None


def collect_entries(since_days=None):
    """Collect all OUTCOMES.jsonl entries across workspaces."""
    entries = []
    global_file = BUGS_ROOT / "OUTCOMES.jsonl"
    paths = [(global_file, "global")]
    # Per-workspace OUTCOMES.jsonl
    for ws_outcomes in BUGS_ROOT.glob("*-audit/OUTCOMES.jsonl"):
        paths.append((ws_outcomes, ws_outcomes.parent.name))
    for ws_outcomes in BUGS_ROOT.glob("*-recon/OUTCOMES.jsonl"):
        paths.append((ws_outcomes, ws_outcomes.parent.name))

    cutoff = None
    if since_days:
        cutoff = datetime.now()
        from datetime import timedelta
        cutoff = cutoff - timedelta(days=since_days)

    for path, source in paths:
        if not path.exists():
            continue
        try:
            with open(path) as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        d = json.loads(line)
                    except Exception:
                        continue
                    d["_source"] = source
                    # Filter by date
                    submit_date = parse_date(
                        d.get("submitted_at") or d.get("date_submitted") or d.get("drafted_at")
                    )
                    if cutoff and submit_date and submit_date < cutoff:
                        continue
                    entries.append(d)
        except Exception as e:
            print(f"WARN: failed to read {path}: {e}", file=sys.stderr)
    return entries


def analyze(entries, class_filter=None):
    """Group by class and compute per-class metrics."""
    by_class = {}
    for e in entries:
        cls = classify(
            e.get("finding", ""),
            e.get("tags", []),
            e.get("class"),
        )
        if class_filter and cls != class_filter:
            continue
        by_class.setdefault(cls, []).append(e)

    results = {}
    for cls, es in by_class.items():
        submissions = len(es)
        accepted_outcomes = ("accepted", "acknowledged", "fixed", "bounty_paid", "awarded")
        accepted = [e for e in es if e.get("outcome") in accepted_outcomes]
        acceptance_rate = len(accepted) / submissions if submissions else 0

        # days to accepted
        days_to_accept = []
        for e in accepted:
            submit = parse_date(
                e.get("submitted_at") or e.get("date_submitted") or e.get("drafted_at")
            )
            result = parse_date(
                e.get("result_at") or e.get("date_resolved")
            )
            if submit and result:
                days_to_accept.append((result - submit).days)

        # rewards
        rewards = []
        for e in accepted:
            r = e.get("reward", e.get("payout_usd", 0))
            try:
                r = float(r)
            except Exception:
                r = 0
            if r > 0:
                rewards.append(r)

        def median(lst):
            if not lst:
                return None
            s = sorted(lst)
            n = len(s)
            if n % 2:
                return s[n // 2]
            return (s[n // 2 - 1] + s[n // 2]) / 2

        def p90(lst):
            if not lst:
                return None
            s = sorted(lst)
            idx = int(0.9 * (len(s) - 1))
            return s[idx]

        results[cls] = {
            "submissions": submissions,
            "accepted": len(accepted),
            "acceptance_rate": round(acceptance_rate, 3),
            "median_days_to_accept": median(days_to_accept),
            "p90_days_to_accept": p90(days_to_accept),
            "avg_reward": round(sum(rewards) / len(rewards), 0) if rewards else None,
            "total_reward": sum(rewards),
            "reward_count": len(rewards),
        }
    return results


def render_table(results):
    """Terminal table."""
    # Sort by total_reward desc, then acceptance_rate
    rows = sorted(
        results.items(),
        key=lambda kv: (kv[1]["total_reward"], kv[1]["acceptance_rate"]),
        reverse=True,
    )
    header = f"{'CLASS':<22} {'SUB':>4} {'ACC':>4} {'RATE':>6} {'MED_D':>6} {'P90_D':>6} {'AVG_$':>10} {'TOTAL_$':>10}"
    print(header)
    print("-" * len(header))
    for cls, m in rows:
        def f(v, fmt):
            return fmt.format(v) if v is not None else "-"
        print(
            f"{cls:<22} "
            f"{m['submissions']:>4} "
            f"{m['accepted']:>4} "
            f"{m['acceptance_rate']:>6.1%} "
            f"{f(m['median_days_to_accept'], '{:>6.1f}')} "
            f"{f(m['p90_days_to_accept'], '{:>6}')} "
            f"{f(m['avg_reward'], '${:>9,.0f}')} "
            f"${m['total_reward']:>9,.0f}"
        )
    print()
    total_sub = sum(m["submissions"] for m in results.values())
    total_acc = sum(m["accepted"] for m in results.values())
    total_r = sum(m["total_reward"] for m in results.values())
    if total_sub:
        print(f"TOTAL: {total_sub} submissions, {total_acc} accepted ({total_acc/total_sub:.1%}), ${total_r:,.0f} paid")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", action="store_true", help="JSON output")
    ap.add_argument("--class", dest="class_filter", help="Filter to one class")
    ap.add_argument("--since", type=int, help="Only entries submitted in last N days")
    args = ap.parse_args()

    entries = collect_entries(since_days=args.since)
    if not entries:
        print("No OUTCOMES.jsonl entries found.", file=sys.stderr)
        sys.exit(1)

    results = analyze(entries, class_filter=args.class_filter)

    if args.json:
        print(json.dumps(results, indent=2, default=str))
    else:
        render_table(results)


if __name__ == "__main__":
    main()
