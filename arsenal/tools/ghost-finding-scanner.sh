#!/usr/bin/env bash
# ghost-finding-scanner.sh — cross-protocol severity retargeting via audit-report DB
#
# Phase A skeleton. Phase B: wire C4/Cantina/Sherlock report ingestion + fork index.
#
# Usage:
#   ./ghost-finding-scanner.sh --update-db                  # ingest new audit reports
#   ./ghost-finding-scanner.sh --add-fork <parent> <fork>   # register a fork
#   ./ghost-finding-scanner.sh --scan <fork-name>           # find ghost matches for a fork
#   ./ghost-finding-scanner.sh --list-classes               # summarize vuln classes in DB
set -euo pipefail

DB="$HOME/arsenal/tracking/ghost-findings.jsonl"
FORKS="$HOME/arsenal/tracking/fork-index.jsonl"

mkdir -p "$(dirname "$DB")"

case "${1:-}" in
  --update-db)
    echo "[stub] ingest audit reports from C4 / Cantina / Sherlock (Phase B)"
    echo "Sources:"
    echo "  - code-423n4.com/reports"
    echo "  - cantina.xyz/portfolio"
    echo "  - audits.sherlock.xyz"
    echo "  - spearbit.com/portfolio"
    echo ""
    echo "Each finding ingested with fields:"
    echo "  id, protocol, audit_platform, date, severity, class, affected_function, root_cause, fix_commit, bounty_paid"
    ;;
  --add-fork)
    shift
    PARENT="${1:?parent protocol required}"; FORK="${2:?fork name required}"
    FORK_REPO="${3:-}"; FORK_CHAIN="${4:-ethereum}"; FORK_COMMIT="${5:-HEAD}"
    jq -c -n \
      --arg parent "$PARENT" \
      --arg fork "$FORK" \
      --arg fork_repo "$FORK_REPO" \
      --arg fork_chain "$FORK_CHAIN" \
      --arg fork_commit "$FORK_COMMIT" \
      '{parent: $parent, fork: $fork, fork_repo: $fork_repo, fork_chain: $fork_chain, fork_commit: $fork_commit}' \
      >> "$FORKS"
    echo "added: $FORK (fork of $PARENT)"
    ;;
  --scan)
    shift
    FORK="${1:?fork name required}"
    [ ! -f "$FORKS" ] && echo "no fork index" && exit 1
    [ ! -f "$DB" ] && echo "no findings DB — run --update-db first" && exit 1

    # Look up fork's parent
    fork_entry=$(grep -F "\"fork\":\"$FORK\"" "$FORKS" | head -1)
    [ -z "$fork_entry" ] && echo "fork $FORK not registered" && exit 1

    parent=$(echo "$fork_entry" | jq -r .parent)
    echo "[scan] ghost findings from $parent applicable to $FORK"
    jq -c --arg p "$parent" 'select(.protocol == $p) | {id, severity, class, affected_function, fix_commit}' "$DB"
    echo ""
    echo "[stub] For each: verify cognate code in $FORK, check fix present, reassess severity (Phase B)"
    ;;
  --list-classes)
    [ ! -f "$DB" ] && echo "no DB" && exit 0
    jq -r '.class' "$DB" | sort | uniq -c | sort -rn
    ;;
  *)
    cat <<EOF
ghost-finding-scanner.sh

Usage:
  --update-db                           ingest new audit reports (Phase B)
  --add-fork <parent> <fork> [repo] [chain] [commit]
                                        register a fork
  --scan <fork-name>                    find ghost matches for a fork
  --list-classes                        summarize vuln classes in DB

See ~/arsenal/methodology/GHOST-FINDING-TRANSFER.md for the full pipeline.
EOF
    ;;
esac
