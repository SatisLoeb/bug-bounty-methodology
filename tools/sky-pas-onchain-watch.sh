#!/usr/bin/env bash
# sky-pas-onchain-watch.sh — surveillance ON-CHAIN read-only du système Sky PAS (mainnet).
# Moitié manquante de tools/sky-pas-watch.sh (qui ne voit que les repos de spells) :
# détecte les changements d'état faits HORS spell et l'activité cBeam réelle.
#
# À exécuter depuis une machine à réseau ouvert (Cowork local) — les RPC sont bloqués
# dans l'environnement Claude Code remote. Kit : memory/-home-malix-Desktop-BUGS/sky-pas-cowork-kit.md
#
# Deps: cast (foundry), python3, un RPC mainnet ($ETH_RPC_URL ou défaut publicnode).
# Usage: tools/sky-pas-onchain-watch.sh [state_dir]
# Exit:  0 = rien ; 10 = événements INFO ; 20 = ALERTE (WATCH condition W1-W4 / P-01 / zeroing)
set -euo pipefail

RPC="${ETH_RPC_URL:-https://ethereum-rpc.publicnode.com}"
STATE_DIR="${1:-$HOME/.sky-pas-watch}"
mkdir -p "$STATE_DIR"

# --- Contrats (mainnet, chainlog v1.20.20 + spells Grove 2026-08-27 / Osero 2026-09-24) ---
BEAM_STATE=0x1A1879E66547F90bfF87D45A5b0335950E019E02
CONFIGURATOR=0xb7E61Df6CAb0A51E9A5dab1A7DD3f942dDe5b929
TIMELOCK=0xB50a06Af02dDE44dB6EA7ee729403848c2B35293
GROVE_RL=0xE016Ae733A77Ba77E7907aAA749394Fc5e75C0e1
GROVE_AC=0x4F6d1704700cd494DD4cd9bF59c0C39DA1Bc9164
OSERO_RL=0xE9a78f34fe497e2186f81B8c014cd93B308BC62a
OSERO_AC=0x791D2a017532CfAD881c446e6bF93BbC3c0778b2
CONTRACTS=("$BEAM_STATE" "$CONFIGURATOR" "$TIMELOCK" "$GROVE_RL" "$GROVE_AC" "$OSERO_RL" "$OSERO_AC")
NAMES=("BeamState" "Configurator" "Timelock" "GroveRateLimits" "GroveAccessControls" "OseroRateLimits" "OseroAccessControls")

LATEST="$(cast block-number --rpc-url "$RPC")"

# --- Bloc de départ : bisection eth_getCode du plus ancien contrat (une fois, mis en cache) ---
find_deploy_block() { # $1 = address
  local lo=1 hi="$LATEST" mid code
  while (( lo < hi )); do
    mid=$(( (lo + hi) / 2 ))
    code="$(cast code "$1" --block "$mid" --rpc-url "$RPC" 2>/dev/null || echo 0x)"
    if [[ "$code" == "0x" ]]; then lo=$((mid + 1)); else hi=$mid; fi
  done
  echo "$lo"
}

LAST_FILE="$STATE_DIR/last_block"
if [[ -s "$LAST_FILE" ]]; then
  FROM=$(( $(cat "$LAST_FILE") + 1 ))
else
  # Premier run : démarrer au déploiement du plus ancien contrat surveillé (Grove RateLimits).
  echo "Premier run : bisection du bloc de déploiement de GroveRateLimits…" >&2
  FROM="$(find_deploy_block "$GROVE_RL")"
  echo "GroveRateLimits déployé au bloc $FROM — scan complet depuis ce bloc (une seule fois, long)." >&2
fi
(( FROM > LATEST )) && { echo "OK: à jour (bloc $LATEST)"; exit 0; }

# --- Collecte des logs, par chunks (limites getLogs des RPC publics) ---
CHUNK=40000
RAW="$STATE_DIR/raw_logs.jsonl"; : > "$RAW"
start="$FROM"
while (( start <= LATEST )); do
  end=$(( start + CHUNK - 1 )); (( end > LATEST )) && end="$LATEST"
  for i in "${!CONTRACTS[@]}"; do
    cast logs --rpc-url "$RPC" --from-block "$start" --to-block "$end" \
      --address "${CONTRACTS[$i]}" --json 2>/dev/null \
      | python3 -c "import sys,json;[print(json.dumps({**l,'who':'${NAMES[$i]}'})) for l in json.load(sys.stdin)]" >> "$RAW" || true
  done
  start=$(( end + 1 ))
