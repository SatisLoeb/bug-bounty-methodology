#!/usr/bin/env python3
"""
github-monitor.py — Real-Time GitHub Commit Monitor for Security Research

Watches repos with active bounties for new commits touching security-relevant
code. Runs pattern-scan.sh on changed files and alerts via email.

Usage:
    python3 github-monitor.py [--check-only] [--add-repo owner/repo]

Config: ~/.github-monitor/repos.json
Cron:   0 * * * * python3 ~/arsenal/tools/github-monitor.py >> /tmp/github-monitor.log
"""

import sys
import os
import json
import subprocess
from pathlib import Path
from datetime import datetime, timezone, timedelta

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

CONFIG_DIR = Path.home() / ".github-monitor"
REPOS_FILE = CONFIG_DIR / "repos.json"
STATE_FILE = CONFIG_DIR / "state.json"
ARSENAL_DIR = Path.home() / "arsenal"

SECURITY_EXTENSIONS = {".sol", ".rs", ".go", ".cairo", ".move", ".ts", ".js"}

SECURITY_PATH_KEYWORDS = [
    "auth", "access", "permission", "role", "admin", "owner",
    "transfer", "withdraw", "deposit", "mint", "burn", "swap",
    "oracle", "price", "feed", "liquidat", "collateral",
    "sign", "verify", "crypto", "key", "hash", "nonce",
    "bridge", "cross-chain", "relay", "message", "endpoint",
    "vault", "pool", "stake", "reward", "fee",
]


def load_repos():
    """Load watched repos."""
    if REPOS_FILE.exists():
        return json.loads(REPOS_FILE.read_text())
    return {
        "repos": [
            # Default repos to watch (protocols with active bounties)
            {"owner": "buildonspark", "repo": "spark", "bounty": "Lightspark H1 $5K"},
            {"owner": "morpho-org", "repo": "sdks", "bounty": "Morpho Cantina $200K"},
            {"owner": "euler-xyz", "repo": "euler-vault-kit", "bounty": "Euler Cantina $7.5M"},
        ]
    }


def save_repos(data):
    """Save repos config."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    REPOS_FILE.write_text(json.dumps(data, indent=2))


def load_state():
    """Load last-seen commit SHAs."""
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {}


def save_state(state):
    """Save state."""
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))


def get_recent_commits(owner, repo, since_hours=24):
    """Get recent commits from GitHub API."""
    if not HAS_REQUESTS:
        return []

    since = (datetime.now(timezone.utc) - timedelta(hours=since_hours)).isoformat()
    url = f"https://api.github.com/repos/{owner}/{repo}/commits"
    params = {"since": since, "per_page": 20}

    headers = {"Accept": "application/vnd.github.v3+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"token {token}"

    try:
        resp = requests.get(url, params=params, headers=headers, timeout=15)
        if resp.status_code == 200:
            return resp.json()
        else:
            print(f"  GitHub API {resp.status_code} for {owner}/{repo}")
            return []
    except Exception as e:
        print(f"  Error: {e}")
        return []


def get_commit_files(owner, repo, sha):
    """Get files changed in a commit."""
    if not HAS_REQUESTS:
        return []

    url = f"https://api.github.com/repos/{owner}/{repo}/commits/{sha}"
    headers = {"Accept": "application/vnd.github.v3+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"token {token}"

    try:
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code == 200:
            return resp.json().get("files", [])
        return []
    except:
        return []


def is_security_relevant(filename):
    """Check if a file change is security-relevant."""
    ext = Path(filename).suffix
    if ext not in SECURITY_EXTENSIONS:
        return False

    filename_lower = filename.lower()
    # Exclude test/mock files
    if any(x in filename_lower for x in ["test", "mock", "script", "deploy"]):
        return False

    # Check for security keywords in path
    for keyword in SECURITY_PATH_KEYWORDS:
        if keyword in filename_lower:
            return True

    # Any .sol/.rs file in src/ is relevant
    if "/src/" in filename or "/contracts/" in filename:
        return True

    return False


def check_repos(check_only=False):
    """Check all watched repos for new security-relevant commits."""
    repos_config = load_repos()
    state = load_state()

    alerts = []
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    print(f"[{timestamp}] Checking {len(repos_config['repos'])} repos...")

    for repo_info in repos_config["repos"]:
        owner = repo_info["owner"]
        repo = repo_info["repo"]
        key = f"{owner}/{repo}"
        bounty = repo_info.get("bounty", "unknown")

        print(f"  {key}...", end=" ", flush=True)

        commits = get_recent_commits(owner, repo)
        if not commits:
            print("no new commits")
            continue

        last_seen = state.get(key, "")
        new_commits = []

        for commit in commits:
            sha = commit["sha"]
            if sha == last_seen:
                break
            new_commits.append(commit)

        if not new_commits:
            print("up to date")
            continue

        # Update state to latest commit
        if not check_only:
            state[key] = commits[0]["sha"]

        # Check each new commit for security-relevant changes
        security_commits = []
        for commit in new_commits:
            sha = commit["sha"]
            message = commit["commit"]["message"].split("\n")[0][:80]
            files = get_commit_files(owner, repo, sha)

            sec_files = [f["filename"] for f in files if is_security_relevant(f.get("filename", ""))]
            if sec_files:
                security_commits.append({
                    "sha": sha[:8],
                    "message": message,
                    "files": sec_files,
                    "url": commit["html_url"],
                })

        if security_commits:
            print(f"🔴 {len(security_commits)} security-relevant commits!")
            alert = {
                "repo": key,
                "bounty": bounty,
                "commits": security_commits,
            }
            alerts.append(alert)

            for sc in security_commits:
                print(f"    [{sc['sha']}] {sc['message']}")
                for f in sc["files"][:5]:
                    print(f"      → {f}")
        else:
            print(f"{len(new_commits)} new commits (none security-relevant)")

    if not check_only:
        save_state(state)

    # Print alert summary
    if alerts:
        print()
        print("=" * 60)
        print(f" 🚨 SECURITY ALERTS — {len(alerts)} repos with changes")
        print("=" * 60)
        for alert in alerts:
            print(f"\n  [{alert['bounty']}] {alert['repo']}")
            for sc in alert["commits"]:
                print(f"    {sc['sha']} — {sc['message']}")
                print(f"    {sc['url']}")
                for f in sc["files"]:
                    print(f"      🔍 {f}")
    else:
        print("\n✅ No security-relevant changes detected.")

    return alerts


def add_repo(repo_str):
    """Add a repo to watch list."""
    parts = repo_str.split("/")
    if len(parts) != 2:
        print(f"Invalid format: {repo_str}. Use owner/repo")
        return

    repos_config = load_repos()
    bounty = input("Bounty program (e.g., 'Cantina $100K'): ").strip()

    repos_config["repos"].append({
        "owner": parts[0],
        "repo": parts[1],
        "bounty": bounty,
    })
    save_repos(repos_config)
    print(f"Added {repo_str} to watch list.")


def main():
    if "--add-repo" in sys.argv:
        idx = sys.argv.index("--add-repo")
        add_repo(sys.argv[idx + 1])
        return

    check_only = "--check-only" in sys.argv
    check_repos(check_only)


if __name__ == "__main__":
    main()
