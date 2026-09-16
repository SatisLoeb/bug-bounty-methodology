#!/usr/bin/env bash
# Usage: drift-check.sh [id-substring-filter]   (no arg = all dossier repos)
# Compares each watched repo's baseline_head (frozen at verdict) vs current remote tip.
# DRIFT = new commits on the watched branch. TRIGGER = a new commit touches a re-arm path/keyword.
set -uo pipefail
WL=~/Desktop/drift-watch/watchlist.tsv
TRG=~/Desktop/drift-watch/triggers.tsv
FILTER="${1:-}"
declare -A TG_GLOB TG_KW
while IFS=$'\t' read -r id glob kw; do TG_GLOB[$id]="$glob"; TG_KW[$id]="$kw"; done < "$TRG"
printf "%-46s %-10s %s\n" "TARGET" "STATUS" "DETAIL"
printf '%.0s-' {1..110}; echo
tail -n +2 "$WL" | while IFS=$'\t' read -r id path remote branch base bdate dossier globs triggers; do
  [ "$dossier" = "yes" ] || continue
  [ -n "$FILTER" ] && [[ "$id" != *"$FILTER"* ]] && continue
  [ "$remote" = "none" ] && continue
  d=~/Desktop/"$path"; cd "$d" 2>/dev/null || { printf "%-46s %-10s %s\n" "$id" "ERR" "no dir"; continue; }
  [ "$branch" = "DETACHED" ] && { printf "%-46s %-10s %s\n" "$id" "FROZEN" "detached snapshot (contest/tag) — no drift"; continue; }
  timeout 45 git fetch -q origin "$branch" 2>/dev/null || { printf "%-46s %-10s %s\n" "$id" "FETCHERR" "fetch failed/timeout"; continue; }
  tip=$(git rev-parse --short FETCH_HEAD 2>/dev/null)
  if [ "$tip" = "$base" ]; then printf "%-46s %-10s %s\n" "$id" "no-drift" "still @ $base ($bdate)"; continue; fi
  n=$(git rev-list --count "$base"..FETCH_HEAD 2>/dev/null)
  g="${TG_GLOB[$id]:-$globs}"; kw="${TG_KW[$id]:-}"
  # path-scoped drift
  pathhits=$(git diff --name-only "$base"..FETCH_HEAD 2>/dev/null | grep -iE "${g//,/|}" | head -5 | tr '\n' ' ')
  # keyword/trigger hits in the new diff
  trg=""
  if [ -n "$kw" ] && [ "$kw" != "." ]; then
    trg=$(git log -p "$base"..FETCH_HEAD 2>/dev/null | grep -iE "^\+" | grep -iE "$kw" | head -3 | sed 's/^+//' | cut -c1-60 | tr '\n' '~')
  fi
  if [ -n "$trg" ]; then st="DRIFT+TRIG"; det="+$n commits; TRIGGER: $trg"
  elif [ -n "$pathhits" ]; then st="DRIFT*path"; det="+$n commits touching: $pathhits"
  else st="drift"; det="+$n commits (none on watched paths)"; fi
  printf "%-46s %-10s %s\n" "$id" "$st" "$det"
done
cd ~/Desktop
