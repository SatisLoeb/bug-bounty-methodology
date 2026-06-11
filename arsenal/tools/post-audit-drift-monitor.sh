#!/usr/bin/env bash
# post-audit-drift-monitor.sh — watch recently-audited protocols for security-sensitive commits
#
# Phase B: wired to gh api + drift scoring 0-10 + cron-ready.
#
# Usage:
#   ./post-audit-drift-monitor.sh --list                           list watched repos
#   ./post-audit-drift-monitor.sh --add <owner/repo> --audit-date YYYY-MM-DD --bounty-max N
#   ./post-audit-drift-monitor.sh --remove <owner/repo>            remove a watched repo
#   ./post-audit-drift-monitor.sh --scan [owner/repo]              scan for new commits since last_scan
#   ./post-audit-drift-monitor.sh --triage <owner/repo> <commit>   score a single commit 0-10
#   ./post-audit-drift-monitor.sh --cron                           scan all + auto-triage, log hits ≥5
#   ./post-audit-drift-monitor.sh --report                         show flagged commits ≥5 from log
#
# Logs:
#   ~/arsenal/tracking/audited-repos.jsonl   watched repos config
#   ~/arsenal/tracking/drift-flagged.jsonl   all flagged commits w/ scores
#   ~/arsenal/tracking/drift-cron.log        cron stdout

set -euo pipefail

CONFIG="$HOME/arsenal/tracking/audited-repos.jsonl"
LOG="$HOME/arsenal/tracking/drift-flagged.jsonl"
CRON_LOG="$HOME/arsenal/tracking/drift-cron.log"
MIN_SCORE="${MIN_SCORE:-5}"

mkdir -p "$(dirname "$CONFIG")"
touch "$LOG"

# ---- Helpers ----

fail() { echo "[error] $*" >&2; exit 1; }

require() {
  command -v "$1" >/dev/null 2>&1 || fail "missing dependency: $1"
}

require gh
require jq

