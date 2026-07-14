#!/usr/bin/env bash
# onchain-read.sh — clean cast-based on-chain reads (avoids the error-prone Etherscan-curl + python-extraction
# pattern that caused repeated §0.5.3 self-corrections on the Boros engagement: newline-stripped addresses,
# off-by-one slot extraction, hand-decoded structs, garbage from wrong/assumed addresses).
#
# cast decodes EIP-1967 slots, struct returns, and proxies natively — use it, don't hand-parse hex.
#
# Usage:
#   onchain-read.sh proxy   <addr>                 # EIP-1967 impl + admin (cast handles the slots)
#   onchain-read.sh admin   <addr>                 # ProxyAdmin -> owner -> if Safe: threshold+owners (A20 check)
#   onchain-read.sh call    <addr> "<sig>" [args]  # cast call with full ABI decode (structs included)
#   onchain-read.sh slot    <addr> <slot>          # raw storage slot, clean
#   onchain-read.sh ctorargs <impl_addr> "<types>" # decode constructor args from the creation tx (e.g. "address,address")
#   onchain-read.sh src     <addr> <outdir>        # fetch verified source (Etherscan V2) -> outdir
#
# Env: RPC (default Arbitrum public), CHAIN (default 42161), ETHERSCAN_API_KEY (for src/ctorargs).
set -euo pipefail
RPC="${RPC:-https://arb1.arbitrum.io/rpc}"
CHAIN="${CHAIN:-42161}"
KEY="${ETHERSCAN_API_KEY:-}"
cmd="${1:-}"; shift || true

case "$cmd" in
  proxy)
    a="$1"
    echo "impl  : $(cast implementation "$a" --rpc-url "$RPC" 2>/dev/null || echo 'not EIP-1967 (impl slot 0)')"
    echo "admin : $(cast admin "$a" --rpc-url "$RPC" 2>/dev/null || echo 'not EIP-1967 (admin slot 0)')"
    ;;
  admin)
    a="$1"
    padm=$(cast admin "$a" --rpc-url "$RPC" 2>/dev/null || echo "")
    [ -z "$padm" ] || [ "$padm" = "0x0000000000000000000000000000000000000000" ] && { echo "no EIP-1967 admin (not a TUP, or immutable)"; exit 0; }
    echo "ProxyAdmin: $padm"
    own=$(cast call "$padm" "owner()(address)" --rpc-url "$RPC" 2>/dev/null || echo "")
    echo "owner: ${own:-<no owner()>}"
    # is the owner a Safe?
    thr=$(cast call "$own" "getThreshold()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo "")
    if [ -n "$thr" ]; then
      echo "  -> Safe threshold: $thr  (NOT single-key = sound)"
      echo "  -> owners: $(cast call "$own" "getOwners()(address[])" --rpc-url "$RPC" 2>/dev/null)"
    else
      code=$(cast code "$own" --rpc-url "$RPC" 2>/dev/null | wc -c)
      [ "$code" -lt 6 ] && echo "  -> ⚠️ owner is an EOA (single-key) = A20 candidate (but admin-key compromise usually OOS unless become-the-actor)" || echo "  -> owner is a contract (not a standard Safe — inspect its governance)"
    fi
    ;;
  call)  a="$1"; sig="$2"; shift 2; cast call "$a" "$sig" "$@" --rpc-url "$RPC" ;;
  slot)  cast storage "$1" "$2" --rpc-url "$RPC" ;;
  ctorargs)
    a="$1"; types="$2"
    tx=$(curl -s "https://api.etherscan.io/v2/api?chainid=$CHAIN&apikey=$KEY&module=contract&action=getcontractcreation&contractaddresses=$a" | python3 -c "import json,sys;print(json.load(sys.stdin)['result'][0]['txHash'])")
    inp=$(cast tx "$tx" input --rpc-url "$RPC" 2>/dev/null)
    n=$(echo "$types" | tr ',' '\n' | wc -l); tail=$((n*64))
    cast abi-decode "f($types)" "0x${inp: -$tail}" 2>/dev/null || echo "decode failed — check the type list / arg count"
    ;;
  src)
    a="$1"; out="$2"; mkdir -p "$out"
    curl -s "https://api.etherscan.io/v2/api?chainid=$CHAIN&apikey=$KEY&module=contract&action=getsourcecode&address=$a" | python3 -c "
import json,sys,os
r=json.load(sys.stdin)['result'][0]; print('name:',r.get('ContractName'),'proxy:',r.get('Proxy'))
sc=r.get('SourceCode','') or ''
if sc.startswith('{'):
    o=json.loads(sc[1:-1] if sc.startswith('{{') else sc)
    for p,v in o.get('sources',o).items():
        c=v.get('content') if isinstance(v,dict) else v
        if c: open('$out/'+os.path.basename(p),'w').write(c)
    print(len(o.get('sources',o)),'files ->','$out')
elif sc: open('$out/flat.sol','w').write(sc); print('flat ->','$out')
" ;;
  *) sed -n '2,22p' "$0" ;;
esac
