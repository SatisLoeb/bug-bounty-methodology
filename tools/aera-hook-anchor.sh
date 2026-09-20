#!/usr/bin/env bash
# aera-hook-anchor.sh — ancrage « deployed-code-not-head » + lectures live du TransferBlacklistHook Aera (Arbitrum).
# Compagnon du dossier memory/-home-malix-Desktop-BUGS/aera-transfer-blacklist-hook-arbitrum-immunefi.md.
#
# À exécuter depuis une machine à réseau ouvert : Etherscan v2 + RPC Arbitrum sont bloqués dans l'environnement
# Claude Code remote (403 policy). Ne fait QUE des lectures (getsourcecode, eth_call, eth_getLogs, eth_getCode).
#
# Deps : cast (foundry), curl, python3, $ETHERSCAN_API_KEY (v2, multi-chain), un RPC Arbitrum ($ARB_RPC_URL).
# Usage : tools/aera-hook-anchor.sh [hook] [outdir] [vault...]
#   hook    défaut 0xCe7Ea99545A6d0744a52Da9017729451Ec92A62C (scope Immunefi 18 Sep 2026)
#   outdir  défaut ./anchor/aera-hook
#   vault…  vaults supplémentaires à tester (défaut : gtUSDa Arbitrum 0x000000001DC8bd45d7E7829fb1c969cbe4D0D1eC)
set -euo pipefail

