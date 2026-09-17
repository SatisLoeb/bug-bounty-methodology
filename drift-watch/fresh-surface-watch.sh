#!/usr/bin/env bash
# fresh-surface-watch.sh — the A5 channel: watch for FRESH SURFACE, not fortress-HEAD churn.
# Two signals the repo-HEAD drift-watch is blind to:
#   A5a NEW-REPO  : a seam-dense org ships a NEW repo = a new product = fresh (often Tier-0) surface.
#   A5b IMPL-DRIFT: a known proxy's EIP-1967 impl slot CHANGES = fresh DEPLOYED code (deployed!=repo,
#                   the lesson from the 2026-09-17 Lombard A1 pass — HEAD watching misses deployments).
# READ-ONLY. Needs: gh (authed), cast, $ETHERSCAN_API_KEY not required (uses public RPC).
# Usage: ./fresh-surface-watch.sh [--baseline]   (--baseline re-freezes current state, no alert)
set -uo pipefail
DIR=~/Desktop/drift-watch/fresh-surface
RPC="${ETH_RPC:-https://ethereum.publicnode.com}"
MODE="${1:-check}"
IMPL_SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
mkdir -p "$DIR"
last40(){ echo "0x${1: -40}"; }
ALERTS=""

# ---------- A5a: new-repo detection ----------
export GH_PAGER=cat
while read -r org; do
  [ -z "$org" ] && continue
  cur=$(gh repo list "$org" --limit 200 --json name,isFork --jq '.[] | select(.isFork==false) | .name' 2>/dev/null | sort)
  base="$DIR/repos.$org.baseline"
  if [ "$MODE" = "--baseline" ] || [ ! -f "$base" ]; then echo "$cur" > "$base"; continue; fi
  new=$(comm -13 "$base" <(echo "$cur") 2>/dev/null)
  [ -n "$new" ] && while read -r r; do [ -n "$r" ] && ALERTS+="NEW-REPO  $org/$r  (fresh surface — audit before the field)"$'\n'; done <<< "$new"
done < "$DIR/orgs.txt"

# ---------- A5b: impl-upgrade detection (deployed-not-head) ----------
# proxies.tsv:  id \t proxy_addr \t chainid   (rpc per chain via ETH_RPC override if not mainnet)
PROX="$DIR/proxies.tsv"
if [ -f "$PROX" ]; then
  while IFS=$'\t' read -r id addr chain; do
    [ -z "${id:-}" ] && continue; [[ "$id" == \#* ]] && continue
    raw=$(cast storage "$addr" "$IMPL_SLOT" --rpc-url "$RPC" 2>/dev/null || echo "")
    [ -z "$raw" ] && continue
    [ "$raw" = "0x0000000000000000000000000000000000000000000000000000000000000000" ] && continue
    impl=$(last40 "$raw")
    bfile="$DIR/impl.$id"
    if [ "$MODE" = "--baseline" ] || [ ! -f "$bfile" ]; then echo "$impl" > "$bfile"; continue; fi
    old=$(cat "$bfile")
    if [ "${impl,,}" != "${old,,}" ]; then
      ALERTS+="IMPL-DRIFT $id  $old -> $impl  (proxy $addr upgraded = fresh deployed code — diff vs repo NOW)"$'\n'
      echo "$impl" > "$bfile"
    fi
  done < "$PROX"
fi

TODAY=$(date -u +%Y-%m-%d)
if [ "$MODE" = "--baseline" ]; then echo "fresh-surface-watch: baseline refrozen $TODAY"; exit 0; fi
if [ -z "$ALERTS" ]; then echo "fresh-surface-watch: NO fresh surface, $TODAY"; else echo "=== FRESH SURFACE $TODAY ==="; printf "%s" "$ALERTS"; fi
