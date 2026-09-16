#!/usr/bin/env bash
# Remote-safe drift check: NO local clones. Compares each watched repo's remote tip (git ls-remote)
# vs the stored baseline SHA. Runs anywhere with network (cloud routine, local, this session).
# Deep TRIGGER analysis (diff keyword) is skipped here; a DRIFT row is the alert to investigate locally.
set -uo pipefail
WL="${1:-$(dirname "$0")/remote-watchlist.tsv}"
drift=0
while IFS=$'\t' read -r id remote branch base; do
  [ -z "$remote" ] && continue
  url="https://github.com/${remote}.git"
  tip=$(timeout 30 git ls-remote "$url" "refs/heads/$branch" 2>/dev/null | awk '{print $1}' | head -1)
  [ -z "$tip" ] && { echo "FETCHERR  $id ($remote@$branch)"; continue; }
  short=${tip:0:${#base}}
  if [ "$short" = "$base" ]; then :; else echo "DRIFT     $id  $remote@$branch  $base -> ${tip:0:9}"; drift=$((drift+1)); fi
done < "$WL"
echo "---"
echo "drift count: $drift  (0 = nothing you've mapped has moved)"