done

# --- Analyse : W1-W4, P-01, zeroing, activité cBeam, changements d'admin ---
REPORT="$STATE_DIR/report.txt"
python3 - "$RAW" "$TIMELOCK" > "$REPORT" <<'PY'
import sys, json

MAX = (1 << 256) - 1
raw_path, timelock = sys.argv[1], sys.argv[2].lower()

T = {  # topic0 -> (nom, décodeur) ; hashes calculés via `cast keccak` et cross-checkés (Rely/RoleGranted/Paused/CallScheduled = valeurs canoniques)
 "0x2f28a70084cd7a0b15c322c46431d8581a1eb1e36f031c7b26c14f6bc22030e3": "AddInitRateLimits",
 "0xc87982b53cd6466c0946dc20072a43f8d8261dafc0c9000578957638c43c18ad": "DelInitRateLimits",
 "0xe097306657870f1c13929112dcd0ad42b8e41a819e63bb53c4a1b11d5bf59c78": "AddInitControllerActions",
 "0x048316335078539a1bf9454ffe0a433fc2bb5738542d92710d21a81fbf8df9db": "DelInitControllerActions",
 "0xb7fde01a6631c3933704fd4fd3f6478e61824517b4f8f38a44bfb6833fd38056": "AddCBeam",
 "0x9d6e9c59afbbb3f29ae91c8bbded878ca85d2c138aff026db1b0523854be69f5": "SetCBeamForRateLimits",
 "0xbd2fef67ff976a85c149699a6381c5c67b56e672d4f0fdf709dba5aee1918f31": "SetCBeamForController",
 "0xdd0e34038ac38b2a1ce960229778ac48a8719bc900b6c4f8d0475c6e8b385a60": "Rely",
 "0x184450df2e323acec0ed3b5c7531b81f9b4cdef7914dfd4c0a4317416bb5251b": "Deny",
 "0xbedf0f4abfe86d4ffad593d9607fe70e83ea706033d44d24b3b6283cf3fc4f6b": "Stop",
 "0x1b55ba3aa851a46be3b365aee5b5c140edd620d578922f3e8466d2cbd96f954b": "Start",
 "0x8aae9c6d6d990871eede637775f0fe522252d829b7545a5e7534409c73000251": "SetHop",
 "0x4f5736b8d3cb02079e7b029deaa2e7ba5b8db860cca8c7ecea73f35e70590c8f": "SetMaxChange",
 "0x356822943b80f809508a684c67d901d5c13b6a22161bf07d510e50a6cb727028": "RateLimitDataSet",
 "0x2f8788117e7eff1d82e926ec794901d17c78024a50270940304540a733656f0d": "RoleGranted",
 "0xf6391f5c32d9c69d2a47ea670b442974b53935d1edc7fd64eb21e047a839171b": "RoleRevoked",
 "0x62e78cea01bee320cd4e420270b5ea74000d11b0c9f74754ebdbfc544b05a258": "Paused",
 "0x5db9ee0a495bf2e6ff9c91a7834c1ba4fdd244a5e8aa4e537bd38aeae4b073aa": "Unpaused",
 "0x4cf4410cc57040e44862ef0f45f3dd5a5e02db8eb8add648d4b0e236f1d07dca": "CallScheduled",
 "0x6529560ab8839bcce1238e51b3e901643111963e33873328475adaf658d62f38": "SetRateLimit",
 "0x7ca8b1108db1e4d18ef4793d363d1e691e918b171fd612aeff46628f2ef1b7e9": "CallControllerAction",
}

def addr(t):  return "0x" + t[-40:]
def u256(h):  return int(h, 16)
def words(d):
    d = d[2:] if d.startswith("0x") else d
    return [d[i:i+64] for i in range(0, len(d), 64)]

