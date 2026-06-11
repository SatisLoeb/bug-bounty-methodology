#!/usr/bin/env python3
"""h1-monitor.py — HackerOne program monitor + hacktivity tracker.

Usage:
  python3 h1-monitor.py --new-programs              # Check for new public programs
  python3 h1-monitor.py --watch bybit_fintech       # Watch specific program updates
  python3 h1-monitor.py --hacktivity bybit_fintech   # Check recent disclosed reports
  python3 h1-monitor.py --search "crypto exchange"   # Search programs by keyword

Data sources:
  - HackerOne Directory API (public, no auth needed)
  - Program pages (public)
  - Hacktivity (public disclosures)
"""

import argparse
import json
import sys
import os
import time
from datetime import datetime, timedelta
from pathlib import Path

try:
    import requests
except ImportError:
    print("pip install requests --break-system-packages")
    sys.exit(1)

STATE_FILE = Path.home() / '.h1-monitor-state.json'
HEADERS = {'Accept': 'application/json', 'User-Agent': 'SecurityResearcher/1.0'}


def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {'known_programs': [], 'last_check': '', 'watched': {}}


def save_state(state):
    STATE_FILE.write_text(json.dumps(state, indent=2))


def fetch_directory(page=1, size=100):
    """Fetch HackerOne public program directory."""
    url = 'https://hackerone.com/directory/programs'
    params = {
        'asset_type': 'URL',
        'order_direction': 'DESC',
        'order_field': 'started_accepting_at',
        'page': page,
    }
    try:
        resp = requests.get(url, params=params, headers=HEADERS, timeout=15)
        if resp.status_code == 200:
            return resp.json()
    except Exception as e:
        print(f'Error fetching directory: {e}')
    return None


def check_new_programs():
    """Check for newly launched public programs."""
    state = load_state()
    known = set(state.get('known_programs', []))

    print('[*] Checking HackerOne for new programs...')
    data = fetch_directory()
    if not data:
        # Fallback: scrape the directory page
        print('[!] API failed, trying web scrape...')
        try:
            resp = requests.get('https://hackerone.com/opportunities/all/search?ordering=Newest+programs&asset_type=URL',
                              headers={'User-Agent': 'Mozilla/5.0'}, timeout=15)
            print(f'[*] Got {resp.status_code} from opportunities page')
        except Exception as e:
            print(f'[!] Scrape also failed: {e}')
        return

    programs = data.get('data', data) if isinstance(data, dict) else data
    if not isinstance(programs, list):
        print(f'[*] Response format: {type(data).__name__}, keys: {list(data.keys()) if isinstance(data, dict) else "N/A"}')
        return

    new_programs = []
    for prog in programs:
        handle = prog.get('handle', prog.get('attributes', {}).get('handle', ''))
        if handle and handle not in known:
            new_programs.append(prog)
            known.add(handle)

    if new_programs:
        print(f'\n[!] {len(new_programs)} NEW PROGRAMS:')
        for p in new_programs:
            attrs = p.get('attributes', p)
            name = attrs.get('name', attrs.get('handle', '?'))
            handle = attrs.get('handle', '?')
            bounty = attrs.get('offers_bounties', False)
            print(f'  + {name} (hackerone.com/{handle}) {"[BOUNTY]" if bounty else "[VDP]"}')
    else:
        print('[*] No new programs found')

    state['known_programs'] = list(known)
    state['last_check'] = datetime.now().isoformat()
    save_state(state)


def watch_program(handle):
    """Watch a specific program for updates."""
    state = load_state()
    url = f'https://hackerone.com/{handle}'

    print(f'[*] Fetching {url}...')
    try:
        resp = requests.get(url, headers={'User-Agent': 'Mozilla/5.0', 'Accept': 'text/html'}, timeout=15)
        if resp.status_code == 200:
            # Extract basic info from HTML
            text = resp.text
            # Look for bounty table, scope changes, policy updates
            if 'scope' in text.lower():
                print(f'[*] Program {handle} is live')

            # Check for scope changes by comparing content hash
            import hashlib
            content_hash = hashlib.md5(text.encode()).hexdigest()
            prev_hash = state.get('watched', {}).get(handle, {}).get('hash', '')

            if prev_hash and prev_hash != content_hash:
                print(f'[!] CHANGE DETECTED on {handle}! Scope or policy may have been updated.')
            elif not prev_hash:
                print(f'[*] First check for {handle}, baseline saved.')
            else:
                print(f'[*] No changes on {handle}')

            state.setdefault('watched', {})[handle] = {
                'hash': content_hash,
                'last_check': datetime.now().isoformat(),
            }
            save_state(state)
        else:
            print(f'[!] Got {resp.status_code} for {handle}')
    except Exception as e:
        print(f'[!] Error: {e}')


