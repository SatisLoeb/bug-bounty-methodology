#!/usr/bin/env bash
# pattern-lift.sh — scan target against 47 H1 vulnerability patterns.
#
# Thin shell wrapper around pattern-lift.py (which does the actual work).
#
# Usage:
#   pattern-lift.sh <target-dir>
#   pattern-lift.sh --recon <workspace>
#   pattern-lift.sh --pattern P-H1-023 <target>
#   pattern-lift.sh --category auth <target>
set -euo pipefail

LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYLIB="$LIFECYCLE_DIR/lib/pattern-lift.py"

exec python3 "$PYLIB" "$@"
