#!/usr/bin/env bash
# evm-anchor.sh — the deployed-code-not-head anchor for any EVM target, in one command.
# Resolves proxy->impl, pulls Etherscan-v2 VERIFIED source to disk, and censuses value.
# Portable: needs only `cast` (foundry), `curl`, `python3`, $ETHERSCAN_API_KEY, an ETH RPC.
#
# Usage:
#   ETHERSCAN_API_KEY=... ./evm-anchor.sh <address> [outdir] [chainid] [rpc]
#     -> prints impl/admin, saves verified source to <outdir>/<ContractName>/, tries value views.
# Examples:
#   ./evm-anchor.sh 0xf6223C567F21E33e859ED7A045773526E9E3c2D5 ./anchor 1
set -euo pipefail

ADDR="${1:?usage: evm-anchor.sh <address> [outdir] [chainid] [rpc]}"
OUT="${2:-./anchor}"
CHAIN="${3:-1}"
RPC="${4:-https://ethereum.publicnode.com}"
KEY="${ETHERSCAN_API_KEY:?export ETHERSCAN_API_KEY (Etherscan v2, works across chains via chainid)}"

IMPL_SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc   # EIP-1967 impl
ADMIN_SLOT=0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103  # EIP-1967 admin
BEACON_SLOT=0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50 # EIP-1967 beacon
last40(){ local x="$1"; echo "0x${x: -40}"; }

echo "=== anchor $ADDR (chain $CHAIN) ==="
IMPLraw=$(cast storage "$ADDR" "$IMPL_SLOT" --rpc-url "$RPC" 2>/dev/null || echo "")
ADMINraw=$(cast storage "$ADDR" "$ADMIN_SLOT" --rpc-url "$RPC" 2>/dev/null || echo "")
BEACONraw=$(cast storage "$ADDR" "$BEACON_SLOT" --rpc-url "$RPC" 2>/dev/null || echo "")
IMPL=""; [ -n "$IMPLraw" ] && [ "$IMPLraw" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && IMPL=$(last40 "$IMPLraw")
[ -n "$IMPL" ] && echo "  proxy -> impl:  $IMPL" || echo "  (no EIP-1967 impl slot -> likely non-proxy; anchoring on $ADDR itself)"
[ -n "$ADMINraw" ] && [ "$ADMINraw" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && echo "  proxy admin:    $(last40 "$ADMINraw")   (upgrade authority — read owner()/Safe threshold next)"
[ -n "$BEACONraw" ] && [ "$BEACONraw" != "0x0000000000000000000000000000000000000000000000000000000000000000" ] && echo "  beacon:         $(last40 "$BEACONraw")"

TARGET="${IMPL:-$ADDR}"

echo "=== verified source for $TARGET -> $OUT ==="
mkdir -p "$OUT"
curl -s --max-time 30 "https://api.etherscan.io/v2/api?chainid=${CHAIN}&module=contract&action=getsourcecode&address=${TARGET}&apikey=${KEY}" -o "$OUT/.raw.json"
python3 - "$OUT" <<'PY'
import json,sys,os
out=sys.argv[1]; d=json.load(open(os.path.join(out,".raw.json")))
r=(d.get("result") or [{}])[0]
name=r.get("ContractName") or "Unverified"
print(f"  ContractName: {name} | compiler {r.get('CompilerVersion')} | proxy={r.get('Proxy')} impl={r.get('Implementation')}")
sc=r.get("SourceCode","") or ""
dst=os.path.join(out,name); os.makedirs(dst,exist_ok=True)
if sc.startswith("{{"):
    j=json.loads(sc[1:-1]); n=0
    for path,body in j.get("sources",{}).items():
        open(os.path.join(dst,os.path.basename(path)),"w").write(body.get("content","")); n+=1
    print(f"  wrote {n} files -> {dst}/")
elif sc.strip().startswith("{"):
    j=json.loads(sc); files=j.get("sources",j); n=0
    for path,body in files.items():
        c=body.get("content",body) if isinstance(body,dict) else body
        open(os.path.join(dst,os.path.basename(path)),"w").write(c); n+=1
    print(f"  wrote {n} files -> {dst}/")
elif sc:
    open(os.path.join(dst,name+".sol"),"w").write(sc); print(f"  wrote flat -> {dst}/{name}.sol")
else:
    print("  NOT VERIFIED on this explorer (bytecode only) — decompile/RE needed")
PY

echo "=== value census (best-effort common views on $ADDR) ==="
for sig in 'getContractValue()(uint256)' 'totalAssets()(uint256)' 'totalSupply()(uint256)' 'token()(address)' 'asset()(address)' 'paused()(bool)'; do
  v=$(cast call "$ADDR" "$sig" --rpc-url "$RPC" 2>/dev/null || echo "n/a")
  printf "  %-28s %s\n" "$sig" "$v"
done
echo "Done. Diff the deployed source against the repo/scope commit BEFORE hunting (deployed-code-not-head)."
