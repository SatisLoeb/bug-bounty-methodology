#!/usr/bin/env python3
"""
vuln-propagate.py — Cross-Protocol Vulnerability Propagator

Given a vulnerability in Protocol A, finds all forks that share the same
vulnerable code and checks if they're affected.

Usage:
    python3 vuln-propagate.py --parent "aave-v3" --file "Pool.sol" --function "liquidationCall" --pattern "collateralAmount.*=.*0"
    python3 vuln-propagate.py --parent-repo "https://github.com/aave/aave-v3-core" --vuln-line "src/Pool.sol:342"
"""

import sys
import os
import json
import subprocess
import tempfile
from pathlib import Path

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


def get_forks_from_defillama(parent_name):
    """Search DeFiLlama for protocols similar to the parent (same category, name match)."""
    if not HAS_REQUESTS:
        print("requests not installed. Install: pip install requests")
        return []

    try:
        resp = requests.get("https://api.llama.fi/protocols", timeout=15)
        protocols = resp.json()
    except Exception as e:
        print(f"DeFiLlama API error: {e}")
        return []

    parent_name_lower = parent_name.lower().replace("-", " ").replace("_", " ")
    parent_words = set(parent_name_lower.split())

    # Find the parent protocol to get its category
    parent_category = None
    for p in protocols:
        if p.get("slug", "").lower().replace("-", " ") == parent_name_lower or \
           p.get("name", "").lower() == parent_name_lower:
            parent_category = p.get("category")
            break

    forks = []
    for protocol in protocols:
        name = protocol.get("name", "").lower()
        slug = protocol.get("slug", "").lower()
        desc = (protocol.get("description") or "").lower()
        category = protocol.get("category", "")

        # Skip the parent itself
        if slug.replace("-", " ") == parent_name_lower or name == parent_name_lower:
            continue

        # Match: same category + name/description mentions parent
        is_match = False
        if parent_category and category == parent_category:
            # Check if description or name references the parent
            for word in parent_words:
                if len(word) > 3 and (word in name or word in desc or word in slug):
                    is_match = True
                    break

        # Also match protocols that explicitly reference parent in description
        if not is_match and any(w in desc for w in parent_words if len(w) > 3):
            is_match = True

        if is_match:
            github_urls = []
            url = protocol.get("url", "")
            if "github.com" in url:
                github_urls.append(url.replace("https://github.com/", ""))

            forks.append({
                "name": protocol.get("name", "Unknown"),
                "slug": protocol.get("slug", ""),
                "tvl": protocol.get("tvl", 0),
                "chains": protocol.get("chains", []),
                "url": url,
                "github": github_urls,
                "audits": protocol.get("audits", "0"),
                "audit_links": [],
            })

    return sorted(forks, key=lambda x: x.get("tvl", 0) or 0, reverse=True)[:30]


def check_fork_for_vulnerability(github_urls, vuln_file, vuln_pattern, vuln_function=None):
    """Clone a fork and check if the vulnerable code exists."""
    for github_url in github_urls:
        if not github_url:
            continue

        repo_url = f"https://github.com/{github_url}" if "github.com" not in github_url else github_url
        if not repo_url.startswith("http"):
            repo_url = f"https://github.com/{repo_url}"

        tmpdir = tempfile.mkdtemp()
        try:
            result = subprocess.run(
                ["git", "clone", "--depth", "1", repo_url, tmpdir + "/repo"],
                capture_output=True, text=True, timeout=30
            )
            if result.returncode != 0:
                continue

            repo_path = tmpdir + "/repo"

            # Search for the vulnerable file
            matches = list(Path(repo_path).rglob(vuln_file))
            if not matches:
                # Try just the filename
                matches = list(Path(repo_path).rglob(Path(vuln_file).name))

            for match_file in matches:
                content = match_file.read_text(errors="ignore")

                # Check for the vulnerability pattern
                import re
                if re.search(vuln_pattern, content):
                    # If function specified, verify it's in the right function
                    if vuln_function:
                        func_pattern = rf"function\s+{vuln_function}\b"
                        if not re.search(func_pattern, content):
                            continue

                    return {
                        "vulnerable": True,
                        "file": str(match_file.relative_to(repo_path)),
                        "repo": repo_url,
                    }

            return {"vulnerable": False, "repo": repo_url}

        except Exception as e:
            continue
        finally:
            subprocess.run(["rm", "-rf", tmpdir], capture_output=True)

    return {"vulnerable": None, "repo": "no accessible repo"}


