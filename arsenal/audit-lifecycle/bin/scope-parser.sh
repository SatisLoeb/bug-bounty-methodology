#!/usr/bin/env bash
# scope-parser.sh — wrapper around scope-parser.py
#
# Usage: scope-parser.sh <url-or-html-file> <output-path> [target-name]
set -euo pipefail

SRC="${1:?Usage: scope-parser.sh <url-or-file> <output> [target-name]}"
OUT="${2:?Usage: scope-parser.sh <url-or-file> <output> [target-name]}"
TARGET="${3:-unknown}"

LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 "$LIFECYCLE_DIR/lib/scope-parser.py" "$SRC" --output "$OUT" --target "$TARGET"
