#!/usr/bin/env bash
# fortress-score.sh — DEPRECATED (2026-07-08 reform). Renamed to saturation-score.sh.
# "fortress" anchored a prove-null reflex ("HIGH → NO-GO, expected $0"); the score now
# names a RE-SOURCE target to a payable surface instead. Backward-compat shim.
exec "$(dirname "$0")/saturation-score.sh" "$@"