def main():
    parent_name = None
    vuln_file = None
    vuln_pattern = None
    vuln_function = None
    parent_repo = None

    # Parse args
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--parent":
            parent_name = args[i + 1]; i += 2
        elif args[i] == "--file":
            vuln_file = args[i + 1]; i += 2
        elif args[i] == "--pattern":
            vuln_pattern = args[i + 1]; i += 2
        elif args[i] == "--function":
            vuln_function = args[i + 1]; i += 2
        elif args[i] == "--parent-repo":
            parent_repo = args[i + 1]; i += 2
        elif args[i] == "--vuln-line":
            parts = args[i + 1].split(":")
            vuln_file = parts[0]
            i += 2
        else:
            i += 1

    if not parent_name and not parent_repo:
        print("Usage: python3 vuln-propagate.py --parent 'aave-v3' --file 'Pool.sol' --pattern 'pattern'")
        print("       python3 vuln-propagate.py --parent-repo 'https://github.com/aave/aave-v3-core' --file 'Pool.sol' --pattern 'pattern'")
        sys.exit(1)

    if not parent_name:
        parent_name = parent_repo.split("/")[-1] if parent_repo else "unknown"

    print("=" * 60)
    print(f" Vulnerability Propagator")
    print(f" Parent: {parent_name}")
    print(f" File: {vuln_file}")
    print(f" Pattern: {vuln_pattern}")
    print(f" Function: {vuln_function or 'any'}")
    print("=" * 60)
    print()

    # Find forks via DeFiLlama
    print("[1/3] Searching DeFiLlama for forks...")
    forks = get_forks_from_defillama(parent_name)
    print(f"Found {len(forks)} forks.")
    print()

    if not forks:
        print("No forks found. Try a different parent name.")
        print("Common names: aave-v3, uniswap-v3, compound-v2, compound-v3, curve, balancer-v2")
        sys.exit(0)

    # Display forks
    print("[2/3] Fork list (by TVL):")
    print(f"{'Name':30s} {'TVL':>15s} {'Chains':20s} {'GitHub':30s}")
    print("-" * 95)
    for fork in forks[:20]:
        tvl = f"${fork['tvl']/1e6:.1f}M" if fork.get('tvl') and fork['tvl'] > 0 else "N/A"
        chains = ", ".join(fork.get("chains", [])[:3]) or "?"
        github = fork.get("github", [""])[0] if fork.get("github") else ""
        print(f"{fork['name']:30s} {tvl:>15s} {chains:20s} {github:30s}")
    print()

    # Check each fork for the vulnerability
    if vuln_file and vuln_pattern:
        print("[3/3] Checking forks for vulnerability...")
        print()

        vulnerable = []
        not_vulnerable = []
        unknown = []

        for fork in forks[:15]:  # Limit to top 15 by TVL
            github_urls = fork.get("github", [])
            if not github_urls:
                unknown.append(fork)
                continue

            print(f"  Checking {fork['name']}...", end=" ", flush=True)
            result = check_fork_for_vulnerability(github_urls, vuln_file, vuln_pattern, vuln_function)

            if result.get("vulnerable"):
                print(f"🔴 VULNERABLE — {result['file']}")
                fork["vuln_file"] = result["file"]
                fork["vuln_repo"] = result["repo"]
                vulnerable.append(fork)
            elif result.get("vulnerable") is False:
                print("✅ not vulnerable")
                not_vulnerable.append(fork)
            else:
                print("⚠ could not check")
                unknown.append(fork)

        # Summary
        print()
        print("=" * 60)
        print(f" RESULTS")
        print("=" * 60)
        print(f" 🔴 Vulnerable: {len(vulnerable)}")
        print(f" ✅ Not vulnerable: {len(not_vulnerable)}")
        print(f" ⚠ Unknown: {len(unknown)}")
        print()

        if vulnerable:
            print("VULNERABLE FORKS (submit findings to these):")
            print(f"{'Name':25s} {'TVL':>12s} {'File':30s} {'Repo':40s}")
            print("-" * 107)
            for fork in vulnerable:
                tvl = f"${fork['tvl']/1e6:.1f}M" if fork.get('tvl') and fork['tvl'] > 0 else "N/A"
                print(f"{fork['name']:25s} {tvl:>12s} {fork.get('vuln_file',''):30s} {fork.get('vuln_repo',''):40s}")

            total_tvl = sum(f.get("tvl", 0) or 0 for f in vulnerable)
            print(f"\nTotal TVL at risk: ${total_tvl/1e6:.1f}M across {len(vulnerable)} protocols")
    else:
        print("[3/3] Skipping vulnerability check (no --file and --pattern provided)")
        print("Provide --file and --pattern to check forks for the specific vulnerability.")