def check_hacktivity(handle):
    """Check recent public disclosures for a program."""
    print(f'[*] Checking hacktivity for {handle}...')

    # HackerOne hacktivity requires GraphQL or JS rendering
    # Use the public API endpoint
    url = f'https://hackerone.com/graphql'
    query = {
        'operationName': 'HacktivityPageQuery',
        'variables': {
            'where': {'program': {'handle': {'_eq': handle}}},
            'orderBy': {'field': 'popular', 'direction': 'DESC'},
            'count': 10,
        },
        'query': '''query HacktivityPageQuery($where: FiltersHacktivityItemFilterInput, $orderBy: HacktivityItemOrderInput, $count: Int) {
            hacktivity_items(where: $where, order_by: $orderBy, first: $count) {
                edges { node { ... on HacktivityItemInterface { id, databaseId, title, severity_rating, disclosed_at } } }
            }
        }'''
    }

    try:
        resp = requests.post(url, json=query, headers={**HEADERS, 'Content-Type': 'application/json'}, timeout=15)
        if resp.status_code == 200:
            data = resp.json()
            items = data.get('data', {}).get('hacktivity_items', {}).get('edges', [])
            if items:
                print(f'\n[*] {len(items)} disclosed reports for {handle}:')
                for item in items:
                    node = item.get('node', {})
                    print(f'  - [{node.get("severity_rating", "?")}] {node.get("title", "?")} ({node.get("disclosed_at", "?")})')
            else:
                print(f'[*] No public disclosures for {handle}')
        else:
            print(f'[*] Hacktivity query returned {resp.status_code} — may need auth or JS rendering')
    except Exception as e:
        print(f'[!] Error: {e}')


def search_programs(keyword):
    """Search for programs matching keyword."""
    print(f'[*] Searching HackerOne for "{keyword}"...')

    url = 'https://hackerone.com/graphql'
    query = {
        'operationName': 'DirectoryQuery',
        'variables': {'where': {'_and': [{'_or': [
            {'name': {'_ilike': f'%{keyword}%'}},
            {'handle': {'_ilike': f'%{keyword}%'}},
        ]}]}, 'count': 20},
        'query': '''query DirectoryQuery($where: FiltersTeamFilterInput, $count: Int) {
            teams(where: $where, first: $count) {
                edges { node { name, handle, offers_bounties, state, started_accepting_at } }
            }
        }'''
    }

    try:
        resp = requests.post(url, json=query, headers={**HEADERS, 'Content-Type': 'application/json'}, timeout=15)
        if resp.status_code == 200:
            data = resp.json()
            teams = data.get('data', {}).get('teams', {}).get('edges', [])
            if teams:
                for t in teams:
                    node = t.get('node', {})
                    bounty = '[BOUNTY]' if node.get('offers_bounties') else '[VDP]'
                    state = node.get('state', '?')
                    print(f'  {node.get("name")} — hackerone.com/{node.get("handle")} {bounty} ({state})')
            else:
                print(f'[*] No programs found for "{keyword}"')
        else:
            print(f'[*] Search returned {resp.status_code}')
    except Exception as e:
        print(f'[!] Error: {e}')


def main():
    parser = argparse.ArgumentParser(description='HackerOne program monitor')
    parser.add_argument('--new-programs', action='store_true', help='Check for new programs')
    parser.add_argument('--watch', help='Watch a specific program handle')
    parser.add_argument('--hacktivity', help='Check disclosed reports for a program')
    parser.add_argument('--search', help='Search programs by keyword')
    args = parser.parse_args()

    if args.new_programs:
        check_new_programs()
    elif args.watch:
        watch_program(args.watch)
    elif args.hacktivity:
        check_hacktivity(args.hacktivity)
    elif args.search:
        search_programs(args.search)
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