alerts, infos = [], []
seen = 0
for line in open(raw_path):
    line = line.strip()
    if not line: continue
    l = json.loads(line); seen += 1
    topics = l.get("topics", []);  ev = T.get(topics[0].lower()) if topics else None
    if not ev: continue
    who, blk, tx = l["who"], int(l.get("blockNumber", "0x0"), 16), l.get("transactionHash", "?")
    w = words(l.get("data", "0x"))
    loc = f"[{who} blk {blk} tx {tx}]"

    if ev == "AddInitRateLimits":
        key, rl = topics[1], addr(topics[2]); mx, sl = u256(w[0]), u256(w[1])
        if mx == MAX and sl > 0:
            alerts.append(f"W1 *** P-01 ARMÉ *** {loc} default (max, slope={sl}) pour key {key} rl={rl} — le gap unlimited-slope devient exploitable, voir dossier")
        elif rl == "0x" + "0"*40:
            alerts.append(f"W2 {loc} default GÉNÉRALE address(0) pour key {key} (max={mx}, slope={sl}) — s'applique cross-Star (namespace partagé)")
        else:
            infos.append(f"INFO {loc} AddInitRateLimits key={key} rl={rl} max={mx} slope={sl}")
    elif ev == "AddInitControllerActions":
        key, ctrl = topics[1], addr(topics[2])
        if ctrl == "0x" + "0"*40:
            alerts.append(f"W3 {loc} calldata GÉNÉRALE address(0) approuvée, hash={key} — exécutable sur tous les controllers pairés")
        else:
            infos.append(f"INFO {loc} AddInitControllerActions hash={key} controller={ctrl}")
    elif ev == "Unpaused" and who == "Timelock":
        alerts.append(f"W4 {loc} TIMELOCK DÉ-PAUSÉ — le flux DELAYED est actif (Core Council peut proposer, délai + cancellers seule garde)")
    elif ev == "RateLimitDataSet":
        mx, sl = u256(w[0]), u256(w[1])
        if mx == MAX and sl > 0:
            alerts.append(f"P-01 ÉTAT ARMÉ {loc} key {topics[1]} posée à (max, slope={sl}) DANS le PAU — unlimited per PAU mais non protégée par le Configurator")
        else:
            infos.append(f"INFO {loc} RateLimitDataSet key={topics[1]} max={mx} slope={sl}")
    elif ev == "SetRateLimit":  # action cBeam via Configurator
        rl, key = addr(topics[1]), topics[2]; mx, sl = u256(w[0]), u256(w[1])
        if mx == 0 and sl == 0:
            alerts.append(f"ZEROING {loc} un cBeam a mis key {key} (rl={rl}) à (0,0) — porte à sens unique via Configurator, récupération = spell")
        else:
            infos.append(f"cBEAM {loc} setRateLimit key={key} rl={rl} max={mx} slope={sl}")
    elif ev == "CallControllerAction":
        infos.append(f"cBEAM {loc} callControllerAction controller={addr(topics[1])} data={l.get('data','0x')[:138]}…")
    elif ev in ("RoleGranted", "RoleRevoked"):
        role, acct = topics[1], addr(topics[2])
        if role == "0x" + "0"*64:  # DEFAULT_ADMIN_ROLE
            alerts.append(f"ADMIN {loc} {ev} DEFAULT_ADMIN_ROLE {'->' if ev=='RoleGranted' else 'retiré à'} {acct} — changement de superadmin PAU/Timelock")
        else:
            infos.append(f"INFO {loc} {ev} role={role} account={acct}")
    elif ev == "CallScheduled":
        infos.append(f"TIMELOCK {loc} proposal schedulée id={topics[1]} target={addr(w[0])} data={('0x'+''.join(w))[:138]}… — À LIRE avant exécution")
    elif ev in ("Stop", "Start", "Paused", "SetHop", "SetMaxChange", "Rely", "Deny",
                "AddCBeam", "SetCBeamForRateLimits", "SetCBeamForController",
                "DelInitRateLimits", "DelInitControllerActions"):
        infos.append(f"GOV {loc} {ev} topics={topics[1:]} data={l.get('data','0x')[:138]}")

print(f"# logs bruts vus: {seen}")
if alerts:
    print("\n=== ALERTES (WATCH conditions) ===")
    print("\n".join(alerts))
if infos:
    print("\n=== ÉVÉNEMENTS ===")
    print("\n".join(infos))
print(f"\nEXITCODE={20 if alerts else (10 if infos else 0)}")
PY

cat "$REPORT"
echo "$LATEST" > "$LAST_FILE"
code="$(grep -oE 'EXITCODE=[0-9]+' "$REPORT" | cut -d= -f2)"
exit "${code:-0}"
