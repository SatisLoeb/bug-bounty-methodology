#!/usr/bin/env bash
# daily-local.sh — LOCAL daily backstop for the re-arm targets the cloud routine does not yet carry
# (rows 19-27) PLUS the on-chain value channel (A6) the cloud egress cannot reach.
# The cloud routine (trig_01J8z1dJDsjqJHtjYnbyi2ca, 07:00 UTC) owns HEAD rows 1-18 + emails a draft.
# This is a log-only backstop (no email) so it never double-alerts; read the log / the ALERT file.
# Run by cron; also runnable by hand. READ-ONLY (git ls-remote + public Hiro reads).
set -uo pipefail
DIR=~/Desktop/drift-watch
LOG="$DIR/daily-local.log"
TODAY=$(date -u +%Y-%m-%dT%H:%M:%SZ)
{
  echo "=== daily-local $TODAY ==="
  echo "-- HEAD drift (rows 19-27, ls-remote) --"
  head=$(bash "$DIR/drift-check-remote.sh" "$DIR/daily-watch.new.tsv" 2>&1)
  echo "$head"
  echo "-- on-chain value (A6) --"
  oc=$(bash "$DIR/onchain-value-watch.sh" 2>&1)
  echo "$oc"
  # raise an ALERT file if anything actionable fired
  if echo "$head" | grep -q '^DRIFT ' || echo "$oc" | grep -qE 'FUNDED|DEPLOY|GROW|NEW-KEY'; then
    AF="$DIR/ALERT-$(date -u +%Y%m%d).txt"
    { echo "drift-watch local backstop — $TODAY"; echo; echo "$head"; echo; echo "$oc"; } > "$AF"
    echo ">> ALERT written: $AF"
  fi
  echo
} >> "$LOG" 2>&1
tail -1 "$LOG" >/dev/null