HOOK="${1:-0xCe7Ea99545A6d0744a52Da9017729451Ec92A62C}"
OUT="${2:-./anchor/aera-hook}"
shift $(( $# >= 2 ? 2 : $# )) || true
VAULTS=("$@")
[ ${#VAULTS[@]} -eq 0 ] && VAULTS=(0x000000001DC8bd45d7E7829fb1c969cbe4D0D1eC)

CHAIN=42161
RPC="${ARB_RPC_URL:-https://arb1.arbitrum.io/rpc}"
KEY="${ETHERSCAN_API_KEY:?export ETHERSCAN_API_KEY (Etherscan v2, fonctionne sur Arbitrum via chainid=42161)}"
SANCTIONS_ORACLE=0x40C57923924B5c5c5455c48D93317139ADDaC8fb   # Chainalysis, même adresse que mainnet (à confirmer ici)
ZERO32=0x0000000000000000000000000000000000000000000000000000000000000000
IMPL_SLOT=0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
ADMIN_SLOT=0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103
BEACON_SLOT=0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50

mkdir -p "$OUT"
call() { cast call "$1" "$2" "${@:3}" --rpc-url "$RPC" 2>/dev/null || echo "n/a"; }

echo "=== 1. proxy ? (slots EIP-1967) — attendu : non-proxy (Auth2Step)"
for s in IMPL_SLOT ADMIN_SLOT BEACON_SLOT; do
  v="$(cast storage "$HOOK" "${!s}" --rpc-url "$RPC" 2>/dev/null || echo "$ZERO32")"
  [ "$v" != "$ZERO32" ] && echo "  $s = 0x${v: -40}   <-- PROXY : ancrer sur l'impl" || echo "  $s vide"
done
echo "  codesize hook : $(cast code "$HOOK" --rpc-url "$RPC" | wc -c) hex chars"

echo "=== 2. source vérifié (Etherscan v2 chainid=$CHAIN) -> $OUT"
curl -s --max-time 40 "https://api.etherscan.io/v2/api?chainid=${CHAIN}&module=contract&action=getsourcecode&address=${HOOK}&apikey=${KEY}" -o "$OUT/.raw.json"
python3 - "$OUT" <<'PY'
import json, os, sys
out = sys.argv[1]
d = json.load(open(os.path.join(out, ".raw.json")))
r = (d.get("result") or [{}])[0]
if not isinstance(r, dict):
    print("  réponse inattendue :", str(d)[:300]); sys.exit(1)
name = r.get("ContractName") or "Unverified"
print(f"  ContractName: {name} | compiler {r.get('CompilerVersion')} | optimizer={r.get('OptimizationUsed')} runs={r.get('Runs')} | proxy={r.get('Proxy')}")
print(f"  ctor args: {r.get('ConstructorArguments')}")
open(os.path.join(out, "abi.json"), "w").write(r.get("ABI", "") or "")
sc = r.get("SourceCode", "") or ""
dst = os.path.join(out, name); os.makedirs(dst, exist_ok=True)
n = 0
if sc.startswith("{{"):
    for path, body in json.loads(sc[1:-1]).get("sources", {}).items():
        p = os.path.join(dst, path); os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, "w").write(body.get("content", "")); n += 1
elif sc.strip().startswith("{"):
    j = json.loads(sc); files = j.get("sources", j)
    for path, body in files.items():
        c = body.get("content", body) if isinstance(body, dict) else body
        p = os.path.join(dst, path); os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p, "w").write(c); n += 1
elif sc:
    open(os.path.join(dst, name + ".sol"), "w").write(sc); n = 1
print(f"  {n} fichier(s) -> {dst}/" if n else "  NON VÉRIFIÉ sur Etherscan : bytecode seulement (décompiler / demander le source)")
PY

echo "=== 3. greps de seam (lire ces lignes EN PREMIER — H2, H1, H5, H3/H4 du dossier)"
SRC="$(find "$OUT" -name '*.sol' -newer "$OUT/.raw.json" -o -name '*.sol' 2>/dev/null | head -50)"
if [ -n "$SRC" ]; then
  echo "--- fichiers :"; echo "$SRC" | sed 's/^/    /'
  HOOKSRC="$(grep -l 'contract TransferBlacklistHook' $SRC 2>/dev/null | head -1 || true)"
  [ -z "$HOOKSRC" ] && HOOKSRC="$(echo "$SRC" | head -1)"
  echo "--- fichier principal : $HOOKSRC"
  echo "--- H2/H5 : ordre des tests dans beforeTransfer (transferAgent / address(0) / blacklist / sanctions)"
  grep -n -E "function beforeTransfer|transferAgent|address\(0\)|isBlacklisted|blacklist|isSanctioned|sanction|return;|revert |require\(" "$HOOKSRC" | sed 's/^/    /'
  echo "--- H1 : appel externe protégé ? (try/catch, staticcall, extcodesize)"
  grep -n -E "try |catch|staticcall|extcodesize|code.length|ISanctions|IChainalysis" "$HOOKSRC" | sed 's/^/    /' || echo "    (aucun try/catch : un revert de l'oracle remonte au vault)"
  echo "--- H3/H4 : auth + stockage (owner/vault/global)"
  grep -n -E "requiresAuth|requiresVaultAuth|onlyOwner|Auth\(vault\)|owner\(\)|mapping\(|immutable|constant " "$HOOKSRC" | sed 's/^/    /'
  echo "--- events/erreurs déclarés (pour le census §5)"
  grep -n -E "^\s*(event|error) " $SRC | sed 's/^/    /'
fi

echo "=== 4. lectures live sur le hook $HOOK"
for sig in 'owner()(address)' 'pendingOwner()(address)' 'authority()(address)' 'version()(string)'; do
  printf "  %-24s %s\n" "$sig" "$(call "$HOOK" "$sig")"
done
echo "  oracle sanctions (getters usuels, best-effort — le nom réel est dans le source) :"
for sig in 'sanctionsList()(address)' 'sanctionsOracle()(address)' 'SANCTIONS_LIST()(address)' 'SANCTIONS_ORACLE()(address)' 'oracle()(address)'; do
  v="$(call "$HOOK" "$sig")"; [ "$v" != "n/a" ] && printf "    %-24s %s\n" "$sig" "$v"
done
echo "  code à $SANCTIONS_ORACLE sur Arbitrum : $(cast code "$SANCTIONS_ORACLE" --rpc-url "$RPC" | wc -c) hex chars (3 = VIDE => tout appel high-level revert)"
echo "  isSanctioned(0x0) sur l'oracle : $(call "$SANCTIONS_ORACLE" 'isSanctioned(address)(bool)' 0x0000000000000000000000000000000000000000)"

echo "=== 5. câblage vault -> hook et flag de transférabilité (V2 on-chain mandate)"
for V in "${VAULTS[@]}"; do
  echo "  vault $V"
  printf "    %-24s %s\n" "beforeTransferHook()" "$(call "$V" 'beforeTransferHook()(address)')"
  printf "    %-24s %s\n" "provisioner()" "$(call "$V" 'provisioner()(address)')"
  printf "    %-24s %s\n" "owner()" "$(call "$V" 'owner()(address)')"
  printf "    %-24s %s\n" "authority()" "$(call "$V" 'authority()(address)')"
  printf "    %-24s %s\n" "totalSupply()" "$(call "$V" 'totalSupply()(uint256)')"
  printf "    %-24s %s\n" "isVaultUnitTransferable" "$(call "$HOOK" 'isVaultUnitTransferable(address)(bool)' "$V")"
  hk="$(call "$V" 'beforeTransferHook()(address)')"
  [ "${hk,,}" = "${HOOK,,}" ] && echo "    => ce vault EST câblé sur le hook en scope" || echo "    => ce vault N'EST PAS câblé sur $HOOK (hook actuel : $hk) — chercher les vaults réellement câblés (§6)"
done

echo "=== 6. census des events émis par le hook (topic0 distincts) + bloc de déploiement"
LATEST="$(cast block-number --rpc-url "$RPC")"
lo=1; hi="$LATEST"
while (( lo < hi )); do
  mid=$(( (lo + hi) / 2 ))
  c="$(cast code "$HOOK" --block "$mid" --rpc-url "$RPC" 2>/dev/null || echo 0x)"
  if [[ "$c" == "0x" ]]; then lo=$((mid + 1)); else hi=$mid; fi
done
DEPLOY="$lo"; echo "  déployé au bloc ~$DEPLOY (latest $LATEST)"
RAW="$OUT/hook_logs.jsonl"; : > "$RAW"
CHUNK=200000; start="$DEPLOY"
while (( start <= LATEST )); do
  end=$(( start + CHUNK - 1 )); (( end > LATEST )) && end="$LATEST"
  cast logs --rpc-url "$RPC" --from-block "$start" --to-block "$end" --address "$HOOK" --json 2>/dev/null >> "$RAW" || true
  start=$(( end + 1 ))
done
python3 - "$RAW" "$OUT/abi.json" <<'PY'
import json, sys, subprocess, collections
raw, abipath = sys.argv[1], sys.argv[2]
logs = []
for line in open(raw):
    line = line.strip()
    if not line: continue
    try:
        j = json.loads(line); logs += j if isinstance(j, list) else [j]
    except Exception: pass
sigs = {}
try:
    for e in json.load(open(abipath)):
        if e.get("type") == "event":
            s = e["name"] + "(" + ",".join(i["type"] for i in e["inputs"]) + ")"
            h = subprocess.run(["cast", "keccak", s], capture_output=True, text=True).stdout.strip()
            sigs[h.lower()] = s
except Exception as ex:
    print("  (abi non décodable :", ex, ")")
cnt = collections.Counter((l.get("topics") or ["?"])[0].lower() for l in logs)
print(f"  {len(logs)} logs")
for t, n in cnt.most_common():
    print(f"    {n:6d}  {sigs.get(t, t)}")
# VaultUnitTransferableSet(address,bool) : liste des vaults touchés
for l in logs:
    t = (l.get("topics") or [""])[0].lower()
    if sigs.get(t, "").startswith("VaultUnitTransferableSet"):
        v = "0x" + l["topics"][1][-40:]; val = int(l.get("data", "0x0"), 16)
        print(f"    VaultUnitTransferableSet vault={v} transferable={bool(val)} block={int(l.get('blockNumber','0x0'),16)}")
PY

cat <<EOF
=== 7. suite (dossier §4-5)
  - Lire beforeTransfer contre H2 (ordre exemption transferAgent vs screen), H1 (try/catch oracle), H5 (to==0),
    H3 (auth de setIsVaultUnitsTransferable), H4 (admin blacklist), H8 (delta vs Spearbit 5.4.1 / PR 201).
  - Immunefi /information/ + /scope/ : copier VERBATIM « Impacts in Scope », known issues, exclusions, vault balance.
  - Ne rien rédiger avant d'avoir la liste d'impacts : un bypass de screening non listé = LATENT sous Primacy of Rules.
Sources : $OUT
EOF