# Compute drift score for a commit's file list + message + author.
# Input (stdin): JSON object with keys {sha, message, author, files[]}
# Output: integer score 0-N, one line per signal, final SCORE=N
score_commit() {
  jq -r '
    . as $c |
    [
      # +3 modifies contract source files (sol/rs/cairo/move in src or programs)
      ( if ($c.files | map(test("(^|/)(programs|src|contracts)/.*\\.(sol|rs|cairo|move)$")) | any) then
          "+3 modifies contract source"
        else empty end ),

      # +2 add/remove require or assert
      ( if ($c.files | map(test("\\.(sol|rs)$")) | any)
             and ($c.message | test("(?i)require|assert|revert|constraint")) then
          "+2 message mentions require/assert/constraint"
        else empty end ),

      # +3 access control change
      ( if $c.message | test("(?i)onlyOwner|hasRole|access[ _-]?control|admin|authority|keeper") then
          "+3 access control / authority / keeper change"
        else empty end ),

      # +2 arithmetic change
      ( if $c.message | test("(?i)mul[dD]iv|overflow|underflow|precision|rounding|truncat|as u(8|16|32|64)") then
          "+2 arithmetic / cast change"
        else empty end ),

      # +3 storage layout / upgradeable
      ( if $c.message | test("(?i)storage|slot|layout|upgrad|migrat|proxy") then
          "+3 storage layout / upgrade touch"
        else empty end ),

      # +3 dep bump on crypto-adjacent lib
      ( if ($c.files | map(test("(Cargo\\.toml|Cargo\\.lock|package\\.json|yarn\\.lock|foundry\\.toml|remappings\\.txt)$")) | any)
             and ($c.message | test("(?i)bump|upgrade|update.*(?:solana|anchor|curve|ecrecover|keccak|sha|hash|signature|crypto)")) then
          "+3 crypto-adjacent dep bump"
        else empty end ),

      # +2 commit message contains fix/security/vuln/cve
      ( if $c.message | test("(?i)\\bfix\\b|\\bsecurity\\b|\\bvuln|\\bCVE\\b|\\bpatch\\b|\\bexploit\\b") then
          "+2 commit msg: fix/security/vuln/patch"
        else empty end ),

      # +1 feature branch merge
      ( if $c.message | test("(?i)Merge.*feat|feature") then
          "+1 feature-branch merge"
        else empty end ),

      # +3 oracle / price / liquidation touch
      ( if ($c.files | map(test("(?i)oracle|price|feed|liquidat")) | any)
             or ($c.message | test("(?i)oracle|price[ _-]?feed|liquidat")) then
          "+3 oracle / price / liquidation touch"
        else empty end ),

      # +3 bridge / cross-chain touch
      ( if ($c.files | map(test("(?i)bridge|relay|message|endpoint|cross[ _-]?chain")) | any)
             or ($c.message | test("(?i)bridge|relay|cross[ _-]?chain")) then
          "+3 bridge / cross-chain touch"
        else empty end )
    ]
    | map(select(. != null))
    | (. as $reasons | ($reasons | map(capture("\\+(?<n>[0-9]+)") | .n | tonumber) | add // 0) as $total
       | $reasons[], "SCORE=\($total)")
  '
}

# Fetch commit details via gh api (sha, message, author, files[])
fetch_commit_json() {
  local repo="$1" sha="$2"
  gh api "repos/$repo/commits/$sha" --cache 1h 2>/dev/null | jq -c '{
    sha: .sha,
    message: .commit.message,
    author: (.commit.author.name // ""),
    date: (.commit.author.date // ""),
    files: (.files // [] | map(.filename))
  }'
}

# ---- Commands ----

cmd_list() {
  [ ! -s "$CONFIG" ] && echo "no watched repos" && return 0
  jq -c '{repo, audit_date, bounty_max, last_scan}' "$CONFIG"
}

cmd_add() {
  local REPO="$1"; shift
  local AUDIT_DATE="" BOUNTY_MAX="0"
  while [ $# -gt 0 ]; do
    case "$1" in
      --audit-date) AUDIT_DATE="$2"; shift 2 ;;
      --bounty-max) BOUNTY_MAX="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -z "$AUDIT_DATE" ] && fail "--audit-date YYYY-MM-DD required"
  # Dedupe
  if [ -s "$CONFIG" ] && jq -e --arg r "$REPO" 'select(.repo == $r)' "$CONFIG" >/dev/null 2>&1; then
    echo "[skip] $REPO already in config"
    return 0
  fi
  jq -c -n \
    --arg repo "$REPO" \
    --arg audit_date "$AUDIT_DATE" \
    --argjson bounty_max "$BOUNTY_MAX" \
    --arg last_scan "" \
    '{repo: $repo, audit_date: $audit_date, bounty_max: $bounty_max, last_scan: $last_scan}' \
    >> "$CONFIG"
  echo "added: $REPO (audit=$AUDIT_DATE bounty_max=\$$BOUNTY_MAX)"
}

cmd_remove() {
  local REPO="$1"
  [ ! -s "$CONFIG" ] && fail "empty config"
  local TMP; TMP="$(mktemp)"
  jq -c --arg r "$REPO" 'select(.repo != $r)' "$CONFIG" > "$TMP"
  mv "$TMP" "$CONFIG"
  echo "removed: $REPO"
}

cmd_scan() {
  local REPO_FILTER="${1:-}"
  [ ! -s "$CONFIG" ] && fail "no watched repos — add first with --add"

  local NOW; NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local TMP; TMP="$(mktemp)"

  while IFS= read -r entry; do
    local repo audit_date last_scan since
    repo=$(echo "$entry" | jq -r .repo)
    [ -n "$REPO_FILTER" ] && [ "$repo" != "$REPO_FILTER" ] && { echo "$entry" >> "$TMP"; continue; }

    audit_date=$(echo "$entry" | jq -r .audit_date)
    last_scan=$(echo "$entry" | jq -r .last_scan)
    since="${last_scan:-${audit_date}T00:00:00Z}"

    echo "[scan] $repo since $since"

    local commits_json
    if ! commits_json="$(gh api "repos/$repo/commits?since=$since&per_page=100" --paginate 2>/dev/null)"; then
      echo "  [warn] gh api failed for $repo (rate limit or repo private/missing)"
      echo "$entry" >> "$TMP"
      continue
    fi

    local n
    n=$(echo "$commits_json" | jq -s 'map(length) | add // 0')
    echo "  fetched $n commits"

    # For each sha, fetch detailed commit (needed for files[])
    # Use process substitution to avoid subshell + pipe issues with `set -e`.
    local shas
    shas=$(echo "$commits_json" | jq -r '.[] | .sha' 2>/dev/null || true)
    if [ -n "$shas" ]; then
      while read -r sha; do
        [ -z "$sha" ] && continue
        local detail=""
        detail="$(fetch_commit_json "$repo" "$sha" 2>/dev/null || true)"
        [ -z "$detail" ] && continue
        local score_output=""
        score_output="$(echo "$detail" | score_commit 2>/dev/null || true)"
        [ -z "$score_output" ] && continue
        local score
        score=$(echo "$score_output" | grep -oE 'SCORE=[0-9]+' | tail -1 | cut -d= -f2)
        score="${score:-0}"
        local reasons
        reasons=$(echo "$score_output" | grep -v '^SCORE=' | jq -Rsc 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')

        jq -c -n \
          --arg repo "$repo" \
          --arg sha "$sha" \
          --argjson commit "$detail" \
          --argjson score "$score" \
          --argjson reasons "$reasons" \
          --arg scanned_at "$NOW" \
          '{repo: $repo, sha: $sha, score: $score, reasons: $reasons, commit: $commit, scanned_at: $scanned_at}' \
          >> "$LOG" || true

        if [ "$score" -ge "$MIN_SCORE" ]; then
          echo "  [FLAG score=$score] $sha $(echo "$detail" | jq -r '.message | split("\n")[0] | .[0:80]')"
        fi
      done <<< "$shas"
    fi

    echo "  [done] $repo"

    # Update last_scan for this entry
    echo "$entry" | jq -c --arg ts "$NOW" '.last_scan = $ts' >> "$TMP"
  done < "$CONFIG"

  mv "$TMP" "$CONFIG"
}

cmd_triage() {
  local REPO="$1" COMMIT="$2"
  local detail
  detail="$(fetch_commit_json "$REPO" "$COMMIT")" || fail "could not fetch $REPO@$COMMIT"
  echo "== $REPO @ $COMMIT =="
  echo "$detail" | jq -r '"author: \(.author)\ndate: \(.date)\nmessage:\n\(.message)\nfiles (\(.files | length)):"'
  echo "$detail" | jq -r '.files[] | "  \(.)"'
  echo "-- score --"
  echo "$detail" | score_commit
}

cmd_cron() {
  echo "=== drift-monitor cron run $(date -u +%Y-%m-%dT%H:%M:%SZ) ===" >> "$CRON_LOG"
  cmd_scan "" >> "$CRON_LOG" 2>&1 || true
  # Tail the flagged hits from this run
  local hits
  hits=$(jq -c --argjson min "$MIN_SCORE" --arg since "$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ)" \
    'select(.score >= $min and .scanned_at >= $since) | {repo, sha, score, msg: (.commit.message | split("\n")[0])}' \
    "$LOG" 2>/dev/null | head -50)
  if [ -n "$hits" ]; then
    echo "[cron] flagged commits this run:" >> "$CRON_LOG"
    echo "$hits" >> "$CRON_LOG"
  fi
}

cmd_report() {
  [ ! -s "$LOG" ] && echo "no flagged commits logged" && return 0
  echo "== flagged commits (score >= $MIN_SCORE) =="
  jq -c --argjson min "$MIN_SCORE" 'select(.score >= $min)' "$LOG" | \
    jq -r '"\(.scanned_at) [score=\(.score)] \(.repo) \(.sha[0:12]) \(.commit.message | split("\n")[0] | .[0:70])"' | \
    sort -u | tail -50
}

# ---- Dispatch ----

case "${1:-}" in
  --list)    shift; cmd_list ;;
  --add)     shift; cmd_add "$@" ;;
  --remove)  shift; cmd_remove "${1:?repo required}" ;;
  --scan)    shift; cmd_scan "${1:-}" ;;
  --triage)  shift; cmd_triage "${1:?repo required}" "${2:?commit required}" ;;
  --cron)    cmd_cron ;;
  --report)  cmd_report ;;
  *)
    sed -n '1,18p' "$0" | sed -n '6,18p'
    ;;
esac
