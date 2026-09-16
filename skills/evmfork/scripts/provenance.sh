#!/usr/bin/env bash
# provenance.sh <ADDR> [rpc]
# The EVM twin of solfork/scripts/provenance.sh. The HARD truth is keccak256 of the DEPLOYED runtime code
# (at the resolved IMPLEMENTATION for a proxy - the shell is stable, the impl is what you reason about).
#
# What the hash is FOR:
#   1. INTRA-SESSION INTEGRITY - you fork/attack the same target across days; this proves you are driving
#      the EXACT bytecode you reasoned about, not a silently re-pulled one.
#   2. IN-FLIGHT UPGRADE DETECTION - an upgradeable proxy can be re-pointed mid-hunt; the impl hash then
#      changes and your fork is STALE. Re-run anytime and it FLAGS the drift against the last recorded hash.
#
# RPC: arg 2, else $EVMFORK_RPC, else the local fork (127.0.0.1:8545), else publicnode.
set -euo pipefail
ADDR="${1:?usage: provenance.sh <ADDR> [rpc]}"
RPC="${2:-${EVMFORK_RPC:-}}"
if [ -z "$RPC" ]; then
  if cast block-number --rpc-url http://127.0.0.1:8545 >/dev/null 2>&1; then RPC="http://127.0.0.1:8545";
  else RPC="https://ethereum.publicnode.com"; fi
fi

# EIP-1967 slots
IMPL_SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
ADMIN_SLOT=0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
BEACON_SLOT=0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50

CODE=$(cast code "$ADDR" --rpc-url "$RPC")
BLOCK=$(cast block-number --rpc-url "$RPC")
if [ "$CODE" = "0x" ] || [ -z "$CODE" ]; then
  echo "address    : $ADDR"
  echo "code       : EMPTY (EOA or self-destructed) at block $BLOCK"
  exit 0
fi
HASH=$(cast keccak "$CODE")

echo "address    : $ADDR"
echo "block      : $BLOCK ($RPC)"
echo "code_hash  : $HASH  ($(( ${#CODE} / 2 - 1 )) bytes runtime)"

# resolve proxy implementation (EIP-1967 -> then a implementation() call as fallback)
IMPL_RAW=$(cast storage "$ADDR" "$IMPL_SLOT" --rpc-url "$RPC" 2>/dev/null || echo "")
IMPL=""
if [ -n "$IMPL_RAW" ] && [ "$IMPL_RAW" != "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
  IMPL="0x${IMPL_RAW: -40}"
else
  IMPL=$(cast call "$ADDR" "implementation()(address)" --rpc-url "$RPC" 2>/dev/null || echo "")
fi
TRACK_ADDR="$ADDR"; TRACK_HASH="$HASH"
if [ -n "$IMPL" ] && [ "$IMPL" != "0x0000000000000000000000000000000000000000" ]; then
  ADMIN_RAW=$(cast storage "$ADDR" "$ADMIN_SLOT" --rpc-url "$RPC" 2>/dev/null || echo "")
  IMPL_CODE=$(cast code "$IMPL" --rpc-url "$RPC")
  IMPL_HASH=$(cast keccak "$IMPL_CODE")
  echo "PROXY      : EIP-1967"
  echo "  impl     : $IMPL"
  echo "  impl_hash: $IMPL_HASH  ($(( ${#IMPL_CODE} / 2 - 1 )) bytes)  <-- reason about THIS"
  [ -n "$ADMIN_RAW" ] && [ "$ADMIN_RAW" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && \
    echo "  admin    : 0x${ADMIN_RAW: -40}"
  TRACK_ADDR="$IMPL"; TRACK_HASH="$IMPL_HASH"
fi

# drift check against the last hash recorded for the tracked (impl) address
LOG="${PROVENANCE_LOG:-PROVENANCE.log}"
PREV=$(grep -F "$TRACK_ADDR" "$LOG" 2>/dev/null | tail -1 | grep -oiP 'hash=\K0x[0-9a-f]+' || true)
if [ -n "$PREV" ] && [ "$PREV" != "$TRACK_HASH" ]; then
  echo "DRIFT      : live hash != last recorded ($PREV) - the contract/impl was REDEPLOYED/UPGRADED mid-hunt."
  echo "             Your fork/prior results are STALE: re-pin the fork block and re-reason."
fi
printf '%s  %s  hash=%s  block=%s\n' "$(date -u +%FT%TZ)" "$TRACK_ADDR" "$TRACK_HASH" "$BLOCK" >> "$LOG"
echo "recorded   -> $LOG  (re-run anytime to detect an in-flight upgrade)"
