#!/usr/bin/env bash
# provenance.sh <PROGRAM_ID> [prog.so]
# The IDL VERSION is a soft anchor; the HARD truth is the sha256 of the deployed bytecode
# (project-injective-swap-deployed-example-010: "code_hash = provenance truth").
#
# What the hash is actually FOR. A Solana scope gives a PROGRAM-ID, almost never a slot, and you can
# rarely reproducible-build the .so from a source commit — so "compare to the scope's pinned commit"
# usually has nothing to compare against (it only bites if the scope genuinely pins a slot or ships a
# verifiable build). The always-on value is two other things:
#   1. INTRA-SESSION INTEGRITY — you fork/attack the same target across days; this proves you are still
#      driving the EXACT bytecode you dumped and reasoned about, not a silently re-pulled one.
#   2. IN-FLIGHT UPGRADE DETECTION — an upgradeable program under active development can be redeployed
#      mid-hunt; the live code_hash then changes and your fork is STALE. Re-run this anytime and it
#      FLAGS the drift against the last hash recorded for this PID.
set -euo pipefail
PID="${1:?usage: provenance.sh <PROGRAM_ID> [prog.so]}"
SO="${2:-prog.so}"
RPC="${SOLFORK_RPC:-https://api.mainnet-beta.solana.com}"

# Always fetch the CURRENT deployed bytecode to a temp file and hash THAT, so the drift check reflects
# the live program independently of any stale local prog.so.
LIVE="$(mktemp)"; trap 'rm -f "$LIVE"' EXIT
solana program dump "$PID" "$LIVE" -u "$RPC" >/dev/null
HASH=$(sha256sum "$LIVE" | awk '{print $1}')
[ -f "$SO" ] || cp "$LIVE" "$SO"      # first run: keep the working copy the pipeline reuses

echo "program_id : $PID"
echo "bytecode   : $SO ($(stat -c%s "$LIVE") bytes, live)"
echo "code_hash  : $HASH"
solana program show "$PID" -u "$RPC" 2>/dev/null | grep -iE "Last Deployed|Authority" || true

# drift check against the last hash recorded for this PID (a program-id is base58/mixed-case, a hash is
# lowercase hex — no collision, so a plain grep for the PID is safe).
PREV=$(grep -F "$PID" PROVENANCE.log 2>/dev/null | tail -1 | grep -oP 'code_hash=\K[0-9a-f]+' || true)
if [ -n "$PREV" ] && [ "$PREV" != "$HASH" ]; then
  echo "⚠ DRIFT: live code_hash != last recorded ($PREV) — the program was REDEPLOYED mid-hunt."
  echo "         Your fork/prior results are STALE: re-dump ($SO), re-recover the IDL, rebuild the fork."
fi

printf '%s  %s  code_hash=%s\n' "$(date -u +%FT%TZ)" "$PID" "$HASH" >> PROVENANCE.log
echo "recorded -> PROVENANCE.log  (re-run anytime to detect an in-flight upgrade)"