def github_code_search(pattern, language=None, max_results=30):
    """Search GitHub Code Search for a vulnerability pattern across all repos.
    Uses the GitHub code search API (no auth = limited, but works for targeted searches).
    """
    if not HAS_REQUESTS:
        print("requests not installed")
        return []

    query = pattern
    if language:
        query += f" language:{language}"

    headers = {"Accept": "application/vnd.github.v3+json"}
    # Check for GitHub token
    gh_token = os.environ.get("GITHUB_TOKEN", "")
    if gh_token:
        headers["Authorization"] = f"token {gh_token}"

    try:
        resp = requests.get(
            "https://api.github.com/search/code",
            params={"q": query, "per_page": min(max_results, 100)},
            headers=headers,
            timeout=15,
        )
        if resp.status_code == 200:
            data = resp.json()
            results = []
            seen_repos = set()
            for item in data.get("items", []):
                repo = item.get("repository", {}).get("full_name", "")
                if repo in seen_repos:
                    continue
                seen_repos.add(repo)
                results.append({
                    "repo": repo,
                    "file": item.get("path", ""),
                    "url": item.get("html_url", ""),
                    "score": item.get("score", 0),
                })
            return results
        elif resp.status_code == 403:
            print("[!] GitHub API rate limited. Set GITHUB_TOKEN env var for higher limits.")
            return []
        else:
            print(f"[!] GitHub search returned {resp.status_code}: {resp.text[:200]}")
            return []
    except Exception as e:
        print(f"[!] GitHub search error: {e}")
        return []


def pattern_search_mode(pattern, language, bounty_only=True):
    """Search for a vulnerability pattern across GitHub repos,
    cross-reference with DeFiLlama for TVL and bounty programs."""

    print(f"[1/3] Searching GitHub for pattern: {pattern}")
    if language:
        print(f"       Language filter: {language}")

    results = github_code_search(pattern, language)
    if not results:
        print("[!] No results from GitHub Code Search")
        return

    print(f"\n[2/3] Found {len(results)} repos. Cross-referencing with DeFiLlama...")

    # Get all DeFiLlama protocols for cross-reference
    try:
        resp = requests.get("https://api.llama.fi/protocols", timeout=15)
        protocols = resp.json()
    except Exception:
        protocols = []

    # Build github → protocol mapping
    github_to_protocol = {}
    for proto in protocols:
        for gh in proto.get("github", []):
            gh_lower = gh.lower()
            github_to_protocol[gh_lower] = {
                "name": proto.get("name", ""),
                "tvl": proto.get("tvl", 0),
                "chains": proto.get("chains", []),
                "category": proto.get("category", ""),
                "url": proto.get("url", ""),
            }

    # Enrich results
    enriched = []
    for r in results:
        owner = r["repo"].split("/")[0].lower() if "/" in r["repo"] else ""
        protocol = github_to_protocol.get(owner, {})
        enriched.append({
            **r,
            "protocol_name": protocol.get("name", ""),
            "tvl": protocol.get("tvl", 0),
            "chains": protocol.get("chains", []),
            "category": protocol.get("category", ""),
        })

    # Sort by TVL
    enriched.sort(key=lambda x: x.get("tvl", 0) or 0, reverse=True)

    # Display
    print(f"\n[3/3] Results ({len(enriched)} repos):\n")
    print(f"{'Repo':40s} {'Protocol':20s} {'TVL':>12s} {'File':30s}")
    print("-" * 102)
    for r in enriched[:30]:
        tvl = f"${r['tvl']/1e6:.1f}M" if r.get("tvl") and r["tvl"] > 0 else "—"
        proto = r.get("protocol_name", "") or "—"
        print(f"{r['repo']:40s} {proto:20s} {tvl:>12s} {r['file']:30s}")

    # Summary
    with_tvl = [r for r in enriched if r.get("tvl", 0) and r["tvl"] > 0]
    if with_tvl:
        total_tvl = sum(r["tvl"] for r in with_tvl)
        print(f"\n{len(with_tvl)} protocols with TVL found. Total TVL: ${total_tvl/1e6:.1f}M")
    print(f"\nFull URLs for manual review:")
    for r in enriched[:10]:
        print(f"  {r['url']}")


def main_with_pattern_search():
    """Extended main with --pattern-search mode."""
    if "--pattern-search" in sys.argv:
        import argparse
        parser = argparse.ArgumentParser()
        parser.add_argument("--pattern-search", required=True, help="Code pattern to search (e.g., 'validateMultisigFromProvidedConfig')")
        parser.add_argument("--language", default=None, help="Language filter (go, rust, solidity, java, python)")
        args, _ = parser.parse_known_args()
        pattern_search_mode(args.pattern_search, args.language)
    else:
        main()


if __name__ == "__main__":
    main_with_pattern_search()
