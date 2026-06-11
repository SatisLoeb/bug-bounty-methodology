#!/usr/bin/env bash
# INVOCATION CONDITION: helper, called by bin/ scripts. Read/write .lifecycle-status.
# Usage: marker.sh <read|has|append|write> [args...]
set -euo pipefail

MARKER_FILE="${WORKSPACE:-$(pwd)}/.lifecycle-status"

cmd="${1:?Usage: marker.sh <read|has|append|write> ...}"
shift

case "$cmd" in
  read)
    cat "$MARKER_FILE" 2>/dev/null || true
    ;;
  has)
    pattern="${1:?pattern required}"
    grep -qE "$pattern" "$MARKER_FILE" 2>/dev/null
    ;;
  append)
    line="${1:?line required}"
    echo "$line" >> "$MARKER_FILE"
    ;;
  write)
    line="${1:?line required}"
    echo "$line" > "$MARKER_FILE"
    ;;
  *)
    echo "Usage: marker.sh <read|has|append|write> ..." >&2
    exit 1
    ;;
esac
